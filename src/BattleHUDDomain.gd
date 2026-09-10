extends "res://src/BattleHUD.gd"

const TurnOrderHUDScript = preload("res://src/ui/NavigableTurnOrderHUD.gd")
const BattleTopBarScript = preload("res://src/ui/BattleTopBar.gd")
const CombatOverlayScript = preload("res://src/ui/CombatOverlayHUD.gd")
const JOYPAD_NAV_REPEAT_MS := 135

var _turn_order_hud: Control = null
var _top_bar: Control = null
var _combat_overlay: Control = null
var _menu_focus_before_timeline: Control = null
var _last_joypad_nav_ms := 0


func _ready() -> void:
	super._ready()
	_rewire_combat_controls()
	_configure_end_turn_command()
	_remove_command_footer_hint()
	_connect_navigation_cleanup()

	_top_bar = BattleTopBarScript.new()
	_top_bar.name = "BattleTopBar"
	add_child(_top_bar)
	if _top_bar.has_method("setup"):
		_top_bar.call("setup", _controller)

	_turn_order_hud = TurnOrderHUDScript.new()
	_turn_order_hud.name = "TurnOrderHUD"
	add_child(_turn_order_hud)
	if _turn_order_hud.has_method("setup"):
		_turn_order_hud.call("setup", _controller)

	_combat_overlay = CombatOverlayScript.new()
	_combat_overlay.name = "CombatOverlayHUD"
	add_child(_combat_overlay)
	if _combat_overlay.has_method("setup"):
		_combat_overlay.call("setup", _controller)
	refresh_from_controller()


# High-level navigation is captured before regular Control focus handling. This
# lets the same ui_* actions work for keyboard arrows, D-pad, and mapped stick
# directions without disturbing the existing mouse/touch behavior.
func _input(event: InputEvent) -> void:
	if _controller == null or _cached_state.is_empty():
		return

	var user_turn := bool(_cached_state.get("is_user_turn", false))
	var battle_over := bool(_cached_state.get("battle_over", false))
	if not user_turn or battle_over:
		if _is_timeline_navigation_active():
			_leave_turn_order_navigation(false)
		return

	if _is_timeline_navigation_active():
		_handle_turn_order_navigation_input(event)
		return

	var planning := bool(_cached_state.get("is_planning_move", false))
	var targeting := bool(_cached_state.get("is_targeting", false))
	if planning or targeting:
		_handle_battlefield_navigation_input(event, planning, targeting)
		return

	if _is_skill_menu_open():
		return

	# On the normal command menu, Right enters the turn timeline. Up/Down remain
	# native menu focus movement, so the command rail keeps behaving like a game
	# menu instead of a custom keyboard-only widget.
	if event.is_action_pressed("ui_right"):
		var owner := get_viewport().gui_get_focus_owner()
		if _is_command_focus(owner) and _enter_turn_order_navigation(owner):
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Numeric shortcuts are intentionally disabled while browsing the timeline;
	# Enter/A activates the highlighted timeline Digimon instead.
	if _is_timeline_navigation_active():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and _controller != null and bool(_cached_state.get("is_user_turn", false)):
			if key.physical_keycode == KEY_2 and not _attack_button.disabled:
				_attack_button.emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return
			if key.physical_keycode == KEY_3 and not _skill_button.disabled:
				_skill_button.emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return
	super._unhandled_input(event)


func _handle_turn_order_navigation_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_left"):
		_leave_turn_order_navigation(true)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		if _turn_order_hud != null and _turn_order_hud.has_method("activate_keyboard_selection"):
			_turn_order_hud.call("activate_keyboard_selection")
		get_viewport().set_input_as_handled()
		return

	var step := 0
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_focus_prev"):
		step = -1
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_focus_next"):
		step = 1
	elif event.is_action_pressed("ui_right"):
		# Right is consumed while inside the timeline so focus never falls through
		# to another Control or the battlefield by accident.
		get_viewport().set_input_as_handled()
		return
	if step == 0:
		return

	if _allow_direction_event(event):
		if _turn_order_hud != null and _turn_order_hud.has_method("navigate_keyboard"):
			_turn_order_hud.call("navigate_keyboard", step)
	get_viewport().set_input_as_handled()


func _handle_battlefield_navigation_input(event: InputEvent, planning: bool, targeting: bool) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cancel_context_from_navigation(planning, targeting)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		if planning and _controller.has_method("keyboard_confirm_move"):
			_controller.call("keyboard_confirm_move")
		elif targeting and _controller.has_method("keyboard_confirm_target"):
			_controller.call("keyboard_confirm_target")
		get_viewport().set_input_as_handled()
		return

	var direction := _direction_for_event(event)
	if direction == Vector2.ZERO:
		return
	# Even throttled stick events are consumed here; otherwise they could fall
	# through and unexpectedly focus the Back button or another UI control.
	if _allow_direction_event(event):
		if planning and _controller.has_method("keyboard_navigate_move"):
			_controller.call("keyboard_navigate_move", direction)
		elif targeting and _controller.has_method("keyboard_navigate_target"):
			_controller.call("keyboard_navigate_target", direction)
	get_viewport().set_input_as_handled()


func _direction_for_event(event: InputEvent) -> Vector2:
	if event.is_action_pressed("ui_left"):
		return Vector2.LEFT
	if event.is_action_pressed("ui_right"):
		return Vector2.RIGHT
	if event.is_action_pressed("ui_up"):
		return Vector2.UP
	if event.is_action_pressed("ui_down"):
		return Vector2.DOWN
	return Vector2.ZERO


func _allow_direction_event(event: InputEvent) -> bool:
	if not event is InputEventJoypadMotion:
		return true
	var now := Time.get_ticks_msec()
	if now - _last_joypad_nav_ms < JOYPAD_NAV_REPEAT_MS:
		return false
	_last_joypad_nav_ms = now
	return true


func _enter_turn_order_navigation(menu_focus: Control) -> bool:
	if _turn_order_hud == null or not _turn_order_hud.has_method("enter_keyboard_navigation"):
		return false
	_menu_focus_before_timeline = menu_focus
	return bool(_turn_order_hud.call("enter_keyboard_navigation"))


func _leave_turn_order_navigation(restore_menu_focus: bool) -> void:
	if _turn_order_hud != null and _turn_order_hud.has_method("exit_keyboard_navigation"):
		_turn_order_hud.call("exit_keyboard_navigation")
	var restore := _menu_focus_before_timeline
	_menu_focus_before_timeline = null
	if restore_menu_focus:
		call_deferred("_restore_command_focus", restore)


func _is_timeline_navigation_active() -> bool:
	return (
		_turn_order_hud != null
		and _turn_order_hud.has_method("is_keyboard_navigation_active")
		and bool(_turn_order_hud.call("is_keyboard_navigation_active"))
	)


func _is_command_focus(owner: Control) -> bool:
	if owner == null:
		return false
	if _primary_buttons.has(owner as Button):
		return true
	return owner == _undo_button


func _restore_command_focus(preferred: Control = null) -> void:
	if preferred != null and is_instance_valid(preferred) and preferred.visible:
		var preferred_button := preferred as Button
		if preferred_button == null or not preferred_button.disabled:
			preferred.grab_focus()
			return
	_focus_first_available()


func _cancel_context_from_navigation(planning: bool, targeting: bool) -> void:
	var focus_target: Control = _move_button
	if targeting:
		var selected_action = _cached_state.get("selected_action", {})
		var selected_id := String(selected_action.get("id", "")) if selected_action is Dictionary else ""
		focus_target = _attack_button if selected_id == "basic_attack" else _skill_button
	_on_cancel_context()
	call_deferred("_restore_command_focus", focus_target)


func _is_skill_menu_open() -> bool:
	if _combat_overlay == null:
		return false
	var panel := _combat_overlay.get_node_or_null("TechniqueMenu") as Control
	return panel != null and panel.visible


func _connect_navigation_cleanup() -> void:
	var cleanup := Callable(self, "_on_command_activated")
	for button: Button in _primary_buttons:
		if not button.pressed.is_connected(cleanup):
			button.pressed.connect(cleanup)
	if not _undo_button.pressed.is_connected(cleanup):
		_undo_button.pressed.connect(cleanup)


func _on_command_activated() -> void:
	if _is_timeline_navigation_active():
		_leave_turn_order_navigation(false)


func _rewire_combat_controls() -> void:
	if _controller == null:
		return
	# Confirm is intentionally removed from normal battle interaction. Move and
	# target choices execute on the first valid destination/target selection.
	var old_confirm := Callable(_controller, "confirm_move_path")
	if _confirm_move_button.pressed.is_connected(old_confirm):
		_confirm_move_button.pressed.disconnect(old_confirm)
	_confirm_move_button.visible = false

	var old_cancel := Callable(_controller, "cancel_move_selection")
	if _cancel_button.pressed.is_connected(old_cancel):
		_cancel_button.pressed.disconnect(old_cancel)
	_cancel_button.pressed.connect(_on_cancel_context)

	_attack_button.pressed.connect(_on_attack_pressed)
	_skill_button.pressed.connect(_on_skill_pressed)
	_attack_button.mouse_entered.connect(_on_attack_hover)
	_attack_button.mouse_exited.connect(_on_action_hover_exit)


func _configure_end_turn_command() -> void:
	_wait_button.text = "End Turn"
	_wait_button.tooltip_text = "End this Digimon's turn  [5]"
	var icon_path := "res://assets/ui/icons/end_turn.svg"
	if ResourceLoader.exists(icon_path):
		_wait_button.icon = load(icon_path) as Texture2D


func _remove_command_footer_hint() -> void:
	# Navigation is discoverable from focus/highlight behavior itself. Keeping a
	# permanent instruction sentence in the command rail only adds visual noise.
	if _nav_hint != null:
		_nav_hint.text = ""
		_nav_hint.visible = false


func _on_attack_pressed() -> void:
	if _combat_overlay != null and _combat_overlay.has_method("hide_skills"):
		_combat_overlay.call("hide_skills")
	if _controller != null and _controller.has_method("begin_basic_attack"):
		_controller.call("begin_basic_attack")


func _on_skill_pressed() -> void:
	if _combat_overlay != null and _combat_overlay.has_method("toggle_skills"):
		_combat_overlay.call("toggle_skills")


func _on_cancel_context() -> void:
	if _controller == null:
		return
	var state: Dictionary = _controller.call("get_hud_state") if _controller.has_method("get_hud_state") else {}
	if bool(state.get("is_targeting", false)) and _controller.has_method("cancel_current_action"):
		_controller.call("cancel_current_action")
	elif _controller.has_method("cancel_move_selection"):
		_controller.call("cancel_move_selection")


func _on_attack_hover() -> void:
	if _controller != null and _controller.has_method("preview_basic_attack_recovery") and not _attack_button.disabled:
		_controller.call("preview_basic_attack_recovery")


func _on_action_hover_exit() -> void:
	if _controller != null and _controller.has_method("clear_action_recovery_preview"):
		_controller.call("clear_action_recovery_preview")


func refresh_from_controller() -> void:
	super.refresh_from_controller()
	_remove_command_footer_hint()
	if _controller != null and _controller.has_method("get_hud_state"):
		var state: Dictionary = _controller.call("get_hud_state")
		_cached_state = state
		var targeting := bool(state.get("is_targeting", false))
		var planning := bool(state.get("is_planning_move", false))
		_attack_button.disabled = not bool(state.get("can_attack", false))
		_skill_button.disabled = not bool(state.get("can_skill", false))
		_defend_button.disabled = not bool(state.get("can_defend", false))
		_wait_button.disabled = not bool(state.get("can_wait", false))
		_move_button.disabled = not bool(state.get("can_move", false))

		# Context mode only needs a Back escape hatch now. A valid click/tap is the
		# action itself, so there is no second Confirm affordance to click or focus.
		_confirm_move_button.visible = false
		_confirm_move_button.disabled = true
		_cancel_button.visible = bool(state.get("is_user_turn", false)) and (planning or targeting)
		_cancel_button.disabled = false
		if planning:
			_phase_label.text = "Choose a destination"
		elif targeting:
			_phase_label.text = "Choose a target"

		var selected_action = state.get("selected_action", {})
		var selected_id := String(selected_action.get("id", "")) if selected_action is Dictionary else ""
		_set_action_selected(_move_button, planning)
		_set_action_selected(_attack_button, targeting and selected_id == "basic_attack")
		_set_action_selected(_skill_button, targeting and not selected_id.is_empty() and selected_id != "basic_attack")
		if not bool(state.get("is_user_turn", false)) and _is_timeline_navigation_active():
			_leave_turn_order_navigation(false)
		if bool(state.get("battle_over", false)):
			for button: Button in _primary_buttons:
				button.disabled = true
			_confirm_move_button.visible = false
			_cancel_button.visible = false
			_undo_button.visible = false
	if _top_bar != null and _top_bar.has_method("refresh"):
		_top_bar.call("refresh")
	if _turn_order_hud != null and _turn_order_hud.has_method("refresh"):
		_turn_order_hud.call("refresh")
	if _combat_overlay != null and _combat_overlay.has_method("refresh"):
		_combat_overlay.call("refresh")
