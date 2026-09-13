extends PanelContainer
class_name TrainingStatRow

signal add_requested(stat_key: String)
signal remove_requested(stat_key: String)

const UI = preload("res://src/ui/TacticalTheme.gd")
const SKIN = preload("res://src/ui/KenneyFantasySkin.gd")
const CHANGE_ICON := preload("res://assets/ui/icons/hp_change_arrow.svg")

var stat_key := ""
var _name: Label
var _value: Label
var _points: Label
var _minus: Button
var _plus: Button
var _accent := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()

func configure(key: String, title: String, current_value: int, preview_value: int, committed_points: int, pending_points: int, max_points: int, can_add: bool, accent: Color) -> void:
	stat_key = key
	_accent = accent
	if _name == null:
		return
	_name.text = title
	_name.add_theme_color_override("font_color", accent)
	_value.text = "%d" % current_value
	if preview_value != current_value:
		_value.text += "   %d" % preview_value
		_value.add_theme_color_override("font_color", UI.GREEN)
	else:
		_value.add_theme_color_override("font_color", UI.TEXT)
	_points.text = "%d / %d" % [committed_points + pending_points, max_points]
	if pending_points > 0:
		_points.text += "   +%d planned" % pending_points
		_points.add_theme_color_override("font_color", UI.GOLD)
	else:
		_points.add_theme_color_override("font_color", UI.MUTED)
	_minus.disabled = pending_points <= 0
	_plus.disabled = not can_add
	add_theme_stylebox_override("panel", SKIN.border_style(accent.darkened(0.35), Vector4(10, 8, 10, 8), 8.0))

func pulse() -> void:
	modulate = Color(1.25, 1.25, 1.25, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_name = _label("STAT", 12, UI.CYAN, true)
	_name.custom_minimum_size.x = 54
	row.add_child(_name)
	var value_box := HBoxContainer.new()
	value_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_box.add_theme_constant_override("separation", 6)
	row.add_child(value_box)
	_value = _label("0", 15, UI.TEXT, true)
	_value.custom_minimum_size.x = 112
	value_box.add_child(_value)
	var icon := TextureRect.new()
	icon.texture = CHANGE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	icon.modulate = UI.CYAN
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_box.add_child(icon)
	_points = _label("0 / 30", 10, UI.MUTED, true)
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_points)
	_minus = _button("-", UI.MUTED)
	_minus.custom_minimum_size = Vector2(38, 34)
	_minus.pressed.connect(func(): remove_requested.emit(stat_key))
	row.add_child(_minus)
	_plus = _button("+", UI.GREEN)
	_plus.custom_minimum_size = Vector2(38, 34)
	_plus.pressed.connect(func(): add_requested.emit(stat_key))
	row.add_child(_plus)

func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	UI.apply_label(label, size, color, bold)
	return label

func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	UI.apply_button(button, accent)
	button.focus_mode = Control.FOCUS_ALL
	return button
