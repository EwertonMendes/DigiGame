extends "res://src/battle/BattleOpeningController.gd"

const BattleEscapeResolverScript = preload("res://src/battle/BattleEscapeResolver.gd")

var _escape_resolver = BattleEscapeResolverScript.new()
var _escape_policy_override: Dictionary = {}
var _flee_failures := 0


func set_escape_policy(policy: Dictionary) -> void:
	_escape_policy_override = policy.duplicate(true)
	_notify_turn_order_changed()


func clear_escape_policy_override() -> void:
	_escape_policy_override.clear()
	_notify_turn_order_changed()


func get_flee_preview() -> Dictionary:
	var policy := _resolved_escape_policy()
	if current_actor == null or not is_instance_valid(current_actor):
		var unavailable := _escape_resolver.normalize_policy(policy)
		return {
			"allowed": false,
			"mode": String(unavailable.get("mode", "allowed")),
			"chance": 0.0,
			"base_chance": float(unavailable.get("baseChance", 50.0)),
			"speed_modifier": 0.0,
			"distance_modifier": 0.0,
			"retry_modifier": 0.0,
			"nearest_distance": 0,
			"failure_recovery": float(unavailable.get("failureRecovery", 120.0)),
			"failed_attempts": _flee_failures,
			"reason": "Wait for your Digimon's turn.",
		}
	return _escape_resolver.preview(_field, current_actor, _alive_actors(false), _flee_failures, policy)


func attempt_flee() -> bool:
	if not _can_act_now():
		return false

	var escape_preview := get_flee_preview()
	if not bool(escape_preview.get("allowed", false)):
		_event_bus.emit_event("flee_blocked", {
			"actor_id": _instance_id(current_actor),
			"reason": String(escape_preview.get("reason", "Retreat is unavailable in this battle.")),
		})
		_refresh_hud()
		return false

	_input_locked = true
	phase = Phase.ACTION_RESOLVE
	_clear_action_selection(false)
	_clear_manual_path_visuals()
	_refresh_hud()
	_event_bus.emit_event("flee_attempt", {
		"actor_id": _instance_id(current_actor),
		"actor_name": _display_name(current_actor),
		"chance": float(escape_preview.get("chance", 0.0)),
		"failed_attempts": _flee_failures,
	})

	await get_tree().create_timer(0.14).timeout
	if _battle_over or current_actor == null:
		return false

	var mode := String(escape_preview.get("mode", "allowed"))
	var escaped := mode == "guaranteed" or _battle_rng.roll_percent(float(escape_preview.get("chance", 0.0)))
	if escaped:
		_event_bus.emit_event("flee_success", {
			"actor_id": _instance_id(current_actor),
			"actor_name": _display_name(current_actor),
			"chance": float(escape_preview.get("chance", 100.0)),
			"attempt": _flee_failures + 1,
		})
		await _play_retreat_success_animation()
		_commit_player_resources()
		_finish_escape(escape_preview)
		return true

	_flee_failures += 1
	_has_acted = true
	var failure_recovery := float(escape_preview.get("failure_recovery", 120.0))
	_pending_recovery_cost = clampf(maxf(_pending_recovery_cost, failure_recovery), MIN_RECOVERY_COST, MAX_RECOVERY_COST)
	_preview_recovery_cost = _pending_recovery_cost
	var next_preview := _escape_resolver.preview(_field, current_actor, _alive_actors(false), _flee_failures, _resolved_escape_policy())
	_event_bus.emit_event("flee_failed", {
		"actor_id": _instance_id(current_actor),
		"actor_name": _display_name(current_actor),
		"chance": float(escape_preview.get("chance", 0.0)),
		"next_chance": float(next_preview.get("chance", 0.0)),
		"attempt": _flee_failures,
		"recovery": _pending_recovery_cost,
	})
	if current_actor.has_method("play_battle_escape_failed_animation"):
		await current_actor.call("play_battle_escape_failed_animation")
	else:
		await get_tree().create_timer(0.32).timeout

	_input_locked = false
	turn_order_changed.emit()
	_refresh_hud()
	call_deferred("_end_turn")
	return true


func get_hud_state() -> Dictionary:
	var state: Dictionary = super.get_hud_state()
	var preview := get_flee_preview()
	var can_attempt := (
		bool(preview.get("allowed", false))
		and not _battle_over
		and current_actor != null
		and _is_user_controlled(current_actor)
		and not _input_locked
		and not _has_acted
		and (phase == Phase.COMMAND or phase == Phase.ACTION_SELECT)
	)
	state["can_flee"] = can_attempt
	state["flee_preview"] = preview
	state["flee_failures"] = _flee_failures
	state["flee_locked_reason"] = String(preview.get("reason", ""))
	return state


func _build_battle_result(victory: bool) -> Dictionary:
	var result: Dictionary = super._build_battle_result(victory)
	result["outcome"] = "victory" if victory else "defeat"
	result["escaped"] = false
	return result


func _resolved_escape_policy() -> Dictionary:
	if not _escape_policy_override.is_empty():
		return _escape_resolver.normalize_policy(_escape_policy_override)

	var policy := _escape_resolver.default_policy()
	for enemy: Node in _alive_actors(false):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var profile := String(enemy.get_meta("encounter_profile", "wild")).to_lower()
		if profile == "boss":
			policy["mode"] = "forbidden"
			policy["reason"] = "Boss battles cannot be escaped."
			return policy
		if profile == "story" or profile == "important":
			policy["mode"] = "forbidden"
			policy["reason"] = "Retreat is unavailable in this important battle."
			return policy
	return policy


func _play_retreat_success_animation() -> void:
	var players: Array[Node] = _alive_actors(true)
	if current_actor != null and players.has(current_actor):
		players.erase(current_actor)
		players.push_front(current_actor)
	for actor: Node in players:
		if actor == null or not is_instance_valid(actor):
			continue
		if actor.has_method("set_turn_active"):
			actor.call("set_turn_active", false)
		if actor.has_method("play_battle_escape_animation"):
			await actor.call("play_battle_escape_animation")
		else:
			actor.visible = false
		await get_tree().create_timer(0.035).timeout


func _commit_player_resources() -> void:
	for actor: Node in _turn_order:
		if actor == null or not is_instance_valid(actor) or not bool(actor.get("is_player_controlled")):
			continue
		var battle_state = actor.get("battle_state")
		if battle_state != null and battle_state.has_method("commit_resources_to_instance"):
			battle_state.call("commit_resources_to_instance")


func _finish_escape(escape_preview: Dictionary) -> void:
	_battle_over = true
	phase = Phase.TURN_END
	_input_locked = true
	_clear_manual_path_visuals()
	_clear_action_selection(false)
	for actor: Node in _turn_order:
		if actor != null and is_instance_valid(actor) and actor.has_method("set_turn_active"):
			actor.call("set_turn_active", false)
	_battle_result = {
		"victory": false,
		"escaped": true,
		"outcome": "escaped",
		"acts": _battle_act_number,
		"battle_seed": _battle_rng.snapshot_seed(),
		"bits": 0,
		"digi_data": {},
		"defeated_enemy_count": _defeated_enemy_ids.size(),
		"flee_attempts": _flee_failures + 1,
		"flee_chance": float(escape_preview.get("chance", 0.0)),
	}
	_event_bus.emit_event("battle_finished", _battle_result)
	battle_finished.emit(_battle_result.duplicate(true))
	turn_order_changed.emit()
	_refresh_hud()
