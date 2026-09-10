extends "res://src/BattleController.gd"

signal turn_order_changed

const TurnSchedulerScript = preload("res://src/battle/TurnScheduler.gd")
const DEFAULT_TURN_RECOVERY_COST := 100.0
const MIN_RECOVERY_COST := 1.0
const MAX_RECOVERY_COST := 300.0

var _turn_scheduler = TurnSchedulerScript.new()
var _pending_recovery_cost: float = DEFAULT_TURN_RECOVERY_COST
var _preview_recovery_cost: float = DEFAULT_TURN_RECOVERY_COST
var _battle_act_number: int = 0


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
	_turn_index = -1
	_battle_act_number = 0
	_pending_recovery_cost = DEFAULT_TURN_RECOVERY_COST
	_preview_recovery_cost = DEFAULT_TURN_RECOVERY_COST
	_start_next_turn()


func _start_next_turn() -> void:
	if _turn_order.is_empty():
		return

	var next_actor: Node = _turn_scheduler.next_actor(_turn_order)
	if next_actor == null:
		return

	_battle_act_number += 1
	current_actor = next_actor
	_turn_index = _turn_order.find(current_actor)
	_pending_recovery_cost = DEFAULT_TURN_RECOVERY_COST
	_preview_recovery_cost = DEFAULT_TURN_RECOVERY_COST
	phase = Phase.TURN_START
	_has_moved = false
	_last_move_path.clear()
	_planned_move_path.clear()
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	_waypoints.clear()
	_reachable_tiles.clear()
	_input_locked = false
	current_actor.set("is_defending", false)
	_turn_start_grid = _grid_for_actor(current_actor)
	_sync_turn_highlight()
	_focus_current_actor()

	phase = Phase.COMMAND
	_refresh_hud()
	turn_order_changed.emit()
	if not _is_user_controlled(current_actor):
		_skip_enemy_placeholder_turn(current_actor)


func _end_turn() -> void:
	if current_actor != null and is_instance_valid(current_actor):
		_turn_scheduler.consume_turn(current_actor, _pending_recovery_cost)
	_pending_recovery_cost = DEFAULT_TURN_RECOVERY_COST
	_preview_recovery_cost = DEFAULT_TURN_RECOVERY_COST
	super._end_turn()
	turn_order_changed.emit()


func get_hud_state() -> Dictionary:
	var state: Dictionary = super.get_hud_state()
	state["turn_number"] = maxi(1, _battle_act_number)
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
	state["initiative"] = _turn_scheduler.get_actor_initiative(current_actor)
	state["recovery_cost"] = _pending_recovery_cost
	state["preview_recovery_cost"] = _preview_recovery_cost
	return state


func get_turn_preview(total_slots: int = 7) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var slots := maxi(1, total_slots)

	if current_actor != null and is_instance_valid(current_actor):
		result.append(_timeline_entry(current_actor, true, 0))
		var upcoming := _turn_scheduler.preview_next_actors(
			_turn_order,
			current_actor,
			slots - 1,
			_preview_recovery_cost
		)
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


func clear_action_recovery_preview() -> void:
	_preview_recovery_cost = _pending_recovery_cost
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
	# CT already accumulated is preserved; only future charge speed changes.
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
	var actor_name := String(actor.get("digimon_key")).capitalize()
	if actor.has_method("get_display_name"):
		actor_name = String(actor.call("get_display_name"))
	var instance_id := ""
	if actor.has_method("get_instance_id"):
		instance_id = String(actor.call("get_instance_id"))
	var level := 1
	if actor.has_method("get_level"):
		level = int(actor.call("get_level"))
	var speed := 1
	if actor.has_method("get_final_stat"):
		speed = maxi(1, int(actor.call("get_final_stat", "speed")))
	return {
		"slot": slot,
		"is_current": is_current,
		"instance_id": instance_id,
		"actor_name": actor_name,
		"digimon_key": String(actor.get("digimon_key")).to_lower(),
		"level": level,
		"speed": speed,
		"is_player": bool(actor.get("is_player_controlled")),
		"initiative": _turn_scheduler.get_actor_initiative(actor),
	}


func _notify_turn_order_changed() -> void:
	turn_order_changed.emit()
	_refresh_hud()
