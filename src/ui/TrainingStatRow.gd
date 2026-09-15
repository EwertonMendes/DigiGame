extends PanelContainer
class_name TrainingStatRow

signal add_requested(stat_key: String)
signal remove_requested(stat_key: String)

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")
const CHANGE_ICON := preload("res://assets/ui/icons/hp_change_arrow.svg")

var stat_key := ""
var _name: Label
var _value: Label
var _arrow: TextureRect
var _preview: Label
var _points: Label
var _minus: Button
var _plus: Button
var _icon: DigiProceduralIcon
var _accent := Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	custom_minimum_size.y = 58.0
	_build()


func configure(
	key: String,
	title: String,
	current_value: int,
	preview_value: int,
	committed_points: int,
	pending_points: int,
	max_points: int,
	can_add: bool,
	accent: Color
) -> void:
	stat_key = key
	_accent = accent
	if _name == null:
		return
	_name.text = title
	_name.add_theme_color_override("font_color", accent)
	_icon.configure(_icon_kind_for(key), Color(accent.r, accent.g, accent.b, 0.92), 1.75)
	_value.text = str(current_value)
	var changed := preview_value != current_value
	_arrow.visible = changed
	_preview.visible = changed
	_preview.text = str(preview_value)
	_points.text = "TRAIN %d / %d" % [committed_points + pending_points, max_points]
	if pending_points > 0:
		_points.text += "  +%d" % pending_points
		_points.add_theme_color_override("font_color", V2.AMBER)
	else:
		_points.add_theme_color_override("font_color", V2.MUTED)
	_minus.disabled = pending_points <= 0
	_plus.disabled = not can_add
	_style_step_button(_minus, V2.MUTED)
	_style_step_button(_plus, accent)
	add_theme_stylebox_override("panel", V2.outlined_surface(accent, pending_points > 0, 7))


func pulse() -> void:
	modulate = Color(1.08, 1.08, 1.08, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func get_focus_buttons() -> Array[Button]:
	return [_minus, _plus]


func focus_minus() -> void:
	if _minus != null and not _minus.disabled:
		_minus.grab_focus()


func focus_plus() -> void:
	if _plus != null and not _plus.disabled:
		_plus.grab_focus()
	elif _minus != null and not _minus.disabled:
		_minus.grab_focus()


func _build() -> void:
	add_theme_stylebox_override("panel", V2.panel_style(V2.BORDER_SOFT, 7))
	var margin := _margin(10, 7, 8, 7)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	_icon = IconScript.new() as DigiProceduralIcon
	_icon.custom_minimum_size = Vector2(24.0, 24.0)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)

	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 58.0
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", -1)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(identity)
	_name = _single_line_label("STAT", 11, V2.CYAN, true)
	identity.add_child(_name)
	_points = _single_line_label("TRAIN 0 / 30", 8, V2.MUTED, true)
	identity.add_child(_points)

	var values := HBoxContainer.new()
	values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.alignment = BoxContainer.ALIGNMENT_CENTER
	values.add_theme_constant_override("separation", 5)
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(values)
	_value = _single_line_label("0", 16, V2.TEXT, true)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.custom_minimum_size.x = 42.0
	values.add_child(_value)
	_arrow = TextureRect.new()
	_arrow.texture = CHANGE_ICON
	_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arrow.custom_minimum_size = Vector2(17.0, 17.0)
	_arrow.modulate = V2.CYAN
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_child(_arrow)
	_preview = _single_line_label("0", 16, V2.GREEN, true)
	_preview.custom_minimum_size.x = 42.0
	values.add_child(_preview)

	_minus = _step_button("−", V2.MUTED, "Remove one point from this training plan")
	_minus.pressed.connect(func(): remove_requested.emit(stat_key))
	row.add_child(_minus)
	_plus = _step_button("+", V2.GREEN, "Add one training point")
	_plus.pressed.connect(func(): add_requested.emit(stat_key))
	row.add_child(_plus)


func _step_button(text: String, accent: Color, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(48.0, 42.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = tooltip
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_pressed_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", V2.SUBTLE)
	V2.apply_heading(button)
	_style_step_button(button, accent)
	return button


func _style_step_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal", 7))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 7))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus", 7))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 7))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled", 7))


func _icon_kind_for(key: String) -> String:
	match key:
		"hp":
			return "heart"
		"mp":
			return "bolt"
		"atk":
			return "sword"
		"def":
			return "shield"
		"int":
			return "spark"
		"speed":
			return "speed"
		_:
			return "info"


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return margin


func _single_line_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		V2.apply_heading(label)
	else:
		V2.apply_body(label)
	return label
