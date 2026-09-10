extends "res://src/DigimonInfoPanel.gd"

const CompactUI = preload("res://src/ui/TacticalTheme.gd")
const CARD_BREAKPOINT := 760.0


func _layout_card() -> void:
	if _card == null:
		return
	var viewport_obj: Viewport = get_viewport()
	var logical: Vector2 = viewport_obj.get_visible_rect().size
	var physical: Vector2 = CompactUI.physical_window_size(viewport_obj)
	var ui_scale: float = CompactUI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var compact: bool = CompactUI.is_compact(viewport_obj, CARD_BREAKPOINT)
	var short_landscape: bool = compact and physical.x > physical.y and physical.y < 560.0
	var laptop: bool = CompactUI.is_laptop(viewport_obj)

	var width: float = 232.0 if compact else (252.0 if laptop else 260.0)
	var height: float = 224.0 if compact else (254.0 if laptop else 266.0)
	if short_landscape:
		width = 226.0
		height = 214.0
	width = minf(width, physical.x - 130.0)
	width = maxf(212.0, width)
	var card_x: float = 10.0 if compact else 16.0
	var card_y: float = 58.0 if compact else 82.0

	_card.scale = Vector2.ONE * ui_scale
	_card.position = Vector2(card_x * ui_scale, card_y * ui_scale)
	_card.size = Vector2(width, height)
	_team_marker.position = Vector2(0.0, 32.0)
	_team_marker.size = Vector2(4.0, height - 48.0)
	_signal_line.position = Vector2(14.0, 0.0)
	_signal_line.size = Vector2(78.0 if compact else 92.0, 2.0)
	_eyebrow.position = Vector2(14.0, 8.0)
	_eyebrow.size = Vector2(width - 86.0, 18.0)
	_eyebrow.add_theme_font_size_override("font_size", 9 if compact else 10)
	_team_tag.size = Vector2(58.0, 21.0)
	_team_tag.position = Vector2(width - 70.0, 6.0)
	_team_tag.add_theme_font_size_override("font_size", 9 if compact else 10)

	var portrait_side: float = 64.0 if compact else (72.0 if laptop else 76.0)
	if short_landscape:
		portrait_side = 60.0
	var portrait_size := Vector2(portrait_side, portrait_side)
	_portrait_frame.position = Vector2(14.0, 37.0)
	_portrait_frame.size = portrait_size
	_portrait.position = Vector2(4.0, 4.0)
	_portrait.size = portrait_size - Vector2(8.0, 8.0)

	var identity_x := 14.0 + portrait_side + 11.0
	var identity_w := width - identity_x - 12.0
	_name_label.position = Vector2(identity_x, 37.0)
	_name_label.size = Vector2(identity_w, 27.0)
	_name_label.add_theme_font_size_override("font_size", 17 if compact else 20)
	_level_label.position = Vector2(identity_x, 63.0)
	_level_label.size = Vector2(46.0, 19.0)
	_level_label.add_theme_font_size_override("font_size", 10 if compact else 11)
	_rank_label.position = Vector2(identity_x, 84.0)
	_rank_label.size = Vector2(identity_w, 21.0)
	_rank_label.add_theme_font_size_override("font_size", 8 if compact else 9)
	_attribute_label.position = Vector2(identity_x, 107.0)
	_attribute_label.size = Vector2(identity_w, 17.0)
	_attribute_label.add_theme_font_size_override("font_size", 9 if compact else 10)
	_species_label.position = Vector2(identity_x, 123.0)
	_species_label.size = Vector2(identity_w, 17.0)
	_species_label.add_theme_font_size_override("font_size", 8 if compact else 9)

	var stats_y: float = 142.0 if compact else (151.0 if laptop else 156.0)
	if short_landscape:
		stats_y = 135.0
	_divider.position = Vector2(14.0, stats_y - 8.0)
	_divider.size = Vector2(width - 28.0, 1.0)

	var value_w := 78.0
	var bar_x := 14.0
	var bar_w := width - 28.0
	var bar_h := 8.0 if compact else 9.0
	var row_gap := 39.0 if compact else 44.0
	_hp_caption.position = Vector2(14.0, stats_y)
	_hp_caption.size = Vector2(30.0, 17.0)
	_hp_value.position = Vector2(width - value_w - 14.0, stats_y)
	_hp_value.size = Vector2(value_w, 17.0)
	_hp_bar.position = Vector2(bar_x, stats_y + 20.0)
	_hp_bar.size = Vector2(bar_w, bar_h)
	_sp_caption.position = Vector2(14.0, stats_y + row_gap)
	_sp_caption.size = Vector2(30.0, 17.0)
	_sp_value.position = Vector2(width - value_w - 14.0, stats_y + row_gap)
	_sp_value.size = Vector2(value_w, 17.0)
	_sp_bar.position = Vector2(bar_x, stats_y + row_gap + 20.0)
	_sp_bar.size = Vector2(bar_w, bar_h)
	for label: Label in [_hp_caption, _hp_value, _sp_caption, _sp_value]:
		label.add_theme_font_size_override("font_size", 9 if compact else 10)

	# MOV and SPD already live in the command/turn UI. Keeping them here made the
	# context card wider without adding useful decision information.
	_mov_label.visible = false
	_spd_label.visible = false
