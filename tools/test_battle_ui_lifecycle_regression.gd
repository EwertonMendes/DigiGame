extends Node

const BATTLE_SCENE = preload("res://scenes/main.tscn")


class FleeControllerSpy:
	extends Node
	var attempts := 0

	func attempt_flee() -> bool:
		attempts += 1
		return true


func _ready() -> void:
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	await _frames(6)

	var hud := battle.get_node_or_null("BattleUI/Root") as Control
	if not _check(hud != null, "Battle HUD must exist after battle startup"):
		return

	# Regression contract for PR #118: EscapeBattleHUD owns these legacy controls
	# and its inherited layout still references them. A subclass may hide them, but
	# must never queue_free the subtree while those references remain in the base.
	var legacy_layer := hud.get("_escape_modal_layer") as Control
	var legacy_panel := hud.get("_escape_modal_panel") as Control
	var legacy_title := hud.get("_escape_title") as Label
	var legacy_question := hud.get("_escape_question") as Label
	if not _check(
		legacy_layer != null
		and legacy_panel != null
		and legacy_title != null
		and legacy_question != null
		and is_instance_valid(legacy_layer)
		and is_instance_valid(legacy_panel)
		and is_instance_valid(legacy_title)
		and is_instance_valid(legacy_question),
		"Base-owned flee controls must remain valid through startup"
	):
		return
	if not _check(not legacy_layer.visible, "Legacy flee confirmation must stay hidden behind the V2 flow"):
		return

	# Force the inherited layout path that previously dereferenced queued-for-free
	# labels and produced intermittent Web/WASM memory access out of bounds.
	hud.call("_layout_escape_ui")
	await _frames(2)
	if not _check(
		is_instance_valid(legacy_panel)
		and is_instance_valid(legacy_title)
		and is_instance_valid(legacy_question),
		"Inherited flee layout must never retain stale UI references"
	):
		return

	var v2_modal := hud.get("_v2_escape_modal") as DigiConfirmationModal
	if not _check(v2_modal != null and is_instance_valid(v2_modal), "Battle HUD must provide the V2 flee modal"):
		return
	if not _check(v2_modal.name == "EscapeConfirmationV2", "V2 flee modal must have independent ownership from the legacy subtree"):
		return

	hud.call("_open_escape_modal")
	await _frames(2)
	if not _check(v2_modal.visible, "V2 flee modal must open normally"):
		return
	if not _check(get_viewport().gui_get_focus_owner() == v2_modal.get_cancel_button(), "V2 flee modal must default focus to the safe NO action"):
		return

	# DigiConfirmationModal hides itself before emitting `confirmed`. Verify the
	# HUD uses a dedicated V2 handler rather than the legacy handler's visibility
	# guard, otherwise confirmation silently stops calling attempt_flee().
	var spy := FleeControllerSpy.new()
	add_child(spy)
	hud.set("_controller", spy)
	var confirm := v2_modal.get_confirm_button()
	confirm.emit_signal("pressed")
	await _frames(1)
	if not _check(spy.attempts == 1, "Confirming the V2 flee modal must call attempt_flee exactly once"):
		return
	if not _check(not v2_modal.visible, "V2 flee modal must close after confirmation"):
		return

	battle.queue_free()
	spy.queue_free()
	await _frames(3)
	print("battle ui lifecycle regression passed")
	get_tree().quit()


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	print("[battle-ui-lifecycle] FAIL: %s" % message)
	get_tree().quit(1)
	return false


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
