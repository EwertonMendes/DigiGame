extends Control
class_name TurnOrderHUD

const UI = preload("res://src/ui/TacticalTheme.gd")
const PORTRAIT_ROOT := "res://assets/characters"
const DESKTOP_SLOTS := 6
const COMPACT_SLOTS := 5
const COMPACT_BREAKPOINT := 760.0

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
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
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

	var compact := _is_compact()
	var slot_count := COMPACT_SLOTS if compact else DESKTOP_SLOTS
	var entries: Array = _controller.call("get_turn_preview", slot_count)
	if entries.is_empty():
		_panel.visible = false
		return

	_panel.visible = true
	var signature := _signature(entries, compact)
	if signature == _last_signature:
		_layout_panel(entries.size(), compact)
		return
	_last_signature = signature

	for child: Node in _cards.get_children():
		child.queue_free()

	var cursor := 0.0
	for index in range(entries.size()):
		var raw_entry = entries[index]
		if not raw_entry is Dictionary or raw_entry.is_empty():
			continue
		var card := _create_turn_card(raw_entry, compact)
		card.position = Vector2(cursor, 0.0) if compact else Vector2(0.0, cursor)
		_cards.add_child(card)
		cursor += (card.size.x if compact else card.size.y) + 6.0
		_animate_card(card, index)
	_layout_panel(entries.size(), compact)


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.name = "TurnOrderRail"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UI.panel(UI.GOLD, 0.92, 0.18, 10, 3))
	add_child(_panel)

	_title = _label("Turns", 14, UI.MUTED)
	_panel.add_child(_title)
	_count_label = _label("", 14, UI.SUBTLE)
	_count_label.visible = false
	_panel.add_child(_count_label)

	_cards = Control.new()
	_cards.name = "TurnCards"
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_cards)


func _create_turn_card(entry: Dictionary, compact: bool) -> Control:
	var current := bool(entry.get("is_current", false))
	var ally := bool(entry.get("is_player", false))
	var accent := UI.BLUE if ally else UI.RED
	var instance_id := String(entry.get("instance_id", ""))
	var actor_name := String(entry.get("actor_name", "Digimon"))
	var digimon_key := String(entry.get("digimon_key", ""))
	var speed := int(entry.get("speed", 1))
	var slot := int(entry.get("slot", 0))
	var size_value := _card_size(current, compact)

	var card := Panel.new()
	card.custom_minimum_size = size_value
	card.size = size_value
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s · Lv. %d · Speed %d%s" % [actor_name, int(entry.get("level", 1)), speed, " · Current turn" if current else ""]
	card.add_theme_stylebox_override("panel", UI.panel_strong(accent, 9) if current else UI.panel(accent, 0.90, 0.22, 9, 0))
	card.gui_input.connect(Callable(self, "_on_card_gui_input").bind(instance_id))
	card.mouse_entered.connect(Callable(self, "_on_card_mouse_entered").bind(card))
	card.mouse_exited.connect(Callable(self, "_on_card_mouse_exited").bind(card))

	var portrait_size := 38.0 if current else 34.0
	if not compact:
		portrait_size = 42.0 if current else 36.0
	var portrait_pos := Vector2((size_value.x - portrait_size) * 0.5, 7.0 if current else (size_value.y - portrait_size) * 0.5)
	var portrait := _portrait_rect(digimon_key, portrait_pos, Vector2(portrait_size, portrait_size), accent, current)
	card.add_child(portrait)

	if current:
		var now_label := _label("Now", 14, UI.GOLD)
		now_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		now_label.position = Vector2(4.0, size_value.y - 25.0)
		now_label.size = Vector2(size_value.x - 8.0, 20.0)
		card.add_child(now_label)
	else:
		var order_label := _label(str(slot), 14, UI.TEXT)
		order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		order_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		order_label.position = Vector2(size_value.x - 23.0, 4.0)
		order_label.size = Vector2(18.0, 18.0)
		order_label.add_theme_stylebox_override("normal", UI.pill(accent, 0.10))
		card.add_child(order_label)
	return card


func _portrait_rect(digimon_key: String, position_value: Vector2, size_value: Vector2, accent: Color, current: bool) -> Panel:
	var frame := Panel.new()
	frame.position = position_value
	frame.size = size_value
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UI.panel(accent, 0.97, 0.38 if current else 0.16, 7, 0))
	var portrait := TextureRect.new()
	portrait.position = Vector2(3.0, 3.0)
	portrait.size = size_value - Vector2(6.0, 6.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = _load_portrait(digimon_key)
	frame.add_child(portrait)
	return frame


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.apply_body_font(label)
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


func _on_card_mouse_entered(card: Control) -> void:
	card.pivot_offset = card.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.04, 1.04), 0.10)


func _on_card_mouse_exited(card: Control) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.10)


func _focus_actor(instance_id: String) -> void:
	if _controller != null and _controller.has_method("focus_actor_by_instance_id"):
		_controller.call("focus_actor_by_instance_id", instance_id)


func _on_viewport_size_changed() -> void:
	_last_signature = ""
	refresh()


func _is_compact() -> bool:
	return UI.is_compact(get_viewport(), COMPACT_BREAKPOINT)


func _card_size(current: bool, compact: bool) -> Vector2:
	if compact:
		return Vector2(62.0, 58.0) if current else Vector2(54.0, 54.0)
	return Vector2(76.0, 76.0) if current else Vector2(76.0, 56.0)


func _layout_panel(entry_count: int, compact: bool) -> void:
	if _panel == null or _cards == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	if compact:
		_title.visible = false
		var current_w := 62.0
		var future_w := 54.0
		var cards_width := current_w + maxf(0.0, float(entry_count - 1)) * future_w + maxf(0.0, float(entry_count - 1)) * 6.0
		var width := minf(physical.x - 20.0, cards_width + 16.0)
		var height := 70.0
		_panel.scale = Vector2.ONE * ui_scale
		_panel.position = Vector2((physical.x - width) * 0.5 * ui_scale, 60.0 * ui_scale)
		_panel.size = Vector2(width, height)
		_cards.position = Vector2(8.0, 7.0)
		_cards.size = Vector2(width - 16.0, height - 14.0)
	else:
		_title.visible = true
		var width := 92.0
		var current_h := 76.0
		var future_h := 56.0
		var cards_height := current_h + maxf(0.0, float(entry_count - 1)) * future_h + maxf(0.0, float(entry_count - 1)) * 6.0
		var height := minf(cards_height + 48.0, physical.y - 190.0)
		var top := clampf((physical.y - height) * 0.5, 78.0, maxf(78.0, physical.y - height - 116.0))
		_panel.scale = Vector2.ONE * ui_scale
		_panel.position = Vector2((physical.x - width - 16.0) * ui_scale, top * ui_scale)
		_panel.size = Vector2(width, height)
		_title.position = Vector2(12.0, 8.0)
		_title.size = Vector2(width - 24.0, 24.0)
		_title.add_theme_font_size_override("font_size", 14)
		_cards.position = Vector2(8.0, 38.0)
		_cards.size = Vector2(width - 16.0, maxf(0.0, height - 46.0))


func _signature(entries: Array, compact: bool) -> String:
	var parts: Array[String] = ["compact" if compact else "desktop"]
	for raw_entry in entries:
		if raw_entry is Dictionary:
			var entry := raw_entry as Dictionary
			parts.append("%s:%s:%s:%s" % [
				String(entry.get("instance_id", "")),
				str(entry.get("slot", 0)),
				str(entry.get("speed", 0)),
				str(entry.get("is_current", false)),
			])
	return "|".join(parts)


func _animate_card(card: Control, index: int) -> void:
	card.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(minf(0.12, float(index) * 0.025))
	tween.tween_property(card, "modulate:a", 1.0, 0.14)
