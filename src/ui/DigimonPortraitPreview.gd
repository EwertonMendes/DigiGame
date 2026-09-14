extends Control
class_name DigimonPortraitPreview

const PortraitResolver = preload("res://src/ui/DigimonPortraitResolver.gd")

# Portrait metadata and imported strips are immutable while the game is running.
# Keep them shared across preview instances so navigating a UI never re-reads JSON
# or re-loads the same texture from the PCK on every selection.
static var _portrait_cache: Dictionary = {}

var _texture_rect: TextureRect = null
var _atlas: AtlasTexture = null
var _frame_size := Vector2.ZERO
var _frame_count := 0
var _durations: Array = []
var _frame_index := 0
var _elapsed := 0.0
var _pending_species := ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect = TextureRect.new()
	_texture_rect.name = "Portrait"
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)
	set_process(false)
	if not _pending_species.is_empty():
		_load_species(_pending_species)


func set_species(species_name: String) -> void:
	_pending_species = species_name
	if _texture_rect != null:
		_load_species(species_name)


func _load_species(species_name: String) -> void:
	_reset_animation()
	var key := PortraitResolver.resolve_key(species_name)
	if key.is_empty():
		return

	var cached = _portrait_cache.get(key, null)
	if cached is Dictionary:
		var entry := cached as Dictionary
		_frame_size = Vector2(entry.get("frame_size", Vector2.ZERO))
		_frame_count = int(entry.get("frame_count", 0))
		_durations = (entry.get("durations", []) as Array).duplicate()
		var cached_strip := entry.get("strip", null) as Texture2D
		if cached_strip != null and _frame_size.x > 0.0 and _frame_size.y > 0.0 and _frame_count > 0:
			_apply_loaded_strip(cached_strip)
		return

	var metadata_path := PortraitResolver.metadata_path(key)
	var strip_path := PortraitResolver.strip_path(key)
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary:
		return
	var strip := load(strip_path) as Texture2D
	if strip == null:
		return
	_frame_size = Vector2(float(metadata.get("frame_width", 0)), float(metadata.get("frame_height", 0)))
	_frame_count = int(metadata.get("frame_count", 0))
	_durations = metadata.get("durations_ms", [])
	if _frame_size.x <= 0.0 or _frame_size.y <= 0.0 or _frame_count <= 0:
		return

	_portrait_cache[key] = {
		"frame_size": _frame_size,
		"frame_count": _frame_count,
		"durations": _durations.duplicate(),
		"strip": strip,
	}
	_apply_loaded_strip(strip)


func _apply_loaded_strip(strip: Texture2D) -> void:
	_atlas = AtlasTexture.new()
	_atlas.atlas = strip
	_texture_rect.texture = _atlas
	_apply_frame()
	set_process(_frame_count > 1)


func _process(delta: float) -> void:
	if _atlas == null or _frame_count <= 1:
		return
	_elapsed += delta
	var duration := _frame_duration()
	while _elapsed >= duration:
		_elapsed -= duration
		_frame_index = (_frame_index + 1) % _frame_count
		_apply_frame()
		duration = _frame_duration()


func _reset_animation() -> void:
	set_process(false)
	_atlas = null
	_frame_size = Vector2.ZERO
	_frame_count = 0
	_durations = []
	_frame_index = 0
	_elapsed = 0.0
	if _texture_rect != null:
		_texture_rect.texture = null


func _frame_duration() -> float:
	if _frame_index < _durations.size():
		return maxf(0.02, float(_durations[_frame_index]) / 1000.0)
	return 0.12


func _apply_frame() -> void:
	if _atlas == null:
		return
	_atlas.region = Rect2(_frame_size.x * float(_frame_index), 0.0, _frame_size.x, _frame_size.y)
