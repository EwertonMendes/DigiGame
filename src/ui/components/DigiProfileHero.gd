extends PanelContainer
class_name DigiProfileHero

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const SemanticPalette = preload("res://src/ui/components/DigiSemanticPalette.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")
const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")
const AttributeChip = preload("res://src/ui/components/DigiAttributeChip.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")


func configure(instance: DigimonInstance, species: Dictionary, progression: DigimonProgressionService, compact: bool) -> DigiProfileHero:
	for child in get_children():
		child.queue_free()
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 1.78
	custom_minimum_size.y = 338.0 if not compact else 520.0
	add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 8))

	var shell := VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 0)
	add_child(shell)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("DIGIMON DATA", "", V2.BLUE, "digimon")
	shell.add_child(header)

	var margin := _margin(16, 14, 16, 14)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 1 if compact else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	margin.add_child(grid)

	var portrait_column := VBoxContainer.new()
	portrait_column.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_column.add_theme_constant_override("separation", 10)
	grid.add_child(portrait_column)
	var portrait_side := 178.0 if compact else 218.0
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(portrait_side, portrait_side)
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(V2.PANEL_DEEP, Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.86), 7))
	portrait_column.add_child(portrait_frame)
	var portrait_margin := _margin(8, 8, 8, 8)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(portrait_side - 16.0, portrait_side - 16.0)
	portrait.set_species(String(species.get("name", "")))
	portrait_margin.add_child(portrait)

	var number_row := HBoxContainer.new()
	number_row.add_theme_constant_override("separation", 10)
	number_row.custom_minimum_size.x = portrait_side
	portrait_column.add_child(number_row)
	number_row.add_child(_thin_line())
	var number_copy := String(species.get("number", species.get("id", "???")))
	if number_copy.is_empty():
		number_copy = "???"
	var number_label := _label("No. %s" % number_copy, 10, V2.MUTED, true)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_row.add_child(number_label)
	number_row.add_child(_thin_line())

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 8)
	grid.add_child(summary)

	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var name_label := _label(display_name.to_upper(), 29 if not compact else 24, V2.WHITE, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(name_label)

	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 7)
	chips.add_theme_constant_override("v_separation", 6)
	summary.add_child(chips)
	chips.add_child(_pill(rank.to_upper(), accent))
	chips.add_child(_tier_pill(instance.tier))
	var footprint_badge := "2×2" if instance.is_expanded() else "1×1"
	chips.add_child(_pill(footprint_badge, V2.AMBER))
	var attribute := String(species.get("attribute", "Free"))
	var family := String(species.get("species", species.get("family", "Unknown")))
	chips.add_child(AttributeChip.build(attribute))
	chips.add_child(_pill(family.to_upper(), SemanticPalette.family_color(family)))

	var description := String(species.get("description", "")).strip_edges()
	if description.is_empty():
		description = "Review this Digimon's growth, techniques and possible forms."
	var description_label := _label(description, 11, V2.MUTED)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 2
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(description_label)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 18)
	summary.add_child(level_row)
	level_row.add_child(_label("Lv %d" % instance.level, 24, V2.AMBER, true))
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(1.0, 28.0)
	divider.color = V2.separator_color(0.40)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_row.add_child(divider)
	var potential := _label("POTENTIAL  %d" % instance.potential, 11, V2.PURPLE, true)
	potential.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_row.add_child(potential)

	var required := progression.exp_to_next_level(instance)
	var xp_copy := "%d XP" % instance.exp if required <= 0 else "%d / %d XP" % [instance.exp, required]
	var xp_caption := HBoxContainer.new()
	xp_caption.add_theme_constant_override("separation", 8)
	summary.add_child(xp_caption)
	var next_label := _label("NEXT LEVEL", 10, V2.MUTED, true)
	next_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_caption.add_child(next_label)
	var xp_value := _label(xp_copy, 10, V2.MUTED, true)
	xp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_caption.add_child(xp_value)
	var xp_bar := _progress(V2.AMBER, 9.0)
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(instance.exp if required > 0 else required)
	summary.add_child(xp_bar)

	var separator := ColorRect.new()
	separator.custom_minimum_size.y = 1.0
	separator.color = V2.separator_color(0.42)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(separator)

	var link_row := HBoxContainer.new()
	link_row.add_theme_constant_override("separation", 9)
	summary.add_child(link_row)
	var link_title := _label("LINK", 10, V2.MUTED, true)
	link_title.custom_minimum_size.x = 42.0
	link_row.add_child(link_title)
	var filled_hearts := 0 if instance.link <= 0 else clampi(int(ceil(float(instance.link) / 25.0)), 1, 4)
	for heart_index in range(4):
		var heart := IconScript.new() as DigiProceduralIcon
		heart.custom_minimum_size = Vector2(20.0, 20.0)
		var heart_color := V2.RED if heart_index < filled_hearts else Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.48)
		heart.configure("heart", heart_color, 1.5)
		link_row.add_child(heart)
	var link_value := _label("%d / %d" % [instance.link, DigimonInstance.MAX_LINK], 10, V2.MUTED, true)
	link_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	link_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	link_row.add_child(link_value)
	return self


func _thin_line() -> Control:
	var holder := CenterContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(36.0, 1.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.color = V2.separator_color(0.48)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	return holder


func _pill(text: String, accent: Color) -> Label:
	var label := _label(text, 9, accent, true)
	label.custom_minimum_size.y = AttributeChip.CHIP_HEIGHT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", V2.pill_style(accent, true))
	return label


func _tier_pill(tier: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = AttributeChip.CHIP_HEIGHT
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", V2.pill_style(V2.AMBER, true))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var tier_icon := TierIconScript.new() as DigiTierIcon
	tier_icon.configure(tier, AttributeChip.ICON_SIZE)
	center.add_child(tier_icon)
	panel.tooltip_text = "Tier %s" % tier.to_upper()
	return panel


func _progress(accent: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.add_theme_stylebox_override("background", V2.progress_track_style())
	bar.add_theme_stylebox_override("fill", V2.progress_fill_style(accent, true))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


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
