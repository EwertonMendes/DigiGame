extends CharacterBody2D

const TurnIndicatorScript = preload("res://src/TurnIndicator.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")
const VEEMON_SPACED_9_IDLE_FRAME := {
	"down_left": 3,
	"down_right": 5,
	"up_left": 1,
	"up_right": 1,
}
const VEEMON_SPACED_9_WALK_SEQUENCE := {
	"down_left": [3, 4, 3],
	"down_right": [5, 4, 5],
	"up_left": [0, 1, 2],
	"up_right": [0, 1, 2],
}
const VEEMON_SPACED_9_FLIP_H := {
	"down_left": false,
	"down_right": false,
	"up_left": false,
	"up_right": true,
}
const VEEMON_SPACED_9_CELL_SIZE := 32
const VEEMON_SPACED_9_CELL_STRIDE := 33
const SELECTED_FRAME_DURATION := 0.15
const MOVE_STEP_DURATION := 0.16
const FACING_DEADZONE := 5.0
const HOVER_PADDING := 3.0

var PLAYER_POSITION_DEVIATION := Vector2.ZERO
var PARTICLES_POSITION_DEVIATION := Vector2.ZERO
var initialTileCoords := Vector2.ZERO
var initial_facing := "up_right"
var sprite_layout := "directional_12"
var sprite_frame_duration := SELECTED_FRAME_DURATION
var horizontal_facing_inverted := false
var digimon_key := ""
var is_player_controlled := true
var is_selected := false
var is_debug_selected := false
var is_turn_active := false
var is_defending := false
var selected_tile_coords := Vector2i.ZERO
var facing_direction := "up_right"
var grid_anchor := Vector2i.ZERO
var footprint_id := BattleFootprint.SINGLE
var _selected_animation_time := 0.0
var _selected_animation_frame := 0
var _is_path_moving := false
var _turn_indicator: Node2D
@onready var sprite: Sprite2D = get_node("Sprite2D") as Sprite2D


func _ready() -> void:
	global_position = Vector2(initialTileCoords) + PLAYER_POSITION_DEVIATION
	var field := _get_field()
	if field != null and field.has_method("world_to_grid"):
		grid_anchor = Vector2i(field.call("world_to_grid", field.to_local(Vector2(initialTileCoords))))
		global_position = get_footprint_center_world(field) + PLAYER_POSITION_DEVIATION
	facing_direction = initial_facing if DirectionalSpriteContract.has_direction(initial_facing) else "up_right"
	_create_turn_indicator()
	_show_current_facing(false)
	_notify_occupancy_changed()


func _physics_process(delta: float) -> void:
	selected_tile_coords = GlobalVariables.SelectedTileCoords

	# Portrait strips are generated directly from the canonical animated WebPs.
	# They represent a complete idle animation rather than directional walk rows,
	# so keep them playing even while the unit is stationary.
	if sprite_layout == "portrait_strip":
		_advance_selected_animation(delta)
		return

	if _is_path_moving:
		_advance_selected_animation(delta)
		return

	if is_selected or is_debug_selected:
		if not GlobalVariables.TouchInputActive:
			face_toward_world_position(get_global_mouse_position())
		_advance_selected_animation(delta)
		return

	_selected_animation_time = 0.0
	_selected_animation_frame = 0
	_show_current_facing(false)


func _input(event: InputEvent) -> void:
	var battle := _get_battle_controller()
	if battle != null and battle.has_method("uses_tactical_input") and bool(battle.call("uses_tactical_input")):
		return
	if not _can_control() or not event is InputEventMouseButton:
		return
	if GlobalVariables.TouchInputActive:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if is_selected:
		if move_digimon_position():
			set_tactical_selected(false)
		return
	if is_digimon_position_clicked():
		_select_for_pointer(get_global_mouse_position())


func handle_touch_tap(tile_world_position: Vector2, pointer_world_position: Vector2) -> bool:
	var battle := _get_battle_controller()
	if battle != null and battle.has_method("uses_tactical_input") and bool(battle.call("uses_tactical_input")):
		return false
	if not _can_control():
		return false

	selected_tile_coords = Vector2i(
		int(round(tile_world_position.x)),
		int(round(tile_world_position.y))
	)
	if is_selected:
		if move_digimon_position():
			set_tactical_selected(false)
		return true
	if is_digimon_position_clicked():
		_select_for_pointer(pointer_world_position)
		return true
	return false


func set_tactical_selected(selected: bool) -> void:
	if is_selected == selected:
		_update_turn_indicator()
		return
	is_selected = selected
	if sprite_layout != "portrait_strip":
		_selected_animation_time = 0.0
		_selected_animation_frame = 0
	_show_current_facing(is_selected or is_debug_selected)
	emit_particles_when_selected()
	_update_turn_indicator()


func set_debug_selected(selected: bool) -> void:
	if is_debug_selected == selected:
		_update_turn_indicator()
		return
	is_debug_selected = selected
	if sprite_layout != "portrait_strip":
		_selected_animation_time = 0.0
		_selected_animation_frame = 0
	_show_current_facing(is_selected or is_debug_selected)
	emit_particles_when_selected()
	_update_turn_indicator()


func set_turn_active(active: bool) -> void:
	is_turn_active = active
	if not active and is_selected:
		set_tactical_selected(false)
	else:
		emit_particles_when_selected()
		_update_turn_indicator()


func move_along_grid_path(path: Array[Vector2i], field: Node) -> void:
	if path.is_empty() or field == null or not field.has_method("grid_to_world"):
		return

	_is_path_moving = true
	if sprite_layout != "portrait_strip":
		_selected_animation_time = 0.0
		_selected_animation_frame = 0
	for grid in path:
		var target_world := FootprintScript.center_world(field, grid, footprint_id)
		if field is Node2D:
			target_world = (field as Node2D).to_global(target_world)
		target_world += PLAYER_POSITION_DEVIATION
		face_toward_world_position(target_world)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "global_position", target_world, MOVE_STEP_DURATION)
		_focus_camera_on(target_world)
		await tween.finished
		grid_anchor = grid
		_notify_occupancy_changed()

	_is_path_moving = false
	if sprite_layout != "portrait_strip":
		_selected_animation_time = 0.0
		_selected_animation_frame = 0
	_show_current_facing(is_selected or is_debug_selected)


func debug_relocate_to_grid(grid: Vector2i, field: Node) -> bool:
	if field == null or not field.has_method("grid_to_world"):
		return false
	var tile_world_position := Vector2(field.call("grid_to_world", grid))
	if field.has_method("can_actor_occupy_anchor"):
		if not bool(field.call("can_actor_occupy_anchor", grid, self)):
			return false
	elif field.has_method("can_digimon_move_to_world"):
		if not bool(field.call("can_digimon_move_to_world", tile_world_position, self)):
			return false

	grid_anchor = grid
	var target_position := get_footprint_center_world(field) + PLAYER_POSITION_DEVIATION
	face_toward_world_position(target_position)
	global_position = target_position
	if sprite_layout != "portrait_strip":
		_selected_animation_time = 0.0
		_selected_animation_frame = 0
	_show_current_facing(is_selected or is_debug_selected)
	_notify_occupancy_changed()
	return true


func _select_for_pointer(pointer_world_position: Vector2) -> void:
	set_tactical_selected(true)
	face_toward_world_position(pointer_world_position)
	move_camera_to_selected_digimon()


func _can_control() -> bool:
	return is_player_controlled or GlobalVariables.DebugMode


func is_digimon_position_clicked() -> bool:
	for tile_world: Vector2 in get_occupied_tile_world_positions():
		if Vector2(selected_tile_coords).distance_squared_to(tile_world) < 0.25:
			return true
	return false


func get_tile_world_position() -> Vector2:
	var field := _get_field()
	if field != null and field.has_method("grid_to_world"):
		var local_position := Vector2(field.call("grid_to_world", grid_anchor))
		return (field as Node2D).to_global(local_position) if field is Node2D else local_position
	return global_position - PLAYER_POSITION_DEVIATION


func configure_battle_footprint(value: String) -> void:
	footprint_id = FootprintScript.normalize_id(value)


func get_battle_footprint_id() -> String:
	return footprint_id


func get_grid_anchor() -> Vector2i:
	return grid_anchor


func get_occupied_grids(anchor_override = null) -> Array[Vector2i]:
	var anchor := Vector2i(anchor_override) if anchor_override is Vector2i else grid_anchor
	return FootprintScript.occupied_grids(anchor, footprint_id)


func occupies_grid(grid: Vector2i) -> bool:
	return get_occupied_grids().has(grid)


func get_occupied_tile_world_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var field := _get_field()
	if field == null or not field.has_method("grid_to_world"):
		result.append(get_tile_world_position())
		return result
	for grid: Vector2i in get_occupied_grids():
		var local_position := Vector2(field.call("grid_to_world", grid))
		result.append((field as Node2D).to_global(local_position) if field is Node2D else local_position)
	return result


func get_footprint_center_world(field: Node = null) -> Vector2:
	var resolved_field := field if field != null else _get_field()
	if resolved_field == null:
		return global_position - PLAYER_POSITION_DEVIATION
	var local_center := FootprintScript.center_world(resolved_field, grid_anchor, footprint_id)
	return (resolved_field as Node2D).to_global(local_center) if resolved_field is Node2D else local_center


func move_digimon_position() -> bool:
	var tile_world_position := Vector2(selected_tile_coords)
	var field := _get_field()
	var next_anchor := grid_anchor
	if field != null and field.has_method("world_to_grid"):
		next_anchor = Vector2i(field.call("world_to_grid", field.to_local(tile_world_position)))
	if field != null and field.has_method("can_actor_occupy_anchor"):
		if not bool(field.call("can_actor_occupy_anchor", next_anchor, self)):
			return false
	elif field != null and field.has_method("can_digimon_move_to_world"):
		if not bool(field.call("can_digimon_move_to_world", tile_world_position, self)):
			return false
	grid_anchor = next_anchor
	global_position = get_footprint_center_world(field) + PLAYER_POSITION_DEVIATION
	_notify_occupancy_changed()
	return true


func is_pointer_over(world_position: Vector2) -> bool:
	if sprite == null or sprite.texture == null:
		return false
	var local_pointer := sprite.to_local(world_position)
	return sprite.get_rect().grow(HOVER_PADDING).has_point(local_pointer)


func _get_field() -> Node:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return null
	return main.get_node_or_null("Blocks")


func _get_battle_controller() -> Node:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return null
	return main.get_node_or_null("BattleController")


func face_toward_world_position(target_position: Vector2) -> void:
	var direction_vector := target_position - global_position
	if direction_vector.length_squared() <= FACING_DEADZONE * FACING_DEADZONE:
		return

	var next_direction := _direction_from_vector(direction_vector)
	if next_direction == facing_direction:
		return

	facing_direction = next_direction
	if sprite_layout != "portrait_strip":
		_selected_animation_time = 0.0
		_selected_animation_frame = 0
	_show_current_facing(is_selected or is_debug_selected or _is_path_moving)


func _direction_from_vector(direction_vector: Vector2) -> String:
	var horizontal := "right" if direction_vector.x >= 0.0 else "left"
	var vertical := "down" if direction_vector.y >= 0.0 else "up"
	if absf(direction_vector.x) < FACING_DEADZONE:
		horizontal = "right" if facing_direction.ends_with("right") else "left"
	if absf(direction_vector.y) < FACING_DEADZONE:
		vertical = "down" if facing_direction.begins_with("down") else "up"
	return "%s_%s" % [vertical, horizontal]


func _advance_selected_animation(delta: float) -> void:
	var duration := maxf(0.02, sprite_frame_duration) if sprite_layout == "portrait_strip" else SELECTED_FRAME_DURATION
	_selected_animation_time += delta
	if _selected_animation_time < duration:
		return
	_selected_animation_time = fmod(_selected_animation_time, duration)
	var frame_count := (
		maxi(1, sprite.hframes * sprite.vframes)
		if sprite_layout == "portrait_strip"
		else DirectionalSpriteContract.WALK_PHASES.size()
	)
	_selected_animation_frame = (_selected_animation_frame + 1) % frame_count
	_show_current_facing(true)


func _show_current_facing(animate: bool) -> void:
	if sprite_layout == "portrait_strip":
		sprite.region_enabled = false
		sprite.flip_h = false
		var frame_count := maxi(1, sprite.hframes * sprite.vframes)
		sprite.frame = _selected_animation_frame % frame_count
		return
	if sprite_layout == "spaced_9_32":
		_show_spaced_9_facing(animate)
		return
	sprite.region_enabled = false
	sprite.flip_h = horizontal_facing_inverted
	sprite.frame = (
		DirectionalSpriteContract.walk_frame(facing_direction, _selected_animation_frame)
		if animate
		else DirectionalSpriteContract.idle_frame(facing_direction)
	)


func _show_spaced_9_facing(animate: bool) -> void:
	var frame_index: int
	if animate:
		var sequence: Array = VEEMON_SPACED_9_WALK_SEQUENCE.get(facing_direction, [3, 4, 3])
		frame_index = int(sequence[_selected_animation_frame])
	else:
		frame_index = int(VEEMON_SPACED_9_IDLE_FRAME.get(facing_direction, 3))

	sprite.hframes = 1
	sprite.vframes = 1
	sprite.frame = 0
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.region_rect = Rect2(
		frame_index * VEEMON_SPACED_9_CELL_STRIDE,
		0,
		VEEMON_SPACED_9_CELL_SIZE,
		VEEMON_SPACED_9_CELL_SIZE
	)
	sprite.flip_h = bool(VEEMON_SPACED_9_FLIP_H.get(facing_direction, false))


func emit_particles_when_selected() -> void:
	var particles := get_node_or_null("Sprite2D/CPUParticles2D") as CPUParticles2D
	if particles == null:
		return
	particles.position = to_local(global_position) + PARTICLES_POSITION_DEVIATION
	particles.emitting = is_selected or is_debug_selected


func _create_turn_indicator() -> void:
	_turn_indicator = TurnIndicatorScript.new()
	_turn_indicator.name = "TurnIndicator"
	add_child(_turn_indicator)
	_update_turn_indicator()


func _update_turn_indicator() -> void:
	if _turn_indicator == null:
		return
	_turn_indicator.call("set_state", is_turn_active, is_selected or is_debug_selected, is_player_controlled)


func move_camera_to_selected_digimon() -> void:
	_focus_camera_on(get_footprint_center_world())


func _focus_camera_on(world_position: Vector2) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if camera.has_method("focus_on"):
		camera.call("focus_on", world_position)
	else:
		camera.global_position = world_position


func _notify_occupancy_changed() -> void:
	var controller := get_parent()
	if controller != null and controller.has_method("refresh_occupancy_index"):
		controller.call_deferred("refresh_occupancy_index")

