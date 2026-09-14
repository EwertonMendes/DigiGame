extends PanelContainer
class_name DigiInputHintBar

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

enum InputMode {
	KEYBOARD_MOUSE,
	XBOX,
	PLAYSTATION,
	TOUCH,
}

var _row: HBoxContainer
var _mode := InputMode.TOUCH if DisplayServer.is_touchscreen_available() else InputMode.KEYBOARD_MOUSE
var _last_touch_msec := -10000


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	add_theme_stylebox_override(
		"panel",
		V2.surface_style(Color(V2.BASE.r, V2.BASE.g, V2.BASE.b, 0.98), Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.52), 10)
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_END
	_row.add_theme_constant_override("separation", 14)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_row)
	_refresh()


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
		# Browsers can emit a synthetic mouse event immediately after a touch.
		# Keep the touch presentation stable instead of flickering back to mouse.
		if Time.get_ticks_msec() - _last_touch_msec > 500:
			if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length_squared() < 0.5:
				return
			next_mode = InputMode.KEYBOARD_MOUSE
	if next_mode != _mode:
		_mode = next_mode
		_refresh()


func _joypad_mode(device: int) -> int:
	var name := Input.get_joy_name(device).to_lower()
	if "playstation" in name or "dualshock" in name or "dualsense" in name or "sony" in name:
		return InputMode.PLAYSTATION
	return InputMode.XBOX


func _menu_hints() -> Array[Dictionary]:
	match _mode:
		InputMode.PLAYSTATION:
			return [
				{"key": "D-PAD", "label": "Navigate"},
				{"key": "X", "label": "Select"},
				{"key": "O", "label": "Back"},
			]
		InputMode.XBOX:
			return [
				{"key": "D-PAD", "label": "Navigate"},
				{"key": "A", "label": "Select"},
				{"key": "B", "label": "Back"},
			]
		InputMode.TOUCH:
			return [
				{"key": "TAP", "label": "Select"},
				{"key": "DRAG", "label": "Scroll"},
			]
		_:
			return [
				{"key": "ARROWS", "label": "Navigate"},
				{"key": "ENTER", "label": "Select"},
				{"key": "ESC", "label": "Back"},
			]


func _refresh() -> void:
	if _row == null:
		return
	for child in _row.get_children():
		child.queue_free()
	for hint in _menu_hints():
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 6)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(group)

		var key := Label.new()
		key.text = String(hint.get("key", ""))
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.custom_minimum_size = Vector2(34.0, 28.0)
		key.add_theme_font_size_override("font_size", 10)
		key.add_theme_color_override("font_color", V2.TEXT)
		key.add_theme_stylebox_override("normal", V2.pill_style(V2.CYAN, true))
		V2.apply_heading(key)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(key)

		var copy := Label.new()
		copy.text = String(hint.get("label", ""))
		copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		copy.add_theme_font_size_override("font_size", 11)
		copy.add_theme_color_override("font_color", V2.MUTED)
		V2.apply_body(copy)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(copy)
