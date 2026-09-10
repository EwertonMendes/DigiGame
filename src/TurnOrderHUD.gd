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
const COMPACT_BREAKPOINT := 900.0
const PHONE_BREAKPOINT := 520.0
const PANEL_HEIGHT := 88.0

var _controller: Node = null
var _panel: Panel = null
var _cards: Control = null
var _title: Label = null
var _hint: Label = null
var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	set_process(true)
	call_deferred("refresh")


func _process(_delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		refresh()


func setup(controller: Node) -> void:
	_controller = controller
	refresh()


func refresh() -> void:
	if _panel == null or _cards == null:
		return
	_last_viewport_size = get_viewport().get_visible_rect().size
	_last_window_size = DisplayServer.window_get_size()
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

	var separation := 4.0 if compact else 6.0
	var cursor_x := 0.0
	for raw_entry in entries:
		if not raw_entry is Dictionary or raw_entry.is_empty():
			continue
		var card := _create_turn_card(raw_entry, compact)
		card.position = Vector2(cursor_x, 0.0)
		_cards.add_child(card)
		cursor_x += card.size.x + separation

	_layout_panel(entries.size(), compact, maxf(0.0, cursor_x - separation))


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "TurnOrderPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	_title = Label.new()
	_title.text = "TURN ORDER  //  SPEED TIMELINE"
	_title.add_theme_font_size_override("font_size", 10)
	_title.add_theme_color_override("font_color", MUTED)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title)

	_hint = Label.new()
	_hint.text = "HOVER / TAP TO FOCUS"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.add_theme_color_override("font_color", Color(0.50, 0.66, 0.76, 0.78))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_hint)

	_cards = Control.new()
	_cards.name = "Cards"
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_cards)


func _create_turn_card(entry: Dictionary, compact: bool) -> Control:
	var current := bool(entry.get("is_current", false))
	var ally := bool(entry.get("is_player", false))
	var accent := CYAN if ally else RED
	var instance_id := String(entry.get("instance_id", ""))
	var actor_name := String(entry.get("actor_name", "DIGIMON"))
	var digimon_key := String(entry.get("digimon_key", ""))
	var speed := int(entry.get("speed", 1))
	var slot := int(entry.get("slot", 0))
	var card_size := _card_size(current, compact)

	var card := Panel.new()
	card.custom_minimum_size = card_size
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s  •  SPD %d  •  %s" % [actor_name, speed, "Current turn" if current else "Upcoming turn"]
	card.add_theme_stylebox_override("panel", _card_style(accent, current))
	card.gui_input.connect(Callable(self, "_on_card_gui_input").bind(instance_id))
	card.mouse_entered.connect(Callable(self, "_focus_actor").bind(instance_id))

	if current:
		_build_current_card(card, actor_name, digimon_key, speed, accent, compact)
	else:
		_build_future_card(card, digimon_key, speed, slot, accent, compact)
	return card


func _build_current_card(card: Panel, actor_name: String, digimon_key: String, speed: int, accent: Color, compact: bool) -> void:
	var portrait_size := 42.0 if not compact else 38.0
	var portrait := _portrait_rect(digimon_key, Vector2(6.0, 9.0), Vector2(portrait_size, portrait_size), accent, true)
	card.add_child(portrait)

	var left := portrait_size + 12.0
	var available_width := card.size.x - left - 5.0
	var now_label := _card_label("NOW", 9, GOLD)
	now_label.position = Vector2(left, 5.0)
	now_label.size = Vector2(available_width, 13.0)
	card.add_child(now_label)

	var name_label := _card_label(_short_name(actor_name, compact), 10 if compact else 11, TEXT)
	name_label.position = Vector2(left, 18.0)
	name_label.size = Vector2(available_width, 17.0)
	name_label.clip_text = true
	card.add_child(name_label)

	var speed_label := _card_label("SPD %d" % speed, 9, accent.lightened(0.18))
	speed_label.position = Vector2(left, 37.0)
	speed_label.size = Vector2(available_width, 14.0)
	card.add_child(speed_label)


func _build_future_card(card: Panel, digimon_key: String, speed: int, slot: int, accent: Color, compact: bool) -> void:
	var order_label := _card_label("#%d" % slot, 8, MUTED)
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_label.position = Vector2(2.0, 2.0)
	order_label.size = Vector2(card.size.x - 4.0, 12.0)
	card.add_child(order_label)

	var portrait_size := 34.0 if compact else 36.0
	var portrait_x := (card.size.x - portrait_size) * 0.5
	var portrait := _portrait_rect(digimon_key, Vector2(portrait_x, 14.0), Vector2(portrait_size, portrait_size), accent, false)
	card.add_child(portrait)

	var speed_label := _card_label("SPD %d" % speed, 8, accent.lightened(0.18))
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.position = Vector2(1.0, 48.0)
	speed_label.size = Vector2(card.size.x - 2.0, 12.0)
	speed_label.clip_text = true
	card.add_child(speed_label)


func _portrait_rect(digimon_key: String, position_value: Vector2, size_value: Vector2, accent: Color, current: bool) -> Panel:
	var frame := Panel.new()
	frame.position = position_value
	frame.size = size_value
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _portrait_style(accent, current))

	var portrait := TextureRect.new()
	portrait.position = Vector2(2.0, 2.0)
	portrait.size = size_value - Vector2(4.0, 4.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = _load_portrait(digimon_key)
	frame.add_child(portrait)
	return frame


func _card_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


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
	var limit := 6 if compact else 9
	if upper.length() <= limit:
		return upper
	return upper.substr(0, maxi(1, limit - 1)) + "."


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
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
	return viewport_size.x < COMPACT_BREAKPOINT or window_size.x < COMPACT_BREAKPOINT


func _is_phone_portrait() -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
	var viewport_phone := viewport_size.x < PHONE_BREAKPOINT and viewport_size.y > viewport_size.x
	var window_phone := window_size.x < PHONE_BREAKPOINT and window_size.y > window_size.x
	return viewport_phone or window_phone


func _card_size(current: bool, compact: bool) -> Vector2:
	if current:
		return Vector2(100.0 if compact else 126.0, 60.0)
	return Vector2(62.0 if compact else 72.0, 60.0)


func _layout_panel(entry_count: int, compact: bool, cards_width: float) -> void:
	if _panel == null or _cards == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := cards_width + 20.0
	panel_width = minf(panel_width, maxf(300.0, viewport_size.x - 20.0))

	var panel_y := 12.0
	if _is_phone_portrait():
		panel_y = 72.0
	_panel.position = Vector2((viewport_size.x - panel_width) * 0.5, panel_y)
	_panel.size = Vector2(panel_width, PANEL_HEIGHT)

	_title.position = Vector2(10.0, 5.0)
	_title.size = Vector2(panel_width * 0.58, 14.0)
	_hint.visible = not _is_phone_portrait()
	_hint.position = Vector2(panel_width * 0.56, 5.0)
	_hint.size = Vector2(panel_width * 0.40 - 10.0, 14.0)

	_cards.position = Vector2(10.0, 21.0)
	_cards.size = Vector2(cards_width, 60.0)


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
