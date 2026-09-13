extends RefCounted
class_name DigimonEvolutionService

const ProgressionScript = preload("res://src/digimon/DigimonProgression.gd")
const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")
const RequirementEvaluatorScript = preload("res://src/digimon/EvolutionRequirementEvaluator.gd")

var _progression = ProgressionScript.new()
var _action_database = ActionDatabaseScript.new()
var _requirements: EvolutionRequirementEvaluator = RequirementEvaluatorScript.new()


func _init() -> void:
	_action_database.load_default()


func can_digivolve(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, context: Dictionary = {}) -> bool:
	return _can_transition(instance, target_seed, database, calculator, false, context)


func can_degenerate(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, context: Dictionary = {}) -> bool:
	return _can_transition(instance, target_seed, database, calculator, true, context)


func get_available_evolutions(instance: DigimonInstance, database: DigimonDatabase, calculator: DigimonStatCalculator, context: Dictionary = {}) -> Array[Dictionary]:
	return _available_routes(instance, database, calculator, false, context)


func get_available_degenerations(instance: DigimonInstance, database: DigimonDatabase, calculator: DigimonStatCalculator, context: Dictionary = {}) -> Array[Dictionary]:
	return _available_routes(instance, database, calculator, true, context)


func digivolve(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, context: Dictionary = {}) -> bool:
	if not can_digivolve(instance, target_seed, database, calculator, context):
		return false
	return _apply_transition(instance, target_seed, database, calculator, false)


func degenerate(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, context: Dictionary = {}) -> bool:
	if not can_degenerate(instance, target_seed, database, calculator, context):
		return false
	return _apply_transition(instance, target_seed, database, calculator, true)


func _can_transition(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, degenerating: bool, context: Dictionary) -> bool:
	if instance == null or database == null or calculator == null:
		return false
	var current_species: Dictionary = database.get_by_seed(instance.species_seed)
	var target_species: Dictionary = database.get_by_seed(target_seed)
	if current_species.is_empty() or target_species.is_empty():
		return false
	var route: Dictionary = _find_route(current_species, target_seed, degenerating)
	if route.is_empty():
		return false
	return _requirements.all_met(instance, current_species, route.get("requirements", []), calculator, context)


func _available_routes(instance: DigimonInstance, database: DigimonDatabase, calculator: DigimonStatCalculator, degenerating: bool, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if instance == null or database == null:
		return result
	var species: Dictionary = database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return result
	var route_key: String = "degenerations" if degenerating else "evolutions"
	var raw_routes = species.get(route_key, [])
	if not raw_routes is Array:
		return result
	for raw_route in raw_routes:
		if not raw_route is Dictionary:
			continue
		var route: Dictionary = (raw_route as Dictionary).duplicate(true)
		var target_seed: String = String(route.get("targetSeed", ""))
		var target: Dictionary = database.get_by_seed(target_seed)
		if target.is_empty():
			continue
		route["targetName"] = String(target.get("name", "Unknown"))
		route["targetRank"] = String(target.get("rank", ""))
		var evaluations := _requirements.evaluate_all(instance, species, route.get("requirements", []), calculator, context)
		route["requirement_results"] = evaluations
		route["unlocked"] = _all_evaluations_met(evaluations)
		result.append(route)
	return result


func _find_route(species: Dictionary, target_seed: String, degenerating: bool) -> Dictionary:
	var route_key: String = "degenerations" if degenerating else "evolutions"
	var raw_routes = species.get(route_key, [])
	if not raw_routes is Array:
		return {}
	for raw_route in raw_routes:
		if raw_route is Dictionary and String((raw_route as Dictionary).get("targetSeed", "")) == target_seed:
			return (raw_route as Dictionary).duplicate(true)
	return {}


func _all_evaluations_met(evaluations: Array[Dictionary]) -> bool:
	for evaluation: Dictionary in evaluations:
		if not bool(evaluation.get("is_met", false)):
			return false
	return true


func _apply_transition(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, degenerating: bool) -> bool:
	var old_species: Dictionary = database.get_by_seed(instance.species_seed)
	var target_species: Dictionary = database.get_by_seed(target_seed)
	if old_species.is_empty() or target_species.is_empty():
		return false

	var old_seed: String = instance.species_seed
	var old_level: int = instance.level
	var direction: String = "degeneration" if degenerating else "digivolution"
	var repeat_count: int = _transition_repeat_count(instance, old_seed, target_seed, direction)
	var potential_gain: int = (
		_progression.potential_gain_for_degeneration(old_level, repeat_count)
		if degenerating
		else _progression.potential_gain_for_digivolution(old_level, repeat_count)
	)
	instance.evolution_history.append({
		"fromSeed": old_seed,
		"toSeed": target_seed,
		"fromLevel": old_level,
		"direction": direction,
		"potentialGain": potential_gain,
		"repeatIndex": repeat_count,
	})
	if instance.species_history.is_empty():
		instance.species_history.append(old_seed)
	instance.species_history.append(target_seed)
	instance.species_seed = target_seed
	instance.level = 1
	instance.exp = 0
	_progression.add_potential(instance, potential_gain)
	_sync_form_skills(instance, target_species)
	calculator.refill_instance(instance, target_species)
	if OS.is_debug_build():
		print("[Evolution] %s -> %s · %s" % [String(old_species.get("name", old_seed)), String(target_species.get("name", target_seed)), direction])
	return true


func _transition_repeat_count(instance: DigimonInstance, from_seed: String, to_seed: String, direction: String) -> int:
	var repeats := 0
	for record in instance.evolution_history:
		if String(record.get("fromSeed", "")) != from_seed:
			continue
		if String(record.get("toSeed", "")) != to_seed:
			continue
		if String(record.get("direction", "")) == direction:
			repeats += 1
	return repeats


func _sync_form_skills(instance: DigimonInstance, species: Dictionary) -> void:
	var available: Array[Dictionary] = _action_database.get_known_actions(String(species.get("name", "")), instance.level)
	for action: Dictionary in available:
		instance.learn_skill(String(action.get("id", "")), true)
