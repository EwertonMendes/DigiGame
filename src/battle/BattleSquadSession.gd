extends RefCounted
class_name BattleSquadSession

const BattleDigimonScript = preload("res://src/battle/BattleDigimon.gd")

var _instances_by_id: Dictionary = {}
var _squad_ids: Array[String] = []
var _initial_active_ids: Array[String] = []
var _initial_reserve_ids: Array[String] = []
var _fielded_ids: Array[String] = []
var _states_by_id: Dictionary = {}
var _participated_ids: Dictionary = {}


func configure(
	active_members: Array[DigimonInstance],
	reserve_members: Array[DigimonInstance],
	deployed_ids: Array[String]
) -> void:
	_instances_by_id.clear()
	_squad_ids.clear()
	_initial_active_ids.clear()
	_initial_reserve_ids.clear()
	_fielded_ids.clear()
	_states_by_id.clear()
	_participated_ids.clear()

	for instance: DigimonInstance in active_members:
		_register_instance(instance, _initial_active_ids)
	for instance: DigimonInstance in reserve_members:
		_register_instance(instance, _initial_reserve_ids)

	for raw_id: String in deployed_ids:
		var instance_id := raw_id.strip_edges()
		if _instances_by_id.has(instance_id) and not _fielded_ids.has(instance_id):
			_fielded_ids.append(instance_id)


func _register_instance(instance: DigimonInstance, role_ids: Array[String]) -> void:
	if instance == null or instance.id.strip_edges().is_empty() or _instances_by_id.has(instance.id):
		return
	_instances_by_id[instance.id] = instance
	_squad_ids.append(instance.id)
	role_ids.append(instance.id)


func get_instance(instance_id: String) -> DigimonInstance:
	var instance = _instances_by_id.get(instance_id.strip_edges())
	return instance as DigimonInstance if instance is DigimonInstance else null


func get_squad_ids() -> Array[String]:
	return _squad_ids.duplicate()


func get_initial_active_ids() -> Array[String]:
	return _initial_active_ids.duplicate()


func get_initial_reserve_ids() -> Array[String]:
	return _initial_reserve_ids.duplicate()


func get_fielded_ids() -> Array[String]:
	return _fielded_ids.duplicate()


func get_state(instance_id: String) -> BattleDigimon:
	var clean_id := instance_id.strip_edges()
	var existing = _states_by_id.get(clean_id)
	if existing is BattleDigimon:
		return existing as BattleDigimon
	var instance := get_instance(clean_id)
	if instance == null:
		return null
	var state := BattleDigimonScript.new(instance, "player") as BattleDigimon
	_states_by_id[clean_id] = state
	return state


func attach_actor(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var instance = actor.get("digimon_instance")
	if not instance is DigimonInstance:
		return false
	var typed_instance := instance as DigimonInstance
	if not _instances_by_id.has(typed_instance.id):
		return false
	var state := get_state(typed_instance.id)
	if state == null:
		return false
	if actor.has_method("adopt_battle_state"):
		actor.call("adopt_battle_state", state)
	else:
		actor.set("battle_state", state)
	if not _fielded_ids.has(typed_instance.id):
		_fielded_ids.append(typed_instance.id)
	_participated_ids[typed_instance.id] = true
	return true


func bench(instance_id: String) -> void:
	var clean_id := instance_id.strip_edges()
	_fielded_ids.erase(clean_id)
	var state := get_state(clean_id)
	if state != null:
		# Bench members never continue charging CT off-field. Returning to the
		# battlefield always starts from neutral initiative.
		state.set_initiative(0.0)


func prepare_deployment(instance_id: String) -> BattleDigimon:
	var state := get_state(instance_id)
	if state != null:
		state.set_initiative(0.0)
	return state


func mark_deployed(instance_id: String) -> void:
	var clean_id := instance_id.strip_edges()
	if clean_id.is_empty() or not _instances_by_id.has(clean_id):
		return
	if not _fielded_ids.has(clean_id):
		_fielded_ids.append(clean_id)
	_participated_ids[clean_id] = true


func is_fielded(instance_id: String) -> bool:
	return _fielded_ids.has(instance_id.strip_edges())


func is_available_on_bench(instance_id: String) -> bool:
	var clean_id := instance_id.strip_edges()
	if clean_id.is_empty() or not _instances_by_id.has(clean_id) or _fielded_ids.has(clean_id):
		return false
	var state = _states_by_id.get(clean_id)
	if state is BattleDigimon:
		return not (state as BattleDigimon).is_knocked_out()
	var instance := get_instance(clean_id)
	return instance != null and not instance.is_fainted()


func get_available_bench_ids() -> Array[String]:
	var result: Array[String] = []
	for instance_id: String in _squad_ids:
		if is_available_on_bench(instance_id):
			result.append(instance_id)
	return result


func get_available_bench_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance_id: String in get_available_bench_ids():
		var instance := get_instance(instance_id)
		if instance != null:
			result.append(instance)
	return result


func has_available_bench() -> bool:
	return not get_available_bench_ids().is_empty()


func was_participant(instance_id: String) -> bool:
	return bool(_participated_ids.get(instance_id.strip_edges(), false))


func is_knocked_out(instance_id: String) -> bool:
	var clean_id := instance_id.strip_edges()
	var state = _states_by_id.get(clean_id)
	if state is BattleDigimon:
		return (state as BattleDigimon).is_knocked_out()
	var instance := get_instance(clean_id)
	return instance == null or instance.is_fainted()


func commit_all_resources() -> void:
	for raw_state in _states_by_id.values():
		if raw_state is BattleDigimon:
			(raw_state as BattleDigimon).commit_resources_to_instance()


func reward_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for instance_id: String in _squad_ids:
		var instance := get_instance(instance_id)
		if instance == null:
			continue
		snapshots.append({
			"instance_id": instance.id,
			"level": instance.level,
			"participated": was_participant(instance_id),
			"knocked_out": is_knocked_out(instance_id),
			"initial_role": PlayerCollection.SQUAD_ROLE_ACTIVE if _initial_active_ids.has(instance_id) else PlayerCollection.SQUAD_ROLE_RESERVE,
		})
	return snapshots
