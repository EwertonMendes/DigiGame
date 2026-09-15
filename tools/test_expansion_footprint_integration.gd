extends Node

const BattleControllerDomainScript = preload("res://src/BattleControllerDomain.gd")
const CombatRuntimeScript = preload("res://src/battle/CombatDigimonRuntimeController.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")
const MapValidatorScript = preload("res://src/combat/FootprintMapValidator.gd")
const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const ExpansionQuestCatalogScript = preload("res://src/quests/ExpansionQuestCatalog.gd")

var _failures: Array[String] = []


class ForcedActor:
	extends Node2D

	var grid_anchor := Vector2i.ZERO
	var footprint_id := FootprintScript.SINGLE

	func _init(anchor: Vector2i, size_id: String = FootprintScript.SINGLE) -> void:
		grid_anchor = anchor
		footprint_id = size_id
		position = Vector2(anchor)

	func get_tile_world_position() -> Vector2:
		return Vector2(grid_anchor)

	func get_battle_footprint_id() -> String:
		return footprint_id

	func get_occupied_grids(override_anchor = null) -> Array[Vector2i]:
		var anchor := grid_anchor if override_anchor == null else Vector2i(override_anchor)
		return FootprintScript.occupied_grids(anchor, footprint_id)

	func debug_relocate_to_grid(destination: Vector2i, _field: Node) -> bool:
		grid_anchor = destination
		position = Vector2(destination)
		return true


class ForcedField:
	extends Node2D

	var board_size := Vector2i(8, 6)
	var blocked_cells: Dictionary = {}
	var occupied_cells: Dictionary = {}

	func world_to_grid(local_position: Vector2) -> Vector2i:
		return Vector2i(roundi(local_position.x), roundi(local_position.y))

	func get_actor_anchor_block_reason(anchor: Vector2i, actor: Node) -> String:
		var footprint := FootprintScript.SINGLE
		if actor != null and actor.has_method("get_battle_footprint_id"):
			footprint = String(actor.call("get_battle_footprint_id"))
		for cell: Vector2i in FootprintScript.occupied_grids(anchor, footprint):
			if cell.x < 0 or cell.y < 0 or cell.x >= board_size.x or cell.y >= board_size.y:
				return "out_of_bounds"
			if blocked_cells.has(cell):
				return "terrain_blocked"
			var occupant = occupied_cells.get(cell)
			if occupant != null and occupant != actor:
				return "occupied"
		return ""


class TerrainField:
	extends Node2D
	var tile_map_data: Dictionary = {}


func _ready() -> void:
	_test_forced_movement_contract()
	_test_story_map_validation()
	_test_expansion_quest_loop()
	_test_multi_cell_terrain_context()

	if _failures.is_empty():
		print("[ExpansionFootprintIntegrationTest] PASS")
		get_tree().quit()
		return
	for failure in _failures:
		push_error("[ExpansionFootprintIntegrationTest] %s" % failure)
	get_tree().quit(1)


func _test_forced_movement_contract() -> void:
	var controller = BattleControllerDomainScript.new()
	var field := ForcedField.new()
	var source := ForcedActor.new(Vector2i(0, 1), FootprintScript.SINGLE)
	var target := ForcedActor.new(Vector2i(2, 1), FootprintScript.LARGE_2X2)
	controller._field = field
	controller.current_actor = source

	var moved := bool(controller._apply_forced_movement(target, "push", 1, "normal"))
	_expect(not moved and target.grid_anchor == Vector2i(2, 1), "Expanded 2x2 Digimon must ignore normal forced movement.")

	moved = bool(controller._apply_forced_movement(target, "push", 1, "heavy"))
	_expect(moved and target.grid_anchor == Vector2i(3, 1), "Heavy forced movement must shift an expanded 2x2 Digimon by one anchor cell.")

	field.blocked_cells[Vector2i(5, 2)] = true
	moved = bool(controller._apply_forced_movement(target, "push", 2, "heavy"))
	_expect(not moved and target.grid_anchor == Vector2i(3, 1), "Forced movement must stop before an obstacle touched by any footprint cell.")
	field.blocked_cells.clear()

	var blocker := ForcedActor.new(Vector2i(5, 1), FootprintScript.SINGLE)
	field.occupied_cells[Vector2i(5, 1)] = blocker
	moved = bool(controller._apply_forced_movement(target, "push", 1, "heavy"))
	_expect(not moved and target.grid_anchor == Vector2i(3, 1), "Forced movement must stop before another unit touched by the footprint.")
	field.occupied_cells.clear()

	moved = bool(controller._apply_forced_movement(target, "pull", 1, "heavy"))
	_expect(moved and target.grid_anchor == Vector2i(2, 1), "Heavy pull must move the complete footprint one cell toward the source.")

	target.grid_anchor = Vector2i(6, 1)
	target.position = Vector2(target.grid_anchor)
	moved = bool(controller._apply_forced_movement(target, "push", 1, "heavy"))
	_expect(not moved and target.grid_anchor == Vector2i(6, 1), "Forced movement must stop before a 2x2 footprint crosses map bounds.")

	controller.free()
	field.free()
	source.free()
	target.free()
	blocker.free()


func _test_story_map_validation() -> void:
	var walkable := _rect_cells(0, 0, 8, 8)
	var deployment := _rect_cells(0, 6, 6, 2)
	var objective_region := _rect_cells(0, 0, 6, 2)
	var valid := MapValidatorScript.validate_story_layout(walkable, deployment, objective_region, 3)
	_expect(bool(valid.get("ok", false)), "A map with a continuous 2-tile-wide route and 6x2 deployment must validate.")

	var too_small := MapValidatorScript.validate_story_layout(walkable, _rect_cells(0, 6, 5, 2), objective_region, 3)
	_expect(not bool(too_small.get("deployment_ok", true)), "Story validation must reject a deployment zone that cannot fit three 2x2 Digimon.")

	var bottleneck: Array[Vector2i] = []
	bottleneck.append_array(_rect_cells(0, 5, 6, 3))
	bottleneck.append_array(_rect_cells(0, 0, 6, 3))
	bottleneck.append(Vector2i(2, 3))
	bottleneck.append(Vector2i(2, 4))
	var narrow := MapValidatorScript.validate_story_layout(bottleneck, _rect_cells(0, 6, 6, 2), _rect_cells(0, 0, 6, 2), 3)
	_expect(not bool(narrow.get("route_ok", true)), "A one-cell bottleneck must fail 2x2 story-route validation.")

	var mixed_objectives: Array[Vector2i] = [Vector2i(0, 0), Vector2i(20, 20)]
	var region_result := MapValidatorScript.validate_story_layout(walkable, deployment, mixed_objectives, 3)
	_expect(bool(region_result.get("route_ok", false)), "Objective-region mode must pass when at least one cell in the target region is reachable.")
	var all_result := MapValidatorScript.validate_required_objectives(walkable, deployment, mixed_objectives, 3)
	_expect(not bool(all_result.get("route_ok", true)), "Required-objective mode must reject any individually unreachable objective.")


func _test_expansion_quest_loop() -> void:
	var database: DigimonDatabase = DatabaseScript.new()
	_expect(database.load_default(), "Species database must load for Expansion quest integration.")
	if _failures.size() > 0:
		return
	var factory: DigimonFactory = FactoryScript.new(database)
	var collection: PlayerCollection = CollectionScript.new()
	var target := factory.create_player_by_name("War Greymon", 30, 100)
	target.tier = "S"
	collection.add_instance(target, "tier_s_target", "War Greymon")

	var sync := ExpansionQuestCatalogScript.sync_progression_unlocks(collection)
	_expect(bool(sync.get("has_tier_s_eligible", false)), "A persisted or debug-created Tier S+ individual must be detected as Expansion-eligible.")
	var status := ExpansionQuestCatalogScript.quest_status(collection)
	_expect(String((status.get("tutorial", {}) as Dictionary).get("state", "")) == "active", "Tier S+ roster state must activate the one-time Expansion tutorial quest.")

	var tutorial_win := ExpansionQuestCatalogScript.record_victory(collection, true)
	_expect(bool(tutorial_win.get("tutorial_completed_now", false)), "The tutorial battle must complete the Expansion teaching quest.")
	_expect(collection.get_item_count("expansion_core") == 1, "The Expansion tutorial must guarantee exactly one Core.")
	_expect(collection.get_item_count("expansion_fragment") == 0, "The tutorial completion battle must not simultaneously farm an advanced Fragment.")

	status = ExpansionQuestCatalogScript.quest_status(collection)
	_expect(String((status.get("advanced", {}) as Dictionary).get("state", "")) == "active", "Completing the tutorial must activate the repeatable advanced Expansion quest.")
	for _index in range(3):
		ExpansionQuestCatalogScript.record_victory(collection, true)
	_expect(collection.get_item_count("expansion_fragment") == 1, "Three qualifying advanced wins must guarantee one Expansion Fragment.")
	for _index in range(3):
		ExpansionQuestCatalogScript.record_victory(collection, true)
	_expect(collection.get_item_count("expansion_fragment") == 2, "The advanced Expansion quest must remain repeatable without a hidden cap.")
	status = ExpansionQuestCatalogScript.quest_status(collection)
	_expect(int((status.get("advanced", {}) as Dictionary).get("completion_count", 0)) == 2, "Repeatable Expansion quest completion count must persist across cycles.")


func _test_multi_cell_terrain_context() -> void:
	var runtime = CombatRuntimeScript.new()
	var actor := Node.new()
	var field := TerrainField.new()
	field.tile_map_data = {
		Vector2i(1, 1): {"defense_modifier": 0.15, "hazard_id": "lava", "height": 2.0},
		Vector2i(2, 1): {"defense_modifier": -0.20, "hazard_id": "lava", "height": 2.0},
		Vector2i(1, 2): {"defense_modifier": 0.05, "hazards": ["poison", "lava"], "height": 2.0},
		Vector2i(2, 2): {"defense_modifier": 0.00, "height": 2.0},
	}
	var cells := FootprintScript.occupied_grids(Vector2i(1, 1), FootprintScript.LARGE_2X2)
	runtime._update_actor_terrain_context(actor, cells, field)
	_expect(is_equal_approx(float(actor.get_meta("terrain_defense_modifier", 999.0)), -0.20), "A multi-cell unit must use the least favorable occupied defense modifier.")
	var hazards = actor.get_meta("terrain_hazard_ids", [])
	_expect(hazards is Array and (hazards as Array).size() == 2 and (hazards as Array).has("lava") and (hazards as Array).has("poison"), "Hazards intersecting several occupied cells must be deduplicated per unit.")
	_expect(bool(actor.get_meta("terrain_height_supported", false)), "Height support metadata must require and record support under every occupied cell.")

	runtime.free()
	actor.free()
	field.free()


func _rect_cells(start_x: int, start_y: int, width: int, height: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			result.append(Vector2i(x, y))
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
