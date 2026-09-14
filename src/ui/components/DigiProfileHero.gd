extends PanelContainer
class_name DigiProfileHero

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")


func configure(instance: DigimonInstance, species: Dictionary, progression: DigimonProgressionService, compact: bool) -> DigiProfileHero:
	for child in get_children():
		child.queue_free()
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE_ALT, Color(accent.r, accent.g, accent.b, 0.34), 12, Vector4.ZERO, 0.15))

	var margin := _margin(18, 16, 18, 16)
	add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 1 if compact else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 14)
	margin.add_child(grid)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(154.0, 154.0) if compact else Vector2(190.0, 190.0)
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(Color(0.018, 0.039, 0.057, 0.90), Color(accent.r, accent.g, accent.b, 0.42), 12))
	grid.add_child(portrait_frame)
	var portrait_margin := _margin(10, 10, 10, 10)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(134.0, 134.0) if compact else Vector2(170.0, 170.0)
	portrait.set_species(String(species.get("name", "")))
	portrait_margin.add_child(portrait)

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 8)
	grid.add_child(summary)

	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var name_label := _label(display_name.to_upper(), 27 if not compact else 23, V2.TEXT, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(name_label)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	summary.add_child(chips)
	chips.add_child(_pill(rank.to_upper(), accent))
	var attribute := String(species.get("attribute", species.get("type", "Free")))
	var family := String(species.get("species", species.get("family", "Unknown")))
	chips.add_child(_pill("%s / %s" % [attribute.to_upper(), family.to_upper()], V2.GREEN))

	var helper := _label("Review growth, techniques and possible forms for this Digimon.", 10, V2.MUTED)
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_child(helper)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 16)
	summary.add_child(level_row)
	level_row.add_child(_label("Lv %d" % instance.level, 24, V2.AMBER, true))
	level_row.add_child(_label("POTENTIAL %d" % instance.potential, 11, V2.PURPLE, true))

	var required := progression.exp_to_next_level(instance)
	var xp_copy := "%d XP" % instance.exp if required <= 0 else "%d / %d XP" % [instance.exp, required]
	var xp_caption := HBoxContainer.new()
	xp_caption.add_theme_constant_override("separation", 8)
	summary.add_child(xp_caption)
	var next_label := _label("NEXT LEVEL", 9, V2.MUTED, true)
	next_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_caption.add_child(next_label)
	var xp_value := _label(xp_copy, 9, V2.MUTED, true)
	xp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_caption.add_child(xp_value)
	var xp_bar := _progress(V2.AMBER, 9.0)
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(instance.exp if required > 0 else required)
	summary.add_child(xp_bar)

	var meta_grid := GridContainer.new()
	meta_grid.columns = 1 if compact else 2
	meta_grid.add_theme_constant_override("h_separation", 10)
	meta_grid.add_theme_constant_override("v_separation", 8)
	summary.add_child(meta_grid)
	meta_grid.add_child(_metric("Potential", instance.potential, DigimonInstance.MAX_POTENTIAL, V2.PURPLE, "spark"))
	meta_grid.add_child(_metric("Link", instance.link, DigimonInstance.MAX_LINK, V2.CYAN, "link"))
	return self


func _metric(title: String, value: int, maximum: int, accent: Color, icon_kind: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.SURFACE_SOFT.r, V2.SURFACE_SOFT.g, V2.SURFACE_SOFT.b, 0.82), Color(accent.r, accent.g, accent.b, 0.24), 9))
	var margin := _margin(10, 7, 10, 7)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	margin.add_child(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	body.add_child(top)
	var icon := IconScript.new() as DigiProceduralIcon
	icon.custom_minimum_size = Vector2(20.0, 20.0)
	icon.configure(icon_kind, accent, 1.9)
	top.add_child(icon)
	var title_label := _label(title, 9, V2.MUTED, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	var value_label := _label("%d / %d" % [value, maximum], 10, V2.TEXT, true)
	top.add_child(value_label)
	var bar := _progress(accent, 6.0)
	bar.max_value = float(maximum)
	bar.value = float(value)
	body.add_child(bar)
	return panel


func _pill(text: String, accent: Color) -> Label:
	var label := _label(text, 9, accent, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", V2.pill_style(accent, true))
	return label


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
