extends "res://src/ui/DigiLabScreen.gd"
class_name ProgressionDigiLabCreateScreen


func _refresh_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	_data_buttons.clear()

	var known_names: Dictionary = {}
	for raw_name in OverworldState.get_digi_data().keys():
		var name := String(raw_name).strip_edges()
		if not name.is_empty():
			known_names[name.to_lower()] = name
	for instance: DigimonInstance in OverworldState.get_roster_instances():
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
		entries.append({
			"name": species_name,
			"amount": amount,
			"required": required,
			"state": state,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority := {"ready": 0, "collecting": 1, "locked": 2}
		var state_a := String(a.get("state", "locked"))
		var state_b := String(b.get("state", "locked"))
		var priority_a := int(priority.get(state_a, 3))
		var priority_b := int(priority.get(state_b, 3))
		if priority_a != priority_b:
			return priority_a < priority_b
		var amount_a := int(a.get("amount", 0))
		var amount_b := int(b.get("amount", 0))
		if amount_a != amount_b:
			return amount_a > amount_b
		return String(a.get("name", "")) < String(b.get("name", ""))
	)

	if entries.is_empty():
		_empty_label = _label("No known Digimon yet.\nDefeat Digimon in battle to discover their reconstruction data.", 13, UI.MUTED)
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_empty_label.custom_minimum_size.y = 160
		_list_box.add_child(_empty_label)
		_selected_name = ""
		return

	var selection_still_exists := false
	for entry: Dictionary in entries:
		var species_name := String(entry.get("name", ""))
		if species_name.to_lower() == _selected_name.to_lower():
			selection_still_exists = true
		var button := _data_button(species_name, int(entry.get("amount", 0)))
		_list_box.add_child(button)
		_data_buttons.append(button)
	if not selection_still_exists:
		_selected_name = String(entries[0].get("name", ""))
	_style_selection()


func _data_button(species_name: String, amount: int) -> Button:
	var species := _database.get_by_name(species_name)
	var rank := String(species.get("rank", "Unknown"))
	var accent := UI.rank_color(rank)
	var required := OverworldState.get_reconstruction_requirement(species_name)
	var percent := minf(100.0, float(amount) * 100.0 / float(maxi(1, required)))
	var state := "READY" if amount >= required else "COLLECTING" if amount > 0 else "LOCKED"
	var button := Button.new()
	button.text = "%s\n%s  ·  %d / %d DATA  ·  %d%%  ·  %s" % [species_name.to_upper(), rank.to_upper(), amount, required, int(round(percent)), state]
	button.custom_minimum_size = Vector2(268, 76)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_select_species.bind(species_name))
	button.focus_entered.connect(_select_species.bind(species_name))
	SKIN.apply_button(button, accent)
	button.set_meta("species_name", species_name)
	return button


func _refresh_detail() -> void:
	for child in _detail_body.get_children():
		child.queue_free()
	if _selected_name.is_empty():
		_detail_body.add_child(_label("DIGI DATA ARCHIVE", 14, UI.CYAN, true))
		_detail_body.add_child(_label("Known species remain visible here as Locked, Collecting or Ready.", 11, UI.MUTED))
		return
	var species := _database.get_by_name(_selected_name)
	if species.is_empty():
		return
	var canonical_name := String(species.get("name", _selected_name))
	var rank := String(species.get("rank", "Unknown"))
	var accent := UI.rank_color(rank)
	var available := OverworldState.get_digi_data_for(canonical_name)
	var required := OverworldState.get_reconstruction_requirement(canonical_name)
	var percent := minf(100.0, float(available) * 100.0 / float(maxi(1, required)))
	var state := "READY" if available >= required else "COLLECTING" if available > 0 else "LOCKED"

	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 14)
	_detail_body.add_child(hero)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(178, 158)
	portrait_frame.add_theme_stylebox_override("panel", SKIN.frame_style(Color(accent.r * 0.40, accent.g * 0.40, accent.b * 0.40, 0.96), Vector4(7, 7, 7, 7), 10.0))
	hero.add_child(portrait_frame)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(164, 144)
	portrait.set_species(canonical_name)
	portrait_frame.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	hero.add_child(info)
	info.add_child(_label(canonical_name.to_upper(), 23, UI.TEXT, true))
	info.add_child(_label(rank.to_upper(), 11, accent.lightened(0.14), true))
	info.add_child(_label("%d / %d DIGI DATA" % [available, required], 20, UI.GOLD, true))
	info.add_child(_label("%d%%  ·  %s" % [int(round(percent)), state], 11, UI.GREEN if state == "READY" else UI.CYAN if state == "COLLECTING" else UI.MUTED, true))

	var progress := ProgressBar.new()
	progress.max_value = float(maxi(1, required))
	progress.value = float(mini(available, required))
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 16)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_child(progress)

	_detail_body.add_child(_section_label("RECONSTRUCTION", UI.CYAN))
	var explainer := _label("Create a new individual when this species reaches its configured Digi Data threshold. The required Data is consumed; extra Data can optionally be spent for a small starting Potential bonus.", 10, UI.MUTED)
	explainer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_child(explainer)

	var spend_options: Array[int] = [required]
	for bonus_step in [50, 100]:
		var candidate := required + int(bonus_step)
		if candidate <= 200 and not spend_options.has(candidate):
			spend_options.append(candidate)
	var grid := GridContainer.new()
	grid.columns = mini(3, spend_options.size())
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_detail_body.add_child(grid)
	for amount: int in spend_options:
		var potential := _factory.potential_from_scan_percent(clampi(amount, 100, 200))
		var caption := "%d DATA" % amount
		if potential > 0:
			caption += "\n+%d POTENTIAL" % potential
		var button := _button(caption, UI.GOLD if amount == required else UI.CYAN)
		button.custom_minimum_size = Vector2(128, 66)
		button.disabled = available < amount
		button.tooltip_text = "Need %d more Digi Data." % (amount - available) if available < amount else "Reconstruct a new %s using %d Digi Data." % [canonical_name, amount]
		button.pressed.connect(_reconstruct.bind(canonical_name, amount))
		grid.add_child(button)

	_detail_body.add_child(_section_label("NEW INDIVIDUAL", UI.PURPLE))
	_detail_body.add_child(_label("The reconstructed Digimon joins Storage at Level 1 with its own persistent UUID. Multiple individuals of the same species are allowed.", 10, UI.MUTED))
