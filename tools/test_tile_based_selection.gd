extends Node2D

const FieldScript = preload("res://src/battle/BattleFieldDomain.gd")
const ControllerScript = preload("res://src/battle/CombatDigimonRuntimeController.gd")

const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const TEST_ENEMY_GRID := Vector2i(7, 12)
const TEST_GREYMON_GRID := Vector2i(8, 12)

var _failed := false


func _ready() -> void:
	var field := FieldScript.new() as Node2D
	field.name = "Blocks"
	add_child(field)

	var controller := ControllerScript.new() as Node2D
	controller.name = "DigimonController"
	add_child(controller)

	_run(field, controller)
	if _failed:
		get_tree().quit(1)
		return
	print("tile-based Digimon selection regression passed")
	get_tree().quit(0)


func _run(field: Node2D, controller: Node2D) -> void:
	var greymon: Node = null
	var enemy: Node = null
	for actor: Node in controller.call("get_battle_digimons"):
		if String(actor.get("digimon_key")) == "greymon" and bool(actor.get("is_player_controlled")):
			greymon = actor
		if String(actor.get("digimon_key")) == "koromon" and not bool(actor.get("is_player_controlled")):
			enemy = actor

	_assert(greymon != null, "Greymon test actor was not spawned")
	_assert(enemy != null, "Koromon test actor was not spawned")
	if greymon == null or enemy == null:
		return

	# Footprint ownership is anchored by grid_anchor. Test relocation therefore uses
	# the actor relocation contract instead of moving only its visual transform.
	# This keeps the occupancy index and rendered position in sync exactly as real
	# movement does.
	var map_data_variant = field.get("tile_map_data")
	var map_data: Dictionary = map_data_variant if map_data_variant is Dictionary else {}
	_assert(map_data.has(TEST_ENEMY_GRID), "Deterministic enemy test tile is missing from the field")
	_assert(map_data.has(TEST_GREYMON_GRID), "Deterministic Greymon test tile is missing from the field")
	if not map_data.has(TEST_ENEMY_GRID) or not map_data.has(TEST_GREYMON_GRID):
		return

	_move_other_actors_out_of_test_tiles(field, controller, greymon, enemy)
	_assert(enemy.has_method("debug_relocate_to_grid"), "Battle actor must expose grid-aware debug relocation")
	_assert(greymon.has_method("debug_relocate_to_grid"), "Battle actor must expose grid-aware debug relocation")
	if not enemy.has_method("debug_relocate_to_grid") or not greymon.has_method("debug_relocate_to_grid"):
		return
	_assert(bool(enemy.call("debug_relocate_to_grid", TEST_ENEMY_GRID, field)), "Koromon test actor could not relocate to its reserved grid anchor")
	controller.call("refresh_occupancy_index")
	_assert(bool(greymon.call("debug_relocate_to_grid", TEST_GREYMON_GRID, field)), "Greymon test actor could not relocate to its reserved grid anchor")
	controller.call("refresh_occupancy_index")

	var enemy_local := Vector2(field.call("grid_to_world", TEST_ENEMY_GRID))
	var enemy_tile_world := field.to_global(enemy_local)
	var greymon_local := Vector2(field.call("grid_to_world", TEST_GREYMON_GRID))
	var greymon_tile_world := field.to_global(greymon_local)

	# Every sampled point inside the occupied diamond must resolve to the Digimon
	# standing on that tile, independent of sprite size, transparent pixels, or
	# neighboring sprites overlapping the same screen area.
	var found_enemy_tile_point_outside_enemy_sprite := false
	var found_greymon_overlap_point := false
	for y in range(-14, 15, 2):
		for x in range(-30, 31, 2):
			var normalized_distance := absf(float(x)) / TILE_HALF_WIDTH + absf(float(y)) / TILE_HALF_HEIGHT
			if normalized_distance > 0.88:
				continue
			var point := enemy_tile_world + Vector2(float(x), float(y))
			var resolved := controller.call("get_digimon_under_pointer", point) as Node
			_assert(resolved == enemy, "Enemy tile point resolved to the wrong Digimon at offset %s" % Vector2i(x, y))

			if enemy.has_method("is_pointer_over") and not bool(enemy.call("is_pointer_over", point)):
				found_enemy_tile_point_outside_enemy_sprite = true
			if greymon.has_method("is_pointer_over") and bool(greymon.call("is_pointer_over", point)):
				found_greymon_overlap_point = true
				_assert(resolved == enemy, "Greymon's overlapping sprite stole the enemy tile interaction")

	_assert(
		found_enemy_tile_point_outside_enemy_sprite,
		"Regression setup did not cover a tile point outside the enemy sprite bounds"
	)
	_assert(
		found_greymon_overlap_point,
		"Regression setup did not reproduce Greymon's sprite overlapping the enemy tile"
	)

	# The same tile ownership rule must also hold for Greymon's own tile.
	for offset in [Vector2.ZERO, Vector2(0.0, 10.0), Vector2(18.0, 0.0), Vector2(-18.0, 0.0)]:
		var resolved_greymon := controller.call("get_digimon_under_pointer", greymon_tile_world + offset) as Node
		_assert(resolved_greymon == greymon, "Greymon tile did not resolve to Greymon at offset %s" % offset)


func _move_other_actors_out_of_test_tiles(field: Node2D, controller: Node2D, greymon: Node, enemy: Node) -> void:
	var reserved := {TEST_ENEMY_GRID: true, TEST_GREYMON_GRID: true}
	var map_data_variant = field.get("tile_map_data")
	var map_data: Dictionary = map_data_variant if map_data_variant is Dictionary else {}
	for actor: Node in controller.call("get_battle_digimons"):
		if actor == greymon or actor == enemy or not actor.has_method("get_occupied_grids"):
			continue
		var overlaps_reserved := false
		for occupied_grid: Vector2i in actor.call("get_occupied_grids"):
			if reserved.has(occupied_grid):
				overlaps_reserved = true
				break
		if not overlaps_reserved:
			continue
		_assert(actor.has_method("debug_relocate_to_grid"), "Contaminating battle actor must support grid-aware relocation")
		if not actor.has_method("debug_relocate_to_grid"):
			continue
		var relocated := false
		var candidates: Array[Vector2i] = []
		for raw_grid in map_data.keys():
			if raw_grid is Vector2i:
				candidates.append(Vector2i(raw_grid))
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y if a.y != b.y else a.x < b.x
		)
		for candidate in candidates:
			if reserved.has(candidate):
				continue
			if bool(actor.call("debug_relocate_to_grid", candidate, field)):
				controller.call("refresh_occupancy_index")
				relocated = true
				break
		_assert(relocated, "Could not clear reserved tile-selection regression cells without violating occupancy rules")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)