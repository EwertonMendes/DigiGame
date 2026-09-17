extends PanelContainer
class_name DigiDevelopmentPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")

var _workspace_mode := false
var _compact_workspace := false


func set_workspace_mode(enabled: bool, compact: bool = false) -> void:
	_workspace_mode = enabled
	_compact_workspace = compact


func configure(instance: DigimonInstance) -> DigiDevelopmentPanel:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 1.0 if _workspace_mode else 1.22
	custom_minimum_size.y = 0.0 if _workspace_mode else 264.0
	add_theme_stylebox_override("panel", V2.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0) if _workspace_mode else V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 8))

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	if not _workspace_mode:
		var header := SectionHeaderScript.new() as DigiSectionHeader
		header.configure("DEVELOPMENT", "", V2.TEXT, "training")
		body.add_child(header)

	var content := _margin(12 if _workspace_mode else 10, 10 if _workspace_mode else 5, 12 if _workspace_mode else 10, 12 if _workspace_mode else 5)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 5 if _workspace_mode else 2)
	content.add_child(stack)

	stack.add_child(_header_row())

	var keys := ["hp", "mp", "atk", "def", "int", "speed", "mov"]
	for index in range(keys.size()):
		var key := String(keys[index])
		var aptitude := int(instance.aptitudes.get(key, 0))
		var training := int(instance.training.get(key, 0))
		var stat_name := "SP" if key == "mp" else ("SPD" if key == "speed" else key.to_upper())
		stack.add_child(_development_row(stat_name, aptitude, training, index))
	return self


func _header_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 32.0 if _compact_workspace else (40.0 if _workspace_mode else 25.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if _workspace_mode else Control.SIZE_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		V2.surface_style(
			Color(V2.SURFACE_ALT.r, V2.SURFACE_ALT.g, V2.SURFACE_ALT.b, 0.66),
			Color.TRANSPARENT,
			3,
			Vector4(8.0, 2.0, 8.0, 2.0)
		)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var font_size := 11 if _compact_workspace else (13 if _workspace_mode else 9)
	row.add_child(_cell("STAT", font_size, V2.MUTED, true, false))
	row.add_child(_cell("APT", font_size, V2.MUTED, true, true))
	row.add_child(_cell("TRAIN", font_size, V2.MUTED, true, true))
	row.add_child(_cell("TOTAL", font_size, V2.MUTED, true, true))
	return panel


func _development_row(stat_name: String, aptitude: int, training: int, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 38.0 if _compact_workspace else (50.0 if _workspace_mode else 25.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if _workspace_mode else Control.SIZE_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := Color.TRANSPARENT
	if index % 2 == 1:
		fill = Color(V2.SURFACE_ALT.r, V2.SURFACE_ALT.g, V2.SURFACE_ALT.b, 0.18)
	panel.add_theme_stylebox_override(
		"panel",
		V2.surface_style(fill, Color.TRANSPARENT, 2, Vector4(7.0, 1.0, 7.0, 1.0))
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var font_size := 13 if _compact_workspace else (16 if _workspace_mode else 11)
	row.add_child(_cell(stat_name, font_size, V2.MUTED, true, false))
	row.add_child(_cell("%+d%%" % aptitude, font_size, V2.CYAN if aptitude >= 0 else V2.RED, true, true))
	row.add_child(_cell("%+d" % training, font_size, V2.AMBER if training > 0 else V2.MUTED, true, true))
	row.add_child(_cell(
		_total_copy(aptitude, training),
		font_size,
		V2.GREEN if aptitude >= 0 and training >= 0 else V2.RED,
		true,
		true
	))
	return panel


func _cell(text: String, font_size: int, color: Color, heading: bool, centered: bool) -> Label:
	var label := _label(text, font_size, color, heading)
	label.custom_minimum_size.x = 52.0 if not centered else 46.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if centered else Control.SIZE_SHRINK_BEGIN
	label.size_flags_stretch_ratio = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _total_copy(aptitude: int, training: int) -> String:
	if training == 0:
		return "%+d%%" % aptitude
	if aptitude == 0:
		return "%+d" % training
	return "%+d%% %+d" % [aptitude, training]


func _label(text: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heading:
		V2.apply_heading(label)
	else:
		V2.apply_body(label)
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin
