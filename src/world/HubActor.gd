extends CharacterBody2D
class_name HubActor

signal world_position_changed(world_position: Vector2)

const GameInputBootstrapScript = preload("res://src/input/GameInputBootstrap.gd")
const FRAME_COLUMNS := 3
const FRAME_ROWS := 5
const WALK_SEQUENCE: Array[int] = [0, 1, 0, 2]
const WALK_FRAME_DURATION := 0.10
const INPUT_DEADZONE := 0.18
const FACING_TIE_EPSILON := 0.0001
const BASE_SPRITE_POSITION := Vector2(0.0, -32.0)

# The supplied Dawn/Dusk trainer sheet contains five authored directions:
# south, southwest, west, northwest and north. The remaining three directions
# are their horizontal mirrors, giving a complete eight-direction walk set.
const FACING_ROWS := {
	"south": 0,
	"southwest": 1,
	"west": 2,
	"northwest": 3,
	"north": 4,
	"northeast": 3,
	"east": 2,
	"southeast": 1,
}
const FACING_FLIP_H := {
	"south": false,
	"southwest": false,
	"west": false,
	"northwest": false,
	"north": false,
	"northeast": true,
	"east": true,
	"southeast": true,
}
const FACING_VECTORS := {
	"east": Vector2(1.0, 0.0),
	"southeast": Vector2(0.70710678, 0.70710678),
	"south": Vector2(0.0, 1.0),
	"southwest": Vector2(-0.70710678, 0.70710678),
	"west": Vector2(-1.0, 0.0),
	"northwest": Vector2(-0.70710678, -0.70710678),
	"north": Vector2(0.0, -1.0),
	"northeast": Vector2(0.70710678, -0.70710678),
}

# Compatibility for the names used by the first hub implementation. Those
# names were based on the old, incorrect four-row crop, so they intentionally
# preserve the visual direction that code expected rather than their literal
# text meaning.
const LEGACY_FACING_ALIASES := {
	"down": "south",
	"left": "west",
	"right": "east",
	"up": "north",
	"down_left": "south",
	"down_right": "west",
	"up_left": "east",
	"up_right": "north",
}

var is_player_controlled := false
var movement_enabled := true
var move_speed := 150.0
var facing_direction := "south"

var _world_controller: Node = null
var _texture: Texture2D = null
var _sprite: Sprite2D = null
var _idle_time := 0.0
var _walk_time := 0.0
var _animation_frame := 0
var _was_walking := false
var _touch_direction := Vector2.ZERO


func configure(texture: Texture2D, player_controlled: bool, world_controller: Node, initial_facing: String) -> void:
	_texture = texture
	is_player_controlled = player_controlled
	_world_controller = world_controller
	var canonical_facing := _canonical_facing(initial_facing)
	if not canonical_facing.is_empty():
		facing_direction = canonical_facing


func _ready() -> void:
	GameInputBootstrapScript.configure_gamepad_actions()
	_sprite = Sprite2D.new()
	_sprite.name = "CharacterSprite"
	_sprite.texture = _texture
	_sprite.hframes = FRAME_COLUMNS
	_sprite.vframes = FRAME_ROWS
	_sprite.position = BASE_SPRITE_POSITION
	_sprite.scale = Vector2(2.0, 2.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := CapsuleShape2D.new()
	shape.radius = 10.0
	shape.height = 22.0
	collision.shape = shape
	collision.position = Vector2(0.0, -11.0)
	add_child(collision)

	_update_frame(false)
	_update_depth()


func _physics_process(delta: float) -> void:
	_idle_time += delta
	if not is_player_controlled:
		_update_idle_pose()
		return

	var direction := _movement_input() if movement_enabled else Vector2.ZERO
	var has_movement_input := direction.length_squared() > INPUT_DEADZONE * INPUT_DEADZONE
	var facing_changed := false
	if has_movement_input:
		direction = direction.normalized()
		velocity = velocity.move_toward(direction * move_speed, 900.0 * delta)
		facing_changed = _face_direction(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 1100.0 * delta)

	var is_walking := velocity.length_squared() > 1.0
	if is_walking:
		if not _was_walking or facing_changed:
			_reset_walk_cycle()
		_advance_walk_animation(delta)
	else:
		_reset_walk_cycle()
		_update_frame(false)

	_was_walking = is_walking
	if is_walking:
		_try_move(velocity * delta)
	_update_depth()


func set_touch_direction(direction: Vector2) -> void:
	_touch_direction = direction.limit_length(1.0)


func set_facing(direction_name: String) -> void:
	var canonical_facing := _canonical_facing(direction_name)
	if canonical_facing.is_empty():
		return
	facing_direction = canonical_facing
	_reset_walk_cycle()
	_update_frame(false)


func _canonical_facing(direction_name: String) -> String:
	if FACING_ROWS.has(direction_name):
		return direction_name
	return String(LEGACY_FACING_ALIASES.get(direction_name, ""))


func _movement_input() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var keyboard := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if keyboard.length_squared() > direction.length_squared():
		direction = keyboard
	if _touch_direction.length_squared() > direction.length_squared():
		direction = _touch_direction
	return direction.limit_length(1.0)


func _try_move(offset: Vector2) -> void:
	var candidate := position + offset
	if _can_move_to(candidate):
		position = candidate
	elif _can_move_to(position + Vector2(offset.x, 0.0)):
		position.x += offset.x
		velocity.y = 0.0
	elif _can_move_to(position + Vector2(0.0, offset.y)):
		position.y += offset.y
		velocity.x = 0.0
	else:
		velocity = Vector2.ZERO
	world_position_changed.emit(position)


func _can_move_to(candidate: Vector2) -> bool:
	if _world_controller == null or not _world_controller.has_method("can_actor_move_to"):
		return true
	return bool(_world_controller.call("can_actor_move_to", candidate, self))


func _face_direction(direction: Vector2) -> bool:
	if direction.length_squared() <= INPUT_DEADZONE * INPUT_DEADZONE:
		return false

	var normalized_direction := direction.normalized()
	var next_facing := facing_direction
	var best_score := -1.0e20
	for candidate_key in FACING_VECTORS:
		var candidate := String(candidate_key)
		var candidate_vector: Vector2 = FACING_VECTORS[candidate]
		var score := normalized_direction.dot(candidate_vector)
		if score > best_score + FACING_TIE_EPSILON:
			best_score = score
			next_facing = candidate
		elif absf(score - best_score) <= FACING_TIE_EPSILON and candidate == facing_direction:
			next_facing = candidate

	if next_facing == facing_direction:
		return false
	facing_direction = next_facing
	return true


func _reset_walk_cycle() -> void:
	_walk_time = 0.0
	_animation_frame = 0


func _advance_walk_animation(delta: float) -> void:
	_walk_time += delta
	var sequence_index := int(floor(_walk_time / WALK_FRAME_DURATION)) % WALK_SEQUENCE.size()
	_animation_frame = WALK_SEQUENCE[sequence_index]
	_update_frame(true)


func _update_idle_pose() -> void:
	_reset_walk_cycle()
	_update_frame(false)
	if _sprite != null:
		_sprite.position = BASE_SPRITE_POSITION + Vector2(0.0, sin(_idle_time * 2.1) * 0.7)


func _update_frame(walking: bool) -> void:
	if _sprite == null:
		return
	var row := int(FACING_ROWS.get(facing_direction, 0))
	_sprite.frame = row * FRAME_COLUMNS + _animation_frame
	_sprite.flip_h = bool(FACING_FLIP_H.get(facing_direction, false))
	if walking:
		_sprite.position = BASE_SPRITE_POSITION


func _update_depth() -> void:
	z_index = 1000 + int(round(global_position.y))
