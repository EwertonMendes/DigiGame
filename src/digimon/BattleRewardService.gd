extends RefCounted
class_name BattleRewardService

const RewardCalculatorScript = preload("res://src/digimon/BattleRewardCalculator.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")

var _database: DigimonDatabase
var _calculator: BattleRewardCalculator
var _progression: DigimonProgressionService


func _init(database: DigimonDatabase) -> void:
	_database = database
	_calculator = RewardCalculatorScript.new(database) as BattleRewardCalculator
	_progression = ProgressionServiceScript.new(database) as DigimonProgressionService


func apply_victory_rewards(player_actors: Array[Node], defeated_enemy_actors: Array[Node], difficulty_modifier: float = 1.0) -> Dictionary:
	var players: Array[Dictionary] = []
	var player_instances: Dictionary = {}
	for actor: Node in player_actors:
		var instance := _instance_from_actor(actor)
		if instance == null:
			continue
		player_instances[instance.id] = instance
		var battle_state = actor.get("battle_state") if actor != null else null
		players.append({
			"instance_id": instance.id,
			"level": instance.level,
			"knocked_out": bool(battle_state != null and battle_state.has_method("is_knocked_out") and battle_state.call("is_knocked_out")),
		})

	var enemies: Array[Dictionary] = []
	for actor: Node in defeated_enemy_actors:
		var instance := _instance_from_actor(actor)
		if instance == null:
			continue
		enemies.append({
			"species_seed": instance.species_seed,
			"level": instance.level,
			"profile": String(actor.get_meta("encounter_profile", "wild")) if actor != null else "wild",
			"reward_modifier": float(actor.get_meta("reward_modifier", 1.0)) if actor != null else 1.0,
		})

	var rewards: BattleRewards = _calculator.calculate(players, enemies, difficulty_modifier)
	var progression_results: Array[Dictionary] = []
	var total_xp := 0
	for raw_instance_id in rewards.xp_by_instance.keys():
		var instance_id := String(raw_instance_id)
		var instance = player_instances.get(instance_id)
		if not instance is DigimonInstance:
			continue
		var amount := maxi(0, int(rewards.xp_by_instance[raw_instance_id]))
		total_xp += amount
		progression_results.append(_progression.apply_experience(instance as DigimonInstance, amount))

	var result := rewards.to_dict()
	result["xp_rewards"] = {
		"total_enemy_xp_value": total_xp,
		"digimon": progression_results,
	}
	return result


func calculate_for_snapshots(player_snapshots: Array[Dictionary], enemy_snapshots: Array[Dictionary], difficulty_modifier: float = 1.0) -> BattleRewards:
	return _calculator.calculate(player_snapshots, enemy_snapshots, difficulty_modifier)


func _instance_from_actor(actor: Node) -> DigimonInstance:
	if actor == null or not is_instance_valid(actor):
		return null
	var instance = actor.get("digimon_instance")
	return instance as DigimonInstance if instance is DigimonInstance else null
