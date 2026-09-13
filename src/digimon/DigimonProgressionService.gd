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
		"display_name": "",
		"species_name": "",
		"species_seed": "",
		"rank": "",
		"xp_gained": maxi(0, amount),
		"old_level": 1,
		"new_level": 1,
		"levels_gained": 0,
		"old_exp": 0,
		"new_exp": 0,
		"old_xp_required": 0,
		"new_xp_required": 0,
		"old_stats": {},
		"new_stats": {},
		"stat_deltas": {},
		"level_steps": [],
		"learned_skills": [],
		"unlocked_evolutions": [],
	}
	if instance == null or _database == null:
		return result
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return result
	var old_stats := _calculator.get_all_stats(instance, species)
	result["instance_id"] = instance.id
	result["species_seed"] = instance.species_seed
	result["species_name"] = String(species.get("name", "Digimon"))
	result["display_name"] = instance.get_display_name(String(result["species_name"]))
	result["rank"] = String(species.get("rank", ""))
	result["old_level"] = instance.level
	result["new_level"] = instance.level
	result["old_exp"] = instance.exp
	result["new_exp"] = instance.exp
	result["old_xp_required"] = _progression.exp_to_next_level(instance, species)
	result["new_xp_required"] = int(result["old_xp_required"])
	result["old_stats"] = old_stats
	result["new_stats"] = old_stats.duplicate(true)
	result["stat_deltas"] = _stat_deltas(old_stats, old_stats)
	if amount <= 0:
		return result

	result["level_steps"] = _build_level_steps(instance.level, instance.exp, amount, species)
	var skills_before := instance.learned_skills.duplicate()
	var unlocked_before := _unlocked_target_seeds(instance)
	var levels_gained := _progression.add_experience(instance, species, amount)
	if levels_gained > 0:
		_sync_level_skills(instance, species)
		_calculator.clamp_resources(instance, species)
	var new_stats := _calculator.get_all_stats(instance, species)
	result["new_level"] = instance.level
	result["new_exp"] = instance.exp
	result["new_xp_required"] = _progression.exp_to_next_level(instance, species)
	result["levels_gained"] = levels_gained
	result["new_stats"] = new_stats
	result["stat_deltas"] = _stat_deltas(old_stats, new_stats)
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
	if OS.is_debug_build() and amount > 0:
		print("[Progression] %s gained %d XP · Level %d -> %d" % [String(result["display_name"]), amount, int(result["old_level"]), instance.level])
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


func _build_level_steps(start_level: int, start_exp: int, amount: int, species: Dictionary) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var level := maxi(1, start_level)
	var exp := maxi(0, start_exp)
	var remaining := maxi(0, amount)
	while remaining > 0 and level < _progression.max_level():
		var required := _progression.exp_to_next_level_for_level(level, species)
		if required <= 0:
			break
		var needed := maxi(0, required - exp)
		var applied := mini(remaining, needed)
		var end_exp := exp + applied
		var leveled_up := end_exp >= required
		steps.append({
			"level": level,
			"start_exp": exp,
			"end_exp": min(end_exp, required),
			"required": required,
			"xp_applied": applied,
			"leveled_up": leveled_up,
			"next_level": level + 1 if leveled_up else level,
		})
		remaining -= applied
		if not leveled_up:
			break
		level += 1
		exp = 0
	return steps


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


func _stat_deltas(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for stat_key: String in ["hp", "sp", "atk", "def", "int", "speed", "mov"]:
		result[stat_key] = int(after.get(stat_key, 0)) - int(before.get(stat_key, 0))
	return result
