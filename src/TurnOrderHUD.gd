extends Control
class_name TurnOrderHUD

const PORTRAIT_ROOT := "res://assets/characters"
const CYAN := Color(0.12, 0.88, 1.0, 1.0)
const RED := Color(1.0, 0.30, 0.28, 1.0)
const GOLD := Color(1.0, 0.76, 0.16, 1.0)
const TEXT := Color(0.93, 0.98, 1.0, 1.0)
const MUTED := Color(0.58, 0.72, 0.82, 1.0)
const PANEL_BG := Color(0.012, 0.042, 0.072, 0.92)
const DESKTOP_SLOTS := 7
const COMPACT_SLOTS := 4
const COMPACT_BREAKPOINT := 760.0

var _controller: Node = null
var _panel: PanelContainer = null
var _cards: HBoxContainer = null
var _title: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("refresh")


func setup(controller: Node) -> void:
	_controller = controller
	refresh()


func refresh() -> void:
	if _panel == null or _cards == null:
		return
	if _controller == null or not _controller.has_method("get_turn_preview"):
		_panel.visible = false
		return

	var compact := _is_compact()
	var slot_count := COMPACT_SLOTS if compact else DESKTOP_SLOTS
	var entries: Array = _controller.call("get_turn_preview", slot_count)
	if entries.is_empty():
		_panel.visible = false
		return

	_panel.visible = true
	for child in _cards.get_children():
		child.queue_free()

	for raw_entry in entries:
		if raw_entry is Dictionary and not raw_entry.is_empty():
			_cards.add_child(_create_turn_card(raw_entry, compact))
	_layout_panel(entries.size(), compact)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TurnOrderPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)

	_title = Label.new()
	_title.text = "TURN ORDER  //  SPEED TIMELINE"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 10)
	_title.add_theme_color_override("font_color", MUTED)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_title)

	var hint := Label.new()
	hint.text = "HOVER / TAP TO FOCUS"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.50, 0.66, 0.76, 0.78))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(hint)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 6)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cards)


func _create_turn_card(entry: Dictionary, compact: bool) -> Control:
	var current := bool(entry.get("is_current", false))
	var ally := bool(entry.get("is_player", false))
	var accent := CYAN if ally else RED
	var instance_id := String(entry.get("instance_id", ""))
	var actor_name := String(entry.get("actor_name", "DIGIMON"))
	var digimon_key := String(entry.get("digimon_key", ""))
	var speed := int(entry.get("speed", 1))
	var slot := int(entry.get("slot", 0))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(108.0 if current else (82.0 if compact else 92.0), 62.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s  •  SPD %d  •  %s" % [actor_name, speed, "Current turn" if current else "Upcoming turn"]
	card.add_theme_stylebox_override("panel", _card_style(accent, current))
	card.gui_input.connect(Callable(self, "_on_card_gui_input").bind(instance_id))
	card.mouse_entered.connect(Callable(self, "_focus_actor").bind(instance_id))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(46.0 if current else 40.0, 46.0 if current else 40.0)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", _portrait_style(accent, current))
	row.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = portrait_frame.custom_minimum_size - Vector2(4.0, 4.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = _load_portrait(digimon_key)
	portrait_frame.add_child(portrait)

	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 0)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)

	var order_label := Label.new()
	order_label.text = "NOW" if current else "NEXT %d" % slot
	order_label.add_theme_font_size_override("font_size", 9)
	order_label.add_theme_color_override("font_color", GOLD if current else MUTED)
	order_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(order_label)

	var name_label := Label.new()
	name_label.text = _short_name(actor_name, compact and not current)
	name_label.add_theme_font_size_override("font_size", 11 if current else 10)
	name_label.add_theme_color_override("font_color", TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(name_label)

	var speed_label := Label.new()
	speed_label.text = "SPD %d" % speed
	speed_label.add_theme_font_size_override("font_size", 9)
	speed_label.add_theme_color_override("font_color", accent.lightened(0.18))
	speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(speed_label)

	return card


func _load_portrait(digimon_key: String) -> Texture2D:
	if digimon_key.is_empty():
		return null
	var metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]
	var strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(strip_path):
		return null
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary:
		return null
	var strip := load(strip_path) as Texture2D
	if strip == null:
		return null
	var frame_width := float(metadata.get("frame_width", 0))
	var frame_height := float(metadata.get("frame_height", 0))
	if frame_width <= 0.0 or frame_height <= 0.0:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = strip
	atlas.region = Rect2(0.0, 0.0, frame_width, frame_height)
	return atlas


func _short_name(actor_name: String, compact: bool) -> String:
	var upper := actor_name.to_upper()
	if not compact or upper.length() <= 7:
		return upper
	return upper.substr(0, 6) + "."


func _on_card_gui_input(event: InputEvent, instance_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_focus_actor(instance_id)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_focus_actor(instance_id)
			accept_event()


func _focus_actor(instance_id: String) -> void:
	if _controller != null and _controller.has_method("focus_actor_by_instance_id"):
		_controller.call("focus_actor_by_instance_id", instance_id)


func _on_viewport_size_changed() -> void:
	refresh()


func _is_compact() -> bool:
	return get_viewport().get_visible_rect().size.x < COMPACT_BREAKPOINT


func _layout_panel(entry_count: int, compact: bool) -> void:
	if _panel == null:
		return
	var current_width := 108.0
	var future_width := 82.0 if compact else 92.0
	var card_width := current_width + future_width * float(maxi(0, entry_count - 1))
	var gap_width := 6.0 * float(maxi(0, entry_count - 1))
	var panel_width := card_width + gap_width + 24.0
	var viewport_width := get_viewport().get_visible_rect().size.x
	panel_width = minf(panel_width, maxf(320.0, viewport_width - 28.0))
	_panel.custom_minimum_size = Vector2(panel_width, 90.0)
	_panel.size = Vector2(panel_width, 90.0)
	_panel.position = Vector2((viewport_width - panel_width) * 0.5, 12.0)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = Color(0.10, 0.72, 0.96, 0.34)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 8
	return style


func _card_style(accent: Color, current: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.09, accent.g * 0.09, accent.b * 0.09, 0.96) if current else Color(0.025, 0.07, 0.105, 0.90)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.95 if current else 0.48)
	style.set_border_width_all(2 if current else 1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _portrait_style(accent: Color, current: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.025, 0.045, 0.98)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.85 if current else 0.38)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style
