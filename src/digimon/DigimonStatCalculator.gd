extends RefCounted
class_name DigimonStatCalculator

const MAX_LEVEL := 99
const STAT_KEYS: Array[String] = ["hp", "mp", "atk", "def", "speed"]
const LEVEL_GROWTH := {
	"hp": 0.025,
	"mp": 0.020,
	"atk": 0.020,
	"def": 0.020,
	"speed": 0.020,
}
const TRAINING_BONUS_PER_POINT := 0.004
const MAX_FINAL_MOV := 8


func get_stat(instance: DigimonInstance, species: Dictionary, stat_key: String) -> int:
	if instance == null or species.is_empty() or not STAT_KEYS.has(stat_key):
		return 0
	var base_value := _base_stat(species, stat_key)
	var level_factor := 1.0 + float(maxi(0, instance.level - 1)) * float(LEVEL_GROWTH.get(stat_key, 0.020))
	var aptitude_factor := 1.0 + float(clampi(int(instance.aptitudes.get(stat_key, 0)), -3, 3)) / 100.0
	var training_factor := 1.0 + float(maxi(0, int(instance.training.get(stat_key, 0)))) * TRAINING_BONUS_PER_POINT
	return maxi(1 if stat_key != "mp" else 0, int(round(float(base_value) * level_factor * aptitude_factor * training_factor)))


func get_all_stats(instance: DigimonInstance, species: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for stat_key: String in STAT_KEYS:
		result[stat_key] = get_stat(instance, species, stat_key)
	result["mov"] = get_mov(instance, species)
	return result


func get_mov(instance: DigimonInstance, species: Dictionary) -> int:
	if instance == null or species.is_empty():
		return 0
	var base_mov := int(species.get("MOV", 4))
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
		"hp": return maxi(1, int(species.get("hp", 1)))
		"mp": return maxi(0, int(species.get("mp", 0)))
		"atk": return maxi(1, int(species.get("atk", species.get("attack", 1))))
		"def": return maxi(1, int(species.get("def", species.get("defense", 1))))
		"speed": return maxi(1, int(species.get("speed", 1)))
	return 0
