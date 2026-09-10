extends Control

const UI = preload("res://src/ui/TacticalTheme.gd")
const ICON_ROOT := "res://assets/ui/icons"
const ACTION_GAP := 7.0

var _controller: Node = null
var _dock: Panel = null
var _phase_label: Label = null
var _mov_label: Label = null
var _actor_label: Label = null
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
	var viewport := get_viewport().get_visible_rect().size
	if viewport != _last_viewport_size:
		_layout_dock()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or _controller == null:
		return
	if not bool(_cached_state.get("is_user_turn", false)):
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
	_dock = Panel.new()
	_dock.name = "ActionDock"
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.93, 0.42, 10, 10))
	add_child(_dock)

	_actor_label = Label.new()
	_actor_label.add_theme_font_size_override("font_size", 9)
	_actor_label.add_theme_color_override("font_color", UI.MUTED)
	_actor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dock.add_child(_actor_label)

	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 10)
	_phase_label.add_theme_color_override("font_color", Color(0.72, 0.87, 0.95, 1.0))
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.clip_text = true
	_dock.add_child(_phase_label)

	_mov_label = Label.new()
	_mov_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mov_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mov_label.add_theme_font_size_override("font_size", 9)
	_mov_label.add_theme_color_override("font_color", UI.TEXT)
	_mov_label.add_theme_stylebox_override("normal", UI.pill(UI.CYAN, 0.12))
	_mov_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_mov_label)

	_move_button = _make_action_button("MOVE", "move.svg", UI.CYAN, "1", "Plan movement")
	_attack_button = _make_action_button("ATTACK", "attack.svg", UI.RED, "2", "Basic attacks are coming with the battle system")
	_skill_button = _make_action_button("SKILL", "skill.svg", UI.PURPLE, "3", "Digimon skills are coming with the battle system")
	_defend_button = _make_action_button("DEFEND", "defend.svg", UI.BLUE, "4", "Defend and end this Digimon's turn")
	_wait_button = _make_action_button("WAIT", "wait.svg", UI.GOLD, "5", "End this Digimon's turn")
	_primary_buttons = [_move_button, _attack_button, _skill_button, _defend_button, _wait_button]
	for button in _primary_buttons:
		_dock.add_child(button)

	_confirm_move_button = _make_context_button("CONFIRM", "confirm.svg", UI.GREEN)
	_undo_button = _make_context_button("UNDO", "undo.svg", UI.GOLD)
	_cancel_button = _make_context_button("CANCEL", "cancel.svg", UI.RED)
	for button in [_confirm_move_button, _undo_button, _cancel_button]:
		_dock.add_child(button)


func _make_action_button(label_text: String, icon_name: String, accent: Color, shortcut: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s  [%s]" % [tooltip, shortcut]
	button.icon = load("%s/%s" % [ICON_ROOT, icon_name]) as Texture2D
	button.expand_icon = true
	button.icon_max_width = 23
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.54, 0.60, 0.58))
	button.add_theme_color_override("icon_normal_color", accent)
	button.add_theme_color_override("icon_hover_color", accent.lightened(0.20))
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_color_override("icon_disabled_color", Color(0.43, 0.50, 0.54, 0.45))
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.action_style(accent, "disabled"))
	button.mouse_entered.connect(Callable(self, "_on_action_hover").bind(button, true))
	button.mouse_exited.connect(Callable(self, "_on_action_hover").bind(button, false))
	button.button_down.connect(Callable(self, "_on_action_pressed_visual").bind(button))
	_accent_by_button[button] = accent
	return button


func _make_context_button(label_text: String, icon_name: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = label_text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.icon = load("%s/%s" % [ICON_ROOT, icon_name]) as Texture2D
	button.expand_icon = true
	button.icon_max_width = 14
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("icon_normal_color", accent)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.action_style(accent, "disabled"))
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
		_dock.visible = false
		return

	var state: Dictionary = _controller.call("get_hud_state")
	_cached_state = state
	_dock.visible = true
	var actor: Node = _controller.get("current_actor") as Node
	var actor_key := ""
	var player_team := true
	if actor != null:
		actor_key = String(actor.get("digimon_key")).to_lower()
		player_team = bool(actor.get("is_player_controlled"))

	var actor_name := String(state.get("actor_name", "DIGIMON")).to_upper()
	var level := int(state.get("level", 1))
	_actor_label.text = "%s  //  LV %d" % [actor_name, level]
	_phase_label.text = _phase_copy(state)
	var planning := bool(state.get("is_planning_move", false))
	_mov_label.text = "MOV %d LEFT" % int(state.get("move_remaining", 0)) if planning else "MOV %d" % int(state.get("mov", 4))
	_mov_label.add_theme_stylebox_override("normal", UI.pill(UI.CYAN if player_team else UI.RED, 0.12))

	var user_turn := bool(state.get("is_user_turn", false))
	_move_button.disabled = not bool(state.get("can_move", false))
	_attack_button.disabled = true
	_skill_button.disabled = true
	_defend_button.disabled = not bool(state.get("can_defend", false))
	_wait_button.disabled = not bool(state.get("can_wait", false))
	_confirm_move_button.visible = planning and user_turn
	_confirm_move_button.disabled = not bool(state.get("can_confirm_move", false))
	_undo_button.visible = bool(state.get("can_undo", false))
	_cancel_button.visible = bool(state.get("can_cancel", false))

	_set_action_selected(_move_button, planning)
	_dock.modulate = Color.WHITE if user_turn else Color(0.78, 0.84, 0.88, 0.72)

	if actor_key != _last_actor_key:
		_last_actor_key = actor_key
		_animate_actor_change()
	_layout_dock()


func _set_action_selected(button: Button, selected: bool) -> void:
	var accent: Color = _accent_by_button.get(button, UI.CYAN)
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "selected" if selected else "normal"))


func _phase_copy(state: Dictionary) -> String:
	var raw_phase := String(state.get("phase", ""))
	if not bool(state.get("is_user_turn", false)):
		return "OPPONENT TURN  •  timeline advances only after actions resolve"
	match raw_phase:
		"Turn Start": return "PREPARING TURN"
		"Choose an action": return "SELECT AN ACTION"
		"Preview movement": return "POINT TO PREVIEW  •  TAP/CLICK TO LOCK  •  DRAG TO TRACE"
		"Plan movement": return "TRACE A ROUTE  •  CONFIRM WHEN READY"
		"Moving": return "FOLLOWING ROUTE"
		"Choose a target": return "SELECT A TARGET"
		"Resolving action": return "RESOLVING ACTION"
		"Turn End": return "ENDING TURN"
	return raw_phase.to_upper()


func _layout_dock() -> void:
	if _dock == null:
		return
	var viewport := get_viewport().get_visible_rect().size
	_last_viewport_size = viewport
	var compact := viewport.x < 760.0
	var side_margin := 10.0 if compact else 18.0
	var width := minf(720.0, viewport.x - side_margin * 2.0)
	var height := 102.0 if compact else 108.0
	_dock.position = Vector2((viewport.x - width) * 0.5, viewport.y - height - (8.0 if compact else 14.0))
	_dock.size = Vector2(width, height)

	var inner_x := 10.0
	var action_y := 10.0
	var action_h := 58.0 if not compact else 54.0
	var action_width := (width - inner_x * 2.0 - ACTION_GAP * 4.0) / 5.0
	for index in range(_primary_buttons.size()):
		var button := _primary_buttons[index]
		button.position = Vector2(inner_x + float(index) * (action_width + ACTION_GAP), action_y)
		button.size = Vector2(action_width, action_h)
		button.icon_max_width = 23 if not compact else 19
		button.add_theme_font_size_override("font_size", 10 if not compact else 8)

	var bottom_y := action_y + action_h + 7.0
	_actor_label.position = Vector2(inner_x, bottom_y)
	_actor_label.size = Vector2(150.0 if not compact else 105.0, 20.0)
	_actor_label.add_theme_font_size_override("font_size", 9 if not compact else 7)
	_mov_label.size = Vector2(78.0 if not compact else 66.0, 22.0)
	_mov_label.position = Vector2(width - inner_x - _mov_label.size.x, bottom_y - 1.0)

	var context_buttons: Array[Button] = [_confirm_move_button, _undo_button, _cancel_button]
	var visible_context: Array[Button] = []
	for button in context_buttons:
		if button.visible:
			visible_context.append(button)
	var context_w := 72.0 if not compact else 58.0
	var context_gap := 5.0
	var context_total := float(visible_context.size()) * context_w + maxf(0.0, float(visible_context.size() - 1)) * context_gap
	var context_start := width - inner_x - _mov_label.size.x - 8.0 - context_total
	for index in range(visible_context.size()):
		var button := visible_context[index]
		button.position = Vector2(context_start + float(index) * (context_w + context_gap), bottom_y - 1.0)
		button.size = Vector2(context_w, 22.0)
		button.add_theme_font_size_override("font_size", 7 if compact else 8)

	var phase_left := _actor_label.position.x + _actor_label.size.x + 8.0
	var phase_right := context_start - 8.0 if not visible_context.is_empty() else _mov_label.position.x - 8.0
	_phase_label.position = Vector2(phase_left, bottom_y)
	_phase_label.size = Vector2(maxf(20.0, phase_right - phase_left), 20.0)
	_phase_label.add_theme_font_size_override("font_size", 8 if compact else 10)


func _animate_actor_change() -> void:
	_dock.modulate.a = 0.45
	_dock.position.y += 8.0
	var target_y := _dock.position.y - 8.0
	var target_alpha := 1.0 if bool(_cached_state.get("is_user_turn", false)) else 0.72
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dock, "modulate:a", target_alpha, 0.18)
	tween.tween_property(_dock, "position:y", target_y, 0.18)


func _on_action_hover(button: Button, entered: bool) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.025, 1.025) if entered else Vector2.ONE, 0.09)
	tween.tween_property(button, "position:y", button.position.y - 2.0 if entered else 10.0, 0.09)


func _on_action_pressed_visual(button: Button) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.98, 0.98)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.10)
