extends RefCounted
class_name ExpansionQuestCatalog

const QuestDefinitionScript = preload("res://src/quests/QuestDefinition.gd")
const QuestServiceScript = preload("res://src/quests/QuestService.gd")

const TUTORIAL_QUEST_ID := "expansion_breakthrough"
const ADVANCED_QUEST_ID := "expansion_fragment_hunt"
const TUTORIAL_COMPLETED_FLAG := "expansion_tutorial_completed"
const CORE_ITEM_ID := "expansion_core"
const FRAGMENT_ITEM_ID := "expansion_fragment"


static func tutorial_definition() -> QuestDefinition:
	var definition: QuestDefinition = QuestDefinitionScript.new()
	definition.quest_id = TUTORIAL_QUEST_ID
	definition.initial_state = QuestService.STATE_LOCKED
	definition.objectives = [
		{"type": "battle_wins", "amount": 1},
	]
	definition.rewards = {
		"items": {CORE_ITEM_ID: 1},
		"flags": {TUTORIAL_COMPLETED_FLAG: true},
	}
	return definition


static func advanced_definition() -> QuestDefinition:
	var definition: QuestDefinition = QuestDefinitionScript.new()
	definition.quest_id = ADVANCED_QUEST_ID
	definition.initial_state = QuestService.STATE_LOCKED
	definition.repeatable = true
	definition.objectives = [
		{"type": "battle_wins", "amount": 3},
	]
	definition.rewards = {
		"items": {FRAGMENT_ITEM_ID: 1},
	}
	return definition


static func unlock_for_tier_s(collection: PlayerCollection) -> bool:
	if collection == null or bool(collection.progression_flags.get(TUTORIAL_COMPLETED_FLAG, false)):
		return false
	var service: QuestService = QuestServiceScript.new()
	var definition := tutorial_definition()
	var state := service.get_state(collection, definition)
	if state == QuestService.STATE_LOCKED:
		service.set_available(collection, definition)
		state = service.get_state(collection, definition)
	if state == QuestService.STATE_AVAILABLE:
		return service.start(collection, definition)
	return state == QuestService.STATE_ACTIVE


static func ensure_advanced_unlocked(collection: PlayerCollection) -> bool:
	if collection == null or not bool(collection.progression_flags.get(TUTORIAL_COMPLETED_FLAG, false)):
		return false
	var service: QuestService = QuestServiceScript.new()
	var definition := advanced_definition()
	var state := service.get_state(collection, definition)
	if state == QuestService.STATE_LOCKED:
		service.set_available(collection, definition)
		state = service.get_state(collection, definition)
	if state == QuestService.STATE_AVAILABLE:
		return service.start(collection, definition)
	return state == QuestService.STATE_ACTIVE


static func record_victory(collection: PlayerCollection, advanced_encounter: bool) -> Dictionary:
	var result := {
		"tutorial": {},
		"advanced": {},
		"rewarded_items": {},
		"tutorial_completed_now": false,
	}
	if collection == null:
		return result
	var service: QuestService = QuestServiceScript.new()
	var tutorial := tutorial_definition()
	var tutorial_state := service.get_state(collection, tutorial)
	if tutorial_state == QuestService.STATE_ACTIVE:
		var tutorial_result := service.record_battle_win(collection, tutorial, 1)
		result["tutorial"] = tutorial_result
		result["tutorial_completed_now"] = bool(tutorial_result.get("completed", false))
		_merge_reward_items(result["rewarded_items"] as Dictionary, tutorial_result)

	if bool(collection.progression_flags.get(TUTORIAL_COMPLETED_FLAG, false)):
		ensure_advanced_unlocked(collection)
		# The battle that teaches Expansion awards the Core only. Fragment farming
		# begins on the following qualifying advanced encounter.
		if advanced_encounter and not bool(result.get("tutorial_completed_now", false)):
			var advanced := advanced_definition()
			var advanced_result := service.record_battle_win(collection, advanced, 1)
			result["advanced"] = advanced_result
			_merge_reward_items(result["rewarded_items"] as Dictionary, advanced_result)
	return result


static func quest_status(collection: PlayerCollection) -> Dictionary:
	if collection == null:
		return {}
	var service: QuestService = QuestServiceScript.new()
	var tutorial := tutorial_definition()
	var advanced := advanced_definition()
	return {
		"tutorial": {
			"id": TUTORIAL_QUEST_ID,
			"state": service.get_state(collection, tutorial),
			"objectives": service.objective_status(collection, tutorial),
			"completion_count": service.completion_count(collection, tutorial),
		},
		"advanced": {
			"id": ADVANCED_QUEST_ID,
			"state": service.get_state(collection, advanced),
			"objectives": service.objective_status(collection, advanced),
			"completion_count": service.completion_count(collection, advanced),
		},
	}


static func _merge_reward_items(target: Dictionary, quest_result: Dictionary) -> void:
	var rewards = quest_result.get("rewards", {})
	if not rewards is Dictionary:
		return
	var items = (rewards as Dictionary).get("items", {})
	if not items is Dictionary:
		return
	for raw_item_id in (items as Dictionary).keys():
		var item_id := String(raw_item_id)
		target[item_id] = int(target.get(item_id, 0)) + int((items as Dictionary)[raw_item_id])
