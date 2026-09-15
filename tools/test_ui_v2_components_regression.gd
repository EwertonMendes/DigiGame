extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")
const GlassPanelScript = preload("res://src/ui/components/DigiGlassPanel.gd")
const InteractionPromptScript = preload("res://src/ui/components/DigiInteractionPrompt.gd")
const ConfirmationModalScript = preload("res://src/ui/components/DigiConfirmationModal.gd")


func _ready() -> void:
	# Keep this regression focused on player-facing contracts instead of exact
	# styling internals. Visual tuning such as shader parameters, border values or
	# focus-neighbor paths should be free to evolve without breaking CI.
	var glass := GlassPanelScript.new() as PanelContainer
	add_child(glass)
	glass.call("configure_glass", DigiUiTheme.CYAN, "floating", Vector4.ZERO, 10)
	await _frames(2)
	if not _check(glass.has_meta("digi_glass_surface") and glass.get_theme_stylebox("panel") != null, "Glass surface must instantiate as a reusable V2 component"):
		return

	var prompt := InteractionPromptScript.new() as DigiInteractionPrompt
	add_child(prompt)
	await _frames(2)
	prompt.set_action("Open DigiLab")
	if not _check(prompt.get_action_label() != null and prompt.get_action_label().text == "OPEN DIGILAB", "Interaction prompt must expose the current action"):
		return
	if not _check(prompt.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET, "Interaction prompt must remain touch-safe"):
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
	var confirm := modal.get_confirm_button()
	var cancel := modal.get_cancel_button()
	if not _check(modal.visible and confirm != null and cancel != null, "Confirmation modal must open with both actions available"):
		return
	if not _check(get_viewport().gui_get_focus_owner() == cancel, "Confirmation modal must default to the safe cancel action"):
		return
	if not _check(confirm.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET and cancel.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET, "Confirmation actions must remain touch-safe"):
		return
	modal.close_dialog(false)

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
	var hub_cancel := hub.find_child("CancelBattleDialog", true, false) as Button
	var hub_start := hub.find_child("StartBattle", true, false) as Button
	if not _check(battle_dialog != null and battle_dialog.visible, "Battle Operator dialog must open"):
		return
	if not _check(hub_cancel != null and hub_start != null, "Battle Operator dialog must expose cancel and start actions"):
		return
	if not _check(get_viewport().gui_get_focus_owner() == hub_cancel, "Battle Operator dialog must default to NOT NOW"):
		return

	hub.queue_free()
	modal.queue_free()
	prompt.queue_free()
	glass.queue_free()
	await _frames(3)
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
