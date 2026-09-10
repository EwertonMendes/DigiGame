extends SceneTree

const FieldScript = preload("res://src/battle/BattleFieldDomain.gd")
const ControllerScript = preload("res://src/battle/CombatDigimonRuntimeController.gd")

const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := Node2D.new()
	main.name = "Main"
	root.add_child(main)

	var field := FieldScript.new() as Node2D
	field.name = "Blocks"
	main.add_child(field)

	var controller := ControllerScript.new() as Node2D
	controller.name = "DigimonController"
	main.add_child(controller)

	await process_frame
	await process_frame

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
		quit(1)
		return

	var enemy_tile_world := Vector2(enemy.call("get_tile_world_position"))
	var enemy_grid := Vector2i(field.call("world_to_grid", field.to_local(enemy_tile_world)))
	var down_right_grid := enemy_grid + Vector2i(1, 0)
	var down_right_local := Vector2(field.call("grid_to_world", down_right_grid))
	var down_right_world := field.to_global(down_right_local)
	greymon.global_position = down_right_world + Vector2(greymon.get("PLAYER_POSITION_DEVIATION"))

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
		var resolved_greymon := controller.call("get_digimon_under_pointer", down_right_world + offset) as Node
		_assert(resolved_greymon == greymon, "Greymon tile did not resolve to Greymon at offset %s" % offset)

	if _failed:
		quit(1)
		return
	print("tile-based Digimon selection regression passed")
	quit(0)


var _failed := false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
