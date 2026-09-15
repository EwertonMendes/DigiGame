extends PanelContainer
class_name DigiInteractionPrompt

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

enum InputMode {
	KEYBOARD_MOUSE,
	XBOX,
	PLAYSTATION,
	TOUCH,
}

var _key_badge: PanelContainer
var _key_label: Label
var _action_label: Label
var _mode := InputMode.TOUCH if DisplayServer.is_touchscreen_available() else InputMode.KEYBOARD_MOUSE
var _last_touch_msec := -10000


func _init() -> void:
	set_meta("digi_ui_v2_component", true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190.0, V2.TOUCH_TARGET)
	add_theme_stylebox_override(
		"panel",
		V2.surface_style(
			Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.97),
			Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.74),
			V2.CARD_RADIUS,
			Vector4(12.0, 8.0, 14.0, 8.0),
			0.14
		)
	)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_key_badge = PanelContainer.new()
	_key_badge.custom_minimum_size = Vector2(44.0, 34.0)
	_key_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_badge.add_theme_stylebox_override("panel", V2.pill_style(V2.AMBER, true))
	row.add_child(_key_badge)

	_key_label = Label.new()
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_label.add_theme_font_size_override("font_size", 11)
	_key_label.add_theme_color_override("font_color", V2.WHITE)
	V2.apply_heading(_key_label)
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_badge.add_child(_key_label)

	_action_label = Label.new()
	_action_label.text = "TALK"
	_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 13)
	_action_label.add_theme_color_override("font_color", V2.TEXT)
	V2.apply_heading(_action_label)
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_action_label)

	_refresh_key()


func set_action(text: String) -> void:
	if _action_label != null:
		_action_label.text = text.strip_edges().to_upper()


func get_action_label() -> Label:
	return _action_label


func get_key_text() -> String:
	return _key_label.text if _key_label != null else ""


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
		_refresh_key()


func _joypad_mode(device: int) -> int:
	var joy_name := Input.get_joy_name(device).to_lower()
	if "playstation" in joy_name or "dualshock" in joy_name or "dualsense" in joy_name or "sony" in joy_name:
		return InputMode.PLAYSTATION
	return InputMode.XBOX


func _refresh_key() -> void:
	if _key_label == null:
		return
	match _mode:
		InputMode.PLAYSTATION:
			_key_label.text = "X"
		InputMode.XBOX:
			_key_label.text = "A"
		InputMode.TOUCH:
			_key_label.text = "TAP"
		_:
			_key_label.text = "E"
