extends PanelContainer
class_name DigiStatsPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const StatRowScript = preload("res://src/ui/components/DigiStatRow.gd")


func configure(stats: Dictionary) -> DigiStatsPanel:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE, Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.24), 11))
	var margin := _margin(13, 12, 13, 12)
	add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)
	body.add_child(_label("COMBAT STATS", 11, V2.CYAN, true))
	body.add_child(_separator())

	var entries := [
		["HP", "hp", "heart", V2.GREEN],
		["SP", "sp", "bolt", V2.BLUE],
		["ATK", "atk", "sword", V2.ORANGE],
		["DEF", "def", "shield", V2.CYAN],
		["INT", "int", "spark", V2.PURPLE],
		["SPD", "speed", "speed", V2.AMBER],
		["MOV", "mov", "move", V2.MUTED],
	]
	for entry in entries:
		var value := int(stats.get(String(entry[1]), 0))
		var cap := _visual_cap(value, String(entry[1]))
		var row := StatRowScript.new() as DigiStatRow
		row.configure(String(entry[0]), value, cap, String(entry[2]), entry[3] as Color)
		body.add_child(row)
	return self


func _visual_cap(value: int, key: String) -> float:
	if key == "mov":
		return maxf(8.0, float(value + 2))
	var step := 50.0 if value < 250 else 100.0
	return maxf(step, ceil(float(maxi(value, 1)) / step) * step)


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
