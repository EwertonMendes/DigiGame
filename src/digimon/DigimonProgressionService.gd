extends RefCounted
class_name DigimonProgressionService

const ProgressionScript = preload("res://src/digimon/DigimonProgression.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const EvolutionServiceScript = preload("res://src/digimon/DigimonEvolutionService.gd")
const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")

var _database
var _progression = ProgressionScript.new()
var _calculator = StatCalculatorScript.new()
var _evolution = EvolutionServiceScript.new()
var _actions = ActionDatabaseScript.new()


func _init(database) -> void:
	_database = database
	_actions.load_default()


func exp_to_next_level(instance: DigimonInstance) -> int:
	if instance == null or _database == null:
		return 0
	return _progression.exp_to_next_level(instance, _database.get_by_seed(instance.species_seed))


func apply_experience(instance: DigimonInstance, amount: int) -> Dictionary:
	var result := {
		"instance_id": "",
		"xp_gained": maxi(0, amount),
		"old_level": 1,
		"new_level": 1,
		"levels_gained": 0,
		"learned_skills": [],
		"unlocked_evolutions": [],
	}
	if instance == null or _database == null or amount <= 0:
		return result
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return result
	result["instance_id"] = instance.id
	result["old_level"] = instance.level
	var skills_before := instance.learned_skills.duplicate()
	var unlocked_before := _unlocked_target_seeds(instance)
	var levels_gained := _progression.add_experience(instance, species, amount)
	if levels_gained > 0:
		_sync_level_skills(instance, species)
		_calculator.clamp_resources(instance, species)
	result["new_level"] = instance.level
	result["levels_gained"] = levels_gained
	for skill_id: String in instance.learned_skills:
		if not skills_before.has(skill_id):
			(result["learned_skills"] as Array).append(skill_id)
	for route: Dictionary in _evolution.get_available_evolutions(instance, _database, _calculator):
		if not bool(route.get("unlocked", false)):
			continue
		var seed := String(route.get("targetSeed", ""))
		if unlocked_before.has(seed):
			continue
		(result["unlocked_evolutions"] as Array).append({
			"seed": seed,
			"name": String(route.get("targetName", "Unknown")),
			"rank": String(route.get("targetRank", "")),
		})
	return result


func get_evolution_routes(instance: DigimonInstance) -> Array[Dictionary]:
	if instance == null:
		return []
	return _evolution.get_available_evolutions(instance, _database, _calculator)


func get_degeneration_routes(instance: DigimonInstance) -> Array[Dictionary]:
	if instance == null:
		return []
	return _evolution.get_available_degenerations(instance, _database, _calculator)


func get_final_stats(instance: DigimonInstance) -> Dictionary:
	if instance == null:
		return {}
	return _calculator.get_all_stats(instance, _database.get_by_seed(instance.species_seed))


func _sync_level_skills(instance: DigimonInstance, species: Dictionary) -> void:
	var available: Array[Dictionary] = _actions.get_known_actions(String(species.get("name", "")), instance.level)
	for action: Dictionary in available:
		instance.learn_skill(String(action.get("id", "")), true)


func _unlocked_target_seeds(instance: DigimonInstance) -> Array[String]:
	var result: Array[String] = []
	for route: Dictionary in _evolution.get_available_evolutions(instance, _database, _calculator):
		if bool(route.get("unlocked", false)):
			result.append(String(route.get("targetSeed", "")))
	return result
