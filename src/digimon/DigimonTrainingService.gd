extends RefCounted
class_name DigimonTrainingService

const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const TRAINABLE_STATS: Array[String] = ["hp", "mp", "atk", "def", "int", "speed"]

var _balance = BalanceScript.new()


func capacity_for(instance: DigimonInstance) -> int:
	if instance == null:
		return 0
	var base := _balance.training_int("baseCapacity", 10)
	var divisor := maxi(1, _balance.training_int("potentialPerCapacity", 2))
	return base + instance.potential / divisor


func used_capacity(instance: DigimonInstance) -> int:
	if instance == null:
		return 0
	var used := 0
	for stat_key: String in TRAINABLE_STATS:
		used += maxi(0, int(instance.training.get(stat_key, 0)))
	var mov_level := clampi(int(instance.training.get("mov", 0)), 0, 2)
	if mov_level >= 1:
		used += _balance.training_int("mobilityOneCapacityCost", 20)
	if mov_level >= 2:
		used += _balance.training_int("mobilityTwoAdditionalCost", 30)
	return used


func remaining_capacity(instance: DigimonInstance) -> int:
	return maxi(0, capacity_for(instance) - used_capacity(instance))


func can_allocate_stat(instance: DigimonInstance, stat_key: String, points: int = 1) -> bool:
	if instance == null or not TRAINABLE_STATS.has(stat_key) or points <= 0:
		return false
	var current := maxi(0, int(instance.training.get(stat_key, 0)))
	if current + points > _balance.training_int("maxPointsPerStat", 30):
		return false
	return remaining_capacity(instance) >= points


func allocate_stat(instance: DigimonInstance, stat_key: String, points: int = 1) -> bool:
	if not can_allocate_stat(instance, stat_key, points):
		return false
	instance.training[stat_key] = int(instance.training.get(stat_key, 0)) + points
	return true


func can_train_mobility(instance: DigimonInstance) -> bool:
	if instance == null:
		return false
	var mov_level := clampi(int(instance.training.get("mov", 0)), 0, 2)
	match mov_level:
		0:
			return (
				instance.potential >= _balance.training_int("mobilityOnePotential", 20)
				and remaining_capacity(instance) >= _balance.training_int("mobilityOneCapacityCost", 20)
			)
		1:
			return (
				instance.potential >= _balance.training_int("mobilityTwoPotential", 70)
				and remaining_capacity(instance) >= _balance.training_int("mobilityTwoAdditionalCost", 30)
			)
	return false


func train_mobility(instance: DigimonInstance) -> bool:
	if not can_train_mobility(instance):
		return false
	instance.training["mov"] = clampi(int(instance.training.get("mov", 0)) + 1, 0, 2)
	return true


func reset_training(instance: DigimonInstance) -> void:
	if instance == null:
		return
	for stat_key: String in TRAINABLE_STATS:
		instance.training[stat_key] = 0
	instance.training["mov"] = 0
