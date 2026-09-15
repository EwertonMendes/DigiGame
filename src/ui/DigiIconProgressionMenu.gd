extends "res://src/ui/DigimonProgressionMenu.gd"
class_name DigiIconProgressionMenu

const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")
const AssetIcons = preload("res://src/ui/components/DigiUiAssetIcons.gd")


func _build() -> void:
	super._build()
	AssetIcons.apply_bits_icon(_header)


func _collection_button(instance: DigimonInstance, species: Dictionary, index: int) -> Button:
	var rank := String(species.get("rank", "Unknown"))
	var rank_color := V2.rank_color(rank)
	var selected := index == _selected_index
	var button := Button.new()
	button.name = "Collection%02d" % index
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(226.0, 84.0)
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_select_index.bind(index))
	button.focus_entered.connect(_select_index.bind(index))
	_style_collection_button(button, selected, rank_color)

	var margin := _margin(11, 8, 11, 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.custom_minimum_size = Vector2(58.0, 58.0)
	preview.set_species(String(species.get("name", "")))
	preview.set_active(selected)
	row.add_child(preview)
	_walk_previews.append(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 3)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	var name_label := _label(display_name, 15, V2.TEXT, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(name_label)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 7)
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(meta_row)
	var sub := _label("Lv %d  ·  %s" % [instance.level, rank], 10, rank_color.lightened(0.08), true)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_row.add_child(sub)
	var tier_icon := TierIconScript.new() as DigiTierIcon
	tier_icon.configure(instance.tier, Vector2(28.0, 18.0))
	meta_row.add_child(tier_icon)

	var xp_gap := Control.new()
	xp_gap.custom_minimum_size.y = 2.0
	xp_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(xp_gap)
	var xp_required := _progression.exp_to_next_level(instance)
	var progress := _mini_progress(V2.CYAN if selected else rank_color)
	progress.max_value = maxf(1.0, float(xp_required))
	progress.value = float(instance.exp if xp_required > 0 else xp_required)
	progress.custom_minimum_size = Vector2(100.0, 6.0)
	copy.add_child(progress)
	_buttons.append(button)
	return button
