extends Control
class_name TurnOrderHUD

const UI = preload("res://src/ui/TacticalTheme.gd")
const PORTRAIT_ROOT := "res://assets/characters"
const DESKTOP_SLOTS := 6
const COMPACT_BREAKPOINT := 760.0

var _controller: Node = null
var _panel: Control = null
var _cards: Control = null
var _title: Label = null
var _spine: ColorRect = null
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
	var physical := UI.physical_window_size(get_viewport())
	var slot_count := _compact_slot_count(physical.x) if compact else DESKTOP_SLOTS
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
		var entry := raw_entry as Dictionary
		var card := _create_turn_card(entry, compact)
		var current := bool(entry.get("is_current", false))
		if compact:
			card.position = Vector2(cursor, 7.0 if current else 11.0)
			cursor += card.size.x + 8.0
		else:
			var x_offset := 0.0 if current else 8.0
			card.position = Vector2(x_offset, cursor)
			cursor += card.size.y + 8.0
		_cards.add_child(card)
		_animate_card(card, index)
	_layout_panel(entries.size(), compact)


func _build_ui() -> void:
	_panel = Control.new()
	_panel.name = "TurnTimeline"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_title = _label("TURN", 12, UI.MUTED)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_title)

	_spine = ColorRect.new()
	_spine.color = UI.separator(UI.GOLD, 0.36)
	_spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_spine)

	_cards = Control.new()
	_cards.name = "TurnNodes"
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_cards)


func _create_turn_card(entry: Dictionary, compact: bool) -> Button:
	var current := bool(entry.get("is_current", false))
	var ally := bool(entry.get("is_player", false))
	var accent := UI.BLUE if ally else UI.RED
	if current:
		accent = UI.GOLD
	var instance_id := String(entry.get("instance_id", ""))
	var actor_name := String(entry.get("actor_name", "Digimon"))
	var digimon_key := String(entry.get("digimon_key", ""))
	var speed := int(entry.get("speed", 1))
	var slot := int(entry.get("slot", 0))
	var size_value := _card_size(current, compact)

	var card := Button.new()
	card.name = "TurnNode_%s" % instance_id
	card.custom_minimum_size = size_value
	card.size = size_value
	card.text = ""
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s · Lv.%d · Speed %d%s" % [actor_name, int(entry.get("level", 1)), speed, " · Current turn" if current else ""]
	card.icon = _load_portrait(digimon_key)
	card.expand_icon = true
	card.icon_max_width = 42 if current else 34
	card.add_theme_color_override("icon_normal_color", Color.WHITE)
	card.add_theme_color_override("icon_hover_color", Color.WHITE)
	card.add_theme_color_override("icon_pressed_color", Color.WHITE)
	card.add_theme_color_override("icon_focus_color", Color.WHITE)
	card.add_theme_stylebox_override("normal", UI.turn_node_style(accent, current, "normal"))
	card.add_theme_stylebox_override("hover", UI.turn_node_style(accent, current, "hover"))
	card.add_theme_stylebox_override("pressed", UI.turn_node_style(accent, current, "pressed"))
	card.add_theme_stylebox_override("focus", UI.focus_outline(accent, 13 if current else 11))
	card.pressed.connect(Callable(self, "_focus_actor").bind(instance_id))
	card.mouse_entered.connect(Callable(self, "_on_card_mouse_entered").bind(card))
	card.mouse_exited.connect(Callable(self, "_on_card_mouse_exited").bind(card))
	card.focus_entered.connect(Callable(self, "_on_card_focus").bind(card, true))
	card.focus_exited.connect(Callable(self, "_on_card_focus").bind(card, false))

	var team_tick := ColorRect.new()
	team_tick.color = accent
	team_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	team_tick.position = Vector2(-4.0, size_value.y * 0.5 - 8.0)
	team_tick.size = Vector2(3.0, 16.0)
	card.add_child(team_tick)

	var order_label := _label("NOW" if current else str(slot), 10 if compact else 11, UI.GOLD if current else UI.MUTED)
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_label.position = Vector2(3.0, size_value.y - 17.0)
	order_label.size = Vector2(size_value.x - 6.0, 14.0)
	card.add_child(order_label)
	return card


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


func _on_card_mouse_entered(card: Control) -> void:
	_animate_card_scale(card, Vector2(1.06, 1.06))


func _on_card_mouse_exited(card: Control) -> void:
	if card != get_viewport().gui_get_focus_owner():
		_animate_card_scale(card, Vector2.ONE)


func _on_card_focus(card: Control, focused: bool) -> void:
	_animate_card_scale(card, Vector2(1.06, 1.06) if focused else Vector2.ONE)


func _animate_card_scale(card: Control, target: Vector2) -> void:
	card.pivot_offset = card.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", target, 0.09)


func _focus_actor(instance_id: String) -> void:
	if _controller != null and _controller.has_method("focus_actor_by_instance_id"):
		_controller.call("focus_actor_by_instance_id", instance_id)


func _on_viewport_size_changed() -> void:
	_last_signature = ""
	refresh()


func _is_compact() -> bool:
	return UI.is_compact(get_viewport(), COMPACT_BREAKPOINT)


func _compact_slot_count(width: float) -> int:
	if width < 280.0:
		return 3
	if width < 360.0:
		return 4
	return 5


func _card_size(current: bool, compact: bool) -> Vector2:
	if compact:
		return Vector2(58.0, 58.0) if current else Vector2(50.0, 50.0)
	return Vector2(66.0, 66.0) if current else Vector2(54.0, 54.0)


func _layout_panel(entry_count: int, compact: bool) -> void:
	if _panel == null or _cards == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	if compact:
		_title.visible = false
		var current_w := 58.0
		var future_w := 50.0
		var cards_width := current_w + maxf(0.0, float(entry_count - 1)) * future_w + maxf(0.0, float(entry_count - 1)) * 8.0
		var width := minf(physical.x - 20.0, cards_width)
		var height := 66.0
		_panel.scale = Vector2.ONE * ui_scale
		_panel.position = Vector2((physical.x - width) * 0.5 * ui_scale, 58.0 * ui_scale)
		_panel.size = Vector2(width, height)
		_cards.position = Vector2(0.0, 0.0)
		_cards.size = Vector2(width, height)
		_spine.position = Vector2(8.0, 32.0)
		_spine.size = Vector2(maxf(0.0, width - 16.0), 1.0)
	else:
		_title.visible = true
		var width := 74.0
		var current_h := 66.0
		var future_h := 54.0
		var cards_height := current_h + maxf(0.0, float(entry_count - 1)) * future_h + maxf(0.0, float(entry_count - 1)) * 8.0
		var height := minf(cards_height + 28.0, physical.y - 160.0)
		var top := clampf((physical.y - height) * 0.5, 82.0, maxf(82.0, physical.y - height - 92.0))
		_panel.scale = Vector2.ONE * ui_scale
		_panel.position = Vector2((physical.x - width - 18.0) * ui_scale, top * ui_scale)
		_panel.size = Vector2(width, height)
		_title.position = Vector2(0.0, 0.0)
		_title.size = Vector2(width, 20.0)
		_title.add_theme_font_size_override("font_size", 11)
		_cards.position = Vector2(4.0, 25.0)
		_cards.size = Vector2(width - 4.0, maxf(0.0, height - 25.0))
		_spine.position = Vector2(width * 0.5 - 1.0, 25.0)
		_spine.size = Vector2(2.0, maxf(0.0, height - 31.0))


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
	card.position += Vector2(8.0, 0.0) if not _is_compact() else Vector2(0.0, -5.0)
	var target := card.position - (Vector2(8.0, 0.0) if not _is_compact() else Vector2(0.0, -5.0))
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(minf(0.10, float(index) * 0.02))
	tween.tween_property(card, "modulate:a", 1.0, 0.14)
	tween.tween_property(card, "position", target, 0.14)
