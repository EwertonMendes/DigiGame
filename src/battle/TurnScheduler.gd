extends RefCounted
class_name TurnScheduler

const READY_THRESHOLD := 100.0
const DEFAULT_RECOVERY_COST := 100.0
const SPEED_INFLUENCE := 0.5
const MIN_RATE := 0.1
const EPSILON := 0.0001


func reset(actors: Array[Node]) -> void:
	for actor: Node in actors:
		if _is_available(actor):
			_set_initiative(actor, 0.0)


func next_actor(actors: Array[Node]) -> Node:
	var available := _available_actors(actors)
	if available.is_empty():
		return null

	var ready := _ready_actors(available)
	if ready.is_empty():
		var delta_time := _time_until_next_ready(available)
		for actor: Node in available:
			_set_initiative(actor, _initiative(actor) + _initiative_rate(actor) * delta_time)
		ready = _ready_actors(available)

	return _best_ready_actor(ready)


func consume_turn(actor: Node, recovery_cost: float = DEFAULT_RECOVERY_COST) -> void:
	if not _is_available(actor):
		return
	_set_initiative(actor, _initiative(actor) - maxf(0.0, recovery_cost))


func advance_actor(actor: Node, amount: float) -> void:
	if not _is_available(actor):
		return
	_set_initiative(actor, _initiative(actor) + maxf(0.0, amount))


func delay_actor(actor: Node, amount: float) -> void:
	if not _is_available(actor):
		return
	_set_initiative(actor, _initiative(actor) - maxf(0.0, amount))


func set_actor_initiative(actor: Node, value: float) -> void:
	if not _is_available(actor):
		return
	_set_initiative(actor, value)


func get_actor_initiative(actor: Node) -> float:
	return _initiative(actor)


func preview_next_actors(
	actors: Array[Node],
	current_actor: Node,
	count: int,
	current_recovery_cost: float = DEFAULT_RECOVERY_COST
) -> Array[Node]:
	var available := _available_actors(actors)
	var result: Array[Node] = []
	if available.is_empty() or count <= 0:
		return result

	var simulated: Dictionary = {}
	for actor: Node in available:
		simulated[actor] = _initiative(actor)

	if current_actor != null and simulated.has(current_actor):
		simulated[current_actor] = float(simulated[current_actor]) - maxf(0.0, current_recovery_cost)

	while result.size() < count:
		var actor := _next_simulated_actor(available, simulated)
		if actor == null:
			break
		result.append(actor)
		simulated[actor] = float(simulated.get(actor, 0.0)) - DEFAULT_RECOVERY_COST

	return result


func _next_simulated_actor(actors: Array[Node], simulated: Dictionary) -> Node:
	var ready: Array[Node] = []
	for actor: Node in actors:
		if float(simulated.get(actor, 0.0)) + EPSILON >= READY_THRESHOLD:
			ready.append(actor)

	if ready.is_empty():
		var delta_time := INF
		for actor: Node in actors:
			var remaining := READY_THRESHOLD - float(simulated.get(actor, 0.0))
			var candidate_time := remaining / _initiative_rate(actor)
			if candidate_time < delta_time:
				delta_time = candidate_time
		if not is_finite(delta_time):
			return null
		for actor: Node in actors:
			simulated[actor] = float(simulated.get(actor, 0.0)) + _initiative_rate(actor) * maxf(0.0, delta_time)
		for actor: Node in actors:
			if float(simulated.get(actor, 0.0)) + EPSILON >= READY_THRESHOLD:
				ready.append(actor)

	if ready.is_empty():
		return null
	return _best_ready_actor_from_values(ready, simulated)


func _available_actors(actors: Array[Node]) -> Array[Node]:
	var result: Array[Node] = []
	for actor: Node in actors:
		if _is_available(actor):
			result.append(actor)
	return result


func _ready_actors(actors: Array[Node]) -> Array[Node]:
	var result: Array[Node] = []
	for actor: Node in actors:
		if _initiative(actor) + EPSILON >= READY_THRESHOLD:
			result.append(actor)
	return result


func _time_until_next_ready(actors: Array[Node]) -> float:
	var best_time := INF
	for actor: Node in actors:
		var remaining := READY_THRESHOLD - _initiative(actor)
		var candidate_time := remaining / _initiative_rate(actor)
		if candidate_time < best_time:
			best_time = candidate_time
	return maxf(0.0, best_time if is_finite(best_time) else 0.0)


func _best_ready_actor(actors: Array[Node]) -> Node:
	if actors.is_empty():
		return null
	var best: Node = actors[0]
	for index in range(1, actors.size()):
		var candidate: Node = actors[index]
		if _is_better(candidate, best, _initiative(candidate), _initiative(best)):
			best = candidate
	return best


func _best_ready_actor_from_values(actors: Array[Node], values: Dictionary) -> Node:
	if actors.is_empty():
		return null
	var best: Node = actors[0]
	for index in range(1, actors.size()):
		var candidate: Node = actors[index]
		if _is_better(candidate, best, float(values.get(candidate, 0.0)), float(values.get(best, 0.0))):
			best = candidate
	return best


func _is_better(candidate: Node, current: Node, candidate_ct: float, current_ct: float) -> bool:
	if candidate_ct > current_ct + EPSILON:
		return true
	if current_ct > candidate_ct + EPSILON:
		return false
	var candidate_speed := _speed(candidate)
	var current_speed := _speed(current)
	if candidate_speed != current_speed:
		return candidate_speed > current_speed
	return _stable_key(candidate).naturalnocasecmp_to(_stable_key(current)) < 0


func _initiative_rate(actor: Node) -> float:
	return maxf(MIN_RATE, pow(float(maxi(1, _speed(actor))), SPEED_INFLUENCE))


func _speed(actor: Node) -> int:
	if actor != null and actor.has_method("get_final_stat"):
		return maxi(1, int(actor.call("get_final_stat", "speed")))
	return 1


func _stable_key(actor: Node) -> String:
	if actor != null and actor.has_method("get_instance_id"):
		var instance_id := String(actor.call("get_instance_id"))
		if not instance_id.is_empty():
			return instance_id
	return String(actor.get_path()) if actor != null and is_instance_valid(actor) else ""


func _initiative(actor: Node) -> float:
	if actor != null and actor.has_method("get_initiative"):
		return float(actor.call("get_initiative"))
	return 0.0


func _set_initiative(actor: Node, value: float) -> void:
	if actor != null and actor.has_method("set_initiative"):
		actor.call("set_initiative", value)


func _is_available(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if actor.has_method("is_available_for_turn"):
		return bool(actor.call("is_available_for_turn"))
	return true
