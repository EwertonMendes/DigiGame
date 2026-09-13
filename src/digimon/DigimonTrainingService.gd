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
	var mov_level := mobility_level(instance)
	if mov_level >= 1:
		used += mobility_cost_for_level(1)
	if mov_level >= 2:
		used += mobility_cost_for_level(2)
	return used

func remaining_capacity(instance: DigimonInstance) -> int:
	return maxi(0, capacity_for(instance) - used_capacity(instance))

func max_points_per_stat() -> int:
	return maxi(1, _balance.training_int("maxPointsPerStat", 30))

func bonus_per_point() -> float:
	return maxf(0.0, _balance.training_number("bonusPerPoint", 0.004))

func stat_bonus_percent(points: int) -> float:
	return float(maxi(0, points)) * bonus_per_point() * 100.0

func mobility_level(instance: DigimonInstance) -> int:
	return clampi(int(instance.training.get("mov", 0)), 0, 2) if instance != null else 0

func mobility_cost_for_level(level: int) -> int:
	match level:
		1: return maxi(1, _balance.training_int("mobilityOneCapacityCost", 20))
		2: return maxi(1, _balance.training_int("mobilityTwoAdditionalCost", 30))
	return 0

func mobility_potential_for_level(level: int) -> int:
	match level:
		1: return maxi(0, _balance.training_int("mobilityOnePotential", 20))
		2: return maxi(0, _balance.training_int("mobilityTwoPotential", 70))
	return 0

func plan_cost(instance: DigimonInstance, stat_additions: Dictionary, mobility_steps: int) -> int:
	if instance == null:
		return 0
	var cost := 0
	for stat_key: String in TRAINABLE_STATS:
		cost += maxi(0, int(stat_additions.get(stat_key, 0)))
	var current_mov := mobility_level(instance)
	for step in range(1, maxi(0, mobility_steps) + 1):
		cost += mobility_cost_for_level(current_mov + step)
	return cost

func validate_plan(instance: DigimonInstance, stat_additions: Dictionary, mobility_steps: int) -> String:
	if instance == null:
		return "No Digimon selected."
	if mobility_steps < 0:
		return "Mobility training cannot be negative."
	var has_change := mobility_steps > 0
	for raw_key in stat_additions.keys():
		var stat_key := String(raw_key).to_lower()
		if not TRAINABLE_STATS.has(stat_key):
			return "Unknown training stat: %s" % stat_key
		var addition := int(stat_additions[raw_key])
		if addition < 0:
			return "Training points cannot be negative."
		if addition > 0:
			has_change = true
		var current := maxi(0, int(instance.training.get(stat_key, 0)))
		if current + addition > max_points_per_stat():
			return "%s training is capped at %d points." % [stat_key.to_upper(), max_points_per_stat()]
	var current_mov := mobility_level(instance)
	if current_mov + mobility_steps > 2:
		return "Mobility training is already at its maximum."
	for step in range(1, mobility_steps + 1):
		var target_level := current_mov + step
		var required_potential := mobility_potential_for_level(target_level)
		if instance.potential < required_potential:
			return "MOV +%d requires Potential %d." % [target_level, required_potential]
	if used_capacity(instance) + plan_cost(instance, stat_additions, mobility_steps) > capacity_for(instance):
		return "Not enough Training Capacity for this plan."
	if not has_change:
		return "Add at least one training point before applying."
	return ""

func can_apply_plan(instance: DigimonInstance, stat_additions: Dictionary, mobility_steps: int) -> bool:
	return validate_plan(instance, stat_additions, mobility_steps).is_empty()

func apply_plan(instance: DigimonInstance, stat_additions: Dictionary, mobility_steps: int) -> bool:
	if not can_apply_plan(instance, stat_additions, mobility_steps):
		return false
	for stat_key: String in TRAINABLE_STATS:
		var addition := maxi(0, int(stat_additions.get(stat_key, 0)))
		if addition > 0:
			instance.training[stat_key] = maxi(0, int(instance.training.get(stat_key, 0))) + addition
	if mobility_steps > 0:
		instance.training["mov"] = mobility_level(instance) + mobility_steps
	return true

func can_allocate_stat(instance: DigimonInstance, stat_key: String, points: int = 1) -> bool:
	if instance == null or not TRAINABLE_STATS.has(stat_key) or points <= 0:
		return false
	var current := maxi(0, int(instance.training.get(stat_key, 0)))
	if current + points > max_points_per_stat():
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
	var mov_level := mobility_level(instance)
	if mov_level >= 2:
		return false
	var next_level := mov_level + 1
	return instance.potential >= mobility_potential_for_level(next_level) and remaining_capacity(instance) >= mobility_cost_for_level(next_level)

func train_mobility(instance: DigimonInstance) -> bool:
	if not can_train_mobility(instance):
		return false
	instance.training["mov"] = mobility_level(instance) + 1
	return true

func reset_training(instance: DigimonInstance) -> void:
	if instance == null:
		return
	for stat_key: String in TRAINABLE_STATS:
		instance.training[stat_key] = 0
	instance.training["mov"] = 0
