extends PanelContainer
class_name DigiSettingsRow

signal value_changed(setting_key: String, value: float)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const VolumeControlScript = preload("res://src/ui/components/DigiVolumeControl.gd")

var _setting_key := ""
var _title_text := "SETTING"
var _description_text := ""
var _initial_value := 1.0
var _title: Label
var _description: Label
var _volume: DigiVolumeControl
var _hovered := false
var _compact := false


func configure(setting_key: String, title: String, description: String, value: float) -> DigiSettingsRow:
	_setting_key = setting_key
	_title_text = title
	_description_text = description
	_initial_value = clampf(value, 0.0, 1.0)
	if is_node_ready():
		_apply_content()
	return self


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = 76.0
	focus_entered.connect(_refresh_style)
	focus_exited.connect(_refresh_style)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 9)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(copy)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", V2.TEXT)
	V2.apply_heading(_title)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(_title)

	_description = Label.new()
	_description.add_theme_font_size_override("font_size", 11)
	_description.add_theme_color_override("font_color", V2.MUTED)
	_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	V2.apply_body(_description)
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(_description)

	_volume = VolumeControlScript.new() as DigiVolumeControl
	_volume.size_flags_horizontal = Control.SIZE_SHRINK_END
	_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume.value_changed.connect(_on_volume_changed)
	row.add_child(_volume)

	_apply_content()
	_refresh_style()


func set_value(value: float) -> void:
	_initial_value = clampf(value, 0.0, 1.0)
	if _volume != null:
		_volume.set_value(_initial_value)


func get_value() -> float:
	return _volume.get_value() if _volume != null else _initial_value


func adjust(direction: int) -> bool:
	if _volume == null or direction == 0:
		return false
	return _volume.adjust_steps(signi(direction), 0.05)


func get_setting_key() -> String:
	return _setting_key


func set_compact(enabled: bool) -> void:
	_compact = enabled
	custom_minimum_size.y = 64.0 if enabled else 76.0
	if _title != null:
		_title.add_theme_font_size_override("font_size", 13 if enabled else 15)
	if _description != null:
		_description.add_theme_font_size_override("font_size", 10 if enabled else 11)
	if _volume != null:
		_volume.set_compact(enabled)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			grab_focus()


func _apply_content() -> void:
	if _title != null:
		_title.text = _title_text.to_upper()
	if _description != null:
		_description.text = _description_text
	if _volume != null:
		_volume.set_value(_initial_value)


func _on_volume_changed(value: float) -> void:
	_initial_value = value
	value_changed.emit(_setting_key, value)


func _set_hovered(value: bool) -> void:
	_hovered = value
	_refresh_style()


func _refresh_style() -> void:
	var state := "normal"
	if has_focus():
		state = "focus"
	elif _hovered:
		state = "hover"
	add_theme_stylebox_override("panel", V2.hospital_button_style(V2.CYAN, state))
