extends PanelContainer
class_name DigiRosterProfilePanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")
const AttributeChip = preload("res://src/ui/components/DigiAttributeChip.gd")
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
	custom_minimum_size.y = 278.0 if dense else 342.0
	add_theme_stylebox_override("panel", V2.hospital_panel_style(V2.CYAN))

	var margin := _margin(16 if dense else 24, 12 if dense else 18, 16 if dense else 24, 12 if dense else 14)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 7 if dense else 9)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)

	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var name := _label(display_name, 26 if dense else 34, V2.WHITE, true)
	name.name = "ProfileName"
	name.custom_minimum_size.y = 36 if dense else 44
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(name)

	var identity := HBoxContainer.new()
	identity.name = "ProfileIdentity"
	identity.custom_minimum_size.y = 28 if dense else 32
	identity.add_theme_constant_override("separation", 10)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(identity)
	var stage := _label("%s   ·   LV. %d" % [rank.to_upper(), instance.level], 15 if dense else 18, V2.TEXT, true)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(stage)
	var tier_caption := _label("TIER", 11 if dense else 13, V2.MUTED, true)
	tier_caption.size_flags_horizontal = Control.SIZE_SHRINK_END
	identity.add_child(tier_caption)
	var tier := TierIconScript.new() as DigiTierIcon
	tier.name = "ProfileTier"
	tier.configure(instance.tier, Vector2(30.0, 22.0) if dense else Vector2(34.0, 24.0))
	tier.size_flags_horizontal = Control.SIZE_SHRINK_END
	tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(tier)

	var badges := HFlowContainer.new()
	badges.name = "ProfileBadges"
	badges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badges.add_theme_constant_override("h_separation", 7)
	badges.add_theme_constant_override("v_separation", 5)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(badges)
	badges.add_child(AttributeChip.build(String(species.get("attribute", "Free"))))
	badges.add_child(_pill("%s" % ("2×2" if instance.is_expanded() else "1×1"), V2.AMBER))
	badges.add_child(_pill("POT %d" % instance.potential, V2.PURPLE))
	badges.add_child(_pill("LINK %d" % instance.link, V2.CYAN))

	var body := HBoxContainer.new()
	body.name = "ProfileBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14 if dense else 20)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(body)

	var portrait_side := 148.0 if dense else 216.0
	var portrait_frame := PanelContainer.new()
	portrait_frame.name = "ProfilePortraitFrame"
	portrait_frame.custom_minimum_size = Vector2(portrait_side, portrait_side)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.82), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.42), 10))
	body.add_child(portrait_frame)
	var portrait_margin := _margin(8, 8, 8, 8)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.name = "ProfilePortrait"
	portrait.custom_minimum_size = Vector2(portrait_side - 16.0, portrait_side - 16.0)
	portrait.set_species(String(species.get("name", "")))
	portrait_margin.add_child(portrait)

	var summary := VBoxContainer.new()
	summary.name = "ProfileSummary"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 6 if dense else 8)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(summary)

	var description := String(species.get("description", "")).strip_edges()
	if description.is_empty():
		description = "Review this Digimon's growth, techniques and possible forms."
	var description_label := _label(description, 11 if dense else 13, V2.MUTED)
	description_label.name = "ProfileDescription"
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 2 if dense else 3
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_child(description_label)

	var required := progression.exp_to_next_level(instance)
	var xp_caption := HBoxContainer.new()
	xp_caption.add_theme_constant_override("separation", 8)
	xp_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(xp_caption)
	var next_level := _label("NEXT LEVEL", 10 if dense else 12, V2.MUTED, true)
	next_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_caption.add_child(next_level)
	var xp_text := "%d XP" % instance.exp if required <= 0 else "%d / %d XP" % [instance.exp, required]
	var xp_value := _label(xp_text, 10 if dense else 12, V2.MUTED, true)
	xp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_caption.add_child(xp_value)
	var xp_bar := ProgressBar.new()
	xp_bar.name = "ProfileXpBar"
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size.y = 8.0 if dense else 10.0
	xp_bar.max_value = maxf(1.0, float(required))
	xp_bar.value = float(instance.exp if required > 0 else required)
	xp_bar.add_theme_stylebox_override("background", V2.progress_track_style())
	xp_bar.add_theme_stylebox_override("fill", V2.progress_fill_style(V2.AMBER, true))
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(xp_bar)

	var health := HBoxContainer.new()
	health.name = "ProfileVitals"
	health.add_theme_constant_override("separation", 8)
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(health)
	var heart := IconScript.new() as DigiProceduralIcon
	heart.custom_minimum_size = Vector2(20.0, 20.0)
	heart.configure("heart", V2.GREEN, 1.5)
	health.add_child(heart)
	var stats := progression.get_final_stats(instance)
	var max_hp := maxi(1, int(stats.get("hp", 1)))
	var max_sp := maxi(1, int(stats.get("sp", stats.get("mp", 1))))
	health.add_child(_label("HP %d / %d" % [clampi(instance.current_hp, 0, max_hp), max_hp], 11 if dense else 13, V2.GREEN, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health.add_child(spacer)
	health.add_child(_label("SP %d / %d" % [clampi(instance.current_mp, 0, max_sp), max_sp], 11 if dense else 13, V2.BLUE, true))
	return self


func _pill(text: String, accent: Color) -> Label:
	var label := _label(text, 10, accent, true)
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
