extends PanelContainer
class_name DigiDevelopmentPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")


func configure(instance: DigimonInstance) -> DigiDevelopmentPanel:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE, Color(V2.PURPLE.r, V2.PURPLE.g, V2.PURPLE.b, 0.24), 11))
	var margin := _margin(13, 12, 13, 12)
	add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	margin.add_child(body)
	body.add_child(_label("DEVELOPMENT", 11, V2.PURPLE, true))
	body.add_child(_label("Innate aptitude + permanent training", 9, V2.MUTED))
	body.add_child(_separator())

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	body.add_child(grid)
	for header in ["STAT", "APT", "TRAIN"]:
		grid.add_child(_label(header, 9, V2.SUBTLE, true))
	for key in ["hp", "mp", "atk", "def", "int", "speed", "mov"]:
		var aptitude := int(instance.aptitudes.get(key, 0))
		var training := int(instance.training.get(key, 0))
		grid.add_child(_label("SP" if key == "mp" else key.to_upper(), 10, V2.TEXT, true))
		grid.add_child(_label("%+d%%" % aptitude, 10, V2.CYAN if aptitude >= 0 else V2.RED, true))
		grid.add_child(_label("+%d" % training, 10, V2.AMBER if training > 0 else V2.MUTED, true))

	var note := _label("Potential can be spent at the Training Center. Training remains with this individual through form changes.", 9, V2.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	return self


func _separator() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1.0
	rule.color = V2.separator_color(0.28)
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
