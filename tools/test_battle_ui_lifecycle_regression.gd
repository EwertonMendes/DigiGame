extends Node

const BATTLE_SCENE = preload("res://scenes/main.tscn")
const EscapeRNGScript = preload("res://src/battle/BattleRNG.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const BATTLE_READY_TIMEOUT_MSEC := 12000
const FLEE_RESULT_TIMEOUT_MSEC := 5000


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests()
	var factory: DigimonFactory = FactoryScript.new(OverworldState.get_database())
	var reserve_fixture := factory.create_player_by_name("agumon", 3, 100)
	if not _check(reserve_fixture != null, "Battle Switch fixture must be creatable"):
		return
	if not _check(not OverworldState.add_collection_instance(reserve_fixture).is_empty(), "Battle Switch fixture must enter the collection"):
		return
	if not _check(OverworldState.add_to_reserve_party(reserve_fixture.id), "Battle Switch fixture must enter Reserve slot 1"):
		return

	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	await _frames(6)

	var hud := battle.get_node_or_null("BattleUI/Root") as Control
	if not _check(hud != null, "Battle HUD must exist after battle startup"):
		return
	var controller := battle.get_node_or_null("BattleController")
	if not _check(controller != null, "Battle controller must exist after battle startup"):
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

	# Battle startup deliberately contains camera/spawn/banner animations driven by
	# real elapsed time. Wait on the actual gameplay predicate with a bounded
	# deadline rather than assuming an arbitrary number of process frames.
	if not await _wait_until_can_flee(controller, BATTLE_READY_TIMEOUT_MSEC):
		_check(false, "Battle must reach a player turn where flee can be attempted")
		return

	# A real Reserve fixture must surface Switch as a normal command. This covers
	# the regression where Reserve existed in the Squad but the battle UI hid it.
	var switch_button := hud.get("_switch_button") as Button
	var move_button := hud.get("_move_button") as Button
	var flee_button := hud.get("_flee_button") as Button
	var command_dock := hud.get("_dock") as Control
	if not _check(switch_button != null and move_button != null and flee_button != null and command_dock != null, "Battle HUD must expose Switch, Flee and the command rail"):
		return
	if not _check(switch_button.visible and not switch_button.disabled, "Switch must be visible and enabled when a battle-ready Reserve exists"):
		return
	if not _check(switch_button.icon != null and switch_button.icon.resource_path.ends_with("switch.svg"), "Switch must render its dedicated packaged icon"):
		return
	if not _check(switch_button.get_theme_font_size("font_size") == move_button.get_theme_font_size("font_size"), "Switch typography must match the other primary commands"):
		return
	if not _check(switch_button.tooltip_text.contains("[6]") and flee_button.tooltip_text.contains("[7]"), "Switch and Flee must have distinct keyboard shortcuts"):
		return
	var switch_rect := switch_button.get_global_rect()
	var flee_rect := flee_button.get_global_rect()
	var dock_rect := command_dock.get_global_rect()
	if not _check(switch_rect.end.y <= dock_rect.end.y + 1.0, "Visible Switch command must remain inside the Battle Operator rail"):
		return
	if not _check(flee_rect.end.y <= dock_rect.end.y + 1.0, "Flee must remain inside the Battle Operator rail after adding Switch"):
		return

	var switch_options: Array[Dictionary] = controller.call("get_switch_options", false)
	if not _check(not switch_options.is_empty() and String(switch_options[0].get("id", "")) == reserve_fixture.id, "Battle controller must expose the Reserve fixture as a Switch option"):
		return
	hud.call("_open_switch_picker", false)
	await _frames(2)
	var picker := hud.get("_switch_picker") as Control
	if not _check(picker != null and picker.visible, "Switch command must open the Reserve picker"):
		return
	picker.call("close_picker", false)

	var switch_events: Array[Dictionary] = []
	controller.connect("combat_event", func(event: Dictionary):
		if String(event.get("type", "")) == "unit_switched":
			switch_events.append(event.duplicate(true))
	)
	var outgoing := controller.get("current_actor") as Node
	if not _check(outgoing != null and bool(controller.call("switch_current", reserve_fixture.id)), "Selecting a Reserve Digimon must execute a real battle Switch"):
		return
	await _frames(2)
	if not _check(not switch_events.is_empty(), "Battle Switch must emit presentation feedback"):
		return
	var switch_event := switch_events[0]
	if not _check(bool(switch_event.get("turn_consumed", false)) and not bool(switch_event.get("forced", true)), "Voluntary Switch must explicitly report that it consumed the turn"):
		return
	var overlay := hud.get("_combat_overlay") as Control
	var toast: Label = (overlay.get("_toast") as Label) if overlay != null else null
	if not _check(toast != null and toast.text.contains("SWITCH") and toast.text.contains("TURN CONSUMED"), "Battle overlay must explain both the replacement and consumed turn"):
		return

	await get_tree().create_timer(0.22).timeout
	var digimon_controller := battle.get_node_or_null("DigimonController")
	var incoming: Node = null
	if digimon_controller != null:
		for child: Node in digimon_controller.get_children():
			if child.has_method("get_digimon_instance_id") and String(child.call("get_digimon_instance_id")) == reserve_fixture.id:
				incoming = child
				break
	if not _check(incoming != null and incoming.visible, "Reserve Digimon must visibly materialize into the battlefield after recall"):
		return

	await get_tree().create_timer(0.22).timeout
	if not _check(outgoing == null or not is_instance_valid(outgoing), "Recalled Digimon must leave the battlefield tree after its switch-out animation"):
		return
	if not await _wait_until_can_flee(controller, BATTLE_READY_TIMEOUT_MSEC):
		_check(false, "Battle must continue to the next available player turn after Switch consumes the current one")
		return

	# Use a normal probabilistic policy rather than guaranteed escape. The preview
	# is intentionally below 100%, and the RNG seeds below prove that the exact
	# first-attempt probability admits both success and failure outcomes.
	controller.call("set_escape_policy", {
		"mode": "allowed",
		"baseChance": 75.0,
		"failureBonus": 15.0,
		"failureBonusCap": 30.0,
		"failureRecovery": 120.0,
	})
	await _frames(1)
	var preview: Dictionary = controller.call("get_flee_preview")
	var chance := float(preview.get("chance", 0.0))
	if not _check(chance > 0.0 and chance < 100.0, "First flee attempt must remain genuinely probabilistic"):
		return
	var success_seed := _find_first_roll_seed(chance, true)
	var failure_seed := _find_first_roll_seed(chance, false)
	if not _check(success_seed != 0, "First flee attempt must have at least one deterministic success seed"):
		return
	if not _check(failure_seed != 0, "First flee attempt must still have at least one deterministic failure seed"):
		return
	controller.call("set_escape_rng_seed", success_seed)

	hud.call("_open_escape_modal")
	await _frames(2)
	if not _check(v2_modal.visible, "V2 flee modal must open normally"):
		return
	if not _check(get_viewport().gui_get_focus_owner() == v2_modal.get_cancel_button(), "V2 flee modal must default focus to the safe NO action"):
		return

	# DigiConfirmationModal hides itself before emitting `confirmed`. The HUD must
	# await the real asynchronous attempt_flee() lifecycle so the roll, retreat
	# animation and battle result all complete after pressing YES.
	var confirm := v2_modal.get_confirm_button()
	confirm.emit_signal("pressed")
	if not _check(not v2_modal.visible, "V2 flee modal must close after confirmation"):
		return
	if not await _wait_until_escaped(controller, FLEE_RESULT_TIMEOUT_MSEC):
		_check(false, "Confirming YES must complete a successful first flee attempt")
		return

	var final_state: Dictionary = controller.call("get_hud_state")
	var result_variant = final_state.get("battle_result", {})
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	if not _check(bool(result.get("escaped", false)), "Successful flee must mark the battle result as escaped"):
		return
	if not _check(int(result.get("flee_attempts", 0)) == 1, "A successful first flee must finish on attempt one"):
		return
	if not _check(int(result.get("escape_seed", 0)) == success_seed, "Escape result must retain the RNG seed used for replay/debugging"):
		return

	battle.queue_free()
	await _frames(3)
	print("battle ui lifecycle regression passed")
	get_tree().quit()


func _wait_until_can_flee(controller: Node, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if controller != null and is_instance_valid(controller) and controller.has_method("get_hud_state"):
			var state: Dictionary = controller.call("get_hud_state")
			if bool(state.get("can_flee", false)):
				return true
		await get_tree().process_frame
	return false


func _wait_until_escaped(controller: Node, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		if controller != null and is_instance_valid(controller) and controller.has_method("get_hud_state"):
			var state: Dictionary = controller.call("get_hud_state")
			var result_variant = state.get("battle_result", {})
			var result: Dictionary = result_variant if result_variant is Dictionary else {}
			if bool(result.get("escaped", false)):
				return true
		await get_tree().process_frame
	return false


func _find_first_roll_seed(chance: float, expected_success: bool) -> int:
	var rng = EscapeRNGScript.new()
	for seed: int in range(1, 2049):
		rng.reset(seed)
		if rng.roll_percent(chance) == expected_success:
			return seed
	return 0


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	print("[battle-ui-lifecycle] FAIL: %s" % message)
	get_tree().quit(1)
	return false


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
