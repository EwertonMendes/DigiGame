extends Control
class_name TurnOrderHUD

const UI = preload("res://src/ui/TacticalTheme.gd")
const PORTRAIT_ROOT := "res://assets/characters"
const DESKTOP_SLOTS := 6
const COMPACT_SLOTS := 4
const COMPACT_BREAKPOINT := 760.0
const DESKTOP_WIDTH := 154.0
const LAPTOP_WIDTH := 162.0
const COMPACT_WIDTH := 98.0

var _controller: Node = null
var _panel: Panel = null
var _cards: Control = null
var _title: Label = null
var _count_label: Label = null
var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2i.ZERO
var _last_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	set_process(true)
	call_deferred("refresh")


func _process(_delta: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		_last_signature = ""
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

	var compact: bool = _is_compact()
	var slot_count: int = COMPACT_SLOTS if compact else DESKTOP_SLOTS
	var entries: Array = _controller.call("get_turn_preview", slot_count)
	if entries.is_empty():
		_panel.visible = false
		return

	_panel.visible = true
	var signature: String = _signature(entries, compact)
	if signature == _last_signature:
		_layout_panel(entries.size(), compact)
		return
	_last_signature = signature

	for child: Node in _cards.get_children():
		child.queue_free()

	var y: float = 0.0
	for index in range(entries.size()):
		var raw_entry = entries[index]
		if not raw_entry is Dictionary or raw_entry.is_empty():
			continue
		var card: Control = _create_turn_card(raw_entry, compact)
		card.position = Vector2(0.0, y)
		_cards.add_child(card)
		y += card.size.y + (5.0 if compact else 7.0)
		_animate_card(card, index)
	_layout_panel(entries.size(), compact)


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "TurnOrderRail"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.94, 0.44, 11, 10))
	add_child(_panel)

	_title = _label("TURN ORDER", 12, UI.TEXT, true)
	_panel.add_child(_title)
	_count_label = _label("CT", 9, UI.SUBTLE, true)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_count_label)

	var line: ColorRect = ColorRect.new()
	line.name = "HeaderLine"
	line.color = UI.separator(UI.CYAN, 0.60)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(line)

	_cards = Control.new()
	_cards.name = "TurnCards"
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_cards)


func _create_turn_card(entry: Dictionary, compact: bool) -> Control:
	var current: bool = bool(entry.get("is_current", false))
	var ally: bool = bool(entry.get("is_player", false))
	var accent: Color = UI.CYAN if ally else UI.RED
	var instance_id: String = String(entry.get("instance_id", ""))
	var actor_name: String = String(entry.get("actor_name", "DIGIMON"))
	var digimon_key: String = String(entry.get("digimon_key", ""))
	var speed: int = int(entry.get("speed", 1))
	var slot: int = int(entry.get("slot", 0))
	var size_value: Vector2 = _card_size(current, compact)

	var card: Panel = Panel.new()
	card.custom_minimum_size = size_value
	card.size = size_value
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s • LV %d • SPD %d%s" % [actor_name, int(entry.get("level", 1)), speed, " • CURRENT" if current else ""]
	card.add_theme_stylebox_override("panel", UI.panel_strong(accent, 8) if current else UI.panel(accent, 0.89, 0.38, 8, 3))
	card.gui_input.connect(Callable(self, "_on_card_gui_input").bind(instance_id))
	card.mouse_entered.connect(Callable(self, "_on_card_mouse_entered").bind(card, instance_id))
	card.mouse_exited.connect(Callable(self, "_on_card_mouse_exited").bind(card))

	if current:
		_build_current_card(card, actor_name, digimon_key, speed, accent, compact)
	else:
		_build_future_card(card, digimon_key, speed, slot, accent, compact)
	return card


func _build_current_card(card: Panel, actor_name: String, digimon_key: String, speed: int, accent: Color, compact: bool) -> void:
	var portrait_size: float = 40.0 if compact else 48.0
	var portrait: Panel = _portrait_rect(digimon_key, Vector2(8.0, 9.0), Vector2(portrait_size, portrait_size), accent, true)
	card.add_child(portrait)
	var left: float = portrait_size + 16.0
	var available: float = maxf(28.0, card.size.x - left - 7.0)
	var now_label: Label = _label("NOW", 9 if compact else 11, UI.GOLD, true)
	now_label.position = Vector2(left, 5.0)
	now_label.size = Vector2(available, 15.0)
	card.add_child(now_label)
	if not compact:
		var name_label: Label = _label(_short_name(actor_name, 10), 12, UI.TEXT, true)
		name_label.position = Vector2(left, 21.0)
		name_label.size = Vector2(available, 18.0)
		name_label.clip_text = true
		card.add_child(name_label)
	var speed_label: Label = _label("SPD %d" % speed if not compact else str(speed), 9 if compact else 10, accent.lightened(0.16), true)
	speed_label.position = Vector2(left, 30.0 if compact else 43.0)
	speed_label.size = Vector2(available, 16.0)
	card.add_child(speed_label)
	var marker: ColorRect = ColorRect.new()
	marker.color = accent
	marker.position = Vector2(-2.0, 13.0)
	marker.size = Vector2(4.0, card.size.y - 26.0)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(marker)


func _build_future_card(card: Panel, digimon_key: String, speed: int, slot: int, accent: Color, compact: bool) -> void:
	var portrait_size: float = 31.0 if compact else 38.0
	var portrait: Panel = _portrait_rect(digimon_key, Vector2(8.0, (card.size.y - portrait_size) * 0.5), Vector2(portrait_size, portrait_size), accent, false)
	card.add_child(portrait)
	var right_x: float = portrait_size + 16.0
	var right_width: float = card.size.x - right_x - 7.0
	var order_label: Label = _label("#%d" % slot, 10 if compact else 12, UI.TEXT, true)
	order_label.position = Vector2(right_x, 6.0)
	order_label.size = Vector2(right_width, 16.0)
	card.add_child(order_label)
	var speed_label: Label = _label(str(speed) if compact else "SPD %d" % speed, 8 if compact else 10, UI.MUTED, true)
	speed_label.position = Vector2(right_x, 24.0 if compact else 27.0)
	speed_label.size = Vector2(right_width, 15.0)
	card.add_child(speed_label)


func _portrait_rect(digimon_key: String, position_value: Vector2, size_value: Vector2, accent: Color, current: bool) -> Panel:
	var frame: Panel = Panel.new()
	frame.position = position_value
	frame.size = size_value
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UI.panel(accent, 0.97, 0.76 if current else 0.34, 6, 0))
	var portrait: TextureRect = TextureRect.new()
	portrait.position = Vector2(3.0, 3.0)
	portrait.size = size_value - Vector2(6.0, 6.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = _load_portrait(digimon_key)
	frame.add_child(portrait)
	return frame


func _label(text_value: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label


func _load_portrait(digimon_key: String) -> Texture2D:
	if digimon_key.is_empty():
		return null
	var metadata_path: String = "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]
	var strip_path: String = "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(strip_path):
		return null
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary:
		return null
	var strip: Texture2D = load(strip_path) as Texture2D
	if strip == null:
		return null
	var frame_width: float = float(metadata.get("frame_width", 0))
	var frame_height: float = float(metadata.get("frame_height", 0))
	if frame_width <= 0.0 or frame_height <= 0.0:
		return null
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = strip
	atlas.region = Rect2(0.0, 0.0, frame_width, frame_height)
	return atlas


func _short_name(actor_name: String, limit: int) -> String:
	var upper: String = actor_name.to_upper()
	if upper.length() <= limit:
		return upper
	return upper.substr(0, maxi(1, limit - 1)) + "."


func _on_card_gui_input(event: InputEvent, instance_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_focus_actor(instance_id)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_focus_actor(instance_id)
			accept_event()


func _on_card_mouse_entered(card: Control, instance_id: String) -> void:
	_focus_actor(instance_id)
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position:x", -5.0, 0.10)
	tween.tween_property(card, "modulate", Color(1.06, 1.06, 1.06, 1.0), 0.10)


func _on_card_mouse_exited(card: Control) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position:x", 0.0, 0.10)
	tween.tween_property(card, "modulate", Color.WHITE, 0.10)


func _focus_actor(instance_id: String) -> void:
	if _controller != null and _controller.has_method("focus_actor_by_instance_id"):
		_controller.call("focus_actor_by_instance_id", instance_id)


func _on_viewport_size_changed() -> void:
	_last_signature = ""
	refresh()


func _is_compact() -> bool:
	return UI.is_compact(get_viewport(), COMPACT_BREAKPOINT)


func _rail_width(compact: bool) -> float:
	if compact:
		return COMPACT_WIDTH
	return LAPTOP_WIDTH if UI.is_laptop(get_viewport()) else DESKTOP_WIDTH


func _card_size(current: bool, compact: bool) -> Vector2:
	var width: float = _rail_width(compact) - 16.0
	if current:
		return Vector2(width, 60.0 if compact else 70.0)
	return Vector2(width, 46.0 if compact else 54.0)


func _layout_panel(entry_count: int, compact: bool) -> void:
	if _panel == null or _cards == null:
		return
	var viewport_obj: Viewport = get_viewport()
	var physical: Vector2 = UI.physical_window_size(viewport_obj)
	var ui_scale: float = UI.ui_scale(viewport_obj)
	var width: float = _rail_width(compact)
	var header_height: float = 44.0 if not compact else 40.0
	var current_h: float = 60.0 if compact else 70.0
	var future_h: float = 46.0 if compact else 54.0
	var gap: float = 5.0 if compact else 7.0
	var gaps: float = maxf(0.0, float(entry_count - 1)) * gap
	var cards_height: float = current_h + maxf(0.0, float(entry_count - 1)) * future_h + gaps
	var height: float = header_height + cards_height + 10.0
	var top_px: float = 60.0 if compact else 78.0
	var bottom_guard: float = 118.0 if compact else 142.0
	height = minf(height, physical.y - top_px - bottom_guard)
	_panel.scale = Vector2.ONE * ui_scale
	_panel.position = Vector2((physical.x - width - (8.0 if compact else 16.0)) * ui_scale, top_px * ui_scale)
	_panel.size = Vector2(width, height)
	_title.position = Vector2(11.0, 9.0)
	_title.size = Vector2(width - 42.0, 20.0)
	_title.add_theme_font_size_override("font_size", 9 if compact else 12)
	_count_label.position = Vector2(width - 34.0, 9.0)
	_count_label.size = Vector2(22.0, 18.0)
	_count_label.add_theme_font_size_override("font_size", 8 if compact else 9)
	_cards.position = Vector2(8.0, header_height)
	_cards.size = Vector2(width - 16.0, maxf(0.0, height - header_height - 8.0))
	var line: ColorRect = _panel.get_node_or_null("HeaderLine") as ColorRect
	if line != null:
		line.position = Vector2(11.0, 33.0)
		line.size = Vector2(width - 22.0, 1.0)


func _animate_card(card: Control, index: int) -> void:
	card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	card.position.x += 10.0
	var target_x: float = card.position.x - 10.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(float(index) * 0.018)
	tween.tween_property(card, "modulate:a", 1.0, 0.15)
	tween.tween_property(card, "position:x", target_x, 0.15)


func _signature(entries: Array, compact: bool) -> String:
	var pieces: Array[String] = ["C" if compact else "D"]
	for raw_entry in entries:
		if raw_entry is Dictionary:
			pieces.append("%s:%s:%s:%s" % [
				String(raw_entry.get("instance_id", "")),
				str(raw_entry.get("slot", 0)),
				str(raw_entry.get("speed", 0)),
				str(raw_entry.get("is_current", false)),
			])
	return "|".join(pieces)
