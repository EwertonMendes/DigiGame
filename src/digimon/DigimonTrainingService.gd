extends RefCounted
class_name DigimonTrainingService

const TRAINABLE_STATS: Array[String] = ["hp", "mp", "atk", "def", "speed"]
const MAX_POINTS_PER_STAT := 30
const MOBILITY_I_POTENTIAL := 20
const MOBILITY_II_POTENTIAL := 70
const MOBILITY_I_CAPACITY_COST := 20
const MOBILITY_II_ADDITIONAL_COST := 30


func capacity_for(instance: DigimonInstance) -> int:
	if instance == null:
		return 0
	return 10 + instance.potential / 2


func used_capacity(instance: DigimonInstance) -> int:
	if instance == null:
		return 0
	var used := 0
	for stat_key: String in TRAINABLE_STATS:
		used += maxi(0, int(instance.training.get(stat_key, 0)))
	var mov_level := clampi(int(instance.training.get("mov", 0)), 0, 2)
	if mov_level >= 1:
		used += MOBILITY_I_CAPACITY_COST
	if mov_level >= 2:
		used += MOBILITY_II_ADDITIONAL_COST
	return used


func remaining_capacity(instance: DigimonInstance) -> int:
	return maxi(0, capacity_for(instance) - used_capacity(instance))


func can_allocate_stat(instance: DigimonInstance, stat_key: String, points: int = 1) -> bool:
	if instance == null or not TRAINABLE_STATS.has(stat_key) or points <= 0:
		return false
	var current := maxi(0, int(instance.training.get(stat_key, 0)))
	if current + points > MAX_POINTS_PER_STAT:
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
			return instance.potential >= MOBILITY_I_POTENTIAL and remaining_capacity(instance) >= MOBILITY_I_CAPACITY_COST
		1:
			return instance.potential >= MOBILITY_II_POTENTIAL and remaining_capacity(instance) >= MOBILITY_II_ADDITIONAL_COST
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
