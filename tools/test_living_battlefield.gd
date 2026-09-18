extends Node

const FieldScript = preload("res://src/world/DevilsWorkshopField.gd")
const MovementSystemScript = preload("res://src/MovementSystem.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

class FakeBattleActor:
	extends Node2D

	var occupied_grids: Array[Vector2i] = []

	func get_occupied_grids() -> Array[Vector2i]:
		return occupied_grids


var _failed := false


func _ready() -> void:
	BattleEncounterSession.clear_pending_encounter()
	var field := FieldScript.new()
	add_child(field)
	await get_tree().process_frame

	_expect(field.get_battlefield_id() == "training_clearing", "Default battle runtime must use Training Clearing.")
	_expect(field.get_grid_size() == Vector2i(11, 15), "Training Clearing must render the compact 11x15 grid.")
	_expect(
		field.tile_map_data.size() == field.get_grid_width() * field.get_grid_height(),
		"Battlefield must author every runtime tactical cell."
	)

	var definition: BattlefieldDefinition = field.get_battlefield_definition()
	_expect(definition != null, "Runtime field must expose its BattlefieldDefinition.")
	if definition != null:
		_validate_definition_projection(field, definition)
		_validate_environment(field, definition)
		_validate_spawn_zones(field, definition)
		_validate_pathfinding(field, definition)

	if _failed:
		push_error("living battlefield regression failed")
		get_tree().quit(1)
		return
	print("living battlefield regression passed")
	get_tree().quit()


func _validate_definition_projection(field: Node, definition: BattlefieldDefinition) -> void:
	for prop: Dictionary in definition.props:
		var grid := Vector2i(prop.get("grid", Vector2i(-1, -1)))
		var kind := String(prop.get("kind", ""))
		_expect(
			field.get_static_tile_block_reason(grid) == "terrain_blocked",
			"Every authored physical prop must block its owning tactical cell."
		)
		var raw_tile = field.tile_map_data.get(grid, {})
		_expect(
			raw_tile is Dictionary and String((raw_tile as Dictionary).get("blocker_kind", "")) == kind,
			"Runtime blocker metadata must match the authored prop kind at %s." % grid
		)

	for cost: Dictionary in definition.movement_cost_cells:
		var grid := Vector2i(cost.get("grid", Vector2i(-1, -1)))
		var expected := int(cost.get("cost", 1))
		_expect(field.get_movement_cost(grid) == expected, "Runtime movement cost must match BattlefieldDefinition at %s." % grid)

	_expect(field.get_node_or_null("PerimeterWater") != null, "Dynamic battlefield perimeter water must still render.")


func _validate_environment(field: Node, definition: BattlefieldDefinition) -> void:
	var environment := field.get_node_or_null("BattlefieldEnvironment")
	_expect(environment != null, "Battlefield environment layer must exist.")
	if environment == null:
		return
	_expect(environment.get_child_count() == definition.props.size(), "Environment must render exactly one visual prop per authored physical prop.")

	var large_tree: Sprite2D = null
	var large_tree_grid := Vector2i.ZERO
	for child in environment.get_children():
		if child is Sprite2D and bool(child.get_meta("large_canopy_occluder", false)):
			large_tree = child as Sprite2D
			large_tree_grid = Vector2i(child.get_meta("grid", Vector2i.ZERO))
			break
	_expect(large_tree != null, "Default compact battlefield must include a large-canopy occluder.")
	if large_tree != null:
		_validate_large_tree_occlusion(environment, large_tree, large_tree_grid)


func _validate_large_tree_occlusion(environment: Node, large_tree: Sprite2D, tree_grid: Vector2i) -> void:
	var actor := FakeBattleActor.new()
	actor.name = "OcclusionProbe"
	environment.get_parent().get_parent().add_child(actor)

	var directly_behind := tree_grid - Vector2i.ONE
	actor.occupied_grids = [directly_behind]
	_expect(bool(environment.call("_should_fade_for_actor", large_tree, actor)), "Large oak must fade for the exact tile directly behind its canopy.")

	actor.occupied_grids = [tree_grid + Vector2i(-1, 0)]
	_expect(not bool(environment.call("_should_fade_for_actor", large_tree, actor)), "Side-adjacent units must not fade a large oak.")

	actor.occupied_grids = [tree_grid + Vector2i(0, -1)]
	_expect(not bool(environment.call("_should_fade_for_actor", large_tree, actor)), "The opposite side-adjacent tile must not fade a large oak.")

	actor.occupied_grids = [
		directly_behind,
		directly_behind + Vector2i.RIGHT,
		directly_behind + Vector2i.DOWN,
		directly_behind + Vector2i.ONE,
	]
	_expect(bool(environment.call("_should_fade_for_actor", large_tree, actor)), "A multi-tile actor covering the exact rear tile must fade the canopy.")
	actor.queue_free()


func _validate_spawn_zones(field: Node, definition: BattlefieldDefinition) -> void:
	var runtime_script = preload("res://src/battle/CombatDigimonRuntimeController.gd")
	var runtime := runtime_script.new()
	for player_side in [true, false]:
		var raw_candidates = runtime.call("_spawn_zone_candidates", field, player_side)
		_expect(raw_candidates is Array, "Runtime spawn-zone query must return authored cells.")
		if not raw_candidates is Array:
			continue
		var expected := definition.player_deployment_cells if player_side else definition.enemy_deployment_cells
		_expect(raw_candidates.size() == expected.size(), "Runtime spawn zones must preserve all authored deployment cells.")
		for raw_grid in raw_candidates:
			if raw_grid is Vector2i:
				_expect(expected.has(Vector2i(raw_grid)), "Spawn runtime must not invent cells outside the authored deployment zone.")


func _validate_pathfinding(field: Node, definition: BattlefieldDefinition) -> void:
	var movement = MovementSystemScript.new()
	var origin := definition.player_deployment_cells[0]
	var destination := definition.enemy_deployment_cells[0]
	var path: Array[Vector2i] = movement.find_path(field, null, null, origin, destination, 80)
	_expect(not path.is_empty(), "Compact battlefield must preserve at least one traversable route between deployment zones.")
	for grid: Vector2i in path:
		_expect(field.get_static_tile_block_reason(grid).is_empty(), "Pathfinding must never enter an authored blocker.")
	_expect(
		FootprintScript.max_extent(definition.max_supported_footprint_id()) == 2,
		"Training Clearing must retain its declared 2x2 maximum footprint."
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
