extends RefCounted
class_name QuestService

const FusionProgressScript = preload("res://src/digimon/FusionProgressService.gd")
const FusionCatalogScript = preload("res://src/digimon/FusionCatalog.gd")

var _fusion_progress = FusionProgressScript.new()
var _fusion_catalog: FusionCatalog = FusionCatalogScript.new()


func _init() -> void:
	_fusion_catalog.load_default()

const STATE_LOCKED := "locked"
const STATE_AVAILABLE := "available"
const STATE_ACTIVE := "active"
const STATE_COMPLETED := "completed"

func get_state(collection: PlayerCollection, definition: QuestDefinition) -> String:
	if collection == null or definition == null:
		return STATE_LOCKED
	var entry := _entry(collection, definition)
	return String(entry.get("state", definition.initial_state))

func set_available(collection: PlayerCollection, definition: QuestDefinition) -> bool:
	if collection == null or definition == null or definition.quest_id.strip_edges().is_empty():
		return false
	var entry := _entry(collection, definition)
	var state := String(entry.get("state", definition.initial_state))
	if state == STATE_COMPLETED or state == STATE_ACTIVE:
		return false
	entry["state"] = STATE_AVAILABLE
	_store_entry(collection, definition.quest_id, entry)
	return true

func start(collection: PlayerCollection, definition: QuestDefinition) -> bool:
	if collection == null or definition == null:
		return false
	var entry := _entry(collection, definition)
	var state := String(entry.get("state", definition.initial_state))
	if state != STATE_AVAILABLE:
		return false
	entry["state"] = STATE_ACTIVE
	_store_entry(collection, definition.quest_id, entry)
	return true

func record_species_defeat(collection: PlayerCollection, definition: QuestDefinition, species_seed: String, amount: int = 1) -> Dictionary:
	var seed := species_seed.strip_edges()
	if seed.is_empty():
		return _empty_result(collection, definition)
	return _record_objective_progress(collection, definition, "species_defeated", seed, amount)

func record_battle_win(collection: PlayerCollection, definition: QuestDefinition, amount: int = 1) -> Dictionary:
	return _record_objective_progress(collection, definition, "battle_wins", "", amount)

func objective_status(collection: PlayerCollection, definition: QuestDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if collection == null or definition == null:
		return result
	var entry := _entry(collection, definition)
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

func completion_count(collection: PlayerCollection, definition: QuestDefinition) -> int:
	if collection == null or definition == null:
		return 0
	return maxi(0, int(_entry(collection, definition).get("completion_count", 0)))

func _record_objective_progress(collection: PlayerCollection, definition: QuestDefinition, kind: String, discriminator: String, amount: int) -> Dictionary:
	var result := _empty_result(collection, definition)
	if collection == null or definition == null or amount <= 0 or get_state(collection, definition) != STATE_ACTIVE:
		return result
	var entry := _entry(collection, definition)
	var progress := _safe_dictionary(entry.get("objective_progress", {}))
	var changed := false
	for objective: Dictionary in definition.objectives:
		var objective_kind := String(objective.get("type", "")).to_lower()
		if objective_kind != kind:
			continue
		if kind == "species_defeated":
			var target_seed := String(objective.get("species_seed", objective.get("species_id", ""))).strip_edges()
			if target_seed != discriminator:
				continue
		var key := _objective_key(objective)
		progress[key] = maxi(0, int(progress.get(key, 0))) + amount
		changed = true
	if not changed:
		return result
	entry["objective_progress"] = progress
	result["changed"] = true
	if _all_objectives_complete(definition, progress):
		var count := maxi(0, int(entry.get("completion_count", 0))) + 1
		entry["completion_count"] = count
		result["completed"] = true
		result["completion_count"] = count
		result["rewards"] = _apply_rewards(collection, definition.rewards)
		if definition.repeatable:
			entry["state"] = STATE_ACTIVE
			entry["objective_progress"] = {}
			result["repeatable_reset"] = true
		else:
			entry["state"] = STATE_COMPLETED
	_store_entry(collection, definition.quest_id, entry)
	result["state"] = String(entry.get("state", STATE_ACTIVE))
	return result

func _empty_result(collection: PlayerCollection, definition: QuestDefinition) -> Dictionary:
	return {
		"changed": false,
		"completed": false,
		"state": get_state(collection, definition),
		"rewards": {},
		"completion_count": completion_count(collection, definition) if collection != null and definition != null else 0,
		"repeatable_reset": false,
	}

func _all_objectives_complete(definition: QuestDefinition, progress: Dictionary) -> bool:
	if definition.objectives.is_empty():
		return false
	for objective: Dictionary in definition.objectives:
		var required := maxi(1, int(objective.get("amount", objective.get("value", 1))))
		if int(progress.get(_objective_key(objective), 0)) < required:
			return false
	return true

func _apply_rewards(collection: PlayerCollection, rewards: Dictionary) -> Dictionary:
	var applied := {"bits": 0, "digi_data": {}, "fusion_data": {}, "items": {}, "flags": {}, "unsupported": {}}
	var bits := maxi(0, int(rewards.get("bits", rewards.get("money", 0))))
	if bits > 0:
		collection.bits += bits
		applied["bits"] = bits
	var raw_data = rewards.get("digi_data", {})
	if raw_data is Dictionary:
		var data_applied: Dictionary = {}
		for raw_seed in raw_data.keys():
			var seed := String(raw_seed).strip_edges()
			var amount := maxi(0, int(raw_data[raw_seed]))
			if not seed.is_empty() and amount > 0:
				collection.add_digi_data(seed, amount)
				data_applied[seed] = amount
		applied["digi_data"] = data_applied
	var raw_fusion_data = rewards.get("fusion_data", {})
	if raw_fusion_data is Dictionary:
		var fusion_applied: Dictionary = {}
		for raw_fusion_id in raw_fusion_data.keys():
			var fusion_id := String(raw_fusion_id).to_lower().strip_edges()
			var amount := maxi(0, int(raw_fusion_data[raw_fusion_id]))
			if fusion_id.is_empty() or amount <= 0:
				continue
			var progress := _fusion_progress.add_data(collection, fusion_id, amount, _fusion_catalog, "quest_reward")
			var gained := int(progress.get("gained", 0))
			if gained > 0:
				fusion_applied[fusion_id] = gained
		applied["fusion_data"] = fusion_applied
	var raw_items = rewards.get("items", {})
	if raw_items is Dictionary:
		var items_applied: Dictionary = {}
		for raw_item_id in raw_items.keys():
			var item_id := String(raw_item_id).strip_edges()
			var amount := maxi(0, int(raw_items[raw_item_id]))
			if not item_id.is_empty() and amount > 0:
				collection.add_item(item_id, amount)
				items_applied[item_id] = amount
		applied["items"] = items_applied
	var raw_flags = rewards.get("flags", {})
	if raw_flags is Dictionary:
		var flags_applied: Dictionary = {}
		for raw_flag in raw_flags.keys():
			var flag := String(raw_flag).strip_edges()
			if not flag.is_empty():
				var value = raw_flags[raw_flag]
				collection.progression_flags[flag] = value
				flags_applied[flag] = value
		applied["flags"] = flags_applied
	for raw_key in rewards.keys():
		var key := String(raw_key)
		if not ["bits", "money", "digi_data", "fusion_data", "items", "flags"].has(key):
			(applied["unsupported"] as Dictionary)[key] = rewards[raw_key]
	return applied

func _entry(collection: PlayerCollection, definition: QuestDefinition) -> Dictionary:
	var raw = collection.quest_states.get(definition.quest_id, {})
	var entry := _safe_dictionary(raw)
	if not entry.has("state"):
		entry["state"] = definition.initial_state
	if not entry.has("objective_progress"):
		entry["objective_progress"] = {}
	if not entry.has("completion_count"):
		entry["completion_count"] = 0
	return entry

func _store_entry(collection: PlayerCollection, quest_id: String, entry: Dictionary) -> void:
	collection.quest_states[quest_id] = entry.duplicate(true)

func _objective_key(objective: Dictionary) -> String:
	var kind := String(objective.get("type", "")).to_lower()
	if kind == "species_defeated":
		return "%s:%s" % [kind, String(objective.get("species_seed", objective.get("species_id", ""))).strip_edges()]
	return kind

func _safe_dictionary(value) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
