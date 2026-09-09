extends Control

const DATABASE_PATH := "res://database/base-digimon-list.json"
const PORTRAIT_ROOT := "res://assets/characters"

var _records_by_name: Dictionary = {}
var _current_key := ""
var _portrait_atlas: AtlasTexture
var _frame_size := Vector2.ZERO
var _frame_count := 0
var _frame_durations: Array = []
var _frame_index := 0
var _frame_elapsed := 0.0

var _card: PanelContainer
var _portrait: TextureRect
var _name_label: Label
var _rank_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_load_database()

	var controller := get_node_or_null("../../DigimonController")
	if controller != null and controller.has_signal("hovered_digimon_changed"):
		controller.connect("hovered_digimon_changed", _on_hovered_digimon_changed)


func _process(delta: float) -> void:
	if not _card.visible or _frame_count <= 1 or _portrait_atlas == null:
		return

	_frame_elapsed += delta
	var duration := 0.1
	if _frame_index < _frame_durations.size():
		duration = maxf(0.02, float(_frame_durations[_frame_index]) / 1000.0)

	while _frame_elapsed >= duration:
		_frame_elapsed -= duration
		_frame_index = (_frame_index + 1) % _frame_count
		_apply_portrait_frame()
		duration = 0.1
		if _frame_index < _frame_durations.size():
			duration = maxf(0.02, float(_frame_durations[_frame_index]) / 1000.0)


func _build_ui() -> void:
	_card = PanelContainer.new()
	_card.name = "DigimonHoverCard"
	_card.position = Vector2(18.0, 18.0)
	_card.custom_minimum_size = Vector2(236.0, 286.0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(208.0, 208.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_portrait)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_name_label)

	_rank_label = Label.new()
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.add_theme_font_size_override("font_size", 15)
	_rank_label.modulate = Color(0.75, 0.9, 1.0, 1.0)
	_rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_rank_label)


func _load_database() -> void:
	if not FileAccess.file_exists(DATABASE_PATH):
		push_error("Missing Digimon database: %s" % DATABASE_PATH)
		return

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATABASE_PATH))
	if not parsed is Array:
		push_error("Digimon database root must be an array")
		return

	for entry in parsed:
		if entry is Dictionary and entry.has("name"):
			_records_by_name[String(entry["name"]).to_lower()] = entry


func _on_hovered_digimon_changed(digimon_key: String) -> void:
	if digimon_key == _current_key:
		return

	_current_key = digimon_key
	if digimon_key.is_empty():
		_card.visible = false
		return

	var record: Dictionary = _records_by_name.get(digimon_key.to_lower(), {})
	if record.is_empty():
		_card.visible = false
		return

	_name_label.text = String(record.get("name", digimon_key.capitalize()))
	_rank_label.text = "Rank: %s" % String(record.get("rank", "Unknown"))
	_load_portrait_animation(digimon_key.to_lower())
	_card.visible = _portrait.texture != null


func _load_portrait_animation(digimon_key: String) -> void:
	_portrait.texture = null
	_portrait_atlas = null
	_frame_size = Vector2.ZERO
	_frame_count = 0
	_frame_durations = []
	_frame_index = 0
	_frame_elapsed = 0.0

	var metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]
	var strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(strip_path):
		push_warning("Missing animated portrait assets for %s" % digimon_key)
		return

	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary:
		push_warning("Invalid portrait metadata for %s" % digimon_key)
		return

	var strip := load(strip_path) as Texture2D
	if strip == null:
		return

	_frame_size = Vector2(
		float(metadata.get("frame_width", 0)),
		float(metadata.get("frame_height", 0))
	)
	_frame_count = int(metadata.get("frame_count", 0))
	_frame_durations = metadata.get("durations_ms", [])
	if _frame_size.x <= 0.0 or _frame_size.y <= 0.0 or _frame_count <= 0:
		return

	_portrait_atlas = AtlasTexture.new()
	_portrait_atlas.atlas = strip
	_portrait.texture = _portrait_atlas
	_apply_portrait_frame()


func _apply_portrait_frame() -> void:
	if _portrait_atlas == null:
		return
	_portrait_atlas.region = Rect2(
		_frame_size.x * _frame_index,
		0.0,
		_frame_size.x,
		_frame_size.y
	)
