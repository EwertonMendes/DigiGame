extends Control

const UI = preload("res://src/ui/TacticalTheme.gd")
const ICON_ROOT := "res://assets/ui/icons"
const PORTRAIT_ROOT := "res://assets/characters"

var _controller: Node = null
var _dock: Panel = null
var _status_panel: Panel = null
var _status_accent: ColorRect = null
var _portrait_frame: Panel = null
var _portrait: TextureRect = null
var _actor_label: Label = null
var _hp_caption: Label = null
var _sp_caption: Label = null
var _hp_bar: ProgressBar = null
var _sp_bar: ProgressBar = null
var _hp_value: Label = null
var _sp_value: Label = null
var _command_title: Label = null
var _phase_label: Label = null
var _mov_label: Label = null
var _nav_hint: Label = null
var _action_grid: GridContainer = null
var _context_row: HBoxContainer = null
var _move_button: Button = null
var _attack_button: Button = null
var _skill_button: Button = null
var _defend_button: Button = null
var _wait_button: Button = null
var _confirm_move_button: Button = null
var _undo_button: Button = null
var _cancel_button: Button = null
var _primary_buttons: Array[Button] = []
var _accent_by_button: Dictionary = {}
var _last_actor_key := ""
var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2i.ZERO
var _cached_state: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_controller = get_node_or_null("../../BattleController")
	_refresh_connections()
	get_viewport().size_changed.connect(_layout_dock)
	set_process(true)
	refresh_from_controller()
	call_deferred("_layout_dock")


func _process(_delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		_layout_dock()


func _unhandled_input(event: InputEvent) -> void:
	if _controller == null or not bool(_cached_state.get("is_user_turn", false)):
		return

	if event.is_action_pressed("ui_cancel") and _context_row != null and _context_row.visible:
		if not _cancel_button.disabled:
			_cancel_button.emit_signal("pressed")
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_focus_next"):
		var owner := get_viewport().gui_get_focus_owner()
		if not _is_our_focus(owner):
			_focus_first_available()
			get_viewport().set_input_as_handled()
			return

	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1:
			if not _move_button.disabled:
				_move_button.emit_signal("pressed")
				get_viewport().set_input_as_handled()
		KEY_4:
			if not _defend_button.disabled:
				_defend_button.emit_signal("pressed")
				get_viewport().set_input_as_handled()
		KEY_5:
			if not _wait_button.disabled:
				_wait_button.emit_signal("pressed")
				get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_build_status_panel()
	_build_command_panel()


func _build_status_panel() -> void:
	_status_panel = Panel.new()
	_status_panel.name = "ActiveUnitStatus"
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_theme_stylebox_override("panel", UI.glass_panel(UI.GOLD, 0.76, 7))
	add_child(_status_panel)

	_status_accent = ColorRect.new()
	_status_accent.color = UI.GOLD
	_status_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_child(_status_accent)

	_portrait_frame = Panel.new()
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_theme_stylebox_override("panel", UI.turn_node_style(UI.GOLD, true))
	_status_panel.add_child(_portrait_frame)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)

	_actor_label = _label("Digimon  Lv. 1", 18, UI.TEXT, true)
	_status_panel.add_child(_actor_label)
	_hp_caption = _label("HP", 14, UI.GREEN, true)
	_sp_caption = _label("SP", 14, UI.BLUE, true)
	_hp_value = _label("0/0", 14, UI.TEXT)
	_sp_value = _label("0/0", 14, UI.TEXT)
	_hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_panel.add_child(_hp_caption)
	_status_panel.add_child(_sp_caption)
	_status_panel.add_child(_hp_value)
	_status_panel.add_child(_sp_value)

	_hp_bar = _resource_bar(UI.GREEN)
	_sp_bar = _resource_bar(UI.BLUE)
	_status_panel.add_child(_hp_bar)
	_status_panel.add_child(_sp_bar)


func _build_command_panel() -> void:
	_dock = Panel.new()
	_dock.name = "CommandRail"
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_theme_stylebox_override("panel", UI.glass_panel(UI.GOLD, 0.70, 6))
	add_child(_dock)

	_command_title = _label("COMMAND", 13, UI.GOLD, true)
	_dock.add_child(_command_title)

	_phase_label = _label("Choose an action", 14, UI.MUTED)
	_phase_label.clip_text = true
	_dock.add_child(_phase_label)

	_mov_label = _label("4 MOV", 13, UI.TEXT, true)
	_mov_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mov_label.add_theme_stylebox_override("normal", UI.pill(UI.GOLD, 0.11))
	_dock.add_child(_mov_label)

	_action_grid = GridContainer.new()
	_action_grid.name = "PrimaryActions"
	_action_grid.columns = 1
	_action_grid.add_theme_constant_override("h_separation", 6)
	_action_grid.add_theme_constant_override("v_separation", 3)
	_action_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_action_grid)

	_move_button = _make_action_button("Move", "move.svg", "1", "Plan movement")
	_attack_button = _make_action_button("Attack", "attack.svg", "2", "Use a basic attack")
	_skill_button = _make_action_button("Skill", "skill.svg", "3", "Choose a technique")
	_defend_button = _make_action_button("Defend", "defend.svg", "4", "Defend and end this Digimon's turn")
	_wait_button = _make_action_button("Wait", "wait.svg", "5", "End this Digimon's turn")
	_primary_buttons = [_move_button, _attack_button, _skill_button, _defend_button, _wait_button]
	for button: Button in _primary_buttons:
		_action_grid.add_child(button)

	_undo_button = _make_action_button("Undo", "undo.svg", "Z", "Undo the committed move")
	_action_grid.add_child(_undo_button)

	_context_row = HBoxContainer.new()
	_context_row.name = "ContextActions"
	_context_row.add_theme_constant_override("separation", 6)
	_context_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_context_row)

	_cancel_button = _make_context_button("Back", "cancel.svg", UI.RED)
	_confirm_move_button = _make_context_button("Confirm", "confirm.svg", UI.GOLD)
	_context_row.add_child(_cancel_button)
	_context_row.add_child(_confirm_move_button)

	_nav_hint = _label("Arrows / D-pad  Navigate   •   Enter / A  Select", 11, UI.SUBTLE)
	_nav_hint.clip_text = true
	_dock.add_child(_nav_hint)


func _label(text_value: String, size: int, color: Color, heading: bool = false) -> Label:
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


func _resource_bar(accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.05, 0.05, 0.72)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _make_action_button(label_text: String, icon_name: String, shortcut: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = "%sAction" % label_text.replace(" ", "")
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s  [%s]" % [tooltip, shortcut]
	button.icon = load("%s/%s" % [ICON_ROOT, icon_name]) as Texture2D
	button.expand_icon = true
	button.icon_max_width = 22
	UI.apply_heading_font(button)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.60, 0.59, 0.50))
	button.add_theme_color_override("icon_normal_color", Color(0.90, 0.94, 0.92, 0.92))
	button.add_theme_color_override("icon_hover_color", UI.GOLD)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_color_override("icon_focus_color", UI.GOLD)
	button.add_theme_color_override("icon_disabled_color", Color(0.45, 0.50, 0.49, 0.42))
	button.add_theme_stylebox_override("normal", UI.command_style(UI.GOLD, "normal"))
	button.add_theme_stylebox_override("hover", UI.command_style(UI.GOLD, "hover"))
	button.add_theme_stylebox_override("pressed", UI.command_style(UI.GOLD, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.command_style(UI.GOLD, "disabled"))
	button.add_theme_stylebox_override("focus", UI.focus_outline(UI.GOLD, 7))
	_add_shortcut_hint(button, shortcut)
	button.mouse_entered.connect(Callable(self, "_on_action_hover").bind(button, true))
	button.mouse_exited.connect(Callable(self, "_on_action_hover").bind(button, false))
	button.focus_entered.connect(Callable(self, "_on_action_focus").bind(button, true))
	button.focus_exited.connect(Callable(self, "_on_action_focus").bind(button, false))
	button.button_down.connect(Callable(self, "_on_action_pressed_visual").bind(button))
	_accent_by_button[button] = UI.GOLD
	return button


func _add_shortcut_hint(button: Button, shortcut: String) -> void:
	var hint := Label.new()
	hint.text = shortcut
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color", UI.SUBTLE)
	hint.add_theme_font_size_override("font_size", 11)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 0.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -34.0
	hint.offset_right = -7.0
	button.add_child(hint)


func _make_context_button(label_text: String, icon_name: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = label_text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.icon = load("%s/%s" % [ICON_ROOT, icon_name]) as Texture2D
	button.expand_icon = true
	button.icon_max_width = 18
	UI.apply_heading_font(button)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("icon_normal_color", accent)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UI.command_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.command_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.command_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.command_style(accent, "disabled"))
	button.add_theme_stylebox_override("focus", UI.focus_outline(accent, 7))
	return button


func _refresh_connections() -> void:
	if _controller == null:
		return
	_move_button.pressed.connect(Callable(_controller, "begin_move_selection"))
	_confirm_move_button.pressed.connect(Callable(_controller, "confirm_move_path"))
	_defend_button.pressed.connect(Callable(_controller, "defend_current"))
	_wait_button.pressed.connect(Callable(_controller, "wait_current"))
	_undo_button.pressed.connect(Callable(_controller, "undo_move"))
	_cancel_button.pressed.connect(Callable(_controller, "cancel_move_selection"))


func refresh_from_controller() -> void:
	if _controller == null:
		_controller = get_node_or_null("../../BattleController")
	if _controller == null or not _controller.has_method("get_hud_state"):
		_status_panel.visible = false
		_dock.visible = false
		return

	var state: Dictionary = _controller.call("get_hud_state")
	_cached_state = state
	_status_panel.visible = true
	var actor := _controller.get("current_actor") as Node
	var actor_key := ""
	var player_team := true
	if actor != null:
		actor_key = String(actor.get("digimon_key")).to_lower()
		player_team = bool(actor.get("is_player_controlled"))
	_update_unit_summary(actor, state)

	var planning := bool(state.get("is_planning_move", false))
	var targeting := bool(state.get("is_targeting", false))
	_phase_label.text = _phase_copy(state)
	_mov_label.text = "%d MOV" % int(state.get("move_remaining", 0)) if planning else "%d MOV" % int(state.get("mov", 4))

	_move_button.disabled = not bool(state.get("can_move", false))
	_attack_button.disabled = not bool(state.get("can_attack", false)) if state.has("can_attack") else true
	_skill_button.disabled = not bool(state.get("can_skill", false)) if state.has("can_skill") else true
	_defend_button.disabled = not bool(state.get("can_defend", false))
	_wait_button.disabled = not bool(state.get("can_wait", false))
	_confirm_move_button.disabled = not bool(state.get("can_confirm_move", false))
	_undo_button.visible = bool(state.get("can_undo", false))
	_cancel_button.disabled = false

	_set_action_selected(_move_button, planning)
	_status_accent.color = UI.GOLD if player_team else UI.RED
	_status_panel.add_theme_stylebox_override("panel", UI.glass_panel(UI.GOLD if player_team else UI.RED, 0.76, 7))
	_portrait_frame.add_theme_stylebox_override("panel", UI.turn_node_style(UI.GOLD if player_team else UI.RED, true))
	_apply_interaction_mode(state)

	if actor_key != _last_actor_key:
		_last_actor_key = actor_key
		_portrait.texture = _load_portrait(actor_key)
		_animate_actor_change()
	_layout_dock()


func _update_unit_summary(actor: Node, state: Dictionary) -> void:
	var actor_name := String(state.get("actor_name", "Digimon"))
	var level := int(state.get("level", 1))
	_actor_label.text = "%s   Lv.%d" % [actor_name, level]
	if actor == null:
		_hp_bar.max_value = 1
		_hp_bar.value = 0
		_sp_bar.max_value = 1
		_sp_bar.value = 0
		_hp_value.text = "—"
		_sp_value.text = "—"
		return

	var max_hp := maxi(1, int(actor.call("get_final_stat", "hp"))) if actor.has_method("get_final_stat") else 1
	var current_hp := max_hp
	if actor.has_method("get_current_hp"):
		current_hp = int(actor.call("get_current_hp"))
	else:
		var battle_state = actor.get("battle_state")
		if battle_state != null:
			current_hp = int(battle_state.get("current_hp"))

	var max_sp := int(state.get("max_sp", 0))
	if max_sp <= 0 and actor.has_method("get_final_stat"):
		max_sp = int(actor.call("get_final_stat", "mp"))
	max_sp = maxi(1, max_sp)
	var current_sp := int(state.get("current_sp", max_sp))
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(current_hp, 0, max_hp)
	_sp_bar.max_value = max_sp
	_sp_bar.value = clampi(current_sp, 0, max_sp)
	_hp_value.text = "%d/%d" % [current_hp, max_hp]
	_sp_value.text = "%d/%d" % [current_sp, max_sp]


func _apply_interaction_mode(state: Dictionary) -> void:
	var user_turn := bool(state.get("is_user_turn", false))
	var planning := bool(state.get("is_planning_move", false))
	var targeting := bool(state.get("is_targeting", false))
	var battle_over := bool(state.get("battle_over", false))
	var contextual := user_turn and (planning or targeting) and not battle_over
	_dock.visible = not battle_over
	_action_grid.visible = user_turn and not contextual
	_context_row.visible = contextual
	_mov_label.visible = user_turn and not targeting and not battle_over
	_nav_hint.visible = user_turn and not battle_over
	if contextual:
		_command_title.text = "TARGET" if targeting else "MOVEMENT"
	elif user_turn:
		_command_title.text = "COMMAND"
	else:
		_command_title.text = "ENEMY TURN"
	_dock.modulate = Color.WHITE if user_turn else Color(0.88, 0.92, 0.90, 0.82)


func _set_action_selected(button: Button, selected: bool) -> void:
	var accent: Color = _accent_by_button.get(button, UI.GOLD)
	button.add_theme_stylebox_override("normal", UI.command_style(accent, "selected" if selected else "normal"))


func _phase_copy(state: Dictionary) -> String:
	var raw_phase := String(state.get("phase", ""))
	if not bool(state.get("is_user_turn", false)):
		return "Opponent is acting"
	if bool(state.get("is_targeting", false)):
		return "Choose a target"
	match raw_phase:
		"Turn Start": return "Preparing turn"
		"Choose an action": return "Choose an action"
		"Preview movement": return "Trace a route, then confirm"
		"Plan movement": return "Trace a route, then confirm"
		"Moving": return "Moving"
		"Resolving action": return "Resolving action"
		"Turn End": return "Ending turn"
	return raw_phase


func _layout_dock() -> void:
	if _dock == null or _status_panel == null:
		return
	var viewport_obj := get_viewport()
	var logical := viewport_obj.get_visible_rect().size
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var compact := UI.is_compact(viewport_obj, 820.0)
	var portrait_mobile := compact and physical.y > physical.x
	var short_landscape := compact and physical.x > physical.y
	var user_turn := bool(_cached_state.get("is_user_turn", false))
	var contextual := _context_row.visible

	_status_panel.scale = Vector2.ONE * ui_scale
	_dock.scale = Vector2.ONE * ui_scale

	if portrait_mobile:
		var margin := 10.0
		var status_w := physical.x - margin * 2.0
		_status_panel.position = Vector2(margin * ui_scale, 132.0 * ui_scale)
		_status_panel.size = Vector2(status_w, 88.0)
		_layout_status(Vector2(status_w, 88.0), true)

		var dock_w := status_w
		var dock_h := 184.0 if user_turn and not contextual else (116.0 if contextual else 78.0)
		if physical.x < 330.0 and user_turn and not contextual:
			dock_h = 230.0
		_dock.position = Vector2(margin * ui_scale, (physical.y - dock_h - margin) * ui_scale)
		_dock.size = Vector2(dock_w, dock_h)
		_action_grid.columns = 2 if physical.x < 330.0 else 3
		_layout_command(Vector2(dock_w, dock_h), true, contextual, user_turn)
	elif short_landscape:
		var margin := 8.0
		var status_w := minf(244.0, physical.x * 0.30)
		_status_panel.position = Vector2(margin * ui_scale, 56.0 * ui_scale)
		_status_panel.size = Vector2(status_w, 78.0)
		_layout_status(Vector2(status_w, 78.0), true)

		var dock_w := minf(300.0, physical.x * 0.37)
		var available_h := maxf(150.0, physical.y - 144.0)
		var dock_h := minf(238.0, available_h)
		if contextual:
			dock_h = minf(118.0, available_h)
		elif not user_turn:
			dock_h = 70.0
		_dock.position = Vector2(margin * ui_scale, 140.0 * ui_scale)
		_dock.size = Vector2(dock_w, dock_h)
		_action_grid.columns = 2
		_layout_command(Vector2(dock_w, dock_h), true, contextual, user_turn)
	else:
		var margin := 16.0
		var status_w := 306.0
		var status_h := 112.0
		_status_panel.position = Vector2(margin * ui_scale, 68.0 * ui_scale)
		_status_panel.size = Vector2(status_w, status_h)
		_layout_status(Vector2(status_w, status_h), false)

		var dock_w := 242.0
		var dock_h := 320.0 if user_turn and not contextual else (132.0 if contextual else 76.0)
		_dock.position = Vector2(margin * ui_scale, 192.0 * ui_scale)
		_dock.size = Vector2(dock_w, dock_h)
		_action_grid.columns = 1
		_layout_command(Vector2(dock_w, dock_h), false, contextual, user_turn)


func _layout_status(panel_size: Vector2, compact: bool) -> void:
	var pad := 10.0 if compact else 12.0
	var portrait_side := 56.0 if compact else 68.0
	_status_accent.position = Vector2(0.0, 10.0)
	_status_accent.size = Vector2(3.0, panel_size.y - 20.0)
	_portrait_frame.position = Vector2(pad, (panel_size.y - portrait_side) * 0.5)
	_portrait_frame.size = Vector2(portrait_side, portrait_side)
	_portrait.position = Vector2(4.0, 4.0)
	_portrait.size = Vector2(portrait_side - 8.0, portrait_side - 8.0)

	var info_x := pad + portrait_side + 10.0
	var info_w := panel_size.x - info_x - pad
	_actor_label.position = Vector2(info_x, 8.0 if compact else 10.0)
	_actor_label.size = Vector2(info_w, 25.0)
	_actor_label.add_theme_font_size_override("font_size", 16 if compact else 18)

	var row_h := 22.0
	var first_y := 35.0 if compact else 43.0
	var caption_w := 24.0
	var value_w := 62.0
	var bar_x := info_x + caption_w + 5.0
	var bar_w := maxf(46.0, info_w - caption_w - value_w - 10.0)
	_hp_caption.position = Vector2(info_x, first_y)
	_hp_caption.size = Vector2(caption_w, row_h)
	_hp_bar.position = Vector2(bar_x, first_y + 7.0)
	_hp_bar.size = Vector2(bar_w, 8.0)
	_hp_value.position = Vector2(panel_size.x - pad - value_w, first_y)
	_hp_value.size = Vector2(value_w, row_h)
	_sp_caption.position = Vector2(info_x, first_y + row_h)
	_sp_caption.size = Vector2(caption_w, row_h)
	_sp_bar.position = Vector2(bar_x, first_y + row_h + 7.0)
	_sp_bar.size = Vector2(bar_w, 8.0)
	_sp_value.position = Vector2(panel_size.x - pad - value_w, first_y + row_h)
	_sp_value.size = Vector2(value_w, row_h)
	for label: Label in [_hp_caption, _sp_caption, _hp_value, _sp_value]:
		label.add_theme_font_size_override("font_size", 12 if compact else 14)


func _layout_command(panel_size: Vector2, compact: bool, contextual: bool, user_turn: bool) -> void:
	var pad := 10.0
	_command_title.position = Vector2(pad + 3.0, 7.0)
	_command_title.size = Vector2(panel_size.x - pad * 2.0 - 72.0, 21.0)
	_command_title.add_theme_font_size_override("font_size", 12 if compact else 13)
	_phase_label.position = Vector2(pad + 3.0, 28.0)
	_phase_label.size = Vector2(panel_size.x - pad * 2.0 - (74.0 if _mov_label.visible else 0.0), 24.0)
	_phase_label.add_theme_font_size_override("font_size", 12 if compact else 14)
	_mov_label.position = Vector2(panel_size.x - 72.0, 27.0)
	_mov_label.size = Vector2(62.0, 24.0)
	_mov_label.add_theme_font_size_override("font_size", 11 if compact else 12)

	if not user_turn:
		_phase_label.position = Vector2(pad + 3.0, 30.0)
		_phase_label.size = Vector2(panel_size.x - pad * 2.0, 28.0)
		_nav_hint.visible = false
		return

	if contextual:
		_context_row.position = Vector2(pad, 58.0)
		_context_row.size = Vector2(panel_size.x - pad * 2.0, 48.0)
		for button: Button in [_cancel_button, _confirm_move_button]:
			button.custom_minimum_size = Vector2(0.0, 44.0)
			button.add_theme_font_size_override("font_size", 13 if compact else 15)
		_nav_hint.position = Vector2(pad + 3.0, maxf(0.0, panel_size.y - 24.0))
		_nav_hint.size = Vector2(panel_size.x - pad * 2.0, 18.0)
		_nav_hint.text = "Esc / B  Back   •   Enter / A  Confirm"
		_nav_hint.add_theme_font_size_override("font_size", 9 if compact else 10)
		return

	var nav_h := 22.0
	var grid_y := 58.0
	var grid_h := maxf(50.0, panel_size.y - grid_y - nav_h - 7.0)
	_action_grid.position = Vector2(pad, grid_y)
	_action_grid.size = Vector2(panel_size.x - pad * 2.0, grid_h)
	_action_grid.add_theme_constant_override("h_separation", 5 if compact else 6)
	_action_grid.add_theme_constant_override("v_separation", 3)
	var button_h := 44.0
	if _action_grid.columns == 1:
		button_h = 45.0 if compact else 47.0
	else:
		button_h = 47.0
	for button: Button in _primary_buttons:
		button.custom_minimum_size = Vector2(0.0, button_h)
		button.icon_max_width = 19 if compact else 22
		button.add_theme_font_size_override("font_size", 13 if compact else 16)
	_undo_button.custom_minimum_size = Vector2(0.0, button_h)
	_undo_button.icon_max_width = 18 if compact else 20
	_undo_button.add_theme_font_size_override("font_size", 13 if compact else 15)
	_nav_hint.position = Vector2(pad + 3.0, panel_size.y - nav_h - 3.0)
	_nav_hint.size = Vector2(panel_size.x - pad * 2.0, nav_h)
	_nav_hint.text = "D-pad / Arrows  Navigate   •   A / Enter  Select"
	_nav_hint.add_theme_font_size_override("font_size", 9 if compact else 10)


func _load_portrait(digimon_key: String) -> Texture2D:
	if digimon_key.is_empty():
		return null
	var metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]
	var strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(strip_path):
		return null
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary:
		return null
	var strip := load(strip_path) as Texture2D
	if strip == null:
		return null
	var frame_width := float(metadata.get("frame_width", 0))
	var frame_height := float(metadata.get("frame_height", 0))
	if frame_width <= 0.0 or frame_height <= 0.0:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = strip
	atlas.region = Rect2(0.0, 0.0, frame_width, frame_height)
	return atlas


func _is_our_focus(owner: Control) -> bool:
	if owner == null:
		return false
	if _primary_buttons.has(owner as Button):
		return true
	return owner == _undo_button or owner == _cancel_button or owner == _confirm_move_button


func _focus_first_available() -> void:
	if _context_row.visible:
		if not _confirm_move_button.disabled and _confirm_move_button.visible:
			_confirm_move_button.grab_focus()
		elif not _cancel_button.disabled and _cancel_button.visible:
			_cancel_button.grab_focus()
		return
	for button: Button in _primary_buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			return
	if _undo_button.visible and not _undo_button.disabled:
		_undo_button.grab_focus()


func _animate_actor_change() -> void:
	if _status_panel == null:
		return
	_status_panel.modulate.a = 0.56
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_status_panel, "modulate:a", 1.0, 0.16)


func _on_action_hover(button: Button, entered: bool) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.012, 1.012) if entered else Vector2.ONE, 0.08)


func _on_action_focus(button: Button, focused: bool) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.012, 1.012) if focused else Vector2.ONE, 0.08)


func _on_action_pressed_visual(button: Button) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.985, 0.985)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.10)
