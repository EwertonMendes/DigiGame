extends CharacterBody2D

const DIRECTION_FRAME_BASE := {"down_left": 0, "down_right": 3, "up_left": 6, "up_right": 9}
const VEEMON_SPACED_9_IDLE_FRAME := {
	"down_left": 3,
	"down_right": 5,
	"up_left": 1,
	"up_right": 1,
}
const VEEMON_SPACED_9_WALK_SEQUENCE := {
	# The supplied strip already contains the real Veemon poses. Keep the
	# front-left and front-right cycles on their own side so the walk animation
	# never sweeps from one facing direction into the opposite one.
	"down_left": [3, 4, 3],
	"down_right": [5, 4, 5],
	"up_left": [0, 1, 2],
	# The supplied strip has one rear-facing side sequence. Mirror only that
	# sequence for the opposite rear diagonal instead of inventing new frames.
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
const FACING_DEADZONE := 5.0

var PLAYER_POSITION_DEVIATION := Vector2.ZERO
var PARTICLES_POSITION_DEVIATION := Vector2.ZERO
var initialTileCoords := Vector2.ZERO
var initial_facing := "up_right"
var sprite_layout := "directional_12"
var is_player_controlled := true
var is_selected := false
var selected_tile_coords := Vector2i.ZERO
var facing_direction := "up_right"
var _selected_animation_time := 0.0
var _selected_animation_frame := 0
@onready var sprite: Sprite2D = get_node("Sprite2D") as Sprite2D

func _ready() -> void:
	global_position = Vector2(initialTileCoords) + PLAYER_POSITION_DEVIATION
	facing_direction = initial_facing if DIRECTION_FRAME_BASE.has(initial_facing) else "up_right"
	_show_current_facing(false)

func _physics_process(delta: float) -> void:
	if not _can_control():
		if is_selected:
			_clear_selection()
		return

	selected_tile_coords = GlobalVariables.SelectedTileCoords
	if is_selected:
		if not GlobalVariables.TouchInputActive:
			face_toward_world_position(get_global_mouse_position())
		_advance_selected_animation(delta)
	else:
		_selected_animation_time = 0.0
		_selected_animation_frame = 0
		_show_current_facing(false)

func _input(event: InputEvent) -> void:
	if not _can_control() or not event is InputEventMouseButton:
		return

	# Touch presses can be mirrored as synthetic mouse clicks so ordinary UI
	# Buttons remain touch-friendly. Native touch gameplay is handled by the
	# camera; suppress the mirrored click so a finger cannot trigger both paths.
	if GlobalVariables.TouchInputActive:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if is_selected:
		var destination := Vector2(selected_tile_coords) + PLAYER_POSITION_DEVIATION
		face_toward_world_position(destination)
		move_digimon_position()
		_clear_selection()
		return

	if is_digimon_position_clicked():
		_select_for_pointer(get_global_mouse_position())

func handle_touch_tap(tile_world_position: Vector2, pointer_world_position: Vector2) -> bool:
	if not _can_control():
		return false

	selected_tile_coords = Vector2i(
		int(round(tile_world_position.x)),
		int(round(tile_world_position.y))
	)

	if is_selected:
		var destination := Vector2(selected_tile_coords) + PLAYER_POSITION_DEVIATION
		face_toward_world_position(destination)
		move_digimon_position()
		_clear_selection()
		return true

	if is_digimon_position_clicked():
		_select_for_pointer(pointer_world_position)
		return true

	return false

func _select_for_pointer(pointer_world_position: Vector2) -> void:
	is_selected = true
	face_toward_world_position(pointer_world_position)
	_selected_animation_time = 0.0
	_selected_animation_frame = 0
	_show_current_facing(true)
	emit_particles_when_selected()
	move_camera_to_selected_digimon()

func _can_control() -> bool:
	return is_player_controlled or GlobalVariables.DebugMode

func _clear_selection() -> void:
	is_selected = false
	_selected_animation_time = 0.0
	_selected_animation_frame = 0
	_show_current_facing(false)
	emit_particles_when_selected()

func is_digimon_position_clicked() -> bool:
	return Vector2(selected_tile_coords) == global_position - PLAYER_POSITION_DEVIATION

func move_digimon_position() -> void:
	global_position = Vector2(selected_tile_coords) + PLAYER_POSITION_DEVIATION

func face_toward_world_position(target_position: Vector2) -> void:
	var direction_vector := target_position - global_position
	if direction_vector.length_squared() <= FACING_DEADZONE * FACING_DEADZONE:
		return

	var next_direction := _direction_from_vector(direction_vector)
	if next_direction == facing_direction:
		return

	facing_direction = next_direction
	_selected_animation_time = 0.0
	_selected_animation_frame = 0
	_show_current_facing(is_selected)

func _direction_from_vector(direction_vector: Vector2) -> String:
	var horizontal := "right" if direction_vector.x >= 0.0 else "left"
	var vertical := "down" if direction_vector.y >= 0.0 else "up"

	if absf(direction_vector.x) < FACING_DEADZONE:
		horizontal = "right" if facing_direction.ends_with("right") else "left"
	if absf(direction_vector.y) < FACING_DEADZONE:
		vertical = "down" if facing_direction.begins_with("down") else "up"

	return "%s_%s" % [vertical, horizontal]

func _advance_selected_animation(delta: float) -> void:
	_selected_animation_time += delta
	if _selected_animation_time < SELECTED_FRAME_DURATION:
		return

	_selected_animation_time = fmod(_selected_animation_time, SELECTED_FRAME_DURATION)
	_selected_animation_frame = (_selected_animation_frame + 1) % 3
	_show_current_facing(true)

func _show_current_facing(animate: bool) -> void:
	if sprite_layout == "spaced_9_32":
		_show_spaced_9_facing(animate)
		return

	sprite.region_enabled = false
	sprite.flip_h = false
	var base_frame: int = DIRECTION_FRAME_BASE.get(facing_direction, 9)
	sprite.frame = base_frame + (_selected_animation_frame if animate else 0)

func _show_spaced_9_facing(animate: bool) -> void:
	# Use the supplied 296x32 image byte-for-byte. It contains nine exact
	# 32x32 cells separated by one transparent pixel, so hframes must not be
	# used: 296 / 9 would cut the source artwork at the wrong boundaries.
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
	var particles := get_node("Sprite2D/CPUParticles2D") as CPUParticles2D
	particles.position = to_local(global_position) + PARTICLES_POSITION_DEVIATION
	particles.emitting = is_selected

func move_camera_to_selected_digimon() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if camera.has_method("focus_on"):
		camera.call("focus_on", global_position)
	else:
		camera.global_position = global_position
