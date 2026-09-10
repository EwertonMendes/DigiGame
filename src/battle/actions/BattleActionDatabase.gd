extends RefCounted
class_name BattleActionDatabase

const TECHNIQUES_PATH := "res://database/techniques.json"
const LEARNSETS_PATH := "res://database/digimon-learnsets.json"

var _actions: Dictionary = {}
var _learnsets_by_species: Dictionary = {}


func load_default() -> bool:
	_actions.clear()
	_learnsets_by_species.clear()
	if not _load_actions():
		return false
	_load_learnsets()
	return true


func get_action(action_id: String) -> Dictionary:
	if not _actions.has(action_id):
		return {}
	return (_actions[action_id] as Dictionary).duplicate(true)


func get_known_actions(species_name: String, level: int, learned_ids: Array[String] = []) -> Array[Dictionary]:
	var ids: Array[String] = []
	for learned_id: String in learned_ids:
		if _actions.has(learned_id) and not ids.has(learned_id):
			ids.append(learned_id)
	var key := species_name.to_lower().strip_edges()
	var learnset = _learnsets_by_species.get(key, [])
	if learnset is Array:
		for raw_entry in learnset:
			if not raw_entry is Dictionary:
				continue
			if int(raw_entry.get("level", 1)) > level:
				continue
			var action_id := String(raw_entry.get("skill", ""))
			if _actions.has(action_id) and not ids.has(action_id):
				ids.append(action_id)
	var result: Array[Dictionary] = []
	for action_id: String in ids:
		result.append(get_action(action_id))
	return result


func get_default_action_for_species(species_name: String, level: int) -> Dictionary:
	var actions := get_known_actions(species_name, level)
	return actions[0] if not actions.is_empty() else {}


func _load_actions() -> bool:
	if not FileAccess.file_exists(TECHNIQUES_PATH):
		push_error("Missing techniques database: %s" % TECHNIQUES_PATH)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TECHNIQUES_PATH))
	if not parsed is Array:
		push_error("Techniques database must be an array")
		return false
	for raw_action in parsed:
		if not raw_action is Dictionary:
			continue
		var action_id := String(raw_action.get("id", "")).strip_edges()
		if action_id.is_empty():
			continue
		_actions[action_id] = raw_action.duplicate(true)
	return not _actions.is_empty()


func _load_learnsets() -> void:
	if not FileAccess.file_exists(LEARNSETS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LEARNSETS_PATH))
	if not parsed is Array:
		return
	for raw_learnset in parsed:
		if not raw_learnset is Dictionary:
			continue
		var species_name := String(raw_learnset.get("species", "")).to_lower().strip_edges()
		if species_name.is_empty():
			continue
		var skills = raw_learnset.get("skills", [])
		if skills is Array:
			_learnsets_by_species[species_name] = skills.duplicate(true)
