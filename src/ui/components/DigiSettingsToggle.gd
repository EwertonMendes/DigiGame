extends Button
class_name DigiSettingsToggle

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

var _on_label := "ON"
var _off_label := "OFF"
var _accent := V2.CYAN


func configure(off_label: String, on_label: String, active: bool, accent: Color = V2.CYAN) -> DigiSettingsToggle:
	_off_label = off_label
	_on_label = on_label
	_accent = accent
	if is_node_ready():
		set_pressed_no_signal(active)
		_refresh()
	else:
		button_pressed = active
	return self


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(132.0, 42.0)
	add_theme_font_size_override("font_size", 13)
	V2.apply_heading(self)
	toggled.connect(_on_toggled)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	mouse_entered.connect(_refresh)
	mouse_exited.connect(_refresh)
	_refresh()


func set_active(active: bool) -> void:
	set_pressed_no_signal(active)
	_refresh()


func is_active() -> bool:
	return button_pressed


func _on_toggled(_active: bool) -> void:
	_refresh()


func _refresh() -> void:
	text = _on_label if button_pressed else _off_label
	var accent := V2.RED if button_pressed else _accent
	add_theme_color_override("font_color", V2.WHITE)
	add_theme_color_override("font_hover_color", V2.WHITE)
	add_theme_color_override("font_focus_color", V2.WHITE)
	add_theme_color_override("font_pressed_color", V2.WHITE)
	var normal_state := "selected" if button_pressed else "normal"
	add_theme_stylebox_override("normal", V2.button_style(accent, normal_state))
	add_theme_stylebox_override("hover", V2.button_style(accent, "hover"))
	add_theme_stylebox_override("focus", V2.button_style(accent, "focus"))
	add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed"))
