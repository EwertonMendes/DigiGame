extends "res://src/BattleHUDVisualDomain.gd"

const MOBILE_EDGE := 12.0
const MOBILE_BOTTOM := 16.0


func _layout_dock() -> void:
	if _dock == null or _status_panel == null:
		return
	var viewport_obj := get_viewport()
	if not UI.is_compact(viewport_obj, 820.0):
		_set_touch_shortcut_visibility(true)
		super._layout_dock()
		return

	var logical := viewport_obj.get_visible_rect().size
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var portrait := physical.y >= physical.x
	var user_turn := bool(_cached_state.get("is_user_turn", false))
	var contextual := _context_row.visible

	_status_panel.scale = Vector2.ONE * ui_scale
	_dock.scale = Vector2.ONE * ui_scale
	_set_touch_shortcut_visibility(false)

	if portrait:
		var status_w := physical.x - MOBILE_EDGE * 2.0
		_status_panel.position = Vector2(MOBILE_EDGE * ui_scale, 140.0 * ui_scale)
		_status_panel.size = Vector2(status_w, 84.0)
		_layout_status(Vector2(status_w, 84.0), true)

		var dock_h := 176.0 if user_turn and not contextual else (106.0 if contextual else 72.0)
		_dock.position = Vector2(
			MOBILE_EDGE * ui_scale,
			(physical.y - dock_h - MOBILE_BOTTOM) * ui_scale
		)
		_dock.size = Vector2(status_w, dock_h)
		_action_grid.columns = 2 if physical.x < 330.0 else 3
		_layout_command(Vector2(status_w, dock_h), true, contextual, user_turn)
		return

	# Landscape phones have width to spare but very little height. The previous
	# vertical command rail consumed almost the entire short edge and sat nearly
	# flush with the browser bottom. Use a wide two-row command sheet instead.
	var status_w := minf(242.0, physical.x * 0.29)
	_status_panel.position = Vector2(MOBILE_EDGE * ui_scale, 58.0 * ui_scale)
	_status_panel.size = Vector2(status_w, 74.0)
	_layout_status(Vector2(status_w, 74.0), true)

	var utility_reserve := 166.0
	var dock_w := minf(620.0, maxf(360.0, physical.x - MOBILE_EDGE * 2.0 - utility_reserve))
	var dock_h := 160.0 if user_turn and not contextual else (102.0 if contextual else 70.0)
	# On exceptionally short browser viewports, compress the sheet rather than
	# letting its bottom disappear behind browser chrome / gesture navigation.
	dock_h = minf(dock_h, maxf(92.0, physical.y - 196.0)) if user_turn else dock_h
	_dock.position = Vector2(
		MOBILE_EDGE * ui_scale,
		maxf(136.0, physical.y - dock_h - MOBILE_BOTTOM) * ui_scale
	)
	_dock.size = Vector2(dock_w, dock_h)
	_action_grid.columns = 3
	_layout_command(Vector2(dock_w, dock_h), true, contextual, user_turn)


func _layout_command(panel_size: Vector2, compact: bool, contextual: bool, user_turn: bool) -> void:
	if not compact:
		super._layout_command(panel_size, compact, contextual, user_turn)
		return

	var pad := 10.0
	_command_title.position = Vector2(pad + 3.0, 5.0)
	_command_title.size = Vector2(panel_size.x - pad * 2.0 - 72.0, 20.0)
	_command_title.add_theme_font_size_override("font_size", 12)
	_phase_label.position = Vector2(pad + 3.0, 25.0)
	_phase_label.size = Vector2(panel_size.x - pad * 2.0 - (74.0 if _mov_label.visible else 0.0), 22.0)
	_phase_label.add_theme_font_size_override("font_size", 12)
	_mov_label.position = Vector2(panel_size.x - 72.0, 23.0)
	_mov_label.size = Vector2(62.0, 24.0)
	_mov_label.add_theme_font_size_override("font_size", 11)
	_nav_hint.visible = false

	if not user_turn:
		_phase_label.position = Vector2(pad + 3.0, 28.0)
		_phase_label.size = Vector2(panel_size.x - pad * 2.0, 26.0)
		return

	if contextual:
		_context_row.position = Vector2(pad, 51.0)
		_context_row.size = Vector2(panel_size.x - pad * 2.0, maxf(42.0, panel_size.y - 60.0))
		_cancel_button.custom_minimum_size = Vector2(0.0, 44.0)
		_cancel_button.add_theme_font_size_override("font_size", 14)
		_confirm_move_button.custom_minimum_size = Vector2.ZERO
		return

	var grid_y := 52.0
	var grid_h := maxf(64.0, panel_size.y - grid_y - 8.0)
	_action_grid.position = Vector2(pad, grid_y)
	_action_grid.size = Vector2(panel_size.x - pad * 2.0, grid_h)
	_action_grid.add_theme_constant_override("h_separation", 6)
	_action_grid.add_theme_constant_override("v_separation", 5)

	var visible_count := 0
	for button: Button in _primary_buttons:
		if button.visible:
			visible_count += 1
	if _undo_button.visible:
		visible_count += 1
	var columns := maxi(1, _action_grid.columns)
	var rows := maxi(1, int(ceil(float(visible_count) / float(columns))))
	var button_h := clampf((grid_h - float(rows - 1) * 5.0) / float(rows), 38.0, 54.0)
	for button: Button in _primary_buttons:
		button.custom_minimum_size = Vector2(0.0, button_h)
		button.add_theme_font_size_override("font_size", 13)
	_undo_button.custom_minimum_size = Vector2(0.0, button_h)
	_undo_button.add_theme_font_size_override("font_size", 13)


func _set_touch_shortcut_visibility(visible: bool) -> void:
	for button: Button in _primary_buttons:
		for child: Node in button.get_children():
			if child is Label:
				(child as Label).visible = visible
	for child: Node in _undo_button.get_children():
		if child is Label:
			(child as Label).visible = visible
