extends PanelContainer
class_name DigiStatRow

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")

var _label_text := "HP"
var _value := 0
var _max_value := 100.0
var _icon_kind := "heart"
var _accent := V2.GREEN
var _built := false


func configure(label_text: String, value: int, max_value: float, icon_kind: String, accent: Color) -> DigiStatRow:
	_label_text = label_text
	_value = value
	_max_value = maxf(1.0, max_value)
	_icon_kind = icon_kind
	_accent = accent
	if _built:
		_build_content()
	return self


func _ready() -> void:
	custom_minimum_size.y = 42.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	_built = true


func _build_content() -> void:
	for child in get_children():
		child.queue_free()
	add_theme_stylebox_override(
		"panel",
		V2.surface_style(Color(V2.SURFACE_SOFT.r, V2.SURFACE_SOFT.g, V2.SURFACE_SOFT.b, 0.48), Color.TRANSPARENT, 8)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icon := IconScript.new() as DigiProceduralIcon
	icon.custom_minimum_size = Vector2(23.0, 23.0)
	icon.configure(_icon_kind, _accent, 2.0)
	row.add_child(icon)

	var label := Label.new()
	label.text = _label_text
	label.custom_minimum_size.x = 38.0
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", V2.MUTED)
	V2.apply_body(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var value_label := Label.new()
	value_label.text = str(_value)
	value_label.custom_minimum_size.x = 48.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", V2.TEXT)
	V2.apply_heading(value_label)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = _max_value
	bar.value = clampf(float(_value), 0.0, _max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(86.0, 7.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", V2.progress_track_style())
	bar.add_theme_stylebox_override("fill", V2.progress_fill_style(_accent, true))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
