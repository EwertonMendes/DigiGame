extends RefCounted
class_name PlayerCollection

const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")

var bits: int = 0
var progression_flags: Dictionary = {}
var quest_states: Dictionary = {}
var unlocked_technique_records: Array[String] = []
var technique_research: Dictionary = {}
var inventory: Dictionary = {}

var _instances_by_id: Dictionary = {}
var _instance_id_by_key: Dictionary = {}
var _collection_key_by_id: Dictionary = {}
var _active_party_ids: Array[String] = []
var _digi_data_by_seed: Dictionary = {}

func is_empty() -> bool:
	return _instances_by_id.is_empty()

func add_instance(instance: DigimonInstance, preferred_key: String = "", species_name: String = "") -> String:
	if instance == null or instance.id.strip_edges().is_empty():
		return ""
	if _instances_by_id.has(instance.id):
		return String(_collection_key_by_id.get(instance.id, ""))
	var base_key := preferred_key.to_lower().strip_edges()
	if base_key.is_empty():
		base_key = species_name.to_lower().strip_edges().replace(" ", "_")
	if base_key.is_empty():
		base_key = "digimon"
	var key := _unique_key(base_key)
	_instances_by_id[instance.id] = instance
	_instance_id_by_key[key] = instance.id
	_collection_key_by_id[instance.id] = key
	return key

func replace_at_key(instance: DigimonInstance, collection_key: String, species_name: String = "") -> bool:
	if instance == null:
		return false
	var key := collection_key.to_lower().strip_edges()
	if key.is_empty():
		return not add_instance(instance, "", species_name).is_empty()
	var old_id := String(_instance_id_by_key.get(key, ""))
	if old_id.is_empty():
		return not add_instance(instance, key, species_name).is_empty()
	if old_id != instance.id and _instances_by_id.has(instance.id):
		return false
	_instances_by_id.erase(old_id)
	_collection_key_by_id.erase(old_id)
	_instances_by_id[instance.id] = instance
	_instance_id_by_key[key] = instance.id
	_collection_key_by_id[instance.id] = key
	var active_index := _active_party_ids.find(old_id)
	if active_index >= 0:
		_active_party_ids[active_index] = instance.id
	return true

func get_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	var keys: Array[String] = []
	for raw_key in _instance_id_by_key.keys():
		keys.append(String(raw_key))
	keys.sort()
	for key: String in keys:
		var instance_id := String(_instance_id_by_key.get(key, ""))
		var instance = _instances_by_id.get(instance_id)
		if instance is DigimonInstance:
			result.append(instance)
	return result

func get_instance(instance_id: String) -> DigimonInstance:
	var instance = _instances_by_id.get(instance_id)
	return instance as DigimonInstance if instance is DigimonInstance else null

func get_instance_by_key(collection_key: String) -> DigimonInstance:
	var instance_id := String(_instance_id_by_key.get(collection_key.to_lower().strip_edges(), ""))
	return get_instance(instance_id)

func get_key_for_instance(instance_id: String) -> String:
	return String(_collection_key_by_id.get(instance_id, ""))

func has_instance(instance_id: String) -> bool:
	return _instances_by_id.has(instance_id)

func remove_reserve_instance(instance_id: String) -> bool:
	var clean_id := instance_id.strip_edges()
	if clean_id.is_empty() or not _instances_by_id.has(clean_id) or _active_party_ids.has(clean_id):
		return false
	var key := String(_collection_key_by_id.get(clean_id, ""))
	_instances_by_id.erase(clean_id)
	_collection_key_by_id.erase(clean_id)
	if not key.is_empty():
		_instance_id_by_key.erase(key)
	return true

func get_active_party_ids() -> Array[String]:
	return _active_party_ids.duplicate()

func get_active_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance_id: String in _active_party_ids:
		var instance := get_instance(instance_id)
		if instance != null:
			result.append(instance)
	return result

func get_reserve_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance: DigimonInstance in get_instances():
		if not _active_party_ids.has(instance.id):
			result.append(instance)
	return result

func set_active_party_ids(instance_ids: Array[String], minimum_size: int, maximum_size: int) -> bool:
	if instance_ids.size() < minimum_size or instance_ids.size() > maximum_size:
		return false
	var normalized: Array[String] = []
	for instance_id: String in instance_ids:
		var clean_id := instance_id.strip_edges()
		if clean_id.is_empty() or not _instances_by_id.has(clean_id) or normalized.has(clean_id):
			return false
		normalized.append(clean_id)
	_active_party_ids = normalized
	return true

func add_digi_data(species_seed: String, amount: int) -> int:
	var seed := species_seed.strip_edges()
	if seed.is_empty() or amount <= 0:
		return get_digi_data(seed)
	_digi_data_by_seed[seed] = get_digi_data(seed) + amount
	return int(_digi_data_by_seed[seed])

func consume_digi_data(species_seed: String, amount: int) -> bool:
	var seed := species_seed.strip_edges()
	var cost := maxi(0, amount)
	if seed.is_empty() or get_digi_data(seed) < cost:
		return false
	var remaining := get_digi_data(seed) - cost
	if remaining <= 0:
		_digi_data_by_seed.erase(seed)
	else:
		_digi_data_by_seed[seed] = remaining
	return true

func get_digi_data(species_seed: String) -> int:
	return maxi(0, int(_digi_data_by_seed.get(species_seed.strip_edges(), 0)))

func get_all_digi_data() -> Dictionary:
	return _digi_data_by_seed.duplicate(true)

func get_item_count(item_id: String) -> int:
	return maxi(0, int(inventory.get(item_id.strip_edges(), 0)))

func add_item(item_id: String, amount: int = 1) -> int:
	var clean_id := item_id.strip_edges()
	if clean_id.is_empty() or amount <= 0:
		return get_item_count(clean_id)
	inventory[clean_id] = get_item_count(clean_id) + amount
	return int(inventory[clean_id])

func consume_item(item_id: String, amount: int = 1) -> bool:
	var clean_id := item_id.strip_edges()
	var cost := maxi(0, amount)
	if clean_id.is_empty() or cost <= 0 or get_item_count(clean_id) < cost:
		return false
	var remaining := get_item_count(clean_id) - cost
	if remaining == 0:
		inventory.erase(clean_id)
	else:
		inventory[clean_id] = remaining
	return true

func get_inventory() -> Dictionary:
	return inventory.duplicate(true)


func has_technique_record(skill_id: String) -> bool:
	return unlocked_technique_records.has(skill_id.strip_edges())


func unlock_technique_record(skill_id: String) -> bool:
	var clean_id := skill_id.strip_edges()
	if clean_id.is_empty() or unlocked_technique_records.has(clean_id):
		return false
	unlocked_technique_records.append(clean_id)
	technique_research.erase(clean_id)
	return true


func get_technique_research(skill_id: String) -> int:
	return clampi(int(technique_research.get(skill_id.strip_edges(), 0)), 0, 3)


func add_technique_research(skill_id: String, amount: int = 1) -> Dictionary:
	var clean_id := skill_id.strip_edges()
	var result := {"skill_id": clean_id, "old_points": 0, "new_points": 0, "unlocked": false}
	if clean_id.is_empty() or amount <= 0 or has_technique_record(clean_id):
		return result
	var old_points := get_technique_research(clean_id)
	var new_points := clampi(old_points + amount, 0, 3)
	result["old_points"] = old_points
	result["new_points"] = new_points
	if new_points >= 3:
		unlock_technique_record(clean_id)
		result["unlocked"] = true
	else:
		technique_research[clean_id] = new_points
	return result

func to_dict() -> Dictionary:
	var entries: Array[Dictionary] = []
	for instance: DigimonInstance in get_instances():
		entries.append({"collectionKey": get_key_for_instance(instance.id), "instance": instance.to_dict()})
	return {
		"instances": entries,
		"activePartyIds": get_active_party_ids(),
		"bits": bits,
		"digiData": get_all_digi_data(),
		"progressionFlags": progression_flags.duplicate(true),
		"questStates": quest_states.duplicate(true),
		"unlockedTechniqueRecords": unlocked_technique_records.duplicate(),
		"techniqueResearch": technique_research.duplicate(true),
		"inventory": get_inventory(),
	}

func load_dict(data: Dictionary) -> void:
	_instances_by_id.clear()
	_instance_id_by_key.clear()
	_collection_key_by_id.clear()
	_active_party_ids.clear()
	_digi_data_by_seed.clear()
	unlocked_technique_records.clear()
	technique_research.clear()
	inventory.clear()
	bits = maxi(0, int(data.get("bits", 0)))
	progression_flags = _safe_dictionary(data.get("progressionFlags", {}))
	quest_states = _safe_dictionary(data.get("questStates", {}))
	var raw_records = data.get("unlockedTechniqueRecords", [])
	if raw_records is Array:
		for raw_record in raw_records:
			var record_id := String(raw_record).strip_edges()
			if not record_id.is_empty() and not unlocked_technique_records.has(record_id):
				unlocked_technique_records.append(record_id)
	var raw_research = data.get("techniqueResearch", {})
	if raw_research is Dictionary:
		for raw_skill_id in raw_research.keys():
			var skill_id := String(raw_skill_id).strip_edges()
			var points := clampi(int(raw_research[raw_skill_id]), 0, 2)
			if not skill_id.is_empty() and points > 0 and not unlocked_technique_records.has(skill_id):
				technique_research[skill_id] = points
	var raw_inventory = data.get("inventory", {})
	if raw_inventory is Dictionary:
		for raw_item_id in raw_inventory.keys():
			var item_id := String(raw_item_id).strip_edges()
			var amount := maxi(0, int(raw_inventory[raw_item_id]))
			if not item_id.is_empty() and amount > 0:
				inventory[item_id] = amount

	var action_database = ActionDatabaseScript.new()
	var action_database_ready := action_database.load_default()
	var entries = data.get("instances", [])
	if entries is Array:
		for raw_entry in entries:
			if not raw_entry is Dictionary:
				continue
			var entry := raw_entry as Dictionary
			var raw_instance = entry.get("instance", {})
			if not raw_instance is Dictionary:
				continue
			var instance := DigimonInstance.from_dict(raw_instance as Dictionary)
			if instance.species_seed.is_empty() or _instances_by_id.has(instance.id):
				continue
			if action_database_ready:
				_migrate_instance_skill_ids(instance, action_database)
			add_instance(instance, String(entry.get("collectionKey", "")), "digimon")
	var raw_party = data.get("activePartyIds", [])
	if raw_party is Array:
		for raw_id in raw_party:
			var instance_id := String(raw_id)
			if _instances_by_id.has(instance_id) and not _active_party_ids.has(instance_id):
				_active_party_ids.append(instance_id)
	var raw_data = data.get("digiData", {})
	if raw_data is Dictionary:
		for raw_seed in raw_data.keys():
			var seed := String(raw_seed).strip_edges()
			var amount := maxi(0, int(raw_data[raw_seed]))
			if not seed.is_empty() and amount > 0:
				_digi_data_by_seed[seed] = amount

func _migrate_instance_skill_ids(instance: DigimonInstance, action_database) -> void:
	if instance == null or action_database == null:
		return
	var species_key := instance.species_seed
	var old_learned := instance.learned_skills.duplicate()
	var old_favorites := instance.favorite_skills.duplicate()
	var old_archived := instance.archived_skills.duplicate()
	var old_mastery := instance.skill_mastery.duplicate(true)
	var migrated_learned: Array[String] = []
	var migrated_mastery: Dictionary = {}

	for raw_skill_id in old_learned:
		var old_id := String(raw_skill_id).strip_edges()
		if old_id.is_empty():
			continue
		var resolved_id := String(action_database.resolve_skill_id(species_key, old_id)).strip_edges()
		if resolved_id.is_empty():
			resolved_id = old_id
		if not migrated_learned.has(resolved_id):
			migrated_learned.append(resolved_id)
		var old_points := clampi(int(old_mastery.get(old_id, old_mastery.get(resolved_id, 0))), 0, DigimonInstance.MAX_SKILL_MASTERY_POINTS)
		migrated_mastery[resolved_id] = maxi(int(migrated_mastery.get(resolved_id, 0)), old_points)

	var migrated_favorites: Array[String] = []
	for raw_skill_id in old_favorites:
		var resolved_id := String(action_database.resolve_skill_id(species_key, String(raw_skill_id))).strip_edges()
		if migrated_learned.has(resolved_id) and not migrated_favorites.has(resolved_id) and migrated_favorites.size() < DigimonInstance.MAX_FAVORITE_SKILLS:
			migrated_favorites.append(resolved_id)

	var migrated_archived: Array[String] = []
	for raw_skill_id in old_archived:
		var resolved_id := String(action_database.resolve_skill_id(species_key, String(raw_skill_id))).strip_edges()
		if migrated_learned.has(resolved_id) and not migrated_archived.has(resolved_id):
			migrated_archived.append(resolved_id)
			migrated_favorites.erase(resolved_id)

	instance.learned_skills = migrated_learned
	instance.favorite_skills = migrated_favorites
	instance.archived_skills = migrated_archived
	instance.skill_mastery = migrated_mastery

func _unique_key(base_key: String) -> String:
	var clean := base_key.to_lower().strip_edges()
	if clean.is_empty():
		clean = "digimon"
	if not _instance_id_by_key.has(clean):
		return clean
	var suffix := 2
	while _instance_id_by_key.has("%s_%d" % [clean, suffix]):
		suffix += 1
	return "%s_%d" % [clean, suffix]

func _safe_dictionary(value) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
