extends RefCounted
class_name SaveMigration

const CURRENT_VERSION := 6

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
	if version == 3:
		data = _migrate_v3_to_v4(data)
		version = 4
	if version == 4:
		data = _migrate_v4_to_v5(data)
		version = 5
	if version == 5:
		data = _migrate_v5_to_v6(data)
		version = 6
	data["save_version"] = version
	data.erase("saveVersion")
	return _normalize_v6(data)

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


func _migrate_v3_to_v4(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var raw_collection = result.get("collection", {})
	if not raw_collection is Dictionary:
		return {"save_version": 4, "collection": {}}
	var collection := raw_collection as Dictionary
	collection["inventory"] = collection.get("inventory", {})
	var raw_entries = collection.get("instances", [])
	if raw_entries is Array:
		for raw_entry in raw_entries:
			if not raw_entry is Dictionary:
				continue
			var raw_instance = (raw_entry as Dictionary).get("instance", {})
			if not raw_instance is Dictionary:
				continue
			var instance := raw_instance as Dictionary
			instance["tier"] = String(instance.get("tier", "E")).to_upper()
			instance["expansionUnlocked"] = bool(instance.get("expansionUnlocked", false))
			instance["battleFootprintId"] = String(instance.get("battleFootprintId", "single"))
	result["save_version"] = 4
	return result


func _migrate_v4_to_v5(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var raw_collection = result.get("collection", {})
	if not raw_collection is Dictionary:
		return {"save_version": 5, "collection": {}}
	var raw_entries = (raw_collection as Dictionary).get("instances", [])
	if raw_entries is Array:
		for raw_entry in raw_entries:
			if not raw_entry is Dictionary:
				continue
			var raw_instance = (raw_entry as Dictionary).get("instance", {})
			if raw_instance is Dictionary:
				(raw_instance as Dictionary)["hospitalRecovery"] = (raw_instance as Dictionary).get("hospitalRecovery", {})
	result["save_version"] = 5
	return result


func _migrate_v5_to_v6(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var raw_collection = result.get("collection", {})
	if not raw_collection is Dictionary:
		return {"save_version": 6, "collection": {}}
	var collection := raw_collection as Dictionary
	var hospital_ids: Array[String] = []
	var raw_existing_hospital = collection.get("hospitalIds", [])
	if raw_existing_hospital is Array:
		for raw_id in raw_existing_hospital:
			var existing_id := String(raw_id).strip_edges()
			if not existing_id.is_empty() and not hospital_ids.has(existing_id):
				hospital_ids.append(existing_id)
	var raw_entries = collection.get("instances", [])
	if raw_entries is Array:
		for raw_entry in raw_entries:
			if not raw_entry is Dictionary:
				continue
			var raw_instance = (raw_entry as Dictionary).get("instance", {})
			if not raw_instance is Dictionary:
				continue
			var instance := raw_instance as Dictionary
			var instance_id := String(instance.get("id", "")).strip_edges()
			var recovery = instance.get("hospitalRecovery", {})
			if instance_id.is_empty() or not recovery is Dictionary:
				continue
			var started_at := maxi(0, int((recovery as Dictionary).get("startedAt", 0)))
			var completes_at := maxi(0, int((recovery as Dictionary).get("completesAt", 0)))
			if completes_at > 0 and completes_at >= started_at and not hospital_ids.has(instance_id):
				hospital_ids.append(instance_id)
	collection["hospitalIds"] = hospital_ids
	var active_ids: Array[String] = []
	var raw_party = collection.get("activePartyIds", [])
	if raw_party is Array:
		for raw_id in raw_party:
			var instance_id := String(raw_id).strip_edges()
			if not instance_id.is_empty() and not hospital_ids.has(instance_id) and not active_ids.has(instance_id):
				active_ids.append(instance_id)
	collection["activePartyIds"] = active_ids
	result["save_version"] = 6
	return result


func _normalize_v6(data: Dictionary) -> Dictionary:
	var result := {
		"save_version": 6,
		"collection": {
			"instances": [],
			"activePartyIds": [],
			"hospitalIds": [],
			"bits": 0,
			"digiData": {},
			"progressionFlags": {},
			"questStates": {},
			"unlockedTechniqueRecords": [],
			"techniqueResearch": {},
			"inventory": {},
		},
	}
	var raw_collection = data.get("collection", {})
	if not raw_collection is Dictionary:
		return result
	var source := raw_collection as Dictionary
	var collection := result["collection"] as Dictionary
	var known_ids: Dictionary = {}
	if source.get("instances", []) is Array:
		var entries := (source.get("instances", []) as Array).duplicate(true)
		collection["instances"] = entries
		for raw_entry in entries:
			if not raw_entry is Dictionary:
				continue
			var raw_instance = (raw_entry as Dictionary).get("instance", {})
			if raw_instance is Dictionary:
				var instance_id := String((raw_instance as Dictionary).get("id", "")).strip_edges()
				if not instance_id.is_empty():
					known_ids[instance_id] = true

	var hospital_ids: Array[String] = []
	var raw_hospital = source.get("hospitalIds", [])
	if raw_hospital is Array:
		for raw_id in raw_hospital:
			var instance_id := String(raw_id).strip_edges()
			if known_ids.has(instance_id) and not hospital_ids.has(instance_id):
				hospital_ids.append(instance_id)
	collection["hospitalIds"] = hospital_ids

	var party_ids: Array[String] = []
	var raw_party = source.get("activePartyIds", [])
	if raw_party is Array:
		for raw_id in raw_party:
			var instance_id := String(raw_id).strip_edges()
			if known_ids.has(instance_id) and not hospital_ids.has(instance_id) and not party_ids.has(instance_id):
				party_ids.append(instance_id)
	collection["activePartyIds"] = party_ids

	collection["bits"] = maxi(0, int(source.get("bits", 0)))
	for dictionary_key: String in ["digiData", "progressionFlags", "questStates", "techniqueResearch", "inventory"]:
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