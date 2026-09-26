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


func build_transition_preview(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, direction: String) -> Dictionary:
	if instance == null or database == null or calculator == null:
		return {}
	if direction != "digivolution" and direction != "degeneration":
		return {}

	var degenerating := direction == "degeneration"
	var current_species: Dictionary = database.get_by_seed(instance.species_seed)
	var target_species: Dictionary = database.get_by_seed(target_seed)
	if current_species.is_empty() or target_species.is_empty():
		return {}
	var fusion_degeneration := degenerating and _is_fusion_degeneration(instance, target_seed, current_species)
	if _find_route(current_species, target_seed, degenerating).is_empty() and not fusion_degeneration:
		return {}

	var before_stats := calculator.get_all_stats(instance, current_species)
	var preview_instance := DigimonInstance.from_dict(instance.to_dict())
	preview_instance.species_seed = target_seed
	preview_instance.level = 1
	preview_instance.exp = 0
	var potential_gain := 0 if fusion_degeneration else _potential_gain_for_transition(instance, target_seed, degenerating)
	_progression.add_potential(preview_instance, potential_gain)
	var after_stats := calculator.get_all_stats(preview_instance, target_species)

	return {
		"direction": direction,
		"from_seed": instance.species_seed,
		"from_name": String(current_species.get("name", "Unknown")),
		"from_rank": String(current_species.get("rank", "Unknown")),
		"to_seed": target_seed,
		"to_name": String(target_species.get("name", "Unknown")),
		"to_rank": String(target_species.get("rank", "Unknown")),
		"before": _transition_snapshot(instance, before_stats),
		"after": _transition_snapshot(preview_instance, after_stats),
		"potential_gain": preview_instance.potential - instance.potential,
	}


func digivolve(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, context: Dictionary = {}) -> bool:
	if not can_digivolve(instance, target_seed, database, calculator, context):
		return false
	return _apply_transition(instance, target_seed, database, calculator, false)


func degenerate(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, context: Dictionary = {}) -> bool:
	if not can_degenerate(instance, target_seed, database, calculator, context):
		return false
	return _apply_transition(instance, target_seed, database, calculator, true)


func force_digivolve_for_debug(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator) -> bool:
	return _force_transition_for_debug(instance, target_seed, database, calculator, false)


func force_degenerate_for_debug(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator) -> bool:
	return _force_transition_for_debug(instance, target_seed, database, calculator, true)


func _force_transition_for_debug(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, degenerating: bool) -> bool:
	if instance == null or database == null or calculator == null:
		return false
	var current_species := database.get_by_seed(instance.species_seed)
	if current_species.is_empty() or database.get_by_seed(target_seed).is_empty():
		return false
	# Debug bypasses requirements, never graph topology. This keeps the tool useful
	# for testing the real transition pipeline without allowing impossible species jumps.
	if _find_route(current_species, target_seed, degenerating).is_empty():
		if not (degenerating and _is_fusion_degeneration(instance, target_seed, current_species)):
			return false
	return _apply_transition(instance, target_seed, database, calculator, degenerating)


func _can_transition(instance: DigimonInstance, target_seed: String, database: DigimonDatabase, calculator: DigimonStatCalculator, degenerating: bool, context: Dictionary) -> bool:
	if instance == null or database == null or calculator == null:
		return false
	var current_species: Dictionary = database.get_by_seed(instance.species_seed)
	var target_species: Dictionary = database.get_by_seed(target_seed)
	if current_species.is_empty() or target_species.is_empty():
		return false
	if not degenerating and String(current_species.get("rank", "")) == "Fusion":
		return false
	var route: Dictionary = _find_route(current_species, target_seed, degenerating)
	if route.is_empty():
		if degenerating and _is_fusion_degeneration(instance, target_seed, current_species):
			return true
		return false
	return _requirements.all_met(instance, current_species, route.get("requirements", []), calculator, context)


func _available_routes(instance: DigimonInstance, database: DigimonDatabase, calculator: DigimonStatCalculator, degenerating: bool, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if instance == null or database == null:
		return result
	var species: Dictionary = database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return result
	if not degenerating and String(species.get("rank", "")) == "Fusion":
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
	if degenerating and String(species.get("rank", "")) == "Fusion":
		for target_seed: String in _fusion_material_seeds(instance):
			var already_present := false
			for existing: Dictionary in result:
				if String(existing.get("targetSeed", "")) == target_seed:
					already_present = true
					break
			if already_present:
				continue
			var target := database.get_by_seed(target_seed)
			if target.is_empty():
				continue
			result.append({
				"targetSeed": target_seed,
				"targetName": String(target.get("name", "Unknown")),
				"targetRank": String(target.get("rank", "")),
				"requirements": [],
				"requirement_results": [],
				"unlocked": true,
				"fusionDegeneration": true,
			})
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
	var fusion_degeneration := degenerating and _is_fusion_degeneration(instance, target_seed, old_species)
	var direction: String = "fusion_degeneration" if fusion_degeneration else ("degeneration" if degenerating else "digivolution")
	var repeat_count: int = _transition_repeat_count(instance, old_seed, target_seed, direction)
	var potential_gain: int = 0 if fusion_degeneration else _potential_gain_for_transition(instance, target_seed, degenerating)
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
	if fusion_degeneration:
		instance.fusion_origin.clear()
	_progression.add_potential(instance, potential_gain)
	_sync_form_skills(instance, target_species)
	# Evolution changes maximum resources but must not act as free treatment.
	# Preserve the current HP/SP and only clamp values that exceed the new form.
	calculator.clamp_resources(instance, target_species)
	if OS.is_debug_build():
		print("[Evolution] %s -> %s · %s" % [String(old_species.get("name", old_seed)), String(target_species.get("name", target_seed)), direction])
	return true


func _potential_gain_for_transition(instance: DigimonInstance, target_seed: String, degenerating: bool) -> int:
	var direction := "degeneration" if degenerating else "digivolution"
	var repeat_count := _transition_repeat_count(instance, instance.species_seed, target_seed, direction)
	return (
		_progression.potential_gain_for_degeneration(instance.level, repeat_count)
		if degenerating
		else _progression.potential_gain_for_digivolution(instance.level, repeat_count)
	)


func _transition_snapshot(instance: DigimonInstance, stats: Dictionary) -> Dictionary:
	return {
		"level": instance.level,
		"exp": instance.exp,
		"potential": instance.potential,
		"hp": int(stats.get("hp", 0)),
		"sp": int(stats.get("sp", stats.get("mp", 0))),
		"atk": int(stats.get("atk", 0)),
		"def": int(stats.get("def", 0)),
		"int": int(stats.get("int", 0)),
		"speed": int(stats.get("speed", 0)),
		"mov": int(stats.get("mov", 0)),
	}


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
	var available: Array[Dictionary] = _action_database.get_known_actions(instance.species_seed, instance.level)
	for action: Dictionary in available:
		instance.learn_skill(String(action.get("id", "")), true)


func _fusion_material_seeds(instance: DigimonInstance) -> Array[String]:
	var result: Array[String] = []
	if instance == null or instance.fusion_origin.is_empty():
		return result
	var raw = instance.fusion_origin.get("materialSeeds", [])
	if raw is Array:
		for value in raw:
			var seed := String(value).strip_edges()
			if not seed.is_empty() and not result.has(seed):
				result.append(seed)
	return result


func _is_fusion_degeneration(instance: DigimonInstance, target_seed: String, species: Dictionary) -> bool:
	return (
		instance != null
		and String(species.get("rank", "")) == "Fusion"
		and _fusion_material_seeds(instance).has(target_seed)
	)
