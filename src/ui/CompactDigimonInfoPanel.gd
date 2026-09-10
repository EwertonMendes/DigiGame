extends "res://src/DigimonInfoPanel.gd"

const CompactUI = preload("res://src/ui/TacticalTheme.gd")
const CARD_BREAKPOINT := 760.0


func _refresh_context() -> void:
	super._refresh_context()
	if _card == null:
		return
	var hovered: Node = null
	if _digimon_controller != null and _digimon_controller.has_method("get_hovered_digimon"):
		hovered = _digimon_controller.call("get_hovered_digimon") as Node

	# Active-unit status is permanently visible in the battle HUD. This card is
	# deliberately inspection-only and lives opposite the command rail.
	_card.visible = hovered != null and is_instance_valid(hovered)
	if not _card.visible:
		return

	_eyebrow.text = "INSPECT"
	_team_tag.text = _team_tag.text.capitalize()
	_name_label.text = _name_label.text.capitalize()
	_level_label.text = _level_label.text.replace("LV ", "Lv.")
	_rank_label.text = _rank_label.text.capitalize()
	_attribute_label.text = _attribute_label.text.capitalize()
	_species_label.text = _species_label.text.capitalize()
	_layout_card()


func _layout_card() -> void:
	if _card == null:
		return
	var viewport_obj := get_viewport()
	var logical := viewport_obj.get_visible_rect().size
	var physical := CompactUI.physical_window_size(viewport_obj)
	var ui_scale := CompactUI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var compact := CompactUI.is_compact(viewport_obj, CARD_BREAKPOINT)
	var portrait_mobile := compact and physical.y > physical.x

	var width := minf(270.0, physical.x - 20.0)
	var height := 226.0
	var card_x := maxf(10.0, physical.x - width - 106.0)
	var card_y := 70.0
	if portrait_mobile:
		width = physical.x - 20.0
		height = 214.0
		card_x = 10.0
		card_y = 230.0
	elif compact:
		width = minf(248.0, physical.x - 20.0)
		height = 214.0
		card_x = maxf(10.0, physical.x - width - 12.0)
		card_y = 122.0
	_card.scale = Vector2.ONE * ui_scale
	_card.position = Vector2(card_x * ui_scale, card_y * ui_scale)
	_card.size = Vector2(width, height)
	_card.add_theme_stylebox_override("panel", CompactUI.glass_panel(CompactUI.GOLD, 0.80, 7))

	_team_marker.position = Vector2(0.0, 38.0)
	_team_marker.size = Vector2(3.0, height - 50.0)
	_signal_line.position = Vector2(12.0, 0.0)
	_signal_line.size = Vector2(48.0, 2.0)
	_eyebrow.position = Vector2(12.0, 8.0)
	_eyebrow.size = Vector2(width - 92.0, 22.0)
	_eyebrow.add_theme_font_size_override("font_size", 12)
	_team_tag.size = Vector2(68.0, 24.0)
	_team_tag.position = Vector2(width - 80.0, 7.0)
	_team_tag.add_theme_font_size_override("font_size", 12)

	var portrait_side := 60.0
	_portrait_frame.position = Vector2(12.0, 39.0)
	_portrait_frame.size = Vector2(portrait_side, portrait_side)
	_portrait.position = Vector2(4.0, 4.0)
	_portrait.size = Vector2(portrait_side - 8.0, portrait_side - 8.0)

	var identity_x := 84.0
	var identity_w := width - identity_x - 12.0
	_name_label.position = Vector2(identity_x, 38.0)
	_name_label.size = Vector2(identity_w, 26.0)
	_name_label.add_theme_font_size_override("font_size", 17)
	_level_label.position = Vector2(identity_x, 65.0)
	_level_label.size = Vector2(identity_w, 20.0)
	_level_label.add_theme_font_size_override("font_size", 12)
	_rank_label.position = Vector2(identity_x, 88.0)
	_rank_label.size = Vector2(identity_w, 23.0)
	_rank_label.add_theme_font_size_override("font_size", 12)

	_attribute_label.position = Vector2(12.0, 112.0)
	_attribute_label.size = Vector2((width - 30.0) * 0.5, 20.0)
	_attribute_label.add_theme_font_size_override("font_size", 12)
	_species_label.position = Vector2(width * 0.5, 112.0)
	_species_label.size = Vector2(width * 0.5 - 12.0, 20.0)
	_species_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_species_label.add_theme_font_size_override("font_size", 12)

	_divider.position = Vector2(12.0, 138.0)
	_divider.size = Vector2(width - 24.0, 1.0)
	_divider.color = CompactUI.separator(CompactUI.GOLD, 0.18)

	var value_w := 76.0
	var bar_w := width - 24.0
	_hp_caption.position = Vector2(12.0, 146.0)
	_hp_caption.size = Vector2(30.0, 19.0)
	_hp_value.position = Vector2(width - value_w - 12.0, 146.0)
	_hp_value.size = Vector2(value_w, 19.0)
	_hp_bar.position = Vector2(12.0, 168.0)
	_hp_bar.size = Vector2(bar_w, 7.0)
	_sp_caption.position = Vector2(12.0, 181.0)
	_sp_caption.size = Vector2(30.0, 19.0)
	_sp_value.position = Vector2(width - value_w - 12.0, 181.0)
	_sp_value.size = Vector2(value_w, 19.0)
	_sp_bar.position = Vector2(12.0, 203.0)
	_sp_bar.size = Vector2(bar_w, 7.0)
	for label: Label in [_hp_caption, _hp_value, _sp_caption, _sp_value]:
		label.add_theme_font_size_override("font_size", 12)

	_mov_label.visible = false
	_spd_label.visible = false
