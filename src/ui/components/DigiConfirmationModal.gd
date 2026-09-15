extends Control
class_name DigiConfirmationModal

signal confirmed
signal cancelled

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

var _backdrop: ColorRect
var _panel: Panel
var _eyebrow: Label
var _title: Label
var _body: Label
var _confirm_button: Button
var _cancel_button: Button
var _accent := V2.CYAN
var _previous_focus: Control = null
var _open_tween: Tween = null


func _init() -> void:
	set_meta("digi_ui_v2_component", true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	visible = false


func configure(
	title_text: String,
	body_text: String,
	confirm_text: String = "YES",
	cancel_text: String = "NO",
	accent: Color = V2.CYAN,
	eyebrow_text: String = "CONFIRM ACTION"
) -> void:
	_accent = accent
	if _title != null:
		_title.text = title_text
		_body.text = body_text
		_confirm_button.text = confirm_text
		_cancel_button.text = cancel_text
		_eyebrow.text = eyebrow_text
		_apply_accent()


func open_dialog(previous_focus: Control = null) -> void:
	_previous_focus = previous_focus if previous_focus != null else get_viewport().gui_get_focus_owner()
	visible = true
	_layout()
	_backdrop.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.965
	_panel.pivot_offset = _panel.size * 0.5
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = create_tween().set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.12)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.14)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, 0.14)
	call_deferred("_focus_safe_default")


func close_dialog(restore_focus: bool = true) -> void:
	if not visible:
		return
	visible = false
	if restore_focus and _previous_focus != null and is_instance_valid(_previous_focus) and _previous_focus.visible and _previous_focus.focus_mode != Control.FOCUS_NONE:
		_previous_focus.grab_focus()
	_previous_focus = null


func get_panel() -> Panel:
	return _panel


func get_confirm_button() -> Button:
	return _confirm_button


func get_cancel_button() -> Button:
	return _cancel_button


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.004, 0.012, 0.020, 0.78)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_panel = Panel.new()
	_panel.name = "ConfirmationPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	add_child(_panel)

	_eyebrow = _label("CONFIRM ACTION", 10, V2.CYAN, true)
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_eyebrow)

	_title = _label("ARE YOU SURE?", 24, V2.WHITE, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_title)

	_body = _label("Review this action before continuing.", 14, V2.MUTED, false)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_body)

	_cancel_button = _button("NO", V2.MUTED)
	_cancel_button.name = "CancelConfirmation"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_panel.add_child(_cancel_button)

	_confirm_button = _button("YES", V2.CYAN)
	_confirm_button.name = "ConfirmConfirmation"
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_panel.add_child(_confirm_button)

	_cancel_button.focus_neighbor_left = _cancel_button.get_path()
	_cancel_button.focus_neighbor_right = _confirm_button.get_path()
	_confirm_button.focus_neighbor_left = _cancel_button.get_path()
	_confirm_button.focus_neighbor_right = _confirm_button.get_path()
	_apply_accent()


func _layout() -> void:
	if _panel == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var scale_factor := V2.ui_scale(get_viewport())
	var compact := V2.is_compact(get_viewport(), 760.0)
	var width := minf(560.0, physical.x - (28.0 if compact else 64.0))
	var height := minf(260.0, physical.y - 36.0)
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_panel.size = Vector2(width, height)
	_panel.pivot_offset = _panel.size * 0.5

	var pad := 22.0 if compact else 28.0
	_eyebrow.position = Vector2(pad, 20.0)
	_eyebrow.size = Vector2(width - pad * 2.0, 20.0)
	_title.position = Vector2(pad, 47.0)
	_title.size = Vector2(width - pad * 2.0, 40.0)
	_body.position = Vector2(pad, 91.0)
	_body.size = Vector2(width - pad * 2.0, 66.0)

	var gap := 12.0
	var button_height := V2.TOUCH_TARGET
	var buttons_width := width - pad * 2.0
	var button_width := (buttons_width - gap) * 0.5
	var buttons_y := height - pad - button_height
	_cancel_button.position = Vector2(pad, buttons_y)
	_cancel_button.size = Vector2(button_width, button_height)
	_confirm_button.position = Vector2(pad + button_width + gap, buttons_y)
	_confirm_button.size = Vector2(button_width, button_height)


func _apply_accent() -> void:
	if _panel == null:
		return
	_panel.add_theme_stylebox_override(
		"panel",
		V2.surface_style(
			Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.995),
			Color(_accent.r, _accent.g, _accent.b, 0.56),
			10,
			Vector4.ZERO,
			0.16
		)
	)
	_eyebrow.add_theme_color_override("font_color", _accent)
	_apply_button_style(_confirm_button, _accent)
	_apply_button_style(_cancel_button, V2.MUTED)


func _button(text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = V2.TOUCH_TARGET
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	V2.apply_heading(button)
	_apply_button_style(button, accent)
	return button


func _apply_button_style(button: Button, accent: Color) -> void:
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_pressed_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(V2.MUTED.r, V2.MUTED.g, V2.MUTED.b, 0.46))
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled"))


func _label(text_value: String, font_size: int, color: Color, heading: bool) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading:
		V2.apply_heading(label)
	else:
		V2.apply_reading(label)
	return label


func _focus_safe_default() -> void:
	if visible and _cancel_button != null and not _cancel_button.disabled:
		_cancel_button.grab_focus()


func _on_cancel_pressed() -> void:
	if not visible:
		return
	close_dialog()
	cancelled.emit()


func _on_confirm_pressed() -> void:
	if not visible:
		return
	visible = false
	_previous_focus = null
	confirmed.emit()
