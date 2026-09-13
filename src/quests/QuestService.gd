extends RefCounted
class_name QuestService

const STATE_LOCKED := "locked"
const STATE_AVAILABLE := "available"
const STATE_ACTIVE := "active"
const STATE_COMPLETED := "completed"


func get_state(roster: PlayerRoster, definition: QuestDefinition) -> String:
	if roster == null or definition == null:
		return STATE_LOCKED
	var entry := _entry(roster, definition)
	return String(entry.get("state", definition.initial_state))


func set_available(roster: PlayerRoster, definition: QuestDefinition) -> bool:
	if roster == null or definition == null or definition.quest_id.strip_edges().is_empty():
		return false
	var entry := _entry(roster, definition)
	var state := String(entry.get("state", definition.initial_state))
	if state == STATE_COMPLETED or state == STATE_ACTIVE:
		return false
	entry["state"] = STATE_AVAILABLE
	_store_entry(roster, definition.quest_id, entry)
	return true


func start(roster: PlayerRoster, definition: QuestDefinition) -> bool:
	if roster == null or definition == null:
		return false
	var entry := _entry(roster, definition)
	var state := String(entry.get("state", definition.initial_state))
	if state != STATE_AVAILABLE:
		return false
	entry["state"] = STATE_ACTIVE
	_store_entry(roster, definition.quest_id, entry)
	return true


func record_species_defeat(roster: PlayerRoster, definition: QuestDefinition, species_seed: String, amount: int = 1) -> Dictionary:
	var result := {
		"changed": false,
		"completed": false,
		"state": get_state(roster, definition),
		"rewards": {},
	}
	if roster == null or definition == null or amount <= 0 or get_state(roster, definition) != STATE_ACTIVE:
		return result
	var seed := species_seed.strip_edges()
	if seed.is_empty():
		return result
	var entry := _entry(roster, definition)
	var progress := _safe_dictionary(entry.get("objective_progress", {}))
	var changed := false
	for objective: Dictionary in definition.objectives:
		if String(objective.get("type", "")).to_lower() != "species_defeated":
			continue
		var target_seed := String(objective.get("species_seed", objective.get("species_id", ""))).strip_edges()
		if target_seed != seed:
			continue
		var key := _objective_key(objective)
		progress[key] = maxi(0, int(progress.get(key, 0))) + amount
		changed = true
	if not changed:
		return result
	entry["objective_progress"] = progress
	result["changed"] = true
	if _all_objectives_complete(definition, progress):
		entry["state"] = STATE_COMPLETED
		result["completed"] = true
		result["rewards"] = _apply_rewards(roster, definition.rewards)
	_store_entry(roster, definition.quest_id, entry)
	result["state"] = String(entry.get("state", STATE_ACTIVE))
	return result


func objective_status(roster: PlayerRoster, definition: QuestDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if roster == null or definition == null:
		return result
	var entry := _entry(roster, definition)
	var progress := _safe_dictionary(entry.get("objective_progress", {}))
	for objective: Dictionary in definition.objectives:
		var kind := String(objective.get("type", "")).to_lower()
		var required := maxi(1, int(objective.get("amount", objective.get("value", 1))))
		var current := int(progress.get(_objective_key(objective), 0))
		result.append({
			"type": kind,
			"species_seed": String(objective.get("species_seed", objective.get("species_id", ""))),
			"current": current,
			"required": required,
			"is_met": current >= required,
		})
	return result


func _all_objectives_complete(definition: QuestDefinition, progress: Dictionary) -> bool:
	if definition.objectives.is_empty():
		return false
	for objective: Dictionary in definition.objectives:
		var required := maxi(1, int(objective.get("amount", objective.get("value", 1))))
		if int(progress.get(_objective_key(objective), 0)) < required:
			return false
	return true


func _apply_rewards(roster: PlayerRoster, rewards: Dictionary) -> Dictionary:
	var applied := {
		"bits": 0,
		"digi_data": {},
		"flags": {},
		"unsupported": {},
	}
	var bits := maxi(0, int(rewards.get("bits", rewards.get("money", 0))))
	if bits > 0:
		roster.bits += bits
		applied["bits"] = bits
	var raw_data = rewards.get("digi_data", {})
	if raw_data is Dictionary:
		var data_applied: Dictionary = {}
		for raw_seed in raw_data.keys():
			var seed := String(raw_seed).strip_edges()
			var amount := maxi(0, int(raw_data[raw_seed]))
			if not seed.is_empty() and amount > 0:
				roster.add_digi_data(seed, amount)
				data_applied[seed] = amount
		applied["digi_data"] = data_applied
	var raw_flags = rewards.get("flags", {})
	if raw_flags is Dictionary:
		var flags_applied: Dictionary = {}
		for raw_flag in raw_flags.keys():
			var flag := String(raw_flag).strip_edges()
			if not flag.is_empty():
				var value = raw_flags[raw_flag]
				roster.progression_flags[flag] = value
				flags_applied[flag] = value
		applied["flags"] = flags_applied
	for raw_key in rewards.keys():
		var key := String(raw_key)
		if not ["bits", "money", "digi_data", "flags"].has(key):
			(applied["unsupported"] as Dictionary)[key] = rewards[raw_key]
	return applied


func _entry(roster: PlayerRoster, definition: QuestDefinition) -> Dictionary:
	var raw = roster.quest_states.get(definition.quest_id, {})
	var entry := _safe_dictionary(raw)
	if not entry.has("state"):
		entry["state"] = definition.initial_state
	if not entry.has("objective_progress"):
		entry["objective_progress"] = {}
	return entry


func _store_entry(roster: PlayerRoster, quest_id: String, entry: Dictionary) -> void:
	roster.quest_states[quest_id] = entry.duplicate(true)


func _objective_key(objective: Dictionary) -> String:
	var kind := String(objective.get("type", "")).to_lower()
	if kind == "species_defeated":
		return "%s:%s" % [kind, String(objective.get("species_seed", objective.get("species_id", ""))).strip_edges()]
	return kind


func _safe_dictionary(value) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
