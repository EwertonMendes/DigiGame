extends RefCounted
class_name HospitalRecoveryCalculator

const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")

var _balance = BalanceScript.new()


func missing_hp(instance: DigimonInstance, max_hp: int) -> int:
	if instance == null:
		return 0
	return maxi(0, maxi(1, max_hp) - clampi(instance.current_hp, 0, maxi(1, max_hp)))


func missing_hp_ratio(instance: DigimonInstance, max_hp: int) -> float:
	var normalized_max := maxi(1, max_hp)
	return clampf(float(missing_hp(instance, normalized_max)) / float(normalized_max), 0.0, 1.0)


func recovery_seconds(instance: DigimonInstance, max_hp: int) -> int:
	var missing_ratio := missing_hp_ratio(instance, max_hp)
	if missing_ratio <= 0.0:
		return 0
	var minimum_seconds := maxi(1, _balance.hospital_int("minimumRecoverySeconds", 60))
	var maximum_seconds := maxi(minimum_seconds, _balance.hospital_int("maximumRecoverySeconds", 1200))
	return maxi(minimum_seconds, int(ceil(float(maximum_seconds) * missing_ratio)))


func instant_cost(instance: DigimonInstance, max_hp: int) -> int:
	var missing_ratio := missing_hp_ratio(instance, max_hp)
	if instance == null or missing_ratio <= 0.0:
		return 0
	var base_cost := maxf(0.0, _balance.hospital_number("baseInstantCost", 500.0))
	var level_cost := maxf(0.0, _balance.hospital_number("levelInstantCost", 50.0))
	var minimum_cost := maxi(1, _balance.hospital_int("minimumInstantCost", 100))
	var full_recovery_cost := base_cost + float(maxi(1, instance.level)) * level_cost
	return maxi(minimum_cost, int(ceil(full_recovery_cost * missing_ratio)))
