extends "res://src/ui/DigiLabScreen.gd"
class_name ProgressionDigiLabCreateScreen

const SemanticPalette = preload("res://src/ui/components/DigiSemanticPalette.gd")


func open_lab() -> void:
	if _hint_bar != null:
		_hint_bar.set_primary_tabs_enabled(true)
	super.open_lab()


func _refresh_list() -> void:
	if _lab_mode == "records":
		super._refresh_list()
		return
	for child in _list_box.get_children():
		child.queue_free()
	_data_buttons.clear()

	var known_names: Dictionary = {}
	for raw_name in OverworldState.get_digi_data().keys():
		var name := String(raw_name).strip_edges()
		if not name.is_empty():
			known_names[name.to_lower()] = name
	for instance: DigimonInstance in OverworldState.get_collection_instances():
		var seeds: Array[String] = instance.species_history.duplicate()
		if seeds.is_empty() and not instance.species_seed.is_empty():
			seeds.append(instance.species_seed)
		for seed: String in seeds:
			var species := _database.get_by_seed(seed)
			if species.is_empty():
				continue
			var species_name := String(species.get("name", "")).strip_edges()
			if not species_name.is_empty():
				known_names[species_name.to_lower()] = species_name

	var entries: Array[Dictionary] = []
	for raw_key in known_names.keys():
		var species_name := String(known_names[raw_key])
		var amount := OverworldState.get_digi_data_for(species_name)
		var required := OverworldState.get_reconstruction_requirement(species_name)
		var state := "ready" if amount >= required else "collecting" if amount > 0 else "locked"
		entries.append({"name": species_name, "amount": amount, "required": required, "state": state})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority := {"ready": 0, "collecting": 1, "locked": 2}
		var priority_a := int(priority.get(String(a.get("state", "locked")), 3))
		var priority_b := int(priority.get(String(b.get("state", "locked")), 3))
		if priority_a != priority_b:
			return priority_a < priority_b
		var amount_a := int(a.get("amount", 0))
		var amount_b := int(b.get("amount", 0))
		if amount_a != amount_b:
			return amount_a > amount_b
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	_list_header.set_trailing("%d KNOWN" % entries.size())

	if entries.is_empty():
		_empty_label = _empty_state("No known Digimon yet.\nDefeat Digimon in battle to discover reconstruction data.")
		_empty_label.custom_minimum_size.y = 160
		_list_box.add_child(_empty_label)
		_selected_name = ""
		return

	var selection_still_exists := false
	for entry: Dictionary in entries:
		var species_name := String(entry.get("name", ""))
		selection_still_exists = selection_still_exists or species_name.to_lower() == _selected_name.to_lower()
		var button := _data_button(species_name, int(entry.get("amount", 0)))
		_list_box.add_child(button)
		_data_buttons.append(button)
	if not selection_still_exists:
		_selected_name = String(entries[0].get("name", ""))
	_style_selection()


func _data_button(species_name: String, amount: int) -> Button:
	var species := _database.get_by_name(species_name)
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	var required := OverworldState.get_reconstruction_requirement(species_name)
	var percent := minf(100.0, float(amount) * 100.0 / float(maxi(1, required)))
	var state := "READY" if amount >= required else "COLLECTING" if amount > 0 else "LOCKED"
	var state_color := V2.GREEN if state == "READY" else V2.CYAN if state == "COLLECTING" else V2.MUTED

	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.pressed.connect(_select_species.bind(species_name))
	button.focus_entered.connect(_select_species.bind(species_name))
	button.set_meta("species_name", species_name)
	button.tooltip_text = "Inspect reconstruction data for %s" % species_name
	_style_roster_button(button, species_name.to_lower() == _selected_name.to_lower(), accent)

	var margin := _margin(11, 8, 11, 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.name = "WalkPreview"
	preview.custom_minimum_size = Vector2(62, 62)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_species(String(species.get("name", species_name)))
	preview.set_active(species_name.to_lower() == _selected_name.to_lower())
	row.add_child(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 3)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name_label := _single_line_label(species_name, 15, V2.TEXT, true)
	copy.add_child(name_label)
	copy.add_child(_single_line_label("%s  ·  %d / %d DATA" % [rank, amount, required], 10, accent, true))
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	copy.add_child(progress_row)
	var progress := _progress_bar(state_color, required, amount)
	progress.custom_minimum_size = Vector2(96, 6)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress)
	var state_label := _single_line_label("%d%% · %s" % [int(round(percent)), state], 9, state_color, true)
	state_label.custom_minimum_size.x = 94
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_row.add_child(state_label)
	return button


func _style_selection() -> void:
	if _lab_mode == "records":
		super._style_selection()
		return
	for button: Button in _data_buttons:
		var species_name := String(button.get_meta("species_name", ""))
		var species := _database.get_by_name(species_name)
		var accent := V2.rank_color(String(species.get("rank", "Unknown")))
		var selected := species_name.to_lower() == _selected_name.to_lower()
		_style_roster_button(button, selected, accent)
		var preview := button.find_child("WalkPreview", true, false) as DigimonWalkPreview
		if preview != null:
			preview.set_active(selected)


func _refresh_detail() -> void:
	if _lab_mode == "records":
		super._refresh_detail()
		return
	for child in _detail_body.get_children():
		child.queue_free()
	if _selected_name.is_empty():
		_detail_body.add_child(_empty_state("Choose a species from the Digi Data Archive to inspect its reconstruction progress."))
		return
	var species := _database.get_by_name(_selected_name)
	if species.is_empty():
		return
	var canonical_name := String(species.get("name", _selected_name))
	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	var available := OverworldState.get_digi_data_for(canonical_name)
	var required := OverworldState.get_reconstruction_requirement(canonical_name)
	var percent := minf(100.0, float(available) * 100.0 / float(maxi(1, required)))
	var state := "READY" if available >= required else "COLLECTING" if available > 0 else "LOCKED"
	var state_color := V2.GREEN if state == "READY" else V2.CYAN if state == "COLLECTING" else V2.MUTED
	var detail_width := _detail_panel.size.x if _detail_panel != null else 900.0
	var narrow_hero := detail_width < 660.0

	var hero := PanelContainer.new()
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_theme_stylebox_override("panel", V2.surface_style(V2.PANEL_DEEP, Color(accent.r, accent.g, accent.b, 0.42), 8))
	_detail_body.add_child(hero)
	var hero_margin := _margin(16, 14, 16, 14)
	hero.add_child(hero_margin)
	var hero_row: BoxContainer
	if narrow_hero:
		hero_row = VBoxContainer.new()
		hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		hero_row = HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 20)
	hero_margin.add_child(hero_row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(166, 158) if narrow_hero else Vector2(190, 182)
	portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if narrow_hero else Control.SIZE_SHRINK_BEGIN
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(Color(0.015, 0.030, 0.044, 1.0), Color(accent.r, accent.g, accent.b, 0.54), 8))
	hero_row.add_child(portrait_frame)
	var portrait_margin := _margin(8, 8, 8, 8)
	portrait_frame.add_child(portrait_margin)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(150, 142) if narrow_hero else Vector2(174, 166)
	portrait.set_species(canonical_name)
	portrait_margin.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 8)
	hero_row.add_child(info)
	var name_label := _single_line_label(canonical_name.to_upper(), 28, V2.TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(name_label)

	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 7)
	chips.add_theme_constant_override("v_separation", 6)
	info.add_child(chips)
	chips.add_child(_pill(rank.to_upper(), accent))
	var attribute := String(species.get("attribute", "Free"))
	var family := String(species.get("species", species.get("family", "Unknown")))
	chips.add_child(_pill(attribute.to_upper(), SemanticPalette.data_attribute_color(attribute)))
	chips.add_child(_pill(family.to_upper(), SemanticPalette.family_color(family)))

	var description := String(species.get("description", "")).strip_edges()
	if not description.is_empty():
		var description_label := _label(description, 10, V2.MUTED)
		description_label.max_lines_visible = 2
		description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(description_label)

	var data_row := HFlowContainer.new()
	data_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_row.add_theme_constant_override("h_separation", 12)
	data_row.add_theme_constant_override("v_separation", 6)
	info.add_child(data_row)
	var data_value := _single_line_label("%d / %d DIGI DATA" % [available, required], 20, V2.AMBER, true)
	data_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_row.add_child(data_value)
	data_row.add_child(_pill("%d%% · %s" % [int(round(percent)), state], state_color))
	info.add_child(_progress_bar(state_color, required, available))

	_detail_body.add_child(_subsection("RECONSTRUCTION OPTIONS", "Data is consumed when a new Digimon is created.", V2.CYAN))
	var explainer := _label("Choose the amount of Digi Data to invest. Spending beyond the species threshold grants a small starting Potential bonus to the new individual.", 10, V2.MUTED)
	explainer.custom_minimum_size.y = 34
	_detail_body.add_child(explainer)

	var spend_options: Array[int] = [required]
	for bonus_step in [50, 100]:
		var candidate := required + int(bonus_step)
		if candidate <= 200 and not spend_options.has(candidate):
			spend_options.append(candidate)
	var option_grid := GridContainer.new()
	if detail_width < 520.0:
		option_grid.columns = 1
	elif detail_width < 760.0:
		option_grid.columns = mini(2, spend_options.size())
	else:
		option_grid.columns = mini(3, spend_options.size())
	option_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_grid.add_theme_constant_override("h_separation", 10)
	option_grid.add_theme_constant_override("v_separation", 10)
	_detail_body.add_child(option_grid)
	for amount: int in spend_options:
		option_grid.add_child(_reconstruction_option(canonical_name, amount, available, required))

	_detail_body.add_child(_subsection("NEW INDIVIDUAL", "Persistent collection member", V2.PURPLE))
	var note := _label("The reconstructed Digimon joins Storage at Level 1 with its own persistent identity. Multiple individuals of the same species are allowed.", 10, V2.MUTED)
	note.custom_minimum_size.y = 34
	_detail_body.add_child(note)


func _reconstruction_option(species_name: String, amount: int, available: int, required: int) -> Button:
	var potential := _factory.potential_from_scan_percent(clampi(amount, 100, 200))
	var accent := V2.AMBER if amount == required else V2.CYAN
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(150, 86)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = available < amount
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not button.disabled else Control.CURSOR_ARROW
	button.add_theme_stylebox_override("normal", V2.action_card_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", V2.action_card_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", V2.action_card_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", V2.action_card_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", V2.action_card_style(accent, "disabled"))
	button.tooltip_text = "Need %d more Digi Data." % (amount - available) if available < amount else "Reconstruct a new %s using %d Digi Data." % [species_name, amount]
	button.pressed.connect(_reconstruct.bind(species_name, amount))
	var margin := _margin(12, 10, 12, 10)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var amount_label := _single_line_label("%d DATA" % amount, 15, V2.TEXT, true)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(amount_label)
	var bonus_copy := "STANDARD RECONSTRUCTION" if potential <= 0 else "+%d STARTING POTENTIAL" % potential
	var bonus := _single_line_label(bonus_copy, 9, accent, true)
	bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(bonus)
	var status := _single_line_label("READY" if available >= amount else "%d MORE NEEDED" % (amount - available), 9, V2.GREEN if available >= amount else V2.SUBTLE, true)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(status)
	return button


func _single_line_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := _label(text, size, color, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _pill(text: String, accent: Color) -> Label:
	var label := _single_line_label(text, 9, accent, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.add_theme_stylebox_override("normal", V2.pill_style(accent, true))
	return label
