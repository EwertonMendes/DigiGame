extends "res://src/BattleController.gd"

signal turn_order_changed
signal combat_event(event: Dictionary)
signal battle_finished(result: Dictionary)

const TurnSchedulerScript = preload("res://src/battle/TurnScheduler.gd")
const BattleConfigScript = preload("res://src/battle/BattleConfig.gd")
const BattleRNGScript = preload("res://src/battle/BattleRNG.gd")
const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")
const TargetingSystemScript = preload("res://src/battle/combat/TargetingSystem.gd")
const DamageCalculatorScript = preload("res://src/battle/combat/DamageCalculator.gd")
const StatusSystemScript = preload("res://src/battle/status/StatusSystem.gd")
const BattleAIScript = preload("res://src/battle/ai/BattleAI.gd")
const BattleEventBusScript = preload("res://src/battle/events/BattleEventBus.gd")

const MIN_RECOVERY_COST := 1.0
const MAX_RECOVERY_COST := 300.0
const DEMO_BATTLE_SEED := 20260910
const INVALID_TARGET_GRID := Vector2i(-9998, -9998)

var _turn_scheduler = TurnSchedulerScript.new()
var _battle_config = BattleConfigScript.new()
var _battle_rng = BattleRNGScript.new()
var _action_database = ActionDatabaseScript.new()
var _targeting_system = TargetingSystemScript.new()
var _status_system = StatusSystemScript.new()
var _damage_calculator = null
var _battle_ai = null
var _event_bus = BattleEventBusScript.new()

var _pending_recovery_cost: float = 55.0
var _preview_recovery_cost: float = 55.0
var _battle_act_number: int = 0
var _has_acted := false
var _movement_recovery_added := 0.0
var _action_recovery_added := 0.0
var _selected_action: Dictionary = {}
var _selected_target: Node = null
var _hover_target: Node = null
var _combat_preview: Dictionary = {}
var _battle_over := false
var _battle_result: Dictionary = {}
var _defeated_enemy_ids: Array[String] = []


func _ready() -> void:
	_battle_config.load_default()
	_action_database.load_default()
	_status_system.load_default()
	_battle_rng.reset(DEMO_BATTLE_SEED)
	_damage_calculator = DamageCalculatorScript.new(_battle_config)
	_battle_ai = BattleAIScript.new(_targeting_system, _damage_calculator)
	_event_bus.event_emitted.connect(_on_battle_event)
	super._ready()
	if _controller != null and _controller.has_signal("hovered_digimon_changed"):
		_controller.connect("hovered_digimon_changed", _on_hovered_digimon_changed)


func _unhandled_input(event: InputEvent) -> void:
	if _battle_over:
		return
	if phase == Phase.TARGET_SELECT and _is_user_controlled(current_actor):
		if event is InputEventKey:
			var key := event as InputEventKey
			if key.pressed and not key.echo:
				if key.keycode == KEY_ESCAPE:
					cancel_current_action()
					get_viewport().set_input_as_handled()
					return
				if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
					confirm_selected_action()
					get_viewport().set_input_as_handled()
					return
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
				cancel_current_action()
				get_viewport().set_input_as_handled()
				return
	super._unhandled_input(event)


func handle_world_tap(world_position: Vector2) -> bool:
	if GlobalVariables.DebugMode:
		return super.handle_world_tap(world_position)
	if phase == Phase.TARGET_SELECT and current_actor != null and _is_user_controlled(current_actor) and not _input_locked:
		var target: Node = null
		if _controller != null and _controller.has_method("get_digimon_under_pointer"):
			target = _controller.call("get_digimon_under_pointer", world_position) as Node
		if target == null:
			return false
		return _select_or_confirm_target(target)
	return super.handle_world_tap(world_position)


func _load_movement_database() -> void:
	# Species metadata is loaded once by DigimonDatabase. Each battle actor exposes
	# its own final MOV, including permanent training and battle-only modifiers.
	_mov_by_key.clear()


func _movement_for(actor: Node) -> int:
	if actor == null:
		return DEFAULT_MOV
	if actor.has_method("get_final_mov"):
		return maxi(0, int(actor.call("get_final_mov")))
	return super._movement_for(actor)


func _start_battle() -> void:
	if _controller == null:
		return
	_turn_order.clear()
	for child in _controller.get_children():
		if child is CharacterBody2D:
			_turn_order.append(child)
	if _turn_order.is_empty():
		return
	_turn_scheduler.reset(_turn_order)
	_event_bus.clear()
	_battle_act_number = 0
	_battle_over = false
	_battle_result.clear()
	_defeated_enemy_ids.clear()
	_start_next_turn()


func _start_next_turn() -> void:
	if _battle_over or _turn_order.is_empty():
		return
	if _check_battle_end():
		return

	var next_actor: Node = _turn_scheduler.next_actor(_turn_order)
	if next_actor == null:
		return

	_battle_act_number += 1
	current_actor = next_actor
	_turn_index = _turn_order.find(current_actor)
	_reset_turn_state()
	phase = Phase.TURN_START
	current_actor.set("is_defending", false)
	_turn_start_grid = _grid_for_actor(current_actor)
	_sync_turn_highlight()
	_focus_current_actor()

	var status_events := _status_system.on_turn_start(current_actor)
	for status_event: Dictionary in status_events:
		var payload := status_event.duplicate()
		payload["target_id"] = _instance_id(current_actor)
		payload.erase("target")
		_event_bus.emit_event("status_damage", payload)
	if not _actor_available(current_actor):
		_handle_knockout(current_actor)
		if not _check_battle_end():
			call_deferred("_start_next_turn")
		return

	phase = Phase.COMMAND
	_refresh_hud()
	turn_order_changed.emit()
	if not _is_user_controlled(current_actor):
		_run_enemy_turn(current_actor)


func _reset_turn_state() -> void:
	_pending_recovery_cost = _base_turn_recovery()
	_preview_recovery_cost = _pending_recovery_cost
	_has_moved = false
	_has_acted = false
	_movement_recovery_added = 0.0
	_action_recovery_added = 0.0
	_last_move_path.clear()
	_planned_move_path.clear()
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	_waypoints.clear()
	_reachable_tiles.clear()
	_input_locked = false
	_clear_action_selection(false)


func begin_move_selection() -> void:
	if _battle_over or current_actor == null or _input_locked or _has_moved or not _is_user_controlled(current_actor):
		return
	if phase != Phase.COMMAND and phase != Phase.ACTION_SELECT:
		return

	_turn_start_grid = _grid_for_actor(current_actor)
	_planned_move_path.clear()
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	_waypoints.clear()
	_reachable_tiles = _movement_system.get_reachable_tiles(
		_field,
		_controller,
		current_actor,
		_turn_start_grid,
		_movement_for(current_actor)
	)
	phase = Phase.MOVE_SELECT
	if current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", true)
	if _field != null and _field.has_method("set_movement_range"):
		_field.call("set_movement_range", _reachable_tiles, _turn_start_grid, current_actor)
	_refresh_movement_plan_state()


func confirm_move_path() -> bool:
	if not is_manual_path_input_active():
		return false
	var movement_points := _movement_for(current_actor)
	if not _movement_system.can_confirm_manual_path(_field, _controller, current_actor, _planned_move_path, movement_points):
		return false

	var path: Array[Vector2i] = _planned_move_path.duplicate()
	var spent := _movement_system.get_path_cost(_field, current_actor, path)
	_input_locked = true
	phase = Phase.MOVING
	_clear_manual_path_visuals()
	_refresh_hud()
	await current_actor.call("move_along_grid_path", path, _field)
	_last_move_path = path.duplicate()
	_planned_move_path.clear()
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	_waypoints.clear()
	_has_moved = true
	_reachable_tiles.clear()
	_input_locked = false
	if current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", false)
	_movement_recovery_added = float(spent) * _movement_recovery_per_point()
	_pending_recovery_cost += _movement_recovery_added
	_preview_recovery_cost = _pending_recovery_cost
	_event_bus.emit_event("unit_moved", {
		"actor_id": _instance_id(current_actor),
		"movement_spent": spent,
		"recovery_added": _movement_recovery_added,
	})
	turn_order_changed.emit()
	if _has_acted:
		phase = Phase.ACTION_RESOLVE
		_refresh_hud()
		call_deferred("_end_turn")
	else:
		phase = Phase.ACTION_SELECT
		_refresh_hud()
	return true


func undo_move() -> void:
	if current_actor == null or _input_locked or not _has_moved or _has_acted:
		return
	if phase != Phase.ACTION_SELECT and phase != Phase.COMMAND:
		return
	if not current_actor.has_method("move_along_grid_path"):
		return
	var route: Array[Vector2i] = [_turn_start_grid]
	for grid: Vector2i in _last_move_path:
		route.append(grid)
	route.reverse()
	if not route.is_empty():
		route.remove_at(0)
	_input_locked = true
	phase = Phase.MOVING
	_refresh_hud()
	await current_actor.call("move_along_grid_path", route, _field)
	_has_moved = false
	_last_move_path.clear()
	_pending_recovery_cost = maxf(_base_turn_recovery(), _pending_recovery_cost - _movement_recovery_added)
	_movement_recovery_added = 0.0
	_preview_recovery_cost = _pending_recovery_cost
	_input_locked = false
	phase = Phase.COMMAND
	turn_order_changed.emit()
	_refresh_hud()


func begin_basic_attack() -> bool:
	return _begin_action_targeting(_basic_attack_definition())


func begin_skill(skill_id: String) -> bool:
	if not _can_act_now():
		return false
	var action := _action_database.get_action(skill_id)
	if action.is_empty() or not _actor_knows_skill(current_actor, skill_id):
		return false
	if _current_sp(current_actor) < int(action.get("spCost", 0)):
		return false
	return _begin_action_targeting(action)


func cancel_current_action() -> void:
	if phase != Phase.TARGET_SELECT or _input_locked:
		return
	_clear_action_selection(true)
	phase = Phase.ACTION_SELECT if _has_moved else Phase.COMMAND
	_refresh_hud()


func confirm_current_context() -> bool:
	if phase == Phase.MOVE_SELECT:
		return await confirm_move_path()
	if phase == Phase.TARGET_SELECT:
		return confirm_selected_action()
	return false


func confirm_selected_action() -> bool:
	if phase != Phase.TARGET_SELECT or _selected_action.is_empty() or _selected_target == null or _input_locked:
		return false
	if not _targeting_system.is_valid_target(_field, current_actor, _selected_target, _selected_action):
		return false
	_execute_selected_action()
	return true


func defend_current() -> void:
	if not _can_act_now():
		return
	_has_acted = true
	current_actor.set("is_defending", true)
	_action_recovery_added = _battle_config.number("turnRecovery", "defend", 15.0)
	_pending_recovery_cost += _action_recovery_added
	_preview_recovery_cost = _pending_recovery_cost
	_event_bus.emit_event("defend", {
		"actor_id": _instance_id(current_actor),
		"damage_multiplier": _battle_config.number("defend", "damageMultiplier", 0.65),
	})
	turn_order_changed.emit()
	if _has_moved:
		phase = Phase.ACTION_RESOLVE
		_refresh_hud()
		call_deferred("_end_turn")
	else:
		phase = Phase.COMMAND
		_refresh_hud()


func wait_current() -> void:
	if _battle_over or current_actor == null or _input_locked or not _is_user_controlled(current_actor):
		return
	if phase != Phase.COMMAND and phase != Phase.ACTION_SELECT:
		return
	phase = Phase.ACTION_RESOLVE
	_event_bus.emit_event("wait", {"actor_id": _instance_id(current_actor)})
	_refresh_hud()
	call_deferred("_end_turn")


func _begin_action_targeting(action: Dictionary) -> bool:
	if not _can_act_now() or action.is_empty():
		return false
	if _current_sp(current_actor) < int(action.get("spCost", 0)):
		return false
	_selected_action = action.duplicate(true)
	_selected_target = null
	_hover_target = null
	_combat_preview.clear()
	phase = Phase.TARGET_SELECT
	_preview_recovery_cost = clampf(_pending_recovery_cost + float(action.get("recoveryCost", 30.0)), MIN_RECOVERY_COST, MAX_RECOVERY_COST)
	_show_action_range()
	turn_order_changed.emit()
	_refresh_hud()
	return true


func _select_or_confirm_target(target: Node) -> bool:
	if not _targeting_system.is_valid_target(_field, current_actor, target, _selected_action):
		return false
	if _selected_target == target:
		return confirm_selected_action()
	_selected_target = target
	_hover_target = null
	_update_combat_preview(target, true)
	_refresh_hud()
	return true


func _on_hovered_digimon_changed(_digimon_key: String) -> void:
	if phase != Phase.TARGET_SELECT or _selected_action.is_empty() or _input_locked:
		return
	var hovered: Node = _controller.call("get_hovered_digimon") as Node if _controller != null and _controller.has_method("get_hovered_digimon") else null
	if hovered != null and _targeting_system.is_valid_target(_field, current_actor, hovered, _selected_action):
		_hover_target = hovered
		if _selected_target == null:
			_update_combat_preview(hovered, false)
	else:
		_hover_target = null
		if _selected_target == null:
			_combat_preview.clear()
			if _field != null and _field.has_method("clear_target_preview"):
				_field.call("clear_target_preview")
	_refresh_hud()


func _update_combat_preview(target: Node, locked: bool) -> void:
	if target == null or _selected_action.is_empty():
		_combat_preview.clear()
		return
	var damage_preview: Dictionary = _damage_calculator.preview(current_actor, target, _selected_action)
	var current_hp := _current_hp(target)
	var predicted_damage := int(damage_preview.get("damage", 0))
	_combat_preview = damage_preview.duplicate(true)
	_combat_preview.merge({
		"valid": true,
		"locked": locked,
		"action_id": String(_selected_action.get("id", "")),
		"action_name": String(_selected_action.get("name", "ACTION")),
		"target_id": _instance_id(target),
		"target_name": _display_name(target),
		"target_hp": current_hp,
		"target_hp_after": maxi(0, current_hp - predicted_damage),
		"sp_cost": int(_selected_action.get("spCost", 0)),
		"recovery_cost": float(_selected_action.get("recoveryCost", 30.0)),
		"turn_recovery": _preview_recovery_cost,
	}, true)
	if _field != null and _field.has_method("set_target_preview_grid"):
		_field.call("set_target_preview_grid", _grid_for_actor(target))


func _execute_selected_action() -> void:
	var action := _selected_action.duplicate(true)
	var target := _selected_target
	if action.is_empty() or target == null:
		return
	_input_locked = true
	phase = Phase.ACTION_RESOLVE
	var sp_cost := maxi(0, int(action.get("spCost", 0)))
	if sp_cost > 0 and (not current_actor.has_method("spend_sp") or not bool(current_actor.call("spend_sp", sp_cost))):
		_input_locked = false
		cancel_current_action()
		return

	_event_bus.emit_event("action_started", {
		"actor_id": _instance_id(current_actor),
		"target_id": _instance_id(target),
		"action_id": String(action.get("id", "")),
	})
	var hit := _battle_rng.roll_percent(float(action.get("accuracy", 100.0)))
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
						var preview := _damage_calculator.preview(current_actor, target, action)
						critical = bool(action.get("canCrit", false)) and _battle_rng.roll_percent(float(preview.get("crit_chance", 0.0)))
						var raw_damage := int(preview.get("critical_damage" if critical else "damage", 0))
						applied_damage = int(target.call("take_damage", raw_damage)) if target.has_method("take_damage") else 0
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
						var chance := float(effect.get("chance", 100.0))
						if _battle_rng.roll_percent(chance):
							var status_id := String(effect.get("status", ""))
							var duration := int(effect.get("duration", -1))
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

	if not _actor_available(target):
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


func _show_action_range() -> void:
	if _field == null or not _field.has_method("set_action_range"):
		return
	var grids := _targeting_system.grids_in_range(_field, current_actor, _selected_action)
	_field.call("set_action_range", grids, "skill" if String(_selected_action.get("id", "")) != "basic_attack" else "attack")


func _clear_action_selection(reset_preview: bool) -> void:
	_selected_action.clear()
	_selected_target = null
	_hover_target = null
	_combat_preview.clear()
	if _field != null and _field.has_method("clear_action_range"):
		_field.call("clear_action_range")
	if reset_preview:
		_preview_recovery_cost = _pending_recovery_cost
		turn_order_changed.emit()


func _can_act_now() -> bool:
	return (
		not _battle_over
		and current_actor != null
		and _is_user_controlled(current_actor)
		and not _input_locked
		and not _has_acted
		and (phase == Phase.COMMAND or phase == Phase.ACTION_SELECT)
	)


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
		"range": {"min": 1, "max": _battle_config.integer("targeting", "basicAttackRange", 1), "requiresLineOfSight": false},
		"area": {"shape": "single", "radius": 0},
		"targets": ["enemy"],
		"canCrit": true,
		"effects": [{"type": "damage"}],
	}


func get_available_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if current_actor == null:
		return result
	var skill_ids: Array[String] = []
	if current_actor.has_method("get_equipped_skill_ids"):
		skill_ids = current_actor.call("get_equipped_skill_ids")
	if skill_ids.is_empty():
		var species_name := _display_name(current_actor)
		var level := int(current_actor.call("get_level")) if current_actor.has_method("get_level") else 1
		var fallback := _action_database.get_known_actions(species_name, level)
		for action: Dictionary in fallback:
			skill_ids.append(String(action.get("id", "")))
	for skill_id: String in skill_ids:
		var action := _action_database.get_action(skill_id)
		if action.is_empty():
			continue
		action["affordable"] = _current_sp(current_actor) >= int(action.get("spCost", 0))
		result.append(action)
	return result


func get_combat_preview() -> Dictionary:
	return _combat_preview.duplicate(true)


func get_selected_action() -> Dictionary:
	return _selected_action.duplicate(true)


func preview_skill_recovery(skill_id: String) -> void:
	if _has_acted or current_actor == null:
		return
	var action := _action_database.get_action(skill_id)
	if action.is_empty():
		return
	_preview_recovery_cost = clampf(_pending_recovery_cost + float(action.get("recoveryCost", 30.0)), MIN_RECOVERY_COST, MAX_RECOVERY_COST)
	_notify_turn_order_changed()


func preview_basic_attack_recovery() -> void:
	if _has_acted:
		return
	_preview_recovery_cost = clampf(_pending_recovery_cost + _battle_config.number("turnRecovery", "basicAttack", 30.0), MIN_RECOVERY_COST, MAX_RECOVERY_COST)
	_notify_turn_order_changed()


func clear_action_recovery_preview() -> void:
	_preview_recovery_cost = _pending_recovery_cost
	_notify_turn_order_changed()


func _run_enemy_turn(actor: Node) -> void:
	await get_tree().create_timer(0.38).timeout
	if _battle_over or current_actor != actor or not _actor_available(actor):
		return
	var opponents := _alive_actors(true)
	var actions := _enemy_actions(actor)
	var choice: Dictionary = _battle_ai.choose_action(_field, actor, opponents, actions)
	if choice.is_empty() and not _has_moved:
		await _enemy_move_toward(actor, opponents)
		if _battle_over or current_actor != actor:
			return
		choice = _battle_ai.choose_action(_field, actor, opponents, actions)
	if not choice.is_empty():
		_selected_action = (choice.get("action", {}) as Dictionary).duplicate(true)
		_selected_target = choice.get("target") as Node
		_preview_recovery_cost = _pending_recovery_cost + float(_selected_action.get("recoveryCost", 30.0))
		_update_combat_preview(_selected_target, true)
		_execute_selected_action()
		if current_actor == actor and not _battle_over and _has_acted and not _has_moved:
			call_deferred("_end_turn")
		return
	phase = Phase.ACTION_RESOLVE
	_refresh_hud()
	call_deferred("_end_turn")


func _enemy_move_toward(actor: Node, opponents: Array[Node]) -> void:
	if opponents.is_empty() or actor == null:
		return
	var origin := _grid_for_actor(actor)
	var reachable: Dictionary = _movement_system.get_reachable_tiles(_field, _controller, actor, origin, _movement_for(actor))
	if reachable.is_empty():
		return
	var best_grid := origin
	var best_score := _distance_to_nearest(origin, opponents)
	var best_cost := 0
	for raw_grid in reachable.keys():
		var grid := Vector2i(raw_grid)
		var score := _distance_to_nearest(grid, opponents)
		var cost := int(reachable[grid])
		if score < best_score or (score == best_score and cost < best_cost):
			best_grid = grid
			best_score = score
			best_cost = cost
	if best_grid == origin:
		return
	var path := _movement_system.find_path(_field, _controller, actor, origin, best_grid, _movement_for(actor))
	if path.is_empty():
		return
	_input_locked = true
	phase = Phase.MOVING
	_refresh_hud()
	await actor.call("move_along_grid_path", path, _field)
	_has_moved = true
	_last_move_path = path.duplicate()
	_movement_recovery_added = float(_movement_system.get_path_cost(_field, actor, path)) * _movement_recovery_per_point()
	_pending_recovery_cost += _movement_recovery_added
	_preview_recovery_cost = _pending_recovery_cost
	_input_locked = false
	phase = Phase.COMMAND
	_event_bus.emit_event("unit_moved", {
		"actor_id": _instance_id(actor),
		"movement_spent": _movement_system.get_path_cost(_field, actor, path),
		"recovery_added": _movement_recovery_added,
	})
	turn_order_changed.emit()


func _distance_to_nearest(grid: Vector2i, actors: Array[Node]) -> int:
	var best := 999999
	for actor: Node in actors:
		var target_grid := _grid_for_actor(actor)
		best = mini(best, absi(grid.x - target_grid.x) + absi(grid.y - target_grid.y))
	return best


func _enemy_actions(actor: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = [_basic_attack_definition()]
	var ids: Array[String] = actor.call("get_equipped_skill_ids") if actor != null and actor.has_method("get_equipped_skill_ids") else []
	for skill_id: String in ids:
		var action := _action_database.get_action(skill_id)
		if not action.is_empty() and _current_sp(actor) >= int(action.get("spCost", 0)):
			result.append(action)
	return result


func _actor_knows_skill(actor: Node, skill_id: String) -> bool:
	if actor == null:
		return false
	if actor.has_method("get_equipped_skill_ids"):
		return (actor.call("get_equipped_skill_ids") as Array).has(skill_id)
	return false


func _end_turn() -> void:
	if _battle_over or current_actor == null:
		return
	var expired := _status_system.on_turn_end(current_actor)
	for status_id: String in expired:
		_event_bus.emit_event("status_expired", {"target_id": _instance_id(current_actor), "status": status_id})
	if current_actor.has_method("get_statuses"):
		notify_speed_changed()
	if current_actor.get("battle_state") != null:
		current_actor.get("battle_state").commit_resources_to_instance()
	_turn_scheduler.consume_turn(current_actor, _pending_recovery_cost)
	_pending_recovery_cost = _base_turn_recovery()
	_preview_recovery_cost = _pending_recovery_cost
	super._end_turn()
	turn_order_changed.emit()


func _handle_knockout(actor: Node) -> void:
	if actor == null:
		return
	actor.set("is_defending", false)
	if actor.has_method("set_turn_active"):
		actor.call("set_turn_active", false)
	actor.modulate = Color(0.56, 0.60, 0.66, 0.50)
	var actor_id := _instance_id(actor)
	_event_bus.emit_event("unit_knocked_out", {
		"target_id": actor_id,
		"target_name": _display_name(actor),
		"is_player": bool(actor.get("is_player_controlled")),
	})
	if not bool(actor.get("is_player_controlled")) and not _defeated_enemy_ids.has(actor_id):
		_defeated_enemy_ids.append(actor_id)
	turn_order_changed.emit()


func _check_battle_end() -> bool:
	if _battle_over:
		return true
	var players := _alive_actors(true)
	var enemies := _alive_actors(false)
	if players.is_empty():
		_finish_battle(false)
		return true
	if enemies.is_empty():
		_finish_battle(true)
		return true
	return false


func _finish_battle(victory: bool) -> void:
	_battle_over = true
	phase = Phase.TURN_END
	_input_locked = true
	_clear_manual_path_visuals()
	_clear_action_selection(false)
	if current_actor != null and current_actor.has_method("set_turn_active"):
		current_actor.call("set_turn_active", false)
	_battle_result = _build_battle_result(victory)
	_event_bus.emit_event("battle_finished", _battle_result)
	battle_finished.emit(_battle_result.duplicate(true))
	turn_order_changed.emit()
	_refresh_hud()


func _build_battle_result(victory: bool) -> Dictionary:
	var bits := 0
	var digi_data: Dictionary = {}
	if victory:
		for actor: Node in _turn_order:
			if actor == null or bool(actor.get("is_player_controlled")):
				continue
			var actor_id := _instance_id(actor)
			if not _defeated_enemy_ids.has(actor_id):
				continue
			var species_raw = actor.get("species_data")
			var species: Dictionary = species_raw if species_raw is Dictionary else {}
			var level := int(actor.call("get_level")) if actor.has_method("get_level") else 1
			bits += maxi(1, int(species.get("bitFarmingRate", 5))) * maxi(1, level)
			var species_name := String(species.get("name", "Unknown"))
			var rank := String(species.get("rank", "Rookie"))
			var data_gain := _digi_data_for_rank(rank) + maxi(0, level - 1)
			digi_data[species_name] = int(digi_data.get(species_name, 0)) + data_gain
	return {
		"victory": victory,
		"acts": _battle_act_number,
		"battle_seed": _battle_rng.snapshot_seed(),
		"bits": bits,
		"digi_data": digi_data,
		"defeated_enemy_count": _defeated_enemy_ids.size(),
	}


func _digi_data_for_rank(rank: String) -> int:
	match rank.to_lower():
		"fresh": return 3
		"in-training": return 5
		"rookie": return 10
		"champion": return 18
		"ultimate": return 28
		"mega": return 40
		"ultra": return 55
	return 10


func get_hud_state() -> Dictionary:
	var state: Dictionary = super.get_hud_state()
	state["turn_number"] = maxi(1, _battle_act_number)
	state["battle_over"] = _battle_over
	state["battle_result"] = _battle_result.duplicate(true)
	state["has_acted"] = _has_acted
	state["has_moved"] = _has_moved
	state["is_targeting"] = phase == Phase.TARGET_SELECT
	state["selected_action"] = _selected_action.duplicate(true)
	state["can_confirm_action"] = phase == Phase.TARGET_SELECT and _selected_target != null and not _input_locked
	if current_actor == null:
		return state
	if current_actor.has_method("get_display_name"):
		state["actor_name"] = String(current_actor.call("get_display_name"))
	if current_actor.has_method("get_level"):
		state["level"] = int(current_actor.call("get_level"))
	if current_actor.has_method("get_potential"):
		state["potential"] = int(current_actor.call("get_potential"))
	if current_actor.has_method("get_instance_id"):
		state["instance_id"] = String(current_actor.call("get_instance_id"))
	if current_actor.has_method("get_species_seed"):
		state["species_seed"] = String(current_actor.call("get_species_seed"))
	if current_actor.has_method("get_movement_type"):
		state["movement_type"] = String(current_actor.call("get_movement_type"))
	if current_actor.has_method("get_final_stat"):
		state["speed"] = int(current_actor.call("get_final_stat", "speed"))
		state["int"] = int(current_actor.call("get_final_stat", "int"))
		state["max_sp"] = int(current_actor.call("get_final_stat", "sp"))
	state["current_sp"] = _current_sp(current_actor)
	state["initiative"] = _turn_scheduler.get_actor_initiative(current_actor)
	state["recovery_cost"] = _pending_recovery_cost
	state["preview_recovery_cost"] = _preview_recovery_cost
	var player_turn := _is_user_controlled(current_actor) and not _battle_over
	state["can_move"] = player_turn and not _has_moved and not _input_locked and (phase == Phase.COMMAND or phase == Phase.ACTION_SELECT)
	state["can_attack"] = player_turn and not _has_acted and not _input_locked and (phase == Phase.COMMAND or phase == Phase.ACTION_SELECT)
	state["can_skill"] = bool(state["can_attack"]) and not get_available_skills().is_empty()
	state["can_defend"] = bool(state["can_attack"])
	state["can_wait"] = player_turn and not _input_locked and (phase == Phase.COMMAND or phase == Phase.ACTION_SELECT)
	state["can_undo"] = player_turn and _has_moved and not _has_acted and not _input_locked and (phase == Phase.ACTION_SELECT or phase == Phase.COMMAND)
	return state


func get_turn_preview(total_slots: int = 7) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var slots := maxi(1, total_slots)
	if _battle_over:
		return result
	if current_actor != null and is_instance_valid(current_actor):
		result.append(_timeline_entry(current_actor, true, 0))
		var upcoming := _turn_scheduler.preview_next_actors(_turn_order, current_actor, slots - 1, _preview_recovery_cost)
		for index in range(upcoming.size()):
			result.append(_timeline_entry(upcoming[index], false, index + 1))
		return result
	var upcoming := _turn_scheduler.preview_next_actors(_turn_order, null, slots)
	for index in range(upcoming.size()):
		result.append(_timeline_entry(upcoming[index], false, index))
	return result


func preview_action_recovery_cost(recovery_cost: float) -> void:
	_preview_recovery_cost = clampf(recovery_cost, MIN_RECOVERY_COST, MAX_RECOVERY_COST)
	_notify_turn_order_changed()


func set_action_recovery_cost(recovery_cost: float) -> void:
	_pending_recovery_cost = clampf(recovery_cost, MIN_RECOVERY_COST, MAX_RECOVERY_COST)
	_preview_recovery_cost = _pending_recovery_cost
	_notify_turn_order_changed()


func delay_actor_initiative(actor: Node, amount: float) -> void:
	_turn_scheduler.delay_actor(actor, amount)
	_notify_turn_order_changed()


func advance_actor_initiative(actor: Node, amount: float) -> void:
	_turn_scheduler.advance_actor(actor, amount)
	_notify_turn_order_changed()


func set_actor_initiative(actor: Node, value: float) -> void:
	_turn_scheduler.set_actor_initiative(actor, value)
	_notify_turn_order_changed()


func notify_speed_changed() -> void:
	_notify_turn_order_changed()


func focus_actor_by_instance_id(instance_id: String) -> void:
	if instance_id.is_empty():
		return
	for actor: Node in _turn_order:
		if actor == null or not is_instance_valid(actor) or not actor.has_method("get_instance_id"):
			continue
		if String(actor.call("get_instance_id")) != instance_id:
			continue
		var camera := get_viewport().get_camera_2d()
		if camera != null and camera.has_method("focus_on"):
			camera.call("focus_on", actor.global_position)
		return


func _timeline_entry(actor: Node, is_current: bool, slot: int) -> Dictionary:
	if actor == null or not is_instance_valid(actor):
		return {}
	var level := int(actor.call("get_level")) if actor.has_method("get_level") else 1
	var speed := maxi(1, int(actor.call("get_final_stat", "speed"))) if actor.has_method("get_final_stat") else 1
	return {
		"slot": slot,
		"is_current": is_current,
		"instance_id": _instance_id(actor),
		"actor_name": _display_name(actor),
		"digimon_key": String(actor.get("digimon_key")).to_lower(),
		"level": level,
		"speed": speed,
		"is_player": bool(actor.get("is_player_controlled")),
		"initiative": _turn_scheduler.get_actor_initiative(actor),
	}


func _notify_turn_order_changed() -> void:
	turn_order_changed.emit()
	_refresh_hud()


func _on_battle_event(event: Dictionary) -> void:
	combat_event.emit(event.duplicate(true))


func _alive_actors(player_team: bool) -> Array[Node]:
	var result: Array[Node] = []
	for actor: Node in _turn_order:
		if actor == null or not is_instance_valid(actor):
			continue
		if bool(actor.get("is_player_controlled")) != player_team:
			continue
		if _actor_available(actor):
			result.append(actor)
	return result


func _actor_available(actor: Node) -> bool:
	return actor != null and is_instance_valid(actor) and (not actor.has_method("is_available_for_turn") or bool(actor.call("is_available_for_turn")))


func _current_hp(actor: Node) -> int:
	return int(actor.call("get_current_hp")) if actor != null and actor.has_method("get_current_hp") else 0


func _current_sp(actor: Node) -> int:
	return int(actor.call("get_current_sp")) if actor != null and actor.has_method("get_current_sp") else 0


func _instance_id(actor: Node) -> String:
	return String(actor.call("get_instance_id")) if actor != null and actor.has_method("get_instance_id") else ""


func _display_name(actor: Node) -> String:
	if actor == null:
		return "Digimon"
	return String(actor.call("get_display_name")) if actor.has_method("get_display_name") else String(actor.get("digimon_key")).capitalize()


func _base_turn_recovery() -> float:
	return _battle_config.number("turnRecovery", "base", 55.0)


func _movement_recovery_per_point() -> float:
	return _battle_config.number("turnRecovery", "movementPerPoint", 4.0)
