extends PanelContainer
class_name DigiDevelopmentPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")


func configure(instance: DigimonInstance) -> DigiDevelopmentPanel:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 1.22
	custom_minimum_size.y = 294.0
	add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 8))

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("DEVELOPMENT", "", V2.TEXT, "training")
	body.add_child(header)

	var content := _margin(12, 9, 12, 10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	var stack := VBoxContainer.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 6)
	content.add_child(stack)
	stack.add_child(_label("Innate aptitude + permanent training", 10, V2.MUTED))

	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.SURFACE_ALT.r, V2.SURFACE_ALT.g, V2.SURFACE_ALT.b, 0.62), Color.TRANSPARENT, 2, Vector4(7.0, 3.0, 7.0, 3.0)))
	stack.add_child(header_panel)
	var header_grid := GridContainer.new()
	header_grid.columns = 4
	header_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_grid.add_theme_constant_override("h_separation", 10)
	header_panel.add_child(header_grid)
	for header_text in ["STAT", "APT", "TRAIN", "TOTAL"]:
		var header_label := _label(header_text, 9, V2.MUTED, true)
		header_label.custom_minimum_size.y = 20.0
		if header_text != "STAT":
			header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header_grid.add_child(header_label)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	stack.add_child(grid)
	for key in ["hp", "mp", "atk", "def", "int", "speed", "mov"]:
		var aptitude := int(instance.aptitudes.get(key, 0))
		var training := int(instance.training.get(key, 0))
		var stat_name: String = "SP" if key == "mp" else ("SPD" if key == "speed" else String(key).to_upper())
		grid.add_child(_table_label(stat_name, V2.TEXT, true, false))
		grid.add_child(_table_label("%+d%%" % aptitude, V2.CYAN if aptitude >= 0 else V2.RED, true, true))
		grid.add_child(_table_label("%+d" % training, V2.AMBER if training > 0 else V2.MUTED, true, true))
		grid.add_child(_table_label(_total_copy(aptitude, training), V2.GREEN if aptitude >= 0 and training >= 0 else V2.RED, true, true))
	return self


func _total_copy(aptitude: int, training: int) -> String:
	if training == 0:
		return "%+d%%" % aptitude
	if aptitude == 0:
		return "%+d" % training
	return "%+d%% %+d" % [aptitude, training]


func _table_label(text: String, color: Color, heading: bool, right: bool) -> Label:
	var label := _label(text, 10, color, heading)
	label.custom_minimum_size.y = 24.0
	if right:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


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
