extends RefCounted
class_name BattleRNG

var seed_value: int = 1
var _rng := RandomNumberGenerator.new()


func reset(seed: int) -> void:
	seed_value = seed if seed != 0 else 1
	_rng.seed = seed_value


func roll_percent(chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 100.0:
		return true
	return _rng.randf_range(0.0, 100.0) < chance


func range_int(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)


func snapshot_seed() -> int:
	return seed_value
