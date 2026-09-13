extends Resource
class_name QuestDefinition

const VALID_STATES: Array[String] = ["locked", "available", "active", "completed"]
const SUPPORTED_OBJECTIVES: Array[String] = ["species_defeated"]

@export var quest_id: String = ""
@export var initial_state: String = "locked"
@export var objectives: Array[Dictionary] = []
@export var rewards: Dictionary = {}


func validate(database: DigimonDatabase = null) -> Array[String]:
	var errors: Array[String] = []
	if quest_id.strip_edges().is_empty():
		errors.append("quest_id is required")
	if not VALID_STATES.has(initial_state):
		errors.append("invalid initial_state: %s" % initial_state)
	if objectives.is_empty():
		errors.append("at least one objective is required")
	for index in objectives.size():
		var objective: Dictionary = objectives[index]
		var kind := String(objective.get("type", "")).to_lower().strip_edges()
		if not SUPPORTED_OBJECTIVES.has(kind):
			errors.append("objective %d has unsupported type: %s" % [index, kind])
			continue
		if kind == "species_defeated":
			var seed := String(objective.get("species_seed", objective.get("species_id", ""))).strip_edges()
			if seed.is_empty():
				errors.append("objective %d is missing species_seed" % index)
			elif database != null and database.get_by_seed(seed).is_empty():
				errors.append("objective %d references unknown species: %s" % [index, seed])
			if int(objective.get("amount", objective.get("value", 0))) < 1:
				errors.append("objective %d amount must be at least 1" % index)
	return errors


func to_dict() -> Dictionary:
	return {
		"quest_id": quest_id,
		"initial_state": initial_state,
		"objectives": objectives.duplicate(true),
		"rewards": rewards.duplicate(true),
	}


static func from_dict(data: Dictionary) -> QuestDefinition:
	var definition := QuestDefinition.new()
	definition.quest_id = String(data.get("quest_id", data.get("id", "")))
	definition.initial_state = String(data.get("initial_state", data.get("state", "locked")))
	var raw_objectives = data.get("objectives", [])
	if raw_objectives is Array:
		for raw_objective in raw_objectives:
			if raw_objective is Dictionary:
				definition.objectives.append((raw_objective as Dictionary).duplicate(true))
	var raw_rewards = data.get("rewards", {})
	if raw_rewards is Dictionary:
		definition.rewards = (raw_rewards as Dictionary).duplicate(true)
	return definition
