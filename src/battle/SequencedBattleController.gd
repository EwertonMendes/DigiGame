extends "res://src/BattleControllerDomain.gd"

const PRESENTATION_FALLBACK_IMPACT_DELAY := 0.22
const KO_RESOLVE_DELAY := 0.82


func _execute_selected_action() -> void:
	var action: Dictionary = _selected_action.duplicate(true)
	var target: Node = _selected_target
	if action.is_empty() or target == null:
		return
	_input_locked = true
	phase = Phase.ACTION_RESOLVE
	_refresh_hud()

	var sp_cost: int = maxi(0, int(action.get("spCost", 0)))
	if sp_cost > 0 and (not current_actor.has_method("spend_sp") or not bool(current_actor.call("spend_sp", sp_cost))):
		_input_locked = false
		cancel_current_action()
		return

	var action_started_payload := {
		"actor_id": _instance_id(current_actor),
		"target_id": _instance_id(target),
		"action_id": String(action.get("id", "")),
	}
	_event_bus.emit_event("action_started", action_started_payload)
	_present_event("action_started", action_started_payload)

	# The presentation sets an exact impact deadline for the lunge/projectile.
	# HP cannot change until that visual beat is reached.
	await _wait_for_presentation_impact()
	if _battle_over or current_actor == null or target == null or not is_instance_valid(target):
		return

	var hit: bool = _battle_rng.roll_percent(float(action.get("accuracy", 100.0)))
	var critical: bool = false
	var applied_damage: int = 0
	if hit:
		var effects = action.get("effects", [])
		if effects is Array:
			for raw_effect in effects:
				if not raw_effect is Dictionary:
					continue
				var effect: Dictionary = raw_effect
				match String(effect.get("type", "")):
					"damage":
						var preview: Dictionary = _damage_calculator.preview(current_actor, target, action)
						critical = bool(action.get("canCrit", false)) and _battle_rng.roll_percent(float(preview.get("crit_chance", 0.0)))
						var raw_damage: int = int(preview.get("critical_damage" if critical else "damage", 0))
						applied_damage = int(target.call("take_damage", raw_damage)) if target.has_method("take_damage") else 0
						var damage_payload := {
							"actor_id": _instance_id(current_actor),
							"target_id": _instance_id(target),
							"action_id": String(action.get("id", "")),
							"damage": applied_damage,
							"critical": critical,
							"type_modifier": float(preview.get("type_modifier", 1.0)),
							"element_modifier": float(preview.get("element_modifier", 1.0)),
						}
						_event_bus.emit_event("damage_applied", damage_payload)
						_present_event("damage_applied", damage_payload)
					"status":
						var chance: float = float(effect.get("chance", 100.0))
						if _battle_rng.roll_percent(chance):
							var status_id: String = String(effect.get("status", ""))
							var duration: int = int(effect.get("duration", -1))
							if _status_system.apply(target, status_id, duration, _instance_id(current_actor)):
								_event_bus.emit_event("status_applied", {
									"actor_id": _instance_id(current_actor),
									"target_id": _instance_id(target),
									"status": status_id,
								})
								notify_speed_changed()
	else:
		var miss_payload := {
			"actor_id": _instance_id(current_actor),
			"target_id": _instance_id(target),
			"action_id": String(action.get("id", "")),
		}
		_event_bus.emit_event("action_missed", miss_payload)
		_present_event("action_missed", miss_payload)

	var target_knocked_out: bool = not _actor_available(target)
	if target_knocked_out:
		_handle_knockout(target)

	_has_acted = true
	_action_recovery_added = float(action.get("recoveryCost", 30.0))
	_pending_recovery_cost = clampf(_pending_recovery_cost + _action_recovery_added, MIN_RECOVERY_COST, MAX_RECOVERY_COST)
	_preview_recovery_cost = _pending_recovery_cost
	_event_bus.emit_event("action_finished", {
		"actor_id": _instance_id(current_actor),
		"target_id": _instance_id(target),
		"action_id": String(action.get("id", "")),
		"hit": hit,
		"critical": critical,
		"damage": applied_damage,
		"sp_cost": sp_cost,
		"recovery_added": _action_recovery_added,
	})
	_clear_action_selection(false)

	# Victory/defeat never opens over a defeated sprite. The renderer normally
	# completes a smoke/dissolve animation; this hard fallback guarantees board
	# state even if a browser drops a tween/callback.
	if target_knocked_out:
		await get_tree().create_timer(KO_RESOLVE_DELAY).timeout
		if is_instance_valid(target) and not _actor_available(target):
			target.visible = false

	_input_locked = false
	turn_order_changed.emit()
	if _check_battle_end():
		return
	if _has_moved:
		phase = Phase.ACTION_RESOLVE
		_refresh_hud()
		call_deferred("_end_turn")
	else:
		phase = Phase.COMMAND
		_refresh_hud()


func _run_enemy_turn(actor: Node) -> void:
	await get_tree().create_timer(0.38).timeout
	if _battle_over or current_actor != actor or not _actor_available(actor):
		return
	var opponents: Array[Node] = _alive_actors(true)
	var actions: Array[Dictionary] = _enemy_actions(actor)
	var choice: Dictionary = _battle_ai.choose_action(_field, actor, opponents, actions)
	if choice.is_empty() and not _has_moved:
		await _enemy_move_toward(actor, opponents)
		if _battle_over or current_actor != actor:
			return
		choice = _battle_ai.choose_action(_field, actor, opponents, actions)
	if not choice.is_empty():
		var raw_action = choice.get("action", {})
		_selected_action = (raw_action as Dictionary).duplicate(true) if raw_action is Dictionary else {}
		_selected_target = choice.get("target") as Node
		_preview_recovery_cost = _pending_recovery_cost + float(_selected_action.get("recoveryCost", 30.0))
		_update_combat_preview(_selected_target, true)
		await _execute_selected_action()
		if current_actor == actor and not _battle_over and _has_acted and not _has_moved:
			call_deferred("_end_turn")
		return
	phase = Phase.ACTION_RESOLVE
	_refresh_hud()
	call_deferred("_end_turn")


func _presentation_node() -> Node:
	var main: Node = get_tree().root.get_node_or_null("Main")
	if main == null:
		return null
	return main.get_node_or_null("BattlePresentationFX")


func _present_event(event_type: String, payload: Dictionary) -> void:
	var presentation: Node = _presentation_node()
	if presentation == null or not presentation.has_method("present_event"):
		return
	var event: Dictionary = payload.duplicate(true)
	event["type"] = event_type
	presentation.call("present_event", event)


func _wait_for_presentation_impact() -> void:
	var presentation: Node = _presentation_node()
	if presentation != null and presentation.has_method("wait_for_current_impact"):
		await presentation.call("wait_for_current_impact")
		return
	await get_tree().create_timer(PRESENTATION_FALLBACK_IMPACT_DELAY).timeout


func _handle_knockout(actor: Node) -> void:
	if actor == null:
		return
	actor.set("is_defending", false)
	if actor.has_method("set_turn_active"):
		actor.call("set_turn_active", false)
	var actor_id: String = _instance_id(actor)
	var ko_payload := {
		"target_id": actor_id,
		"target_name": _display_name(actor),
		"is_player": bool(actor.get("is_player_controlled")),
	}
	_event_bus.emit_event("unit_knocked_out", ko_payload)
	_present_event("unit_knocked_out", ko_payload)
	if not bool(actor.get("is_player_controlled")) and not _defeated_enemy_ids.has(actor_id):
		_defeated_enemy_ids.append(actor_id)
	turn_order_changed.emit()


func _instance_id(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor):
		return ""
	if actor.has_method("get_digimon_instance_id"):
		var persistent_id: String = String(actor.call("get_digimon_instance_id"))
		if not persistent_id.is_empty():
			return persistent_id
	return str(actor.get_instance_id())


func focus_actor_by_instance_id(instance_id: String) -> void:
	if instance_id.is_empty():
		return
	for actor: Node in _turn_order:
		if actor == null or not is_instance_valid(actor):
			continue
		if _instance_id(actor) != instance_id:
			continue
		var camera: Camera2D = get_viewport().get_camera_2d()
		if camera != null and camera.has_method("focus_on"):
			camera.call("focus_on", actor.global_position)
		return
