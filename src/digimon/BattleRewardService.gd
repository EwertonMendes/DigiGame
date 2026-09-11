extends RefCounted
class_name BattleRewardService

const ExperienceCalculatorScript = preload("res://src/digimon/ExperienceCalculator.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")

var _database
var _experience = ExperienceCalculatorScript.new()
var _progression


func _init(database) -> void:
	_database = database
	_progression = ProgressionServiceScript.new(database)


func apply_victory_rewards(player_actors: Array[Node], defeated_enemy_actors: Array[Node]) -> Dictionary:
	var result := {
		"total_enemy_xp_value": 0,
		"digimon": [],
	}
	if _database == null or player_actors.is_empty() or defeated_enemy_actors.is_empty():
		return result

	for player_actor: Node in player_actors:
		var instance := _instance_from_actor(player_actor)
		if not instance is DigimonInstance:
			continue
		var total_xp := 0
		for enemy_actor: Node in defeated_enemy_actors:
			var enemy_instance := _instance_from_actor(enemy_actor)
			if not enemy_instance is DigimonInstance:
				continue
			var species: Dictionary = _database.get_by_seed(enemy_instance.species_seed)
			var profile := String(enemy_actor.get_meta("encounter_profile", "wild")) if enemy_actor != null else "wild"
			total_xp += _experience.reward_for_enemy(instance.level, enemy_instance.level, species, profile)
		var progression_result: Dictionary = _progression.apply_experience(instance, total_xp)
		(result["digimon"] as Array).append(progression_result)
		result["total_enemy_xp_value"] = int(result["total_enemy_xp_value"]) + total_xp
	return result


func _instance_from_actor(actor: Node):
	if actor == null or not is_instance_valid(actor):
		return null
	var instance = actor.get("digimon_instance")
	return instance if instance is DigimonInstance else null
