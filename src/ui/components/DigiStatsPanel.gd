extends PanelContainer
class_name DigiStatsPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const StatRowScript = preload("res://src/ui/components/DigiStatRow.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")


func configure(stats: Dictionary, current_hp: int = -1, current_sp: int = -1) -> DigiStatsPanel:
	for child in get_children():
		child.queue_free()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE, Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.24), 10))
	var margin := _margin(9, 7, 9, 7)
	add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	margin.add_child(body)
	body.add_child(_label("COMBAT STATS", 11, V2.CYAN, true))
	body.add_child(_separator())

	var max_hp := maxi(1, int(stats.get("hp", 0)))
	var max_sp := maxi(1, int(stats.get("sp", stats.get("mp", 0))))
	var hp_now := clampi(max_hp if current_hp < 0 else current_hp, 0, max_hp)
	var sp_now := clampi(max_sp if current_sp < 0 else current_sp, 0, max_sp)
	var hp_row := StatRowScript.new() as DigiStatRow
	hp_row.configure("HP", hp_now, float(max_hp), "heart", V2.GREEN, true, "%d / %d" % [hp_now, max_hp])
	body.add_child(hp_row)
	var sp_row := StatRowScript.new() as DigiStatRow
	sp_row.configure("SP", sp_now, float(max_sp), "bolt", V2.BLUE, true, "%d / %d" % [sp_now, max_sp])
	body.add_child(sp_row)
	body.add_child(_separator())

	# Secondary combat stats deliberately stay numeric-only. Apart from matching
	# the prototype, this keeps the hierarchy meaningful: only resources that
	# deplete during play (HP/SP) use progress bars.
	var entries := [
		["ATK", "atk", "sword", V2.ORANGE],
		["DEF", "def", "shield", V2.CYAN],
		["INT", "int", "spark", V2.PURPLE],
		["SPD", "speed", "speed", V2.AMBER],
		["MOV", "mov", "move", V2.MUTED],
	]
	for entry in entries:
		var value := int(stats.get(String(entry[1]), 0))
		body.add_child(_numeric_row(String(entry[0]), value, String(entry[2]), entry[3] as Color))
	return self


func _numeric_row(label_text: String, value: int, icon_kind: String, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 21.0
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := IconScript.new() as DigiProceduralIcon
	icon.custom_minimum_size = Vector2(17.0, 17.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(icon_kind, accent, 1.7)
	row.add_child(icon)

	var name_label := _label(label_text, 10, V2.MUTED, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var value_label := _label(str(value), 11, V2.TEXT, true)
	value_label.custom_minimum_size.x = 48.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)
	return row


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
