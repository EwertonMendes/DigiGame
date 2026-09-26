extends RefCounted
class_name BattleRewardCalculator

const RewardsScript = preload("res://src/digimon/BattleRewards.gd")
const ExperienceCalculatorScript = preload("res://src/digimon/ExperienceCalculator.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")

var _database: DigimonDatabase
var _experience = ExperienceCalculatorScript.new()
var _balance = BalanceScript.new()


func _init(database: DigimonDatabase) -> void:
	_database = database


func calculate(player_snapshots: Array[Dictionary], defeated_enemy_snapshots: Array[Dictionary], difficulty_modifier: float = 1.0) -> BattleRewards:
	var rewards: BattleRewards = RewardsScript.new()
	if _database == null or defeated_enemy_snapshots.is_empty():
		return rewards
	var difficulty := maxf(0.0, difficulty_modifier)
	for enemy: Dictionary in defeated_enemy_snapshots:
		_apply_enemy_economic_rewards(rewards, enemy, difficulty)
	for player: Dictionary in player_snapshots:
		_apply_player_xp(rewards, player, defeated_enemy_snapshots, difficulty)
	return rewards


func digi_data_for_enemy(enemy_level: int, species: Dictionary, profile: String = "wild", difficulty_modifier: float = 1.0) -> int:
	if species.is_empty() or String(species.get("rank", "")) == "Fusion" or not bool(species.get("reconstructable", true)):
		return 0
	var base := _balance.digi_data_base_for_rank(String(species.get("rank", "Rookie")), 10)
	var level_rate := _balance.reward_number("digiDataLevelMultiplierPerLevel", 0.0)
	var max_level_multiplier := _balance.reward_number("digiDataMaxLevelMultiplier", 1.25)
	var level_multiplier := minf(max_level_multiplier, 1.0 + float(maxi(0, enemy_level - 1)) * level_rate)
	var profile_multiplier := _balance.reward_profile_multiplier(profile, 1.0)
	return maxi(1, int(round(float(base) * level_multiplier * profile_multiplier * maxf(0.0, difficulty_modifier))))


func bits_for_enemy(enemy_level: int, species: Dictionary, profile: String = "wild", difficulty_modifier: float = 1.0) -> int:
	if species.is_empty():
		return 0
	var base_rate := maxi(1, int(species.get("bitFarmingRate", 5)))
	var level_multiplier := _balance.reward_number("bitsLevelMultiplier", 1.0)
	var profile_multiplier := _balance.reward_profile_multiplier(profile, 1.0)
	return maxi(1, int(round(float(base_rate * maxi(1, enemy_level)) * level_multiplier * profile_multiplier * maxf(0.0, difficulty_modifier))))


func _apply_enemy_economic_rewards(rewards: BattleRewards, enemy: Dictionary, difficulty: float) -> void:
	var seed := String(enemy.get("species_seed", ""))
	var species := _database.get_by_seed(seed)
	if species.is_empty():
		return
	var level := maxi(1, int(enemy.get("level", 1)))
	var profile := String(enemy.get("profile", "wild"))
	var modifier := difficulty * maxf(0.0, float(enemy.get("reward_modifier", 1.0)))
	rewards.bits += bits_for_enemy(level, species, profile, modifier)
	var species_name := String(species.get("name", seed))
	var data_gain := digi_data_for_enemy(level, species, profile, modifier)
	if data_gain > 0:
		rewards.digi_data[species_name] = int(rewards.digi_data.get(species_name, 0)) + data_gain


func _apply_player_xp(rewards: BattleRewards, player: Dictionary, enemies: Array[Dictionary], difficulty: float) -> void:
	var instance_id := String(player.get("instance_id", ""))
	if instance_id.is_empty():
		return
	# Incapacitated Squad members never receive battle XP. This applies equally
	# to a Digimon knocked out in the current encounter and one that entered the
	# encounter already fainted on the Reserve bench.
	if bool(player.get("knocked_out", false)):
		return
	var recipient_level := maxi(1, int(player.get("level", 1)))
	# XP belongs to the healthy Battle Squad, not only to actors that were
	# deployed. Active/Reserve is a tactical field role and must never change
	# whether a healthy Squad member learns from the victory.
	var xp_multiplier := _balance.party_number(
		"squadXpMultiplier",
		_balance.party_number("participantXpMultiplier", 1.0)
	)
	var total := 0.0
	for enemy: Dictionary in enemies:
		var species := _database.get_by_seed(String(enemy.get("species_seed", "")))
		if species.is_empty():
			continue
		var enemy_level := maxi(1, int(enemy.get("level", 1)))
		var profile := String(enemy.get("profile", "wild"))
		var enemy_modifier := maxf(0.0, float(enemy.get("reward_modifier", 1.0)))
		total += float(_experience.reward_for_enemy(recipient_level, enemy_level, species, profile)) * enemy_modifier
	rewards.xp_by_instance[instance_id] = maxi(0, int(round(total * xp_multiplier * difficulty)))
