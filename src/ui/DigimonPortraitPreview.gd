extends Control
class_name DigimonPortraitPreview

const PORTRAIT_ROOT := "res://assets/characters"

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
	var key := _resolve_portrait_key(species_name)
	if key.is_empty():
		return
	var metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, key]
	var strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, key]
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
	_atlas = AtlasTexture.new()
	_atlas.atlas = strip
	_texture_rect.texture = _atlas
	_apply_frame()
	set_process(_frame_count > 1)


func _resolve_portrait_key(species_name: String) -> String:
	var normalized := species_name.strip_edges().to_lower()
	if normalized.is_empty():
		return ""
	var candidates: Array[String] = []
	for raw_candidate in [
		normalized,
		normalized.replace(" ", ""),
		normalized.replace(" ", "_"),
		normalized.replace("-", "").replace(" ", ""),
	]:
		var candidate := String(raw_candidate)
		if not candidate.is_empty() and not candidates.has(candidate):
			candidates.append(candidate)
	for candidate: String in candidates:
		var metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, candidate]
		var strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, candidate]
		if FileAccess.file_exists(metadata_path) and ResourceLoader.exists(strip_path):
			return candidate
	return ""


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
