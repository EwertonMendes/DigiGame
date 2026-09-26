extends RefCounted
class_name DigimonStatCalculator

const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const STAT_KEYS: Array[String] = ["hp", "mp", "atk", "def", "int", "speed"]
const MAX_FINAL_MOV := 8

var _balance = BalanceScript.new()


func get_stat(instance: DigimonInstance, species: Dictionary, stat_key: String) -> int:
	var normalized_key := "mp" if stat_key.to_lower() == "sp" else stat_key.to_lower()
	if instance == null or species.is_empty() or not STAT_KEYS.has(normalized_key):
		return 0
	var base_value := _base_stat(species, normalized_key)
	var level_growth := _balance.stat_growth(normalized_key, 0.02)
	var level_factor := 1.0 + float(maxi(0, instance.level - 1)) * level_growth
	var aptitude_factor := 1.0 + float(clampi(int(instance.aptitudes.get(normalized_key, 0)), -3, 3)) / 100.0
	var training_bonus := _balance.training_number("bonusPerPoint", 0.004)
	var training_factor := 1.0 + float(maxi(0, int(instance.training.get(normalized_key, 0)))) * training_bonus
	var tier_factor := _balance.tier_stat_multiplier(instance.tier, normalized_key)
	var minimum := 1 if normalized_key != "mp" else 0
	# Resolve the normal final stat first. Expansion is a modifier of the actual
	# max HP the individual has in 1x1 mode, so +20% must remain exact even when
	# the base/tier/training calculation lands between integers.
	var normal_final := maxi(
		minimum,
		int(round(float(base_value) * level_factor * aptitude_factor * training_factor * tier_factor))
	)
	if normalized_key == "hp" and instance.is_expanded():
		return maxi(minimum, int(round(float(normal_final) * _balance.expansion_number("hpMultiplier", 1.2))))
	return normal_final


func get_all_stats(instance: DigimonInstance, species: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for stat_key: String in STAT_KEYS:
		result[stat_key] = get_stat(instance, species, stat_key)
	result["sp"] = result.get("mp", 0)
	result["mov"] = get_mov(instance, species)
	return result


func get_mov(instance: DigimonInstance, species: Dictionary) -> int:
	if instance == null or species.is_empty():
		return 0
	var base_mov := int(species["MOV"])
	var mobility_training := clampi(int(instance.training.get("mov", 0)), 0, 2)
	return clampi(base_mov + mobility_training, 1, MAX_FINAL_MOV)


func refill_instance(instance: DigimonInstance, species: Dictionary) -> void:
	if instance == null:
		return
	instance.current_hp = get_stat(instance, species, "hp")
	instance.current_mp = get_stat(instance, species, "mp")


func clamp_resources(instance: DigimonInstance, species: Dictionary) -> void:
	if instance == null:
		return
	instance.current_hp = clampi(instance.current_hp, 0, get_stat(instance, species, "hp"))
	instance.current_mp = clampi(instance.current_mp, 0, get_stat(instance, species, "mp"))


func _base_stat(species: Dictionary, stat_key: String) -> int:
	match stat_key:
		"hp": return maxi(1, int(species["hp"]))
		"mp": return maxi(0, int(species["mp"]))
		"atk": return maxi(1, int(species["atk"]))
		"def": return maxi(1, int(species["def"]))
		"int": return maxi(1, int(species["int"]))
		"speed": return maxi(1, int(species["speed"]))
	return 0
