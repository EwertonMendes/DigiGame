extends RefCounted
class_name BattleConfig

const CONFIG_PATH := "res://database/battle-balance.json"

var data: Dictionary = {}


func load_default() -> bool:
	data.clear()
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("Missing battle balance config: %s" % CONFIG_PATH)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		push_error("Battle balance config must be a JSON object")
		return false
	data = parsed.duplicate(true)
	return true


func number(section: String, key: String, fallback: float) -> float:
	var section_data = data.get(section, {})
	if not section_data is Dictionary:
		return fallback
	return float(section_data.get(key, fallback))


func integer(section: String, key: String, fallback: int) -> int:
	return int(round(number(section, key, float(fallback))))
