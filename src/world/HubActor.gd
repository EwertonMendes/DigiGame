extends CharacterBody2D
class_name HubActor

signal world_position_changed(world_position: Vector2)

const FRAME_COLUMNS := 3
const FRAME_ROWS := 4
const WALK_SEQUENCE: Array[int] = [0, 1, 0, 2]
const FACING_ROWS := {
	"down_left": 0,
	"down_right": 1,
	"up_left": 2,
	"up_right": 3,
}
const BASE_SPRITE_POSITION := Vector2(0.0, -32.0)
const INPUT_DEADZONE := 0.18

var is_player_controlled := false
var movement_enabled := true
var move_speed := 150.0
var facing_direction := "down_left"

var _world_controller: Node = null
var _texture: Texture2D = null
var _sprite: Sprite2D = null
var _animation_time := 0.0
var _animation_frame := 0
var _touch_direction := Vector2.ZERO


func configure(texture: Texture2D, player_controlled: bool, world_controller: Node, initial_facing: String) -> void:
	_texture = texture
	is_player_controlled = player_controlled
	_world_controller = world_controller
	if FACING_ROWS.has(initial_facing):
		facing_direction = initial_facing


func _ready() -> void:
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
	_animation_time += delta
	if not is_player_controlled:
		_update_idle_pose()
		return

	var direction := _movement_input() if movement_enabled else Vector2.ZERO
	if direction.length_squared() > INPUT_DEADZONE * INPUT_DEADZONE:
		direction = direction.normalized()
		velocity = velocity.move_toward(direction * move_speed, 900.0 * delta)
		_face_direction(direction)
		_advance_walk_animation()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 1100.0 * delta)
		_animation_frame = 0
		_update_frame(false)

	if velocity.length_squared() > 1.0:
		_try_move(velocity * delta)
	_update_depth()


func set_touch_direction(direction: Vector2) -> void:
	_touch_direction = direction.limit_length(1.0)


func set_facing(direction_name: String) -> void:
	if not FACING_ROWS.has(direction_name):
		return
	facing_direction = direction_name
	_animation_frame = 0
	_update_frame(false)


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


func _face_direction(direction: Vector2) -> void:
	if direction.length_squared() <= INPUT_DEADZONE * INPUT_DEADZONE:
		return
	var horizontal := "right" if direction.x >= 0.0 else "left"
	var vertical := "down" if direction.y >= -0.05 else "up"
	if absf(direction.x) < 0.08:
		horizontal = "right" if facing_direction.ends_with("right") else "left"
	var next_facing := "%s_%s" % [vertical, horizontal]
	if next_facing != facing_direction:
		facing_direction = next_facing
		_animation_frame = 0


func _advance_walk_animation() -> void:
	var sequence_index := int(floor(_animation_time * 10.0)) % WALK_SEQUENCE.size()
	_animation_frame = WALK_SEQUENCE[sequence_index]
	_update_frame(true)


func _update_idle_pose() -> void:
	_animation_frame = 0
	_update_frame(false)
	if _sprite != null:
		_sprite.position = BASE_SPRITE_POSITION + Vector2(0.0, sin(_animation_time * 2.1) * 0.7)


func _update_frame(walking: bool) -> void:
	if _sprite == null:
		return
	var row := int(FACING_ROWS.get(facing_direction, 0))
	_sprite.frame = row * FRAME_COLUMNS + _animation_frame
	if walking:
		_sprite.position = BASE_SPRITE_POSITION


func _update_depth() -> void:
	z_index = 1000 + int(round(global_position.y))
