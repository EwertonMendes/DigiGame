extends RefCounted
class_name DebugTechniqueTools

const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")

var actions: BattleActionDatabase = ActionDatabaseScript.new()


func _init() -> void:
	actions.load_default()


func catalog(include_unavailable: bool = true) -> Array[Dictionary]:
	return actions.get_all_actions(include_unavailable)


func action(skill_id: String, instance_id: String = "") -> Dictionary:
	var mastery_points := 0
	var value := instance(instance_id)
	if value != null and value.learned_skills.has(skill_id):
		mastery_points = value.get_skill_mastery_points(skill_id)
	return actions.get_action(skill_id, mastery_points)


func instance(instance_id: String) -> DigimonInstance:
	return OverworldState.get_instance_by_id(instance_id) if not instance_id.is_empty() else null


func learn(instance_id: String, skill_id: String, favorite: bool = false) -> bool:
	var value := instance(instance_id)
	if value == null or actions.get_action(skill_id).is_empty():
		return false
	var changed := value.learn_skill(skill_id, favorite)
	if changed:
		OverworldState.notify_collection_changed()
	return changed


func forget(instance_id: String, skill_id: String) -> bool:
	var value := instance(instance_id)
	if value == null or not value.learned_skills.has(skill_id):
		return false
	value.learned_skills.erase(skill_id)
	value.favorite_skills.erase(skill_id)
	value.archived_skills.erase(skill_id)
	value.skill_mastery.erase(skill_id)
	OverworldState.notify_collection_changed()
	return true


func set_favorite(instance_id: String, skill_id: String, enabled: bool) -> bool:
	var value := instance(instance_id)
	if value == null or not value.learned_skills.has(skill_id):
		return false
	var changed := value.favorite_skill(skill_id) if enabled else value.unfavorite_skill(skill_id)
	if changed:
		OverworldState.notify_collection_changed()
	return changed


func set_archived(instance_id: String, skill_id: String, enabled: bool) -> bool:
	var value := instance(instance_id)
	if value == null or not value.learned_skills.has(skill_id):
		return false
	var changed := value.archive_skill(skill_id) if enabled else value.restore_skill(skill_id)
	if changed:
		OverworldState.notify_collection_changed()
	return changed


func set_mastery(instance_id: String, skill_id: String, points: int) -> bool:
	var value := instance(instance_id)
	if value == null or not value.learned_skills.has(skill_id):
		return false
	var bounded := clampi(points, 0, DigimonInstance.MAX_SKILL_MASTERY_POINTS)
	if value.get_skill_mastery_points(skill_id) == bounded:
		return true
	value.skill_mastery[skill_id] = bounded
	OverworldState.notify_collection_changed()
	return true


func current_form_learnset(instance_id: String) -> Array[Dictionary]:
	var value := instance(instance_id)
	if value == null:
		return []
	var result: Array[Dictionary] = []
	for entry: Dictionary in actions.get_learnset_entries(value.species_seed):
		var row := entry.duplicate(true)
		var skill_id := String(row.get("skill", ""))
		var skill := actions.get_action(skill_id)
		row["name"] = String(skill.get("name", skill_id))
		row["learned"] = value.learned_skills.has(skill_id)
		result.append(row)
	return result
