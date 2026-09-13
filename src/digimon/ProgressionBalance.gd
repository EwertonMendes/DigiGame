extends RefCounted
class_name ProgressionBalance

const PATH := "res://database/progression-balance.json"

var _data: Dictionary = {}


func _init() -> void:
	load_default()


func load_default() -> bool:
	_data.clear()
	if not FileAccess.file_exists(PATH):
		push_error("Missing progression balance: %s" % PATH)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("Progression balance root must be an object")
		return false
	_data = (parsed as Dictionary).duplicate(true)
	return true


func max_level() -> int:
	return maxi(1, int(_data.get("maxLevel", 99)))


func section(name: String) -> Dictionary:
	var raw = _data.get(name, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func experience_number(key: String, fallback: float) -> float:
	return float(section("experience").get(key, fallback))


func experience_rank_multiplier(key: String, rank: String, fallback: float = 1.0) -> float:
	var group_raw = section("experience").get(key, {})
	if not group_raw is Dictionary:
		return fallback
	return float((group_raw as Dictionary).get(rank, fallback))


func potential_int(key: String, fallback: int) -> int:
	return int(section("potential").get(key, fallback))


func potential_repeat_multiplier(repeat_count: int) -> float:
	var raw = section("potential").get("repeatTransitionMultipliers", [1.0])
	if not raw is Array or (raw as Array).is_empty():
		return 1.0
	var values := raw as Array
	return float(values[mini(maxi(0, repeat_count), values.size() - 1)])


func training_int(key: String, fallback: int) -> int:
	return int(section("training").get(key, fallback))


func training_number(key: String, fallback: float) -> float:
	return float(section("training").get(key, fallback))


func party_int(key: String, fallback: int) -> int:
	return int(section("party").get(key, fallback))


func party_number(key: String, fallback: float) -> float:
	return float(section("party").get(key, fallback))


func stat_growth(stat_key: String, fallback: float = 0.02) -> float:
	return float(section("statGrowth").get(stat_key.to_lower(), fallback))


func reward_number(key: String, fallback: float) -> float:
	return float(section("rewards").get(key, fallback))


func digi_data_base_for_rank(rank: String, fallback: int = 10) -> int:
	var raw = section("rewards").get("digiDataByRank", {})
	if not raw is Dictionary:
		return fallback
	return int((raw as Dictionary).get(rank, fallback))


func reward_profile_multiplier(profile: String, fallback: float = 1.0) -> float:
	var raw = section("rewards").get("profileMultiplier", {})
	if not raw is Dictionary:
		return fallback
	return float((raw as Dictionary).get(profile.to_lower(), fallback))


func reconstruction_int(key: String, fallback: int) -> int:
	return int(section("reconstruction").get(key, fallback))


func reconstruction_bool(key: String, fallback: bool) -> bool:
	return bool(section("reconstruction").get(key, fallback))
