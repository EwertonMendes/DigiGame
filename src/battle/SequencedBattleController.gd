extends "res://src/BattleControllerDomain.gd"

const PRESENTATION_FALLBACK_IMPACT_DELAY := 0.22
const KO_RESOLVE_DELAY := 0.82
const INVALID_ACTION_GRID := Vector2i(-9996, -9996)

var _selected_target_grid := INVALID_ACTION_GRID
var _hover_target_grid := INVALID_ACTION_GRID


func handle_world_tap(world_position: Vector2) -> bool:
	# Movement is destination-driven now: once Move is active, the first valid
	# tile click commits the route and immediately starts the movement.
	if (
		not GlobalVariables.DebugMode
		and phase == Phase.MOVE_SELECT
		and current_actor != null
		and not _input_locked
		and _is_user_controlled(current_actor)
		and _field != null
		and _field.has_method("select_tile_from_world")
	):
		if not bool(_field.call("select_tile_from_world", world_position)):
			return false
		var grid := Vector2i(_field.call("world_to_grid", _field.to_local(world_position)))
		var handled := _lock_move_destination(grid)
		if handled and phase == Phase.MOVE_SELECT and not _planned_move_path.is_empty():
			confirm_move_path()
		return handled

	if (
		phase == Phase.TARGET_SELECT
		and current_actor != null
		and not _input_locked
		and _is_user_controlled(current_actor)
	):
		var selection := _targeting_system.selection_mode(_selected_action)
		if selection == "unit":
			var target: Node = null
			if _controller != null and _controller.has_method("get_digimon_under_pointer"):
				target = _controller.call("get_digimon_under_pointer", world_position) as Node
			return _select_or_confirm_target(target) if target != null else false
		if _field == null or not _field.has_method("select_tile_from_world"):
			return false
		if not bool(_field.call("select_tile_from_world", world_position)):
			return false
		var aim_grid := Vector2i(_field.call("world_to_grid", _field.to_local(world_position)))
		return _select_or_confirm_aim_grid(aim_grid)

	return super.handle_world_tap(world_position)


func _begin_action_targeting(action: Dictionary) -> bool:
	_selected_target_grid = INVALID_ACTION_GRID
	_hover_target_grid = INVALID_ACTION_GRID
	return super._begin_action_targeting(action)


func _clear_action_selection(reset_preview: bool) -> void:
	_selected_target_grid = INVALID_ACTION_GRID
	_hover_target_grid = INVALID_ACTION_GRID
	super._clear_action_selection(reset_preview)


func _basic_attack_definition() -> Dictionary:
	return {
		"id": "basic_attack",
		"name": "Attack",
		"category": "damage",
		"damageClass": "physical",
		"element": "neutral",
		"power": _battle_config.integer("damage", "basicAttackPower", 28),
		"accuracy": 100,
		"spCost": 0,
		"recoveryCost": _battle_config.number("turnRecovery", "basicAttack", 30.0),
		"selection": "unit",
		"range": {"shape": "adjacent_8", "min": 1, "max": 1, "requiresLineOfSight": false},
		"area": {"shape": "single", "radius": 0},
		"targets": ["enemy"],
		"canCrit": true,
		"effects": [{"type": "damage"}],
	}


func _select_or_confirm_target(target: Node) -> bool:
	if target == null or not _targeting_system.is_valid_target(_field, current_actor, target, _selected_action):
		return false
	_selected_target = target
	_selected_target_grid = _grid_for_actor(target)
	_hover_target = null
	_hover_target_grid = INVALID_ACTION_GRID
	_update_combat_preview(target, true)
	_refresh_hud()
	return confirm_selected_action()


func _select_or_confirm_aim_grid(aim_grid: Vector2i) -> bool:
	if not _targeting_system.is_valid_aim_grid(_field, current_actor, _selected_action, aim_grid):
		return false
	var targets := _targets_for_aim(aim_grid)
	if targets.is_empty():
		return false
	_selected_target_grid = aim_grid
	_selected_target = targets[0]
	_hover_target = null
	_hover_target_grid = INVALID_ACTION_GRID
	_update_combat_preview_for_grid(aim_grid, _selected_target, true)
	_refresh_hud()
	return confirm_selected_action()


func confirm_selected_action() -> bool:
	if phase != Phase.TARGET_SELECT or _selected_action.is_empty() or _input_locked:
		return false
	var aim_grid := _effective_selected_grid()
	if aim_grid == INVALID_ACTION_GRID:
		return false
	if not _targeting_system.is_valid_aim_grid(_field, current_actor, _selected_action, aim_grid):
		return false
	if _targets_for_aim(aim_grid).is_empty():
		return false
	_execute_selected_action()
	return true


func _on_field_hovered_grid_changed(grid: Vector2i, block_reason: String) -> void:
	if (
		phase == Phase.TARGET_SELECT
		and not _selected_action.is_empty()
		and not _input_locked
		and current_actor != null
		and _targeting_system.selection_mode(_selected_action) != "unit"
	):
		if grid == INVALID_GRID or not _targeting_system.is_valid_aim_grid(_field, current_actor, _selected_action, grid):
			_hover_target_grid = INVALID_ACTION_GRID
			_combat_preview.clear()
			if _field != null and _field.has_method("clear_target_preview"):
				_field.call("clear_target_preview")
			_refresh_hud()
			return
		_hover_target_grid = grid
		var targets := _targets_for_aim(grid)
		var primary: Node = targets[0] if not targets.is_empty() else null
		_update_combat_preview_for_grid(grid, primary, false)
		if _field != null and _field.has_method("set_targeting_hover_state"):
			_field.call("set_targeting_hover_state", grid, not targets.is_empty())
		_refresh_hud()
		return
	super._on_field_hovered_grid_changed(grid, block_reason)


func _on_hovered_digimon_changed(digimon_key: String) -> void:
	if phase == Phase.TARGET_SELECT and not _selected_action.is_empty() and _targeting_system.selection_mode(_selected_action) != "unit":
		return
	super._on_hovered_digimon_changed(digimon_key)


func _update_combat_preview(target: Node, locked: bool) -> void:
	if target == null:
		_combat_preview.clear()
		return
	_update_combat_preview_for_grid(_grid_for_actor(target), target, locked)


func _update_combat_preview_for_grid(aim_grid: Vector2i, primary_target: Node, locked: bool) -> void:
	if _selected_action.is_empty() or aim_grid == INVALID_ACTION_GRID:
		_combat_preview.clear()
		return
	var targets := _targets_for_aim(aim_grid)
	var summaries: Array[Dictionary] = []
	var total_damage := 0
	for target: Node in targets:
		var preview: Dictionary = _damage_calculator.preview(current_actor, target, _selected_action)
		var predicted_damage := int(preview.get("damage", 0))
		total_damage += predicted_damage
		summaries.append({
			"target_id": _instance_id(target),
			"target_name": _display_name(target),
			"damage": predicted_damage,
			"hp": _current_hp(target),
			"hp_after": maxi(0, _current_hp(target) - predicted_damage),
		})

	if primary_target == null and not targets.is_empty():
		primary_target = targets[0]
	var primary_preview: Dictionary = _damage_calculator.preview(current_actor, primary_target, _selected_action) if primary_target != null else {}
	_combat_preview = primary_preview.duplicate(true)
	_combat_preview.merge({
		"valid": not targets.is_empty(),
		"locked": locked,
		"action_id": String(_selected_action.get("id", "")),
		"action_name": String(_selected_action.get("name", "ACTION")),
		"target_id": _instance_id(primary_target) if primary_target != null else "",
		"target_name": _display_name(primary_target) if primary_target != null else "No target",
		"target_hp": _current_hp(primary_target) if primary_target != null else 0,
		"target_hp_after": maxi(0, _current_hp(primary_target) - int(primary_preview.get("damage", 0))) if primary_target != null else 0,
		"target_count": targets.size(),
		"targets": summaries,
		"total_damage": total_damage,
		"aim_grid": aim_grid,
		"sp_cost": int(_selected_action.get("spCost", 0)),
		"recovery_cost": float(_selected_action.get("recoveryCost", 30.0)),
		"turn_recovery": _preview_recovery_cost,
	}, true)

	var effect_grids: Array[Vector2i] = _targeting_system.effect_grids(_field, current_actor, _selected_action, aim_grid)
	if _field != null and _field.has_method("set_target_preview_grids"):
		_field.call("set_target_preview_grids", effect_grids, aim_grid)
	elif _field != null and _field.has_method("set_target_preview_grid"):
		_field.call("set_target_preview_grid", aim_grid)


func _show_action_range() -> void:
	if _field == null or not _field.has_method("set_action_range"):
		return
	var grids: Array[Vector2i] = _targeting_system.grids_in_range(_field, current_actor, _selected_action)
	_field.call("set_action_range", grids, "skill" if String(_selected_action.get("id", "")) != "basic_attack" else "attack")


func _targets_for_aim(aim_grid: Vector2i) -> Array[Node]:
	return _targeting_system.valid_targets_for_aim(_field, current_actor, _available_actors(), _selected_action, aim_grid)


func _available_actors() -> Array[Node]:
	var result: Array[Node] = []
	for actor: Node in _turn_order:
		if actor != null and is_instance_valid(actor) and _actor_available(actor):
			result.append(actor)
	return result


func _effective_selected_grid() -> Vector2i:
	if _selected_target_grid != INVALID_ACTION_GRID:
		return _selected_target_grid
	if _selected_target != null and is_instance_valid(_selected_target):
		return _grid_for_actor(_selected_target)
	return INVALID_ACTION_GRID


func _execute_selected_action() -> void:
	var action: Dictionary = _selected_action.duplicate(true)
	var aim_grid := _effective_selected_grid()
	var targets := _targets_for_aim(aim_grid)
	if action.is_empty() or targets.is_empty():
		return
	var primary_target: Node = _selected_target if _selected_target != null and targets.has(_selected_target) else targets[0]
	_input_locked = true
	phase = Phase.ACTION_RESOLVE
	_refresh_hud()

	var sp_cost: int = maxi(0, int(action.get("spCost", 0)))
	if sp_cost > 0 and (not current_actor.has_method("spend_sp") or not bool(current_actor.call("spend_sp", sp_cost))):
		_input_locked = false
		cancel_current_action()
		return

	var target_ids: Array[String] = []
	for target: Node in targets:
		target_ids.append(_instance_id(target))
	_event_bus.emit_event("action_started", {
		"actor_id": _instance_id(current_actor),
		"target_id": _instance_id(primary_target),
		"target_ids": target_ids,
		"target_count": targets.size(),
		"action_id": String(action.get("id", "")),
		"aim_grid": aim_grid,
	})

	await _wait_for_presentation_impact()
	if _battle_over or current_actor == null:
		return

	var total_damage := 0
	var any_hit := false
	var any_critical := false
	var knocked_out: Array[Node] = []
	for target: Node in targets:
		if target == null or not is_instance_valid(target) or not _actor_available(target):
			continue
		var result := _resolve_action_against_target(action, target)
		any_hit = any_hit or bool(result.get("hit", false))
		any_critical = any_critical or bool(result.get("critical", false))
		total_damage += int(result.get("damage", 0))
		if not _actor_available(target):
			knocked_out.append(target)

	for target: Node in knocked_out:
		_handle_knockout(target)

	_has_acted = true
	_action_recovery_added = float(action.get("recoveryCost", 30.0))
	_pending_recovery_cost = clampf(_pending_recovery_cost + _action_recovery_added, MIN_RECOVERY_COST, MAX_RECOVERY_COST)
	_preview_recovery_cost = _pending_recovery_cost
	_event_bus.emit_event("action_finished", {
		"actor_id": _instance_id(current_actor),
		"target_id": _instance_id(primary_target),
		"target_ids": target_ids,
		"target_count": targets.size(),
		"action_id": String(action.get("id", "")),
		"hit": any_hit,
		"critical": any_critical,
		"damage": total_damage,
		"sp_cost": sp_cost,
		"recovery_added": _action_recovery_added,
	})
	_clear_action_selection(false)

	if not knocked_out.is_empty():
		await get_tree().create_timer(KO_RESOLVE_DELAY).timeout

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


func _resolve_action_against_target(action: Dictionary, target: Node) -> Dictionary:
	var hit: bool = _battle_rng.roll_percent(float(action.get("accuracy", 100.0)))
	var critical := false
	var applied_damage := 0
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
						applied_damage += int(target.call("take_damage", raw_damage)) if target.has_method("take_damage") else 0
						_event_bus.emit_event("damage_applied", {
							"actor_id": _instance_id(current_actor),
							"target_id": _instance_id(target),
							"action_id": String(action.get("id", "")),
							"damage": applied_damage,
							"critical": critical,
							"type_modifier": float(preview.get("type_modifier", 1.0)),
							"element_modifier": float(preview.get("element_modifier", 1.0)),
						})
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
		_event_bus.emit_event("action_missed", {
			"actor_id": _instance_id(current_actor),
			"target_id": _instance_id(target),
			"action_id": String(action.get("id", "")),
		})
	return {"hit": hit, "critical": critical, "damage": applied_damage}


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
		_selected_target_grid = Vector2i(choice.get("target_grid", _grid_for_actor(_selected_target))) if _selected_target != null else INVALID_ACTION_GRID
		_preview_recovery_cost = _pending_recovery_cost + float(_selected_action.get("recoveryCost", 30.0))
		_update_combat_preview_for_grid(_selected_target_grid, _selected_target, true)
		await _execute_selected_action()
		if current_actor == actor and not _battle_over and _has_acted and not _has_moved:
			call_deferred("_end_turn")
		return
	phase = Phase.ACTION_RESOLVE
	_refresh_hud()
	call_deferred("_end_turn")


func _wait_for_presentation_impact() -> void:
	var main: Node = get_tree().root.get_node_or_null("Main")
	if main != null:
		var presentation: Node = main.get_node_or_null("BattlePresentationFX")
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
	_event_bus.emit_event("unit_knocked_out", {
		"target_id": actor_id,
		"target_name": _display_name(actor),
		"is_player": bool(actor.get("is_player_controlled")),
	})
	if not bool(actor.get("is_player_controlled")) and not _defeated_enemy_ids.has(actor_id):
		_defeated_enemy_ids.append(actor_id)
	turn_order_changed.emit()
