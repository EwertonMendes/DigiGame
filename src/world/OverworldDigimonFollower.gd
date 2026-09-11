extends Node2D
class_name OverworldDigimonFollower

const DIRECTION_FRAME_BASE := {
	"down_left": 0,
	"down_right": 3,
	"up_left": 6,
	"up_right": 9,
}
const WALK_SEQUENCE: Array[int] = [0, 1, 2]
const WALK_FRAME_DURATION := 0.12
const FOLLOW_SPEED := 215.0
const ARRIVAL_DISTANCE := 2.0
const MIN_SEPARATION := 40.0
const FACING_DEADZONE := 0.08
const SPRITE_SCALE := 1.5
const SPRITE_POSITION := Vector2(0.0, -24.0)

const SPACED_9_IDLE_FRAME := {
	"down_left": 3,
	"down_right": 5,
	"up_left": 1,
	"up_right": 1,
}
const SPACED_9_WALK_SEQUENCE := {
	"down_left": [3, 4, 3],
	"down_right": [5, 4, 5],
	"up_left": [0, 1, 2],
	"up_right": [0, 1, 2],
}
const SPACED_9_FLIP_H := {
	"down_left": false,
	"down_right": false,
	"up_left": false,
	"up_right": true,
}
const SPACED_9_CELL_SIZE := 32
const SPACED_9_CELL_STRIDE := 33

var digimon_key := ""
var slot_index := 0
var facing_direction := "up_right"

var _digimon: Digimon = null
var _sprite: Sprite2D = null
var _walk_time := 0.0
var _walk_sequence_index := 0
var _walking := false


func configure(digimon: Digimon, key: String, party_slot: int) -> void:
	_digimon = digimon
	digimon_key = key
	slot_index = party_slot
	name = "Follower_%d_%s" % [party_slot + 1, key.capitalize()]
	if _digimon != null and DIRECTION_FRAME_BASE.has(_digimon.initial_facing):
		facing_direction = _digimon.initial_facing
	if is_node_ready():
		_apply_digimon_visuals()


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.position = SPRITE_POSITION
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_apply_digimon_visuals()
	_show_idle_frame()
	_update_depth()


func teleport_to(world_position: Vector2, initial_facing: String = "up_right") -> void:
	global_position = world_position
	if DIRECTION_FRAME_BASE.has(initial_facing):
		facing_direction = initial_facing
	_walk_time = 0.0
	_walk_sequence_index = 0
	_walking = false
	_show_idle_frame()
	_update_depth()


func step_toward(target_position: Vector2, delta: float, separation_points: Array[Vector2]) -> bool:
	var offset := target_position - global_position
	if offset.length() <= ARRIVAL_DISTANCE:
		set_idle()
		return false

	var candidate := global_position.move_toward(target_position, FOLLOW_SPEED * delta)
	if not _has_safe_separation(candidate, separation_points):
		set_idle()
		return false

	var previous_position := global_position
	global_position = candidate
	var movement := global_position - previous_position
	if movement.length_squared() > 0.0001:
		_face_motion(movement)
		_advance_walk_animation(delta)
		_update_depth()
		return true

	set_idle()
	return false


func set_idle() -> void:
	if not _walking and _walk_sequence_index == 0:
		return
	_walking = false
	_walk_time = 0.0
	_walk_sequence_index = 0
	_show_idle_frame()


func _apply_digimon_visuals() -> void:
	if _sprite == null or _digimon == null:
		return
	_sprite.texture = _digimon.texture
	_sprite.flip_h = false
	_sprite.region_enabled = false
	if _digimon.sprite_layout == "spaced_9_32":
		_sprite.hframes = 1
		_sprite.vframes = 1
	else:
		_sprite.hframes = maxi(1, _digimon.sprite_hframes)
		_sprite.vframes = maxi(1, _digimon.sprite_vframes)


func _face_motion(motion: Vector2) -> void:
	var horizontal := "right" if motion.x >= 0.0 else "left"
	var vertical := "down" if motion.y >= 0.0 else "up"
	if absf(motion.x) < FACING_DEADZONE:
		horizontal = "right" if facing_direction.ends_with("right") else "left"
	if absf(motion.y) < FACING_DEADZONE:
		vertical = "down" if facing_direction.begins_with("down") else "up"
	var next_facing := "%s_%s" % [vertical, horizontal]
	if next_facing == facing_direction:
		return
	facing_direction = next_facing
	_walk_time = 0.0
	_walk_sequence_index = 0


func _advance_walk_animation(delta: float) -> void:
	_walking = true
	_walk_time += delta
	if _walk_time >= WALK_FRAME_DURATION:
		_walk_time = fmod(_walk_time, WALK_FRAME_DURATION)
		_walk_sequence_index = (_walk_sequence_index + 1) % WALK_SEQUENCE.size()
	_show_walk_frame()


func _show_idle_frame() -> void:
	if _sprite == null or _digimon == null:
		return
	if _digimon.sprite_layout == "spaced_9_32":
		_show_spaced_9_frame(int(SPACED_9_IDLE_FRAME.get(facing_direction, 3)))
		return
	_sprite.region_enabled = false
	_sprite.flip_h = false
	var base_frame := int(DIRECTION_FRAME_BASE.get(facing_direction, 9))
	_sprite.frame = base_frame


func _show_walk_frame() -> void:
	if _sprite == null or _digimon == null:
		return
	if _digimon.sprite_layout == "spaced_9_32":
		var sequence: Array = SPACED_9_WALK_SEQUENCE.get(facing_direction, [3, 4, 3])
		var frame_index := int(sequence[_walk_sequence_index % sequence.size()])
		_show_spaced_9_frame(frame_index)
		return
	_sprite.region_enabled = false
	_sprite.flip_h = false
	var base_frame := int(DIRECTION_FRAME_BASE.get(facing_direction, 9))
	_sprite.frame = base_frame + WALK_SEQUENCE[_walk_sequence_index]


func _show_spaced_9_frame(frame_index: int) -> void:
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	_sprite.region_enabled = true
	_sprite.region_filter_clip_enabled = true
	_sprite.region_rect = Rect2(
		frame_index * SPACED_9_CELL_STRIDE,
		0,
		SPACED_9_CELL_SIZE,
		SPACED_9_CELL_SIZE
	)
	_sprite.flip_h = bool(SPACED_9_FLIP_H.get(facing_direction, false))


func _has_safe_separation(candidate: Vector2, separation_points: Array[Vector2]) -> bool:
	for point in separation_points:
		if candidate.distance_to(point) < MIN_SEPARATION:
			return false
	return true


func _update_depth() -> void:
	z_index = 1000 + int(round(global_position.y))
