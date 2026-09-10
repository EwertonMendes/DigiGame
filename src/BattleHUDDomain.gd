extends "res://src/BattleHUD.gd"

const TurnOrderHUDScript = preload("res://src/TurnOrderHUD.gd")
const BattleTopBarScript = preload("res://src/ui/BattleTopBar.gd")
const CombatOverlayScript = preload("res://src/ui/CombatOverlayHUD.gd")

var _turn_order_hud: Control = null
var _top_bar: Control = null
var _combat_overlay: Control = null


func _ready() -> void:
	super._ready()
	_rewire_combat_controls()
	_configure_end_turn_command()
	_remove_command_footer_hint()

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


func _unhandled_input(event: InputEvent) -> void:
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
