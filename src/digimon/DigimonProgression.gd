extends RefCounted
class_name DigimonProgression

const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")

var _balance = BalanceScript.new()


func max_level() -> int:
	return _balance.max_level()


func exp_to_next_level(instance: DigimonInstance, species: Dictionary) -> int:
	if instance == null:
		return 0
	return exp_to_next_level_for_level(instance.level, species)


func exp_to_next_level_for_level(level: int, species: Dictionary) -> int:
	if level >= max_level():
		return 0
	var safe_level := maxi(1, level)
	var rank := String(species.get("rank", "Rookie"))
	var rank_multiplier := _balance.experience_rank_multiplier("rankRequirementMultiplier", rank, 1.0)
	var base := _balance.experience_number("base", 18.0)
	var exponent := _balance.experience_number("exponent", 1.58)
	return maxi(1, int(round(base * pow(float(safe_level), exponent) * rank_multiplier)))


func add_experience(instance: DigimonInstance, species: Dictionary, amount: int) -> int:
	if instance == null or amount <= 0 or instance.level >= max_level():
		return 0
	instance.exp += amount
	var levels_gained := 0
	while instance.level < max_level():
		var required := exp_to_next_level(instance, species)
		if required <= 0 or instance.exp < required:
			break
		instance.exp -= required
		instance.level += 1
		levels_gained += 1
	if instance.level >= max_level():
		instance.level = max_level()
		instance.exp = 0
	return levels_gained


func potential_gain_for_digivolution(level_before_reset: int, repeat_count: int = 0) -> int:
	return _potential_gain(false, level_before_reset, repeat_count)


func potential_gain_for_degeneration(level_before_reset: int, repeat_count: int = 0) -> int:
	return _potential_gain(true, level_before_reset, repeat_count)


func _potential_gain(degenerating: bool, level_before_reset: int, repeat_count: int) -> int:
	var base_key := "degenerationBase" if degenerating else "digivolutionBase"
	var base := _balance.potential_int(base_key, 4 if degenerating else 2)
	var divisor := maxi(1, _balance.potential_int("levelDivisor", 10))
	var raw_gain := base + maxi(0, level_before_reset) / divisor
	var multiplier := _balance.potential_repeat_multiplier(repeat_count)
	return maxi(1, int(round(float(raw_gain) * multiplier)))


func add_potential(instance: DigimonInstance, amount: int) -> int:
	if instance == null or amount <= 0:
		return 0
	var before := instance.potential
	var maximum := _balance.potential_int("max", DigimonInstance.MAX_POTENTIAL)
	instance.potential = clampi(instance.potential + amount, 0, maximum)
	return instance.potential - before
