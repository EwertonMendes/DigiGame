extends PanelContainer
class_name DigiDevelopmentPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")


func configure(instance: DigimonInstance) -> DigiDevelopmentPanel:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE, Color(V2.PURPLE.r, V2.PURPLE.g, V2.PURPLE.b, 0.24), 10))
	var margin := _margin(10, 9, 10, 9)
	add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	margin.add_child(body)
	body.add_child(_label("DEVELOPMENT", 11, V2.PURPLE, true))
	body.add_child(_label("Innate aptitude + permanent training", 9, V2.MUTED))
	body.add_child(_separator())

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	body.add_child(grid)
	for header in ["STAT", "APT", "TRAIN", "TOTAL"]:
		var header_label := _label(header, 8, V2.SUBTLE, true)
		if header != "STAT":
			header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(header_label)
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
	var label := _label(text, 9, color, heading)
	label.custom_minimum_size.y = 20.0
	if right:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _separator() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1.0
	rule.color = V2.separator_color(0.24)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


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
