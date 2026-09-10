extends Control

const DATABASE_PATH := "res://database/base-digimon-list.json"
const PORTRAIT_ROOT := "res://assets/characters"
const CYAN := Color(0.12, 0.88, 1.0, 1.0)
const TEXT := Color(0.93, 0.98, 1.0, 1.0)
const MUTED := Color(0.56, 0.72, 0.82, 1.0)

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
var _scan_label: Label


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
	var duration := _frame_duration_seconds()
	while _frame_elapsed >= duration:
		_frame_elapsed -= duration
		_frame_index = (_frame_index + 1) % _frame_count
		_apply_portrait_frame()
		duration = _frame_duration_seconds()


func _build_ui() -> void:
	_card = PanelContainer.new()
	_card.name = "DigimonHoverCard"
	_card.position = Vector2(18.0, 18.0)
	_card.custom_minimum_size = Vector2(270.0, 342.0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_card.add_theme_stylebox_override("panel", _card_style())
	add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)

	_scan_label = Label.new()
	_scan_label.text = "DIGIMON DATA // LIVE SCAN"
	_scan_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scan_label.add_theme_font_size_override("font_size", 10)
	_scan_label.add_theme_color_override("font_color", MUTED)
	_scan_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_scan_label)

	var live := Label.new()
	live.text = "● LIVE"
	live.add_theme_font_size_override("font_size", 10)
	live.add_theme_color_override("font_color", Color(0.26, 1.0, 0.72, 1.0))
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(live)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(0.0, 2.0)
	accent.color = Color(0.12, 0.88, 1.0, 0.72)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(accent)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(242.0, 226.0)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", _portrait_style())
	content.add_child(portrait_frame)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(230.0, 214.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_portrait)

	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 8)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(identity)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 23)
	_name_label.add_theme_color_override("font_color", TEXT)
	_name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.6, 1.0, 0.30))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(_name_label)

	_rank_label = Label.new()
	_rank_label.custom_minimum_size = Vector2(86.0, 30.0)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rank_label.add_theme_font_size_override("font_size", 11)
	_rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(_rank_label)

	var footer := Label.new()
	footer.text = "FIELD UNIT  /  HOVER INSPECTION"
	footer.add_theme_font_size_override("font_size", 9)
	footer.add_theme_color_override("font_color", Color(0.42, 0.58, 0.68, 1.0))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(footer)


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

	_name_label.text = String(record.get("name", digimon_key.capitalize())).to_upper()
	var rank := String(record.get("rank", "Unknown"))
	_rank_label.text = rank.to_upper()
	_rank_label.add_theme_color_override("font_color", _rank_color(rank))
	_rank_label.add_theme_stylebox_override("normal", _rank_style(rank))
	_load_portrait_animation(digimon_key.to_lower())
	_card.visible = _portrait.texture != null
	if _card.visible:
		_animate_in()


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


func _frame_duration_seconds() -> float:
	if _frame_index < _frame_durations.size():
		return maxf(0.02, float(_frame_durations[_frame_index]) / 1000.0)
	return 0.1


func _apply_portrait_frame() -> void:
	if _portrait_atlas == null:
		return
	_portrait_atlas.region = Rect2(
		_frame_size.x * _frame_index,
		0.0,
		_frame_size.x,
		_frame_size.y
	)


func _animate_in() -> void:
	_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_card.position = Vector2(10.0, 18.0)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, 0.14)
	tween.tween_property(_card, "position:x", 18.0, 0.14)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.045, 0.075, 0.94)
	style.border_color = Color(0.10, 0.76, 1.0, 0.66)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _portrait_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.14, 0.86)
	style.border_color = Color(0.14, 0.64, 0.88, 0.42)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 5.0
	style.content_margin_top = 5.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 5.0
	return style


func _rank_style(rank: String) -> StyleBoxFlat:
	var accent := _rank_color(rank)
	var style := StyleBoxFlat.new()
	var bg := accent
	bg.a = 0.13
	var border := accent
	border.a = 0.58
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _rank_color(rank: String) -> Color:
	match rank.to_lower():
		"rookie": return Color(0.24, 0.90, 1.0, 1.0)
		"champion": return Color(0.28, 0.88, 0.58, 1.0)
		"ultimate": return Color(0.78, 0.50, 1.0, 1.0)
		"mega": return Color(1.0, 0.72, 0.20, 1.0)
		"ultra": return Color(1.0, 0.34, 0.36, 1.0)
		"in-training", "training": return Color(0.58, 0.84, 1.0, 1.0)
	return CYAN
