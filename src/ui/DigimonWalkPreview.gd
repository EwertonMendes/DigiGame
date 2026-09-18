extends Control
class_name DigimonWalkPreview

const WALK_FRAME_DURATION := 0.11
const PREVIEW_FACING := "down_right"
const PREVIEW_REFERENCE_CELL := 64.0
const PREVIEW_FILL_RATIO := 0.82
const DEFAULT_POSITION_BIAS := Vector2(0.0, 3.0)

# Default previews preserve the authored runtime relationship between species.
# Contexts that need maximum legibility (such as the Evolution Chart) may opt
# into an envelope fit while still preserving each resource's authored aspect.
const FIT_AUTHORED_PROPORTION := 0
const FIT_VISUAL_ENVELOPE := 1
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
var _pending_species := ""
var _fit_mode := FIT_AUTHORED_PROPORTION
var _fill_ratio := PREVIEW_FILL_RATIO
var _position_bias := DEFAULT_POSITION_BIAS


func _ready() -> void:
	name = "WalkPreview"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite = Sprite2D.new()
	_sprite.name = "FieldSprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	set_process(false)
	if not _pending_species.is_empty():
		_load_species(_pending_species)
	else:
		_layout_sprite()


func set_species(species_name: String) -> void:
	_pending_species = species_name
	if _sprite != null:
		_load_species(species_name)


func configure_presentation(fit_mode: int, fill_ratio: float = PREVIEW_FILL_RATIO, position_bias: Vector2 = DEFAULT_POSITION_BIAS) -> void:
	_fit_mode = FIT_VISUAL_ENVELOPE if fit_mode == FIT_VISUAL_ENVELOPE else FIT_AUTHORED_PROPORTION
	_fill_ratio = clampf(fill_ratio, 0.10, 1.0)
	_position_bias = position_bias
	_layout_sprite()


func set_active(value: bool) -> void:
	_active = value
	_elapsed = 0.0
	_sequence_index = 0
	set_process(_active and _sprite != null and _digimon != null)
	if _active:
		_show_walk_frame()
	else:
		_show_idle_frame()


func _load_species(species_name: String) -> void:
	var key := species_name.strip_edges().to_lower()
	var path := "res://assets/resources/%s.tres" % key
	_digimon = load(path) as Digimon if ResourceLoader.exists(path) else null
	_apply_visuals()
	if _active:
		_show_walk_frame()
	else:
		_show_idle_frame()
	set_process(_active and _digimon != null)
	_layout_sprite()


func _process(delta: float) -> void:
	if not _active or _digimon == null or _sprite == null:
		return
	_elapsed += delta
	var duration := maxf(0.02, _digimon.sprite_frame_duration) if _digimon.sprite_layout == "portrait_strip" else WALK_FRAME_DURATION
	while _elapsed >= duration:
		_elapsed -= duration
		if _digimon.sprite_layout == "portrait_strip":
			var frame_count := maxi(1, _sprite.hframes * _sprite.vframes)
			_sequence_index = (_sequence_index + 1) % frame_count
		else:
			_sequence_index = (_sequence_index + 1) % DirectionalSpriteContract.WALK_PHASES.size()
	_show_walk_frame()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_sprite()


func _apply_visuals() -> void:
	if _sprite == null:
		return
	_sprite.visible = _digimon != null and _digimon.texture != null
	if not _sprite.visible:
		_sprite.texture = null
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
	if _digimon.sprite_layout == "portrait_strip":
		_sprite.region_enabled = false
		_sprite.flip_h = false
		_sprite.frame = 0
	elif _digimon.sprite_layout == "spaced_9_32":
		_show_spaced_9_frame(int(SPACED_9_IDLE_FRAME.get(PREVIEW_FACING, 5)))
	else:
		_sprite.region_enabled = false
		_sprite.flip_h = false
		_sprite.frame = DirectionalSpriteContract.idle_frame(PREVIEW_FACING)


func _show_walk_frame() -> void:
	if _sprite == null or _digimon == null:
		return
	if _digimon.sprite_layout == "portrait_strip":
		_sprite.region_enabled = false
		_sprite.flip_h = false
		var frame_count := maxi(1, _sprite.hframes * _sprite.vframes)
		_sprite.frame = _sequence_index % frame_count
	elif _digimon.sprite_layout == "spaced_9_32":
		var sequence: Array = SPACED_9_WALK_SEQUENCE.get(PREVIEW_FACING, [5, 4, 5, 4])
		_show_spaced_9_frame(int(sequence[_sequence_index % sequence.size()]))
	else:
		_sprite.region_enabled = false
		_sprite.flip_h = false
		_sprite.frame = DirectionalSpriteContract.walk_frame(PREVIEW_FACING, _sequence_index)


func _show_spaced_9_frame(frame_index: int) -> void:
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	_sprite.region_enabled = true
	_sprite.region_filter_clip_enabled = true
	_sprite.region_rect = Rect2(frame_index * SPACED_9_CELL_STRIDE, 0, SPACED_9_CELL_SIZE, SPACED_9_CELL_SIZE)
	_sprite.flip_h = bool(SPACED_9_FLIP_H.get(PREVIEW_FACING, false))


func _layout_sprite() -> void:
	if _sprite == null:
		return
	_sprite.position = size * 0.5 + _position_bias
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
	var authored_size := Vector2(
		frame_size.x * absf(_digimon.sprite_scale.x),
		frame_size.y * absf(_digimon.sprite_scale.y)
	)
	if _fit_mode == FIT_VISUAL_ENVELOPE:
		# Fill a caller-defined visual envelope. This is intentionally generic:
		# the caller decides the hierarchy, while this component only preserves
		# the resource's aspect and fits it as large as the envelope permits.
		var envelope := size * _fill_ratio
		var envelope_fit := minf(
			envelope.x / maxf(authored_size.x, 0.001),
			envelope.y / maxf(authored_size.y, 0.001)
		)
		_sprite.scale = _digimon.sprite_scale * envelope_fit
		return

	# Normal menu cards preserve the same authored/native proportions used by
	# overworld and battle. A 64 px runtime cell at scale 1 is the shared
	# reference; oversized forms are only reduced when they would clip.
	var preview_unit_scale := minf(size.x, size.y) / PREVIEW_REFERENCE_CELL * _fill_ratio
	var desired_scale := _digimon.sprite_scale * preview_unit_scale
	var desired_size := Vector2(
		frame_size.x * absf(desired_scale.x),
		frame_size.y * absf(desired_scale.y)
	)
	var available_size := size * _fill_ratio
	var overflow_fit := minf(
		1.0,
		minf(
			available_size.x / maxf(desired_size.x, 0.001),
			available_size.y / maxf(desired_size.y, 0.001)
		)
	)
	_sprite.scale = desired_scale * overflow_fit
