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

	# The active unit now lives in the bottom action dock. This panel is only an
	# inspection surface, so it no longer occupies the playfield permanently.
	_card.visible = hovered != null and is_instance_valid(hovered)
	if not _card.visible:
		return

	_eyebrow.text = "Inspecting"
	_team_tag.text = _team_tag.text.capitalize()
	_name_label.text = _name_label.text.capitalize()
	_level_label.text = _level_label.text.replace("LV ", "Lv. ")
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

	var width := minf(286.0, physical.x - 20.0)
	var height := 246.0
	var card_x := 10.0 if compact else 16.0
	var card_y := 138.0 if compact else 76.0
	_card.scale = Vector2.ONE * ui_scale
	_card.position = Vector2(card_x * ui_scale, card_y * ui_scale)
	_card.size = Vector2(width, height)
	_card.add_theme_stylebox_override("panel", CompactUI.panel(CompactUI.GOLD, 0.97, 0.24, 11, 4))

	_team_marker.position = Vector2(0.0, 42.0)
	_team_marker.size = Vector2(3.0, height - 58.0)
	_signal_line.position = Vector2(14.0, 0.0)
	_signal_line.size = Vector2(54.0, 2.0)
	_eyebrow.position = Vector2(14.0, 10.0)
	_eyebrow.size = Vector2(width - 96.0, 22.0)
	_eyebrow.add_theme_font_size_override("font_size", 14)
	_team_tag.size = Vector2(72.0, 26.0)
	_team_tag.position = Vector2(width - 86.0, 8.0)
	_team_tag.add_theme_font_size_override("font_size", 14)

	var portrait_side := 68.0
	_portrait_frame.position = Vector2(14.0, 43.0)
	_portrait_frame.size = Vector2(portrait_side, portrait_side)
	_portrait.position = Vector2(5.0, 5.0)
	_portrait.size = Vector2(portrait_side - 10.0, portrait_side - 10.0)

	var identity_x := 94.0
	var identity_w := width - identity_x - 14.0
	_name_label.position = Vector2(identity_x, 43.0)
	_name_label.size = Vector2(identity_w, 28.0)
	_name_label.add_theme_font_size_override("font_size", 19)
	_level_label.position = Vector2(identity_x, 72.0)
	_level_label.size = Vector2(identity_w, 22.0)
	_level_label.add_theme_font_size_override("font_size", 14)
	_rank_label.position = Vector2(identity_x, 97.0)
	_rank_label.size = Vector2(identity_w, 25.0)
	_rank_label.add_theme_font_size_override("font_size", 14)

	_attribute_label.position = Vector2(14.0, 124.0)
	_attribute_label.size = Vector2((width - 34.0) * 0.5, 22.0)
	_attribute_label.add_theme_font_size_override("font_size", 14)
	_species_label.position = Vector2(width * 0.5, 124.0)
	_species_label.size = Vector2(width * 0.5 - 14.0, 22.0)
	_species_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_species_label.add_theme_font_size_override("font_size", 14)

	_divider.position = Vector2(14.0, 153.0)
	_divider.size = Vector2(width - 28.0, 1.0)
	_divider.color = CompactUI.separator(CompactUI.GOLD, 0.16)

	var value_w := 82.0
	var bar_w := width - 28.0
	_hp_caption.position = Vector2(14.0, 162.0)
	_hp_caption.size = Vector2(30.0, 20.0)
	_hp_value.position = Vector2(width - value_w - 14.0, 162.0)
	_hp_value.size = Vector2(value_w, 20.0)
	_hp_bar.position = Vector2(14.0, 185.0)
	_hp_bar.size = Vector2(bar_w, 8.0)
	_sp_caption.position = Vector2(14.0, 201.0)
	_sp_caption.size = Vector2(30.0, 20.0)
	_sp_value.position = Vector2(width - value_w - 14.0, 201.0)
	_sp_value.size = Vector2(value_w, 20.0)
	_sp_bar.position = Vector2(14.0, 224.0)
	_sp_bar.size = Vector2(bar_w, 8.0)
	for label: Label in [_hp_caption, _hp_value, _sp_caption, _sp_value]:
		label.add_theme_font_size_override("font_size", 14)

	_mov_label.visible = false
	_spd_label.visible = false
