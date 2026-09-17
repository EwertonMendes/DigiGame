extends PanelContainer
class_name DigiRosterProfilePanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")
const AttributeChip = preload("res://src/ui/components/DigiAttributeChip.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")


func configure(instance: DigimonInstance, species: Dictionary, progression: DigimonProgressionService, dense: bool = false) -> DigiRosterProfilePanel:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 246.0 if dense else 324.0
	add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.74), 8))

	var shell := VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 0)
	add_child(shell)

	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("DIGIMON PROFILE", "", V2.BLUE, "digimon")
	shell.add_child(header)

	var margin := _margin(14 if not dense else 10, 10 if not dense else 7, 14 if not dense else 10, 10 if not dense else 7)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18 if not dense else 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var portrait_side := 214.0 if not dense else 142.0
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(portrait_side, portrait_side)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(V2.PANEL_DEEP, Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.86), 8))
	row.add_child(portrait_frame)
	var portrait_margin := _margin(7, 7, 7, 7)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(portrait_side - 14.0, portrait_side - 14.0)
	portrait.set_species(String(species.get("name", "")))
	portrait_margin.add_child(portrait)

	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 6 if not dense else 4)
	row.add_child(summary)

	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var name := _label(display_name, 27 if not dense else 21, V2.WHITE, true)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(name)

	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(chips)
	chips.add_child(_pill(rank.to_upper(), accent))
	chips.add_child(_tier_chip(instance.tier))
	chips.add_child(AttributeChip.build(String(species.get("attribute", "Free"))))
	if not dense:
		chips.add_child(_pill("2×2" if instance.is_expanded() else "1×1", V2.AMBER))

	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 10)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(identity)
	identity.add_child(_label("LV. %d" % instance.level, 18 if not dense else 15, V2.AMBER, true))
	identity.add_child(_label("POT %d" % instance.potential, 10, V2.PURPLE, true))
	identity.add_child(_label("LINK %d" % instance.link, 10, V2.CYAN, true))

	var description := String(species.get("description", "")).strip_edges()
	if description.is_empty():
		description = "Review this Digimon's growth, techniques and possible forms."
	var description_label := _label(description, 10, V2.MUTED)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 1 if dense else 2
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(description_label)

	var required := progression.exp_to_next_level(instance)
	var xp_caption := HBoxContainer.new()
	xp_caption.add_theme_constant_override("separation", 8)
	xp_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(xp_caption)
	var next_level := _label("NEXT LEVEL", 9, V2.MUTED, true)
	next_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_caption.add_child(next_level)
	var xp_text := "%d XP" % instance.exp if required <= 0 else "%d / %d XP" % [instance.exp, required]
	var xp_value := _label(xp_text, 9, V2.MUTED, true)
	xp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_caption.add_child(xp_value)
	var xp_bar := ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size.y = 8.0
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(instance.exp if required > 0 else required)
	xp_bar.add_theme_stylebox_override("background", V2.progress_track_style())
	xp_bar.add_theme_stylebox_override("fill", V2.progress_fill_style(V2.AMBER, true))
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(xp_bar)

	var health := HBoxContainer.new()
	health.add_theme_constant_override("separation", 8)
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(health)
	var heart := IconScript.new() as DigiProceduralIcon
	heart.custom_minimum_size = Vector2(18.0, 18.0)
	heart.configure("heart", V2.GREEN, 1.4)
	health.add_child(heart)
	var stats := progression.get_final_stats(instance)
	var max_hp := maxi(1, int(stats.get("hp", 1)))
	var max_sp := maxi(1, int(stats.get("sp", stats.get("mp", 1))))
	health.add_child(_label("HP %d / %d" % [clampi(instance.current_hp, 0, max_hp), max_hp], 10, V2.GREEN, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health.add_child(spacer)
	health.add_child(_label("SP %d / %d" % [clampi(instance.current_mp, 0, max_sp), max_sp], 10, V2.BLUE, true))
	return self


func _tier_chip(tier: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = AttributeChip.CHIP_HEIGHT
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", V2.pill_style(V2.AMBER, true))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var icon := TierIconScript.new() as DigiTierIcon
	icon.configure(tier, AttributeChip.ICON_SIZE)
	center.add_child(icon)
	panel.tooltip_text = "Tier %s" % tier.to_upper()
	return panel


func _pill(text: String, accent: Color) -> Label:
	var label := _label(text, 9, accent, true)
	label.custom_minimum_size.y = AttributeChip.CHIP_HEIGHT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", V2.pill_style(accent, true))
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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin
