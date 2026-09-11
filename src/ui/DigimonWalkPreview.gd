extends Control
class_name DigimonWalkPreview

const WALK_SEQUENCE: Array[int] = [0, 1, 0, 2]
const WALK_FRAME_DURATION := 0.11
const PREVIEW_FACING := "down_right"
const DIRECTION_FRAME_BASE := {
	"down_left": 0,
	"down_right": 3,
	"up_left": 6,
	"up_right": 9,
}
const SPACED_9_IDLE_FRAME := {
	"down_left": 3,
	"down_right": 5,
	"up_left": 1,
	"up_right": 1,
}
const SPACED_9_WALK_SEQUENCE := {
	"down_left": [3, 4, 3, 4],
	"down_right": [5, 4, 5, 4],
	"up_left": [0, 1, 2, 1],
	"up_right": [0, 1, 2, 1],
}
const SPACED_9_FLIP_H := {
	"down_left": false,
	"down_right": false,
	"up_left": false,
	"up_right": true,
}
const SPACED_9_CELL_SIZE := 32
const SPACED_9_CELL_STRIDE := 33

var _digimon: Digimon = null
var _sprite: Sprite2D = null
var _active := false
var _elapsed := 0.0
var _sequence_index := 0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite = Sprite2D.new()
	_sprite.name = "FieldSprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	set_process(false)
	_layout_sprite()


func set_species(species_name: String) -> void:
	var key := species_name.strip_edges().to_lower()
	var path := "res://assets/resources/%s.tres" % key
	_digimon = load(path) as Digimon if ResourceLoader.exists(path) else null
	_apply_visuals()
	_show_idle_frame()
	_layout_sprite()


func set_active(value: bool) -> void:
	_active = value
	_elapsed = 0.0
	_sequence_index = 0
	set_process(_active)
	if _active:
		_show_walk_frame()
	else:
		_show_idle_frame()


func _process(delta: float) -> void:
	if not _active or _digimon == null or _sprite == null:
		return
	_elapsed += delta
	while _elapsed >= WALK_FRAME_DURATION:
		_elapsed -= WALK_FRAME_DURATION
		_sequence_index = (_sequence_index + 1) % WALK_SEQUENCE.size()
	_show_walk_frame()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_sprite()


func _apply_visuals() -> void:
	if _sprite == null:
		return
	_sprite.visible = _digimon != null and _digimon.texture != null
	if not _sprite.visible:
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


func _show_idle_frame() -> void:
	if _sprite == null or _digimon == null:
		return
	if _digimon.sprite_layout == "spaced_9_32":
		_show_spaced_9_frame(int(SPACED_9_IDLE_FRAME.get(PREVIEW_FACING, 5)))
	else:
		_sprite.region_enabled = false
		_sprite.flip_h = false
		_sprite.frame = int(DIRECTION_FRAME_BASE.get(PREVIEW_FACING, 3))


func _show_walk_frame() -> void:
	if _sprite == null or _digimon == null:
		return
	if _digimon.sprite_layout == "spaced_9_32":
		var sequence: Array = SPACED_9_WALK_SEQUENCE.get(PREVIEW_FACING, [5, 4, 5, 4])
		_show_spaced_9_frame(int(sequence[_sequence_index % sequence.size()]))
	else:
		_sprite.region_enabled = false
		_sprite.flip_h = false
		var base_frame := int(DIRECTION_FRAME_BASE.get(PREVIEW_FACING, 3))
		_sprite.frame = base_frame + WALK_SEQUENCE[_sequence_index]


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
	_sprite.flip_h = bool(SPACED_9_FLIP_H.get(PREVIEW_FACING, false))


func _layout_sprite() -> void:
	if _sprite == null:
		return
	_sprite.position = size * 0.5 + Vector2(0.0, 3.0)
	if _digimon == null or _digimon.texture == null:
		return
	var frame_size := Vector2.ZERO
	if _digimon.sprite_layout == "spaced_9_32":
		frame_size = Vector2(SPACED_9_CELL_SIZE, SPACED_9_CELL_SIZE)
	else:
		frame_size = Vector2(
			float(_digimon.texture.get_width()) / float(maxi(1, _digimon.sprite_hframes)),
			float(_digimon.texture.get_height()) / float(maxi(1, _digimon.sprite_vframes))
		)
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return
	var fit := minf(size.x / frame_size.x, size.y / frame_size.y) * 0.82
	_sprite.scale = Vector2.ONE * clampf(fit, 0.6, 2.5)
