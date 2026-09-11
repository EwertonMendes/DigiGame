extends RefCounted
class_name BattleRewardService

const ExperienceCalculatorScript = preload("res://src/digimon/ExperienceCalculator.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")

var _database: DigimonDatabase
var _experience: ExperienceCalculator = ExperienceCalculatorScript.new()
var _progression: DigimonProgressionService


func _init(database: DigimonDatabase) -> void:
	_database = database
	_progression = ProgressionServiceScript.new(database) as DigimonProgressionService


func apply_victory_rewards(player_actors: Array[Node], defeated_enemy_actors: Array[Node]) -> Dictionary:
	var result := {
		"total_enemy_xp_value": 0,
		"digimon": [],
	}
	if _database == null or player_actors.is_empty() or defeated_enemy_actors.is_empty():
		return result

	for player_actor: Node in player_actors:
		var instance: DigimonInstance = _instance_from_actor(player_actor)
		if instance == null:
			continue
		var total_xp := 0
		for enemy_actor: Node in defeated_enemy_actors:
			var enemy_instance: DigimonInstance = _instance_from_actor(enemy_actor)
			if enemy_instance == null:
				continue
			var species: Dictionary = _database.get_by_seed(enemy_instance.species_seed)
			var profile: String = String(enemy_actor.get_meta("encounter_profile", "wild")) if enemy_actor != null else "wild"
			total_xp += _experience.reward_for_enemy(instance.level, enemy_instance.level, species, profile)
		var progression_result: Dictionary = _progression.apply_experience(instance, total_xp)
		(result["digimon"] as Array).append(progression_result)
		result["total_enemy_xp_value"] = int(result["total_enemy_xp_value"]) + total_xp
	return result


func _instance_from_actor(actor: Node) -> DigimonInstance:
	if actor == null or not is_instance_valid(actor):
		return null
	var instance = actor.get("digimon_instance")
	return instance as DigimonInstance if instance is DigimonInstance else null
