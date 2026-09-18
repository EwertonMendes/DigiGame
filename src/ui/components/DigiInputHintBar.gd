extends PanelContainer
class_name DigiInputHintBar

signal input_mode_changed(mode: int)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

enum InputMode {
	KEYBOARD_MOUSE,
	XBOX,
	PLAYSTATION,
	TOUCH,
}

var _row: HBoxContainer
var _description: Label
var _description_text := "Manage your Digimon and view their information."
var _mode := InputMode.TOUCH if DisplayServer.is_touchscreen_available() else InputMode.KEYBOARD_MOUSE
var _last_touch_msec := -10000
var _primary_tabs_enabled := false
var _secondary_tabs_enabled := false
var _secondary_tabs_label := "Stats / Development"
var _pagination_enabled := false
var _scroll_hint_enabled := true
var _hide_hints_on_touch := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	clip_contents = true
	var style := V2.surface_style(Color(V2.BASE.r, V2.BASE.g, V2.BASE.b, 0.995), Color.TRANSPARENT, 0)
	style.border_color = Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.60)
	style.border_width_top = 1
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row.add_theme_constant_override("separation", 12)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.clip_contents = true
	margin.add_child(_row)
	_refresh()


func set_description(text: String) -> void:
	_description_text = text
	if _description != null:
		_description.text = text


func set_primary_tabs_enabled(enabled: bool) -> void:
	if _primary_tabs_enabled == enabled:
		return
	_primary_tabs_enabled = enabled
	if _row != null:
		_refresh()


func set_secondary_tabs_enabled(enabled: bool) -> void:
	if _secondary_tabs_enabled == enabled:
		return
	_secondary_tabs_enabled = enabled
	if _row != null:
		_refresh()


func set_secondary_tabs_label(label: String) -> void:
	var next_label := label.strip_edges()
	if next_label.is_empty():
		next_label = "Stats / Development"
	if _secondary_tabs_label == next_label:
		return
	_secondary_tabs_label = next_label
	if _row != null:
		_refresh()


func set_pagination_enabled(enabled: bool) -> void:
	if _pagination_enabled == enabled:
		return
	_pagination_enabled = enabled
	if _row != null:
		_refresh()


func set_scroll_hint_enabled(enabled: bool) -> void:
	if _scroll_hint_enabled == enabled:
		return
	_scroll_hint_enabled = enabled
	if _row != null:
		_refresh()


func set_hide_hints_on_touch(enabled: bool) -> void:
	if _hide_hints_on_touch == enabled:
		return
	_hide_hints_on_touch = enabled
	if _row != null:
		_refresh()


func get_input_mode() -> int:
	return _mode


func is_touch_mode() -> bool:
	return _mode == InputMode.TOUCH


func _input(event: InputEvent) -> void:
	var next_mode := _mode
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_msec = Time.get_ticks_msec()
		next_mode = InputMode.TOUCH
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_mode = _joypad_mode(event.device)
	elif event is InputEventKey:
		next_mode = InputMode.KEYBOARD_MOUSE
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if Time.get_ticks_msec() - _last_touch_msec > 500:
			if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length_squared() < 0.5:
				return
			next_mode = InputMode.KEYBOARD_MOUSE
	if next_mode != _mode:
		_mode = next_mode
		_refresh()
		input_mode_changed.emit(_mode)


func _joypad_mode(device: int) -> int:
	var name := Input.get_joy_name(device).to_lower()
	if "playstation" in name or "dualshock" in name or "dualsense" in name or "sony" in name:
		return InputMode.PLAYSTATION
	return InputMode.XBOX


func _menu_hints() -> Array[Dictionary]:
	match _mode:
		InputMode.PLAYSTATION:
			var hints: Array[Dictionary] = []
			if _primary_tabs_enabled:
				hints.append({"key": "L1/R1", "label": "Tabs", "accent": V2.CYAN})
			if _secondary_tabs_enabled:
				hints.append({"key": "□", "label": _secondary_tabs_label, "accent": V2.CYAN})
			if _pagination_enabled:
				hints.append({"key": "L2/R2", "label": "Pages", "accent": V2.CYAN})
			hints.append({"key": "D-PAD", "label": "Navigate", "accent": V2.MUTED})
			if _scroll_hint_enabled:
				hints.append({"key": "RS", "label": "Scroll", "accent": V2.MUTED})
			hints.append_array([
				{"key": "X", "label": "Select", "accent": V2.BLUE},
				{"key": "O", "label": "Back", "accent": V2.RED},
			])
			return hints
		InputMode.XBOX:
			var hints: Array[Dictionary] = []
			if _primary_tabs_enabled:
				hints.append({"key": "LB/RB", "label": "Tabs", "accent": V2.CYAN})
			if _secondary_tabs_enabled:
				hints.append({"key": "X", "label": _secondary_tabs_label, "accent": V2.CYAN})
			if _pagination_enabled:
				hints.append({"key": "LT/RT", "label": "Pages", "accent": V2.CYAN})
			hints.append({"key": "D-PAD", "label": "Navigate", "accent": V2.MUTED})
			if _scroll_hint_enabled:
				hints.append({"key": "RS", "label": "Scroll", "accent": V2.MUTED})
			hints.append_array([
				{"key": "A", "label": "Select", "accent": V2.GREEN},
				{"key": "B", "label": "Back", "accent": V2.RED},
			])
			return hints
		InputMode.TOUCH:
			if _hide_hints_on_touch:
				return []
			var hints: Array[Dictionary] = [
				{"key": "TAP", "label": "Select", "accent": V2.CYAN},
			]
			if _scroll_hint_enabled:
				hints.append({"key": "DRAG", "label": "Scroll", "accent": V2.MUTED})
			return hints
		_:
			var hints: Array[Dictionary] = []
			if _primary_tabs_enabled:
				hints.append({"key": "TAB", "label": "Tabs · Click", "accent": V2.CYAN})
			if _secondary_tabs_enabled:
				hints.append({"key": "X", "label": _secondary_tabs_label, "accent": V2.CYAN})
			hints.append_array([
				{"key": "ARROWS", "label": "Navigate", "accent": V2.MUTED},
				{"key": "ENTER", "label": "Select · Click", "accent": V2.CYAN},
				{"key": "ESC", "label": "Back", "accent": V2.MUTED},
			])
			return hints


func _refresh() -> void:
	if _row == null:
		return
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()

	_description = Label.new()
	_description.text = _description_text
	_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description.custom_minimum_size.x = 0.0
	_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description.autowrap_mode = TextServer.AUTOWRAP_OFF
	_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_description.add_theme_font_size_override("font_size", 12)
	_description.add_theme_color_override("font_color", V2.MUTED)
	V2.apply_body(_description)
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_description)

	for hint in _menu_hints():
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 7)
		group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(group)

		var accent: Color = hint.get("accent", V2.CYAN) as Color
		var key := Label.new()
		key.text = String(hint.get("key", ""))
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.custom_minimum_size = Vector2(34.0, 28.0)
		key.add_theme_font_size_override("font_size", 10)
		key.add_theme_color_override("font_color", V2.TEXT)
		key.add_theme_stylebox_override("normal", V2.pill_style(accent, true))
		V2.apply_heading(key)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(key)

		var copy := Label.new()
		copy.text = String(hint.get("label", ""))
		copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		copy.autowrap_mode = TextServer.AUTOWRAP_OFF
		copy.add_theme_font_size_override("font_size", 11)
		copy.add_theme_color_override("font_color", V2.MUTED)
		V2.apply_body(copy)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(copy)
