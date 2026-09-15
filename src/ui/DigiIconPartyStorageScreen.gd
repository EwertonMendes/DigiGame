extends "res://src/ui/DigiLabPartyStorageScreen.gd"
class_name DigiIconPartyStorageScreen

const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")
const AssetIcons = preload("res://src/ui/components/DigiUiAssetIcons.gd")


func open_screen() -> void:
	super.open_screen()
	AssetIcons.apply_bits_icon(_header)


func _collection_button(instance: DigimonInstance, species: Dictionary, active: bool, active_ids: Array[String]) -> Button:
	var rank := String(species.get("rank", "Unknown"))
	var rank_color := V2.rank_color(rank)
	var selected := instance.id == _selected_id
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.pressed.connect(_select.bind(instance.id))
	button.focus_entered.connect(_select.bind(instance.id))
	button.tooltip_text = "Select %s" % instance.get_display_name(String(species.get("name", "Digimon")))
	_style_list_button(button, selected, rank_color)

	var margin := _margin(11, 8, 11, 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(62, 62)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_species(String(species.get("name", "")))
	preview.set_active(selected)
	row.add_child(preview)
	_list_previews.append(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 3)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name := instance.get_display_name(String(species.get("name", "Unknown")))
	var location := "PARTY SLOT %d" % (active_ids.find(instance.id) + 1) if active else "STORAGE"
	var location_color := V2.AMBER if active else V2.CYAN
	var footprint_badge := "2×2" if instance.is_expanded() else "1×1"
	copy.add_child(_single_line_label(name, 15, V2.TEXT, true))
	copy.add_child(_single_line_label("Lv %d  ·  %s" % [instance.level, rank], 10, rank_color, true))
	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 8)
	copy.add_child(meta_row)
	var location_label := _single_line_label(location, 9, location_color, true)
	location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(location_label)
	meta_row.add_child(_tier_icon(instance.tier, Vector2(27.0, 18.0)))
	meta_row.add_child(_single_line_label("%s · POT %d · LINK %d" % [footprint_badge, instance.potential, instance.link], 9, V2.MUTED, true))
	return button


func _identity_card(instance: DigimonInstance, species: Dictionary, display_name: String, rank: String, accent: Color, active: bool, party_index: int) -> Control:
	var panel := super._identity_card(instance, species, display_name, rank, accent, active, party_index)
	var tier_label := _find_label_starting_with(panel, "TIER ")
	if tier_label != null:
		var parent := tier_label.get_parent()
		var index := tier_label.get_index()
		parent.remove_child(tier_label)
		tier_label.queue_free()
		parent.add_child(_tier_icon(instance.tier, Vector2(34.0, 23.0)))
		parent.move_child(parent.get_child(parent.get_child_count() - 1), index)
	return panel


func _tier_icon(tier: String, minimum_size: Vector2) -> DigiTierIcon:
	var icon := TierIconScript.new() as DigiTierIcon
	icon.configure(tier, minimum_size)
	return icon


func _find_label_starting_with(root: Node, prefix: String) -> Label:
	for child in root.get_children():
		if child is Label and (child as Label).text.begins_with(prefix):
			return child as Label
		var nested := _find_label_starting_with(child, prefix)
		if nested != null:
			return nested
	return null
