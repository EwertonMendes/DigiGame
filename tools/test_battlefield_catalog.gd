extends SceneTree

const CatalogScript = preload("res://src/world/BattlefieldCatalog.gd")
const Footprint = preload("res://src/combat/BattleFootprint.gd")
const Planner = preload("res://src/combat/FootprintDeploymentPlanner.gd")

var _failures: Array[String] = []


func _init() -> void:
	var catalog := CatalogScript.new() as BattlefieldCatalog
	_expect(catalog.load_default(), "Battlefield catalog must load without validation errors.")
	for error in catalog.validation_errors():
		_failures.append("Catalog validation: %s" % error)

	var definitions := catalog.all_definitions()
	_expect(definitions.size() == 5, "Battlefield V2 must expose the five initial authored layouts.")

	var expected_sizes := {
		"training_clearing": Vector2i(11, 15),
		"twin_grove": Vector2i(13, 17),
		"forest_crossing": Vector2i(11, 17),
		"broken_clearing": Vector2i(13, 17),
		"grand_digital_field": Vector2i(15, 19),
	}
	for battlefield_id: String in expected_sizes:
		var definition := catalog.get_by_id(battlefield_id)
		_expect(definition != null, "Catalog must expose battlefield '%s'." % battlefield_id)
		if definition == null:
			continue
		_expect(definition.grid_size == expected_sizes[battlefield_id], "%s must preserve its authored dimensions." % battlefield_id)
		_expect(definition.validate().is_empty(), "%s must pass standalone battlefield validation." % battlefield_id)
		_assert_deployment_contract(definition)

	var compact := catalog.get_by_id("training_clearing")
	_expect(compact != null and compact.max_supported_footprint_id() == Footprint.LARGE_2X2, "Training Clearing must support parties up to 2x2.")
	_expect(compact != null and not compact.supports_teams([Footprint.LARGE_3X3], [Footprint.SINGLE]), "Compact maps must reject unsupported 3x3 combatants.")

	var grand := catalog.get_by_id("grand_digital_field")
	var triple_colossal := [Footprint.LARGE_3X3, Footprint.LARGE_3X3, Footprint.LARGE_3X3]
	_expect(grand != null and grand.max_supported_footprint_id() == Footprint.LARGE_3X3, "Grand Digital Field must advertise 3x3 support.")
	_expect(grand != null and grand.supports_teams(triple_colossal, triple_colossal), "Grand Digital Field must fit three 3x3 Digimon on both teams.")

	var compatible := catalog.compatible_definitions(triple_colossal, triple_colossal)
	_expect(compatible.size() == 1, "Only the authored colossal field should accept two full 3x3 teams in the initial catalog.")
	if compatible.size() == 1:
		_expect(compatible[0].battlefield_id == "grand_digital_field", "3x3 compatibility must select Grand Digital Field.")

	var selected := catalog.select_for_battle(triple_colossal, triple_colossal, "", 73)
	_expect(selected != null and selected.battlefield_id == "grand_digital_field", "Automatic field selection must route 3x3 encounters to Grand Digital Field.")

	if _failures.is_empty():
		print("[BattlefieldCatalogTest] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[BattlefieldCatalogTest] %s" % failure)
	quit(1)


func _assert_deployment_contract(definition: BattlefieldDefinition) -> void:
	var footprint_id := definition.max_supported_footprint_id()
	var footprints: Array = []
	for _index in range(definition.recommended_team_size):
		footprints.append(footprint_id)
	var blockers := definition.blocker_cells()
	var player_plan := Planner.plan(footprints, definition.player_deployment_cells, blockers)
	var enemy_plan := Planner.plan(footprints, definition.enemy_deployment_cells, blockers)
	_expect(bool(player_plan.get("ok", false)), "%s player deployment must fit its declared max footprint." % definition.display_name)
	_expect(bool(enemy_plan.get("ok", false)), "%s enemy deployment must fit its declared max footprint." % definition.display_name)

	for grid: Vector2i in definition.player_deployment_cells + definition.enemy_deployment_cells:
		_expect(definition.blocker_kind_at(grid).is_empty(), "%s deployment cells must never contain physical props." % definition.display_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
