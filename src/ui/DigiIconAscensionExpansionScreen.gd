extends "res://src/ui/AscensionExpansionScreen.gd"
class_name DigiIconAscensionExpansionScreen

const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")
const AttributeChip = preload("res://src/ui/components/DigiAttributeChip.gd")
const AssetIcons = preload("res://src/ui/components/DigiUiAssetIcons.gd")


func open_screen(preferred_instance_id: String = "") -> void:
	super.open_screen(preferred_instance_id)
	AssetIcons.apply_bits_icon(_header)


func _collection_button(instance: DigimonInstance, species: Dictionary, active_ids: Array[String]) -> Button:
	var button := super._collection_button(instance, species, active_ids)
	var label := _find_label_containing(button, "TIER %s" % instance.tier)
	if label != null:
		label.text = label.text.replace("TIER %s · " % instance.tier, "")
		var parent := label.get_parent()
		var index := label.get_index()
		parent.add_child(_tier_icon(instance.tier, Vector2(27.0, 18.0)))
		parent.move_child(parent.get_child(parent.get_child_count() - 1), index)
	return button


func _identity_card(instance: DigimonInstance, species: Dictionary, display_name: String, rank: String, accent: Color) -> Control:
	var panel := super._identity_card(instance, species, display_name, rank, accent)
	var attribute := String(species.get("attribute", "Free"))
	var family := String(species.get("species", species.get("family", "Unknown")))
	AttributeChip.replace_text_pill(panel, attribute)
	AttributeChip.normalize_text_pill_height(panel, rank.to_upper())
	AttributeChip.normalize_text_pill_height(panel, attribute.to_upper())
	AttributeChip.normalize_text_pill_height(panel, family.to_upper())

	var label := _find_label_containing(panel, "TIER %s" % instance.tier)
	if label != null:
		var parent := label.get_parent()
		var index := label.get_index()
		parent.remove_child(label)
		label.queue_free()
		parent.add_child(_tier_icon(instance.tier, Vector2(34.0, 23.0)))
		parent.move_child(parent.get_child(parent.get_child_count() - 1), index)
	return panel


func _tier_panel(instance: DigimonInstance) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.PURPLE.r, V2.PURPLE.g, V2.PURPLE.b, 0.32), 8))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("TIER ASCENSION", "Permanent individual progression", V2.PURPLE, "evolution")
	stack.add_child(header)
	var inset := _margin(12, 10, 12, 12)
	stack.add_child(inset)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	inset.add_child(body)

	var current_row := HFlowContainer.new()
	current_row.add_theme_constant_override("h_separation", 8)
	current_row.add_theme_constant_override("v_separation", 6)
	body.add_child(current_row)
	current_row.add_child(_pill("CURRENT", V2.PURPLE))
	current_row.add_child(_tier_icon(instance.tier, Vector2(36.0, 24.0)))
	current_row.add_child(_semantic_label(_tier_bonus_copy(instance.tier), 9, V2.MUTED, false))

	var initial_preview: Dictionary = OverworldState.get_tier_promotion_preview(instance.id)
	var next_tier := String(initial_preview.get("target_tier", ""))
	if next_tier.is_empty():
		body.add_child(_tier_info_card("MAXIMUM TIER", instance.tier, "This individual has reached the maximum Tier.", V2.GREEN))
		return panel

	var requirement_copy := "%d BITS · %s+" % [int(initial_preview.get("bits_cost", 0)), String(initial_preview.get("minimum_rank", "Fresh"))]
	if bool(initial_preview.get("fusion_required", false)):
		requirement_copy += " · SAME-SPECIES DONOR"
	body.add_child(_tier_info_card("NEXT", next_tier, requirement_copy, V2.PURPLE))
	body.add_child(_single_line_label("NEXT BONUS · %s" % _tier_bonus_copy(next_tier), 9, V2.PURPLE.lightened(0.18), true))

	var donor_picker: OptionButton = null
	if bool(initial_preview.get("fusion_required", false)):
		body.add_child(_single_line_label("FUSION DONOR", 9, V2.MUTED, true))
		donor_picker = OptionButton.new()
		donor_picker.name = "DonorPicker"
		donor_picker.custom_minimum_size = Vector2(0, 44)
		donor_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		donor_picker.focus_mode = Control.FOCUS_ALL
		donor_picker.add_item("Select exact-species donor")
		donor_picker.set_item_metadata(0, "")
		var selected_index := 0
		for donor: DigimonInstance in OverworldState.get_tier_donors(instance.id):
			var donor_species := _database.get_by_seed(donor.species_seed)
			var donor_name := donor.get_display_name(String(donor_species.get("name", "Unknown")))
			donor_picker.add_item("%s · Lv %d · %s" % [donor_name, donor.level, donor.id.substr(0, mini(8, donor.id.length()))])
			donor_picker.set_item_metadata(donor_picker.item_count - 1, donor.id)
			if donor.id == _pending_donor_id:
				selected_index = donor_picker.item_count - 1
		donor_picker.select(selected_index)
		donor_picker.item_selected.connect(_on_donor_selected.bind(donor_picker))
		_style_option_button(donor_picker, V2.PURPLE)
		body.add_child(donor_picker)

	var promote := _button("ASCEND", V2.PURPLE)
	promote.name = "PromoteButton"
	promote.icon = TierIconScript.texture_for(next_tier)
	promote.expand_icon = false
	promote.custom_minimum_size.y = 48
	promote.tooltip_text = "Ascend to Tier %s after reviewing all permanent requirements." % next_tier
	promote.pressed.connect(_request_promotion.bind(donor_picker))
	body.add_child(promote)
	return panel


func _expansion_panel(instance: DigimonInstance) -> Control:
	var panel := super._expansion_panel(instance)
	var required_tier := _balance.expansion_string("requiredTier", "S")
	var requirement_label := _find_label_containing(panel, "TIER %s" % required_tier)
	if requirement_label != null:
		var state := "READY" if _balance.tier_index(instance.tier) >= _balance.tier_index(required_tier) else "REQUIRED"
		var parent := requirement_label.get_parent()
		var index := requirement_label.get_index()
		parent.remove_child(requirement_label)
		requirement_label.queue_free()
		var requirement := HBoxContainer.new()
		requirement.add_theme_constant_override("separation", 6)
		requirement.mouse_filter = Control.MOUSE_FILTER_IGNORE
		requirement.add_child(_tier_icon(required_tier, Vector2(32.0, 21.0)))
		requirement.add_child(_semantic_label(state, 9, V2.GREEN if state == "READY" else V2.MUTED, true))
		parent.add_child(requirement)
		parent.move_child(requirement, index)
	var info := _find_label_containing(panel, "Requires Tier %s" % required_tier)
	if info != null:
		info.text = "Requires the shown Tier and 1 Expansion Core."
	return panel


func _request_promotion(picker: OptionButton = null) -> void:
	var donor_id := _pending_donor_id
	if picker != null and picker.selected >= 0:
		donor_id = String(picker.get_item_metadata(picker.selected))
	var preview: Dictionary = OverworldState.get_tier_promotion_preview(_selected_id, donor_id)
	if not bool(preview.get("success", false)):
		_status_text = _reason_text(String(preview.get("reason", "invalid")))
		_refresh_detail()
		call_deferred("_wire_focus_navigation")
		return
	_pending_donor_id = donor_id
	var target: DigimonInstance = OverworldState.get_instance_by_id(_selected_id)
	var target_species: Dictionary = _database.get_by_seed(target.species_seed)
	var copy := "Ascend %s to the next Tier for %d Bits?" % [
		target.get_display_name(String(target_species.get("name", "Digimon"))),
		int(preview.get("bits_cost", 0)),
	]
	if bool(preview.get("fusion_required", false)):
		var donor: DigimonInstance = OverworldState.get_instance_by_id(donor_id)
		if donor != null:
			var donor_species: Dictionary = _database.get_by_seed(donor.species_seed)
			copy += "\n\nThis permanently consumes %s (%s)." % [donor.get_display_name(String(donor_species.get("name", "Digimon"))), donor.id]
	_confirmation.dialog_text = copy
	_confirmation.popup_centered(Vector2i(540, 250))
	call_deferred("_focus_confirmation_cancel")


func _confirm_promotion() -> void:
	var result: Dictionary = OverworldState.promote_digimon_tier(_selected_id, _pending_donor_id)
	_status_text = "Ascension complete." if bool(result.get("success", false)) else _reason_text(String(result.get("reason", "invalid")))
	_pending_donor_id = ""
	_refresh()


func _reason_text(reason: String) -> String:
	match reason:
		"maximum_tier":
			return "This individual is already at the maximum Tier."
		"tier_too_low":
			return "The required Tier has not been reached yet."
		_:
			return super._reason_text(reason)


func _tier_info_card(title: String, tier: String, body_text: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.surface_style(Color(accent.r, accent.g, accent.b, 0.065), Color(accent.r, accent.g, accent.b, 0.24), 7))
	var margin := _margin(11, 8, 11, 8)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 8)
	stack.add_child(title_row)
	var title_label := _single_line_label(title, 11, accent, true)
	title_label.custom_minimum_size.x = 80.0
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	var tier_icon := _tier_icon(tier, Vector2(34.0, 22.0))
	tier_icon.size_flags_horizontal = Control.SIZE_SHRINK_END
	title_row.add_child(tier_icon)
	var body := _label(body_text, 9, V2.MUTED)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	return panel


func _tier_icon(tier: String, minimum_size: Vector2) -> DigiTierIcon:
	var icon := TierIconScript.new() as DigiTierIcon
	icon.configure(tier, minimum_size)
	return icon


func _find_label_containing(root: Node, needle: String) -> Label:
	for child in root.get_children():
		if child is Label and (child as Label).text.contains(needle):
			return child as Label
		var nested := _find_label_containing(child, needle)
		if nested != null:
			return nested
	return null
