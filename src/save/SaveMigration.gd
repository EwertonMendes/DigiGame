extends RefCounted
class_name SaveMigration

const CURRENT_VERSION := 3

func migrate(raw_data: Dictionary) -> Dictionary:
	if raw_data.is_empty():
		return {}
	var data := raw_data.duplicate(true)
	var version := int(data.get("save_version", data.get("saveVersion", 0)))
	if version > CURRENT_VERSION:
		push_error("Save version %d is newer than supported version %d" % [version, CURRENT_VERSION])
		return {}
	if version <= 0:
		data = _migrate_unversioned(data)
		version = 1
	if version == 1:
		data = _migrate_v1_to_v2(data)
		version = 2
	if version == 2:
		data = _migrate_v2_to_v3(data)
		version = 3
	data["save_version"] = version
	data.erase("saveVersion")
	return _normalize_v3(data)

func _migrate_unversioned(data: Dictionary) -> Dictionary:
	var legacy_collection: Dictionary = {}
	var legacy_root = data.get("roster")
	if data.has("roster") and legacy_root is Dictionary:
		legacy_collection = (legacy_root as Dictionary).duplicate(true)
	else:
		legacy_collection = {
			"instances": data.get("ownedDigimon", data.get("instances", [])),
			"activePartyIds": data.get("activePartyIds", []),
			"bits": data.get("bits", 0),
			"digiData": data.get("digiData", {}),
			"progressionFlags": data.get("progressionFlags", {}),
			"questStates": data.get("questStates", {}),
		}
	return {"save_version": 1, "roster": legacy_collection}

func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var legacy_root = data.get("roster", {})
	var collection: Dictionary = (legacy_root as Dictionary).duplicate(true) if legacy_root is Dictionary else {}
	var raw_entries = collection.get("instances", [])
	if raw_entries is Array:
		var migrated_entries: Array = []
		for raw_entry in raw_entries:
			if not raw_entry is Dictionary:
				continue
			var entry := (raw_entry as Dictionary).duplicate(true)
			if not entry.has("collectionKey"):
				entry["collectionKey"] = String(entry.get("rosterKey", ""))
			entry.erase("rosterKey")
			migrated_entries.append(entry)
		collection["instances"] = migrated_entries
	return {"save_version": 2, "collection": collection}


func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var raw_collection = result.get("collection", {})
	if not raw_collection is Dictionary:
		return {"save_version": 3, "collection": {}}
	var collection := raw_collection as Dictionary
	collection["unlockedTechniqueRecords"] = collection.get("unlockedTechniqueRecords", [])
	collection["techniqueResearch"] = collection.get("techniqueResearch", {})
	var raw_entries = collection.get("instances", [])
	if raw_entries is Array:
		for raw_entry in raw_entries:
			if not raw_entry is Dictionary:
				continue
			var entry := raw_entry as Dictionary
			var raw_instance = entry.get("instance", {})
			if not raw_instance is Dictionary:
				continue
			var instance := raw_instance as Dictionary
			var favorites: Array = []
			var equipped = instance.get("equippedSkills", [])
			if equipped is Array:
				for raw_skill in equipped:
					var skill_id := String(raw_skill).strip_edges()
					if skill_id.is_empty() or favorites.has(skill_id) or favorites.size() >= 4:
						continue
					favorites.append(skill_id)
			instance["favoriteSkills"] = favorites
			instance["archivedSkills"] = []
			var mastery: Dictionary = {}
			var learned = instance.get("learnedSkills", [])
			if learned is Array:
				for raw_skill in learned:
					var skill_id := String(raw_skill).strip_edges()
					if not skill_id.is_empty():
						mastery[skill_id] = 0
			instance["skillMastery"] = mastery
			instance.erase("equippedSkills")
	result["save_version"] = 3
	return result


func _normalize_v3(data: Dictionary) -> Dictionary:
	var result := {
		"save_version": 3,
		"collection": {
			"instances": [],
			"activePartyIds": [],
			"bits": 0,
			"digiData": {},
			"progressionFlags": {},
			"questStates": {},
			"unlockedTechniqueRecords": [],
			"techniqueResearch": {},
		},
	}
	var raw_collection = data.get("collection", {})
	if not raw_collection is Dictionary:
		return result
	var source := raw_collection as Dictionary
	var collection := result["collection"] as Dictionary
	if source.get("instances", []) is Array:
		collection["instances"] = (source.get("instances", []) as Array).duplicate(true)
	if source.get("activePartyIds", []) is Array:
		collection["activePartyIds"] = (source.get("activePartyIds", []) as Array).duplicate()
	collection["bits"] = maxi(0, int(source.get("bits", 0)))
	for dictionary_key: String in ["digiData", "progressionFlags", "questStates", "techniqueResearch"]:
		var raw_value = source.get(dictionary_key, {})
		if raw_value is Dictionary:
			collection[dictionary_key] = (raw_value as Dictionary).duplicate(true)
	var records = source.get("unlockedTechniqueRecords", [])
	if records is Array:
		var normalized_records: Array[String] = []
		for raw_record in records:
			var record_id := String(raw_record).strip_edges()
			if not record_id.is_empty() and not normalized_records.has(record_id):
				normalized_records.append(record_id)
		collection["unlockedTechniqueRecords"] = normalized_records
	return result
