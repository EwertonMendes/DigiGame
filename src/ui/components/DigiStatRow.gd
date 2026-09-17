extends PanelContainer
class_name DigiStatRow

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")

var _label_text := "HP"
var _value := 0
var _max_value := 100.0
var _icon_kind := "heart"
var _accent := V2.GREEN
var _show_bar := true
var _value_text := ""
var _built := false
var _roomy := false
var _compact_roomy := false


func set_roomy(enabled: bool, compact: bool = false) -> void:
	_roomy = enabled
	_compact_roomy = compact
	if _built:
		_build_content()


func configure(
	label_text: String,
	value: int,
	max_value: float,
	icon_kind: String,
	accent: Color,
	show_bar: bool = true,
	value_text: String = ""
) -> DigiStatRow:
	_label_text = label_text
	_value = value
	_max_value = maxf(1.0, max_value)
	_icon_kind = icon_kind
	_accent = accent
	_show_bar = show_bar
	_value_text = value_text
	if _built:
		_build_content()
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	_built = true


func _build_content() -> void:
	for child in get_children():
		child.queue_free()
	# Compact workspace rows use a readable floor and let the surrounding
	# VBox distribute remaining height. This prevents their minima from forcing
	# the Overview presentation surface to grow on short viewports.
	custom_minimum_size.y = 29.0 if _compact_roomy else ((56.0 if _show_bar else 50.0) if _roomy else (30.0 if _show_bar else 22.0))
	size_flags_vertical = Control.SIZE_EXPAND_FILL if _roomy else Control.SIZE_FILL
	add_theme_stylebox_override("panel", V2.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10 if _roomy else 7)
	margin.add_theme_constant_override("margin_top", 1 if _show_bar else 0)
	margin.add_theme_constant_override("margin_right", 10 if _roomy else 7)
	margin.add_theme_constant_override("margin_bottom", 1 if _show_bar else 0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icon := IconScript.new() as DigiProceduralIcon
	icon.custom_minimum_size = Vector2(21.0 if _compact_roomy else (24.0 if _roomy else 19.0), 21.0 if _compact_roomy else (24.0 if _roomy else 19.0))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(_icon_kind, _accent, 1.8)
	row.add_child(icon)

	var label := Label.new()
	label.text = _label_text
	label.custom_minimum_size.x = 48.0 if _compact_roomy else (56.0 if _roomy else 42.0)
	label.add_theme_font_size_override("font_size", 14 if _compact_roomy else (17 if _roomy else 12))
	label.add_theme_color_override("font_color", V2.MUTED)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	V2.apply_heading(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var value_label := Label.new()
	value_label.text = _value_text if not _value_text.is_empty() else str(_value)
	value_label.custom_minimum_size.x = 92.0 if _compact_roomy else (112.0 if _roomy else 78.0)
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 15 if _compact_roomy else (19 if _roomy else 13))
	value_label.add_theme_color_override("font_color", V2.TEXT)
	V2.apply_heading(value_label)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)

	if _show_bar:
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = _max_value
		bar.value = clampf(float(_value), 0.0, _max_value)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(92.0, 9.0 if _compact_roomy else (12.0 if _roomy else 8.0))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", V2.progress_track_style())
		bar.add_theme_stylebox_override("fill", V2.progress_fill_style(_accent, true))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
