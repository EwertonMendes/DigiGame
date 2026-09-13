extends PanelContainer
class_name TrainingStatRow

signal add_requested(stat_key: String)
signal remove_requested(stat_key: String)

const UI = preload("res://src/ui/TacticalTheme.gd")
const MENU = preload("res://src/ui/MenuUiStyle.gd")
const CHANGE_ICON := preload("res://assets/ui/icons/hp_change_arrow.svg")

var stat_key := ""
var _name: Label
var _value: Label
var _arrow: TextureRect
var _preview: Label
var _points: Label
var _minus: Button
var _plus: Button
var _accent := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	custom_minimum_size.y = 46.0
	_build()

func configure(key: String, title: String, current_value: int, preview_value: int, committed_points: int, pending_points: int, max_points: int, can_add: bool, accent: Color) -> void:
	stat_key = key
	_accent = accent
	if _name == null:
		return
	_name.text = title
	_name.add_theme_color_override("font_color", accent)
	_value.text = str(current_value)
	var changed := preview_value != current_value
	_arrow.visible = changed
	_preview.visible = changed
	_preview.text = str(preview_value)
	_points.text = "%d / %d" % [committed_points + pending_points, max_points]
	if pending_points > 0:
		_points.text += "  +%d" % pending_points
		_points.add_theme_color_override("font_color", UI.GOLD)
	else:
		_points.add_theme_color_override("font_color", UI.MUTED)
	_minus.disabled = pending_points <= 0
	_plus.disabled = not can_add
	add_theme_stylebox_override("panel", MENU.stat_surface(accent, pending_points > 0))

func pulse() -> void:
	modulate = Color(1.12, 1.12, 1.12, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_focus_buttons() -> Array[Button]:
	return [_minus, _plus]

func _build() -> void:
	var margin := MENU.margin(10, 6, 8, 6)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	_name = _single_line_label("STAT", 11, UI.CYAN, true)
	_name.custom_minimum_size.x = 42
	row.add_child(_name)

	var values := HBoxContainer.new()
	values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.add_theme_constant_override("separation", 5)
	row.add_child(values)
	_value = _single_line_label("0", 14, UI.TEXT, true)
	_value.custom_minimum_size.x = 38
	values.add_child(_value)
	_arrow = TextureRect.new()
	_arrow.texture = CHANGE_ICON
	_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arrow.custom_minimum_size = Vector2(16, 16)
	_arrow.modulate = UI.CYAN
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_child(_arrow)
	_preview = _single_line_label("0", 14, UI.GREEN, true)
	_preview.custom_minimum_size.x = 38
	values.add_child(_preview)

	_points = _single_line_label("0 / 30", 10, UI.MUTED, true)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_points.custom_minimum_size.x = 82
	row.add_child(_points)

	_minus = MENU.action_button("−", UI.MUTED, 34)
	_minus.custom_minimum_size = Vector2(38, 34)
	_minus.tooltip_text = "Remove one point from the current plan"
	_minus.pressed.connect(func(): remove_requested.emit(stat_key))
	row.add_child(_minus)
	_plus = MENU.action_button("+", UI.GREEN, 34)
	_plus.custom_minimum_size = Vector2(38, 34)
	_plus.tooltip_text = "Add one training point"
	_plus.pressed.connect(func(): add_requested.emit(stat_key))
	row.add_child(_plus)

func _single_line_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	label.add_theme_constant_override("outline_size", 2 if size >= 13 else 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label
