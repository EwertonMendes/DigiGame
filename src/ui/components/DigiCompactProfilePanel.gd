extends PanelContainer
class_name DigiCompactProfilePanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")
const AttributeChip = preload("res://src/ui/components/DigiAttributeChip.gd")


func configure(instance: DigimonInstance, species: Dictionary, progression: DigimonProgressionService, show_vitals: bool = true, dense: bool = false) -> DigiCompactProfilePanel:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 122.0 if dense else 176.0
	clip_contents = true
	add_theme_stylebox_override("panel", V2.workspace_panel_style(accent))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12 if dense else 16)
	margin.add_theme_constant_override("margin_top", 8 if dense else 12)
	margin.add_theme_constant_override("margin_right", 12 if dense else 16)
	margin.add_theme_constant_override("margin_bottom", 8 if dense else 12)
	add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12 if dense else 16)
	margin.add_child(row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(96, 96) if dense else Vector2(136, 136)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.86), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.42), 9))
	row.add_child(portrait_frame)
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 7)
	pm.add_theme_constant_override("margin_top", 7)
	pm.add_theme_constant_override("margin_right", 7)
	pm.add_theme_constant_override("margin_bottom", 7)
	portrait_frame.add_child(pm)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(82, 82) if dense else Vector2(122, 122)
	portrait.set_species(String(species.get("name", "")))
	pm.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4 if dense else 6)
	row.add_child(info)

	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var name := _label(display_name, 20 if dense else 26, V2.WHITE, true)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name)

	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 10)
	info.add_child(identity)
	var rank_level := _label("%s  ·  LV. %d" % [rank.to_upper(), instance.level], 12 if dense else 14, accent, true)
	rank_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(rank_level)
	var tier := TierIconScript.new() as DigiTierIcon
	tier.configure(instance.tier, Vector2(34, 24))
	identity.add_child(tier)

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 7)
	chips.add_theme_constant_override("v_separation", 5)
	info.add_child(chips)
	var attribute_chip := AttributeChip.build(String(species.get("attribute", "Free")))
	if dense:
		attribute_chip.custom_minimum_size.y = 24.0
	chips.add_child(attribute_chip)
	chips.add_child(_pill("2×2" if instance.is_expanded() else "1×1", V2.AMBER, dense))
	chips.add_child(_pill("POT %d" % instance.potential, V2.PURPLE, dense))
	chips.add_child(_pill("LINK %d" % instance.link, V2.CYAN, dense))

	if show_vitals:
		var stats := progression.get_final_stats(instance)
		var max_hp := maxi(1, int(stats.get("hp", 1)))
		var max_sp := maxi(1, int(stats.get("sp", stats.get("mp", 1))))
		var vitals := HBoxContainer.new()
		vitals.add_theme_constant_override("separation", 16)
		info.add_child(vitals)
		var hp := _label("HP %d / %d" % [clampi(instance.current_hp, 0, max_hp), max_hp], 10 if dense else 11, V2.GREEN, true)
		hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vitals.add_child(hp)
		vitals.add_child(_label("SP %d / %d" % [clampi(instance.current_mp, 0, max_sp), max_sp], 10 if dense else 11, V2.BLUE, true))
	return self


func _pill(text: String, accent: Color, dense: bool = false) -> Label:
	var label := _label(text, 8 if dense else 9, accent, true)
	label.custom_minimum_size.y = 24 if dense else 28
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", V2.pill_style(accent, true))
	return label


func _label(text: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading:
		V2.apply_heading(label)
	else:
		V2.apply_body(label)
	return label
