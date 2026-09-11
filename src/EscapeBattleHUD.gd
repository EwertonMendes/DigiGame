extends "res://src/BattleHUDMobileDomain.gd"

var _flee_button: Button = null
var _escape_modal_layer: Control = null
var _escape_modal_panel: Panel = null
var _escape_title: Label = null
var _escape_chance: Label = null
var _escape_breakdown: Label = null
var _escape_warning: Label = null
var _escape_confirm: Button = null
var _escape_cancel: Button = null
var _escape_announcement: Panel = null
var _escape_announcement_title: Label = null
var _escape_announcement_subtitle: Label = null
var _escape_result: Panel = null
var _escape_result_title: Label = null
var _escape_result_body: Label = null
var _escape_result_return: Button = null
var _escape_announcement_tween: Tween = null


func _ready() -> void:
	super._ready()
	_install_flee_command()
	_build_escape_ui()
	if _controller != null and _controller.has_signal("combat_event"):
		_controller.connect("combat_event", _on_escape_combat_event)
	refresh_from_controller()
	_layout_dock()


func _install_flee_command() -> void:
	if _action_grid == null or _flee_button != null:
		return
	_flee_button = _make_action_button("Flee", "flee.svg", "6", "Attempt a tactical retreat")
	_flee_button.pressed.connect(_on_flee_pressed)
	_primary_buttons.append(_flee_button)
	_action_grid.add_child(_flee_button)
	if _undo_button != null:
		_action_grid.move_child(_flee_button, _undo_button.get_index())


func refresh_from_controller() -> void:
	super.refresh_from_controller()
	if _flee_button == null or _controller == null or not _controller.has_method("get_hud_state"):
		return
	var state: Dictionary = _controller.call("get_hud_state")
	var preview_variant = state.get("flee_preview", {})
	var preview: Dictionary = preview_variant if preview_variant is Dictionary else {}
	var policy_allowed := bool(preview.get("allowed", false))
	var command_available := bool(state.get("can_wait", false))
	_flee_button.disabled = not bool(state.get("can_flee", false)) if policy_allowed else not command_available
	_flee_button.text = "Flee" if policy_allowed else "Flee · LOCKED"
	var reason := String(preview.get("reason", "Retreat is unavailable in this battle."))
	if policy_allowed:
		_flee_button.tooltip_text = "Attempt retreat · %d%% chance  [6]" % int(round(float(preview.get("chance", 0.0))))
	else:
		_flee_button.tooltip_text = "%s  [6]" % reason
	if bool(state.get("battle_over", false)):
		_flee_button.disabled = true
		_close_escape_modal()
		var result_variant = state.get("battle_result", {})
		var result: Dictionary = result_variant if result_variant is Dictionary else {}
		if bool(result.get("escaped", false)):
			_show_escape_result(result)
		else:
			_escape_result.visible = false
	else:
		_escape_result.visible = false
	_layout_dock()


func _input(event: InputEvent) -> void:
	if _escape_modal_layer != null and _escape_modal_layer.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_escape_modal()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept"):
			_on_escape_confirmed()
			get_viewport().set_input_as_handled()
			return
	super._input(event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_6:
			if not _is_timeline_navigation_active() and (_combat_overlay == null or not _combat_overlay.is_skill_menu_visible()):
				_on_flee_pressed()
				get_viewport().set_input_as_handled()
				return
	super._unhandled_input(event)


func _on_flee_pressed() -> void:
	if _controller == null or not _controller.has_method("get_flee_preview"):
		return
	var preview: Dictionary = _controller.call("get_flee_preview")
	if not bool(preview.get("allowed", false)):
		_show_escape_announcement(false, "RETREAT LOCKED", String(preview.get("reason", "Retreat is unavailable in this battle.")), 1.3)
		return
	if _flee_button != null and _flee_button.disabled:
		return
	_open_escape_modal(preview)


func _open_escape_modal(preview: Dictionary) -> void:
	if _escape_modal_layer == null:
		return
	var chance := int(round(float(preview.get("chance", 0.0))))
	var mode := String(preview.get("mode", "allowed"))
	_escape_title.text = "TACTICAL RETREAT"
	_escape_chance.text = "GUARANTEED ESCAPE" if mode == "guaranteed" else "%d%% ESCAPE CHANCE" % chance
	_escape_breakdown.text = "Base %+d%%   ·   Speed %+d%%   ·   Distance %+d%%   ·   Retry %+d%%" % [
		int(round(float(preview.get("base_chance", 0.0)))),
		int(round(float(preview.get("speed_modifier", 0.0)))),
		int(round(float(preview.get("distance_modifier", 0.0)))),
		int(round(float(preview.get("retry_modifier", 0.0)))),
	]
	var recovery := int(round(float(preview.get("failure_recovery", 120.0))))
	_escape_warning.text = "Failure ends this Digimon's turn with at least %d CT recovery.\nRetreat forfeits all Bits and Digi Data from this battle." % recovery
	_escape_modal_layer.visible = true
	_layout_escape_ui()
	_escape_confirm.grab_focus()
	_escape_modal_panel.modulate.a = 0.0
	_escape_modal_panel.scale *= 0.96
	var target_scale := Vector2.ONE * UI.ui_scale(get_viewport())
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_escape_modal_panel, "modulate:a", 1.0, 0.14)
	tween.tween_property(_escape_modal_panel, "scale", target_scale, 0.14)


func _close_escape_modal() -> void:
	if _escape_modal_layer != null:
		_escape_modal_layer.visible = false
	if _flee_button != null and _flee_button.visible and not _flee_button.disabled:
		_flee_button.grab_focus()


func _on_escape_confirmed() -> void:
	if _escape_modal_layer == null or not _escape_modal_layer.visible:
		return
	_escape_modal_layer.visible = false
	if _controller != null and _controller.has_method("attempt_flee"):
		_controller.call("attempt_flee")


func _on_escape_combat_event(event: Dictionary) -> void:
	match String(event.get("type", "")):
		"flee_attempt":
			_show_escape_announcement(true, "RETREAT LINK", "Searching for a safe disengage route...", 0.55)
		"flee_failed":
			_show_escape_announcement(false, "RETREAT FAILED", "SIGNAL INTERCEPTED  ·  Next chance %d%%" % int(round(float(event.get("next_chance", 0.0)))), 1.05)
		"flee_success":
			_show_escape_announcement(true, "RETREAT SUCCESSFUL", "DATA LINK DISENGAGED", 1.35)
		"flee_blocked":
			_show_escape_announcement(false, "RETREAT LOCKED", String(event.get("reason", "Retreat unavailable.")), 1.25)


func _build_escape_ui() -> void:
	_escape_modal_layer = Control.new()
	_escape_modal_layer.name = "EscapeConfirmation"
	_escape_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_escape_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_escape_modal_layer.visible = false
	_escape_modal_layer.z_index = 70
	add_child(_escape_modal_layer)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.018, 0.025, 0.66)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_escape_modal_layer.add_child(backdrop)

	_escape_modal_panel = Panel.new()
	_escape_modal_panel.name = "RetreatPanel"
	_escape_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_escape_modal_panel.add_theme_stylebox_override("panel", UI.panel_strong(UI.CYAN, 10))
	_escape_modal_layer.add_child(_escape_modal_panel)

	_escape_title = _escape_label("TACTICAL RETREAT", 16, UI.CYAN, true)
	_escape_chance = _escape_label("50% ESCAPE CHANCE", 29, Color.WHITE, true)
	_escape_chance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_breakdown = _escape_label("", 13, UI.MUTED)
	_escape_breakdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_warning = _escape_label("", 13, UI.TEXT)
	_escape_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label: Label in [_escape_title, _escape_chance, _escape_breakdown, _escape_warning]:
		_escape_modal_panel.add_child(label)

	_escape_confirm = _escape_dialog_button("ATTEMPT RETREAT", UI.CYAN)
	_escape_confirm.name = "ConfirmFlee"
	_escape_confirm.pressed.connect(_on_escape_confirmed)
	_escape_modal_panel.add_child(_escape_confirm)
	_escape_cancel = _escape_dialog_button("STAY IN BATTLE", UI.GOLD)
	_escape_cancel.name = "CancelFlee"
	_escape_cancel.pressed.connect(_close_escape_modal)
	_escape_modal_panel.add_child(_escape_cancel)

	_escape_announcement = Panel.new()
	_escape_announcement.name = "RetreatAnnouncement"
	_escape_announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escape_announcement.visible = false
	_escape_announcement.z_index = 72
	add_child(_escape_announcement)
	_escape_announcement_title = _escape_label("RETREAT", 30, Color.WHITE, true)
	_escape_announcement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_announcement_subtitle = _escape_label("", 14, UI.CYAN, true)
	_escape_announcement_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_announcement.add_child(_escape_announcement_title)
	_escape_announcement.add_child(_escape_announcement_subtitle)

	_escape_result = Panel.new()
	_escape_result.name = "RetreatResult"
	_escape_result.mouse_filter = Control.MOUSE_FILTER_STOP
	_escape_result.visible = false
	_escape_result.z_index = 80
	_escape_result.add_theme_stylebox_override("panel", UI.panel_strong(UI.CYAN, 10))
	add_child(_escape_result)
	_escape_result_title = _escape_label("RETREAT SUCCESSFUL", 30, UI.CYAN, true)
	_escape_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_result_body = _escape_label("", 15, UI.TEXT)
	_escape_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_escape_result_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_escape_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_escape_result_return = _escape_dialog_button("RETURN TO TERMINAL COMMONS", UI.CYAN)
	_escape_result_return.name = "ReturnAfterRetreat"
	_escape_result_return.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/world/hub.tscn"))
	_escape_result.add_child(_escape_result_title)
	_escape_result.add_child(_escape_result_body)
	_escape_result.add_child(_escape_result_return)
	_layout_escape_ui()


func _escape_label(text_value: String, size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label


func _escape_dialog_button(text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_stylebox_override("focus", UI.focus_outline(accent, 8))
	return button


func _show_escape_announcement(success_style: bool, title: String, subtitle: String, hold: float) -> void:
	if _escape_announcement == null:
		return
	var accent := UI.CYAN if success_style else UI.RED
	_escape_announcement.add_theme_stylebox_override("panel", UI.panel_strong(accent, 8))
	_escape_announcement_title.text = title
	_escape_announcement_title.add_theme_color_override("font_color", accent if title != "RETREAT LINK" else Color.WHITE)
	_escape_announcement_subtitle.text = subtitle
	_escape_announcement_subtitle.add_theme_color_override("font_color", UI.TEXT)
	_escape_announcement.visible = true
	_escape_announcement.modulate.a = 0.0
	var scale_value := UI.ui_scale(get_viewport())
	_escape_announcement.scale = Vector2.ONE * scale_value * 0.92
	_layout_escape_ui()
	if _escape_announcement_tween != null and _escape_announcement_tween.is_valid():
		_escape_announcement_tween.kill()
	_escape_announcement_tween = create_tween()
	_escape_announcement_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_escape_announcement_tween.tween_property(_escape_announcement, "scale", Vector2.ONE * scale_value, 0.16)
	_escape_announcement_tween.parallel().tween_property(_escape_announcement, "modulate:a", 1.0, 0.12)
	_escape_announcement_tween.tween_interval(hold)
	_escape_announcement_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_escape_announcement_tween.tween_property(_escape_announcement, "modulate:a", 0.0, 0.18)
	_escape_announcement_tween.tween_callback(func(): _escape_announcement.visible = false)


func _show_escape_result(result: Dictionary) -> void:
	_hide_base_result_panel()
	_escape_announcement.visible = false
	_escape_result.visible = true
	_escape_result_body.text = "Disengaged after %d turns · %d retreat attempt%s\nNo Bits or Digi Data were gained from this battle." % [
		int(result.get("acts", 0)),
		int(result.get("flee_attempts", 1)),
		"" if int(result.get("flee_attempts", 1)) == 1 else "s",
	]
	_layout_escape_ui()
	call_deferred("_focus_escape_result")


func _focus_escape_result() -> void:
	if _escape_result_return != null and _escape_result_return.visible:
		_escape_result_return.grab_focus()


func _hide_base_result_panel() -> void:
	if _combat_overlay == null:
		return
	var return_button := _find_descendant_named(_combat_overlay, "ReturnToHub")
	if return_button != null and return_button.get_parent() is Control:
		(return_button.get_parent() as Control).visible = false


func _find_descendant_named(root: Node, target_name: String) -> Node:
	for child: Node in root.get_children():
		if child.name == target_name:
			return child
		var nested := _find_descendant_named(child, target_name)
		if nested != null:
			return nested
	return null


func _layout_dock() -> void:
	super._layout_dock()
	if _dock == null or _flee_button == null:
		_layout_escape_ui()
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	var compact := UI.is_compact(viewport_obj, 820.0)
	var user_turn := bool(_cached_state.get("is_user_turn", false))
	var contextual := _context_row.visible
	if user_turn and not contextual:
		if not compact:
			var dock_h := minf(410.0, maxf(330.0, physical.y - 208.0))
			_dock.size = Vector2(_dock.size.x, dock_h)
			_layout_command(Vector2(_dock.size.x, dock_h), false, false, true)
			var visible_count := 0
			for button: Button in _primary_buttons:
				if button.visible:
					visible_count += 1
			if _undo_button.visible:
				visible_count += 1
			var grid_h := maxf(50.0, dock_h - 87.0)
			var button_h := clampf((grid_h - float(maxi(0, visible_count - 1)) * 3.0) / float(maxi(1, visible_count)), 34.0, 42.0)
			for button: Button in _primary_buttons:
				button.custom_minimum_size.y = button_h
			_undo_button.custom_minimum_size.y = button_h
		elif physical.x > physical.y:
			var dock_w := _dock.size.x
			_action_grid.columns = 4 if dock_w >= 420.0 else 3
			var target_h := 178.0 if _undo_button.visible else 160.0
			target_h = minf(target_h, maxf(148.0, physical.y - 196.0))
			_dock.position.y = maxf(136.0, physical.y - target_h - MOBILE_BOTTOM) * ui_scale
			_dock.size.y = target_h
			_layout_command(Vector2(dock_w, target_h), true, false, true)
		else:
			var target_h := 198.0 if _undo_button.visible else 176.0
			_dock.position.y = (physical.y - target_h - MOBILE_BOTTOM) * ui_scale
			_dock.size.y = target_h
			_layout_command(Vector2(_dock.size.x, target_h), true, false, true)
	_layout_escape_ui()


func _layout_escape_ui() -> void:
	if _escape_modal_panel == null:
		return
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	var compact := UI.is_compact(viewport_obj, 820.0)

	var modal_w := minf(540.0, physical.x - 24.0)
	var modal_h := minf(314.0, physical.y - 24.0)
	_escape_modal_panel.scale = Vector2.ONE * ui_scale
	_escape_modal_panel.position = Vector2((physical.x - modal_w) * 0.5, (physical.y - modal_h) * 0.5) * ui_scale
	_escape_modal_panel.size = Vector2(modal_w, modal_h)
	_escape_title.position = Vector2(20.0, 16.0)
	_escape_title.size = Vector2(modal_w - 40.0, 24.0)
	_escape_chance.position = Vector2(20.0, 48.0)
	_escape_chance.size = Vector2(modal_w - 40.0, 48.0)
	_escape_chance.add_theme_font_size_override("font_size", 24 if compact else 29)
	_escape_breakdown.position = Vector2(18.0, 101.0)
	_escape_breakdown.size = Vector2(modal_w - 36.0, 26.0)
	_escape_breakdown.add_theme_font_size_override("font_size", 11 if compact else 13)
	_escape_warning.position = Vector2(24.0, 132.0)
	_escape_warning.size = Vector2(modal_w - 48.0, 66.0)
	_escape_warning.add_theme_font_size_override("font_size", 11 if compact else 13)
	var button_y := modal_h - 66.0
	var gap := 10.0
	var button_w := (modal_w - 40.0 - gap) * 0.5
	_escape_confirm.position = Vector2(20.0, button_y)
	_escape_confirm.size = Vector2(button_w, 46.0)
	_escape_cancel.position = Vector2(20.0 + button_w + gap, button_y)
	_escape_cancel.size = Vector2(button_w, 46.0)

	var announce_w := minf(560.0, physical.x - 24.0)
	var announce_h := 120.0
	_escape_announcement.scale = Vector2.ONE * ui_scale
	_escape_announcement.position = Vector2((physical.x - announce_w) * 0.5, maxf(28.0, physical.y * 0.22)) * ui_scale
	_escape_announcement.size = Vector2(announce_w, announce_h)
	_escape_announcement_title.position = Vector2(16.0, 18.0)
	_escape_announcement_title.size = Vector2(announce_w - 32.0, 42.0)
	_escape_announcement_subtitle.position = Vector2(16.0, 65.0)
	_escape_announcement_subtitle.size = Vector2(announce_w - 32.0, 28.0)

	var result_w := minf(520.0, physical.x - 28.0)
	var result_h := minf(244.0, physical.y - 28.0)
	_escape_result.scale = Vector2.ONE * ui_scale
	_escape_result.position = Vector2((physical.x - result_w) * 0.5, (physical.y - result_h) * 0.5) * ui_scale
	_escape_result.size = Vector2(result_w, result_h)
	_escape_result_title.position = Vector2(18.0, 22.0)
	_escape_result_title.size = Vector2(result_w - 36.0, 46.0)
	_escape_result_body.position = Vector2(24.0, 72.0)
	_escape_result_body.size = Vector2(result_w - 48.0, 86.0)
	_escape_result_return.position = Vector2(64.0, result_h - 62.0)
	_escape_result_return.size = Vector2(result_w - 128.0, 44.0)
