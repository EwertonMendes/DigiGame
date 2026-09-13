extends RefCounted
class_name SaveMigration

const CURRENT_VERSION := 2

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
	data["save_version"] = version
	data.erase("saveVersion")
	return _normalize_v2(data)

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

func _normalize_v2(data: Dictionary) -> Dictionary:
	var result := {
		"save_version": 2,
		"collection": {
			"instances": [],
			"activePartyIds": [],
			"bits": 0,
			"digiData": {},
			"progressionFlags": {},
			"questStates": {},
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
	for dictionary_key: String in ["digiData", "progressionFlags", "questStates"]:
		var raw_value = source.get(dictionary_key, {})
		if raw_value is Dictionary:
			collection[dictionary_key] = (raw_value as Dictionary).duplicate(true)
	return result
