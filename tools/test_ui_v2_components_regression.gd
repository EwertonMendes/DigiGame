extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")
const GlassPanelScript = preload("res://src/ui/components/DigiGlassPanel.gd")
const InteractionPromptScript = preload("res://src/ui/components/DigiInteractionPrompt.gd")
const ConfirmationModalScript = preload("res://src/ui/components/DigiConfirmationModal.gd")


func _ready() -> void:
	var glass := GlassPanelScript.new() as PanelContainer
	add_child(glass)
	glass.call("configure_glass", DigiUiTheme.CYAN, "floating", Vector4.ZERO, 10)
	await _frames(2)
	var glass_style := glass.get_theme_stylebox("panel") as StyleBoxFlat
	if not _check(glass.has_meta("digi_glass_surface") and glass_style != null, "Glass surface must be reusable as a standalone V2 component"):
		return
	if not _check(glass_style.bg_color.a < 0.90 and glass_style.bg_color.a > 0.50, "Glass surface must stay translucent without sacrificing readability"):
		return
	glass.queue_free()

	var prompt := InteractionPromptScript.new() as DigiInteractionPrompt
	add_child(prompt)
	await _frames(2)
	prompt.set_action("Open DigiLab")
	if not _check(prompt.get_action_label() != null and prompt.get_action_label().text == "OPEN DIGILAB", "Interaction prompt must separate the action from the input badge"):
		return
	if not _check(prompt.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET, "Interaction prompt must keep a touch-safe height"):
		return
	if not _check(prompt.has_meta("digi_glass_surface"), "Interaction prompt must use the shared glass surface instead of a duplicated local style"):
		return
	var joy := InputEventJoypadButton.new()
	joy.device = 0
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	prompt.call("_input", joy)
	if not _check(prompt.get_key_text() == "A", "Interaction prompt must adapt to gamepad input"):
		return

	var modal := ConfirmationModalScript.new() as DigiConfirmationModal
	add_child(modal)
	await _frames(2)
	modal.configure("DELETE SAVE?", "This is only a regression prompt.", "YES", "NO", DigiUiTheme.RED, "CONFIRM")
	modal.open_dialog()
	await _frames(2)
	if not _check(modal.visible, "Confirmation modal must open as a blocking overlay"):
		return
	if not _check(modal.get_panel().has_meta("digi_glass_surface"), "Confirmation modal must compose the shared glass surface"):
		return
	if not _check(get_viewport().gui_get_focus_owner() == modal.get_cancel_button(), "Confirmation modal must focus the safe cancel action by default"):
		return
	if not _check(modal.get_confirm_button().custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET and modal.get_cancel_button().custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET, "Confirmation actions must be touch-safe"):
		return
	modal.close_dialog(false)
	modal.queue_free()
	prompt.queue_free()
	await _frames(2)

	var hub: Node = HUB_SCENE.instantiate()
	add_child(hub)
	await _frames(5)
	var hub_prompt := hub.find_child("InteractionPrompt", true, false)
	if not _check(hub_prompt is DigiInteractionPrompt, "Hub must use the shared Digi UI V2 interaction prompt"):
		return
	var player := hub.get("_player") as Node2D
	var operator := hub.get("_operator") as Node2D
	if not _check(player != null and operator != null, "Hub regression requires player and Battle Operator"):
		return
	player.position = operator.position + Vector2(18.0, 18.0)
	hub.call("_refresh_interaction")
	hub.call("open_test_battle_dialog")
	await _frames(3)
	var battle_dialog := hub.find_child("BattleDialog", true, false) as Control
	var cancel := hub.find_child("CancelBattleDialog", true, false) as Button
	var start := hub.find_child("StartBattle", true, false) as Button
	if not _check(battle_dialog != null and battle_dialog.visible, "Battle Operator dialog must open near the NPC"):
		return
	if not _check(battle_dialog.has_meta("digi_glass_surface"), "Battle Operator dialog must use the shared glass panel foundation"):
		return
	if not _check(cancel != null and get_viewport().gui_get_focus_owner() == cancel, "Battle Operator dialog must default to NOT NOW"):
		return
	if not _check(start != null and cancel.focus_neighbor_right == start.get_path() and start.focus_neighbor_left == cancel.get_path(), "Battle Operator dialog must expose a deterministic horizontal focus graph"):
		return
	if not _check(cancel.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET and start.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET, "Battle Operator dialog actions must remain touch-safe"):
		return

	var move_right := InputEventAction.new()
	move_right.action = "ui_right"
	move_right.pressed = true
	hub.call("_unhandled_input", move_right)
	await _frames(1)
	if not _check(get_viewport().gui_get_focus_owner() == start, "Battle Operator dialog must navigate from NOT NOW to START TEST BATTLE"):
		return
	var move_left := InputEventAction.new()
	move_left.action = "ui_left"
	move_left.pressed = true
	hub.call("_unhandled_input", move_left)
	await _frames(1)
	if not _check(get_viewport().gui_get_focus_owner() == cancel, "Battle Operator dialog must navigate back to NOT NOW"):
		return

	hub.queue_free()
	await _frames(2)
	print("global ui v2 components regression passed")
	get_tree().quit()


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	print("[global-ui-v2] FAIL: %s" % message)
	get_tree().quit(1)
	return false


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
