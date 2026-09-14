extends RefCounted
class_name TechniqueRecordService

const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")

var _actions = ActionDatabaseScript.new()


func _init() -> void:
	_actions.load_default()


func teach(collection: PlayerCollection, instance: DigimonInstance, species: Dictionary, skill_id: String) -> Dictionary:
	var result := {"success": false, "reason": "invalid", "skill_id": skill_id, "bits_spent": 0}
	if collection == null or instance == null or species.is_empty():
		return result
	if instance.learned_skills.has(skill_id):
		result["reason"] = "already_learned"
		return result
	if not collection.has_technique_record(skill_id):
		result["reason"] = "record_locked"
		return result
	var action := _actions.get_action(skill_id)
	if action.is_empty() or String(action.get("availability", "ready")) != "ready":
		result["reason"] = "unavailable"
		return result
	if not _actions.can_teach(skill_id, species):
		result["reason"] = "incompatible"
		return result
	var record := _actions.get_record(skill_id)
	var cost := maxi(0, int(record.get("bitsCost", 0)))
	if collection.bits < cost:
		result["reason"] = "insufficient_bits"
		return result
	collection.bits -= cost
	instance.learn_skill(skill_id, true)
	result["success"] = true
	result["reason"] = "taught"
	result["bits_spent"] = cost
	return result


func apply_research_insights(collection: PlayerCollection, skill_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if collection == null:
		return result
	var unique_ids: Array[String] = []
	for raw_id: String in skill_ids:
		var skill_id := raw_id.strip_edges()
		if skill_id.is_empty() or unique_ids.has(skill_id):
			continue
		unique_ids.append(skill_id)
		var record := _actions.get_record(skill_id)
		var unlock_sources = record.get("unlockSources", [])
		if not bool(record.get("teachable", false)) or not unlock_sources is Array or not (unlock_sources as Array).has("research"):
			continue
		result.append(collection.add_technique_research(skill_id, 1))
	return result


func get_teachable_records(collection: PlayerCollection, instance: DigimonInstance, species: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if collection == null or instance == null:
		return result
	for action: Dictionary in _actions.get_all_actions(false):
		var skill_id := String(action.get("id", ""))
		var record := _actions.get_record(skill_id)
		if record.is_empty() or not bool(record.get("teachable", false)):
			continue
		action["record"] = record
		action["unlocked"] = collection.has_technique_record(skill_id)
		action["compatible"] = _actions.can_teach(skill_id, species)
		action["learned"] = instance.learned_skills.has(skill_id)
		action["research"] = collection.get_technique_research(skill_id)
		result.append(action)
	return result
