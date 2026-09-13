extends RefCounted
class_name SaveMigration

const CURRENT_VERSION := 1


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
	data["save_version"] = version
	data.erase("saveVersion")
	return _normalize_v1(data)


func _migrate_unversioned(data: Dictionary) -> Dictionary:
	var roster: Dictionary = {}
	var existing_roster = data.get("roster")
	if data.has("roster") and existing_roster is Dictionary:
		roster = (existing_roster as Dictionary).duplicate(true)
	else:
		roster = {
			"instances": data.get("ownedDigimon", data.get("instances", [])),
			"activePartyIds": data.get("activePartyIds", []),
			"bits": data.get("bits", 0),
			"digiData": data.get("digiData", {}),
			"progressionFlags": data.get("progressionFlags", {}),
			"questStates": data.get("questStates", {}),
		}
	return {
		"save_version": 1,
		"roster": roster,
	}


func _normalize_v1(data: Dictionary) -> Dictionary:
	var result := {
		"save_version": 1,
		"roster": {
			"instances": [],
			"activePartyIds": [],
			"bits": 0,
			"digiData": {},
			"progressionFlags": {},
			"questStates": {},
		},
	}
	var raw_roster = data.get("roster", {})
	if not raw_roster is Dictionary:
		return result
	var source := raw_roster as Dictionary
	var roster := result["roster"] as Dictionary
	if source.get("instances", []) is Array:
		roster["instances"] = (source.get("instances", []) as Array).duplicate(true)
	if source.get("activePartyIds", []) is Array:
		roster["activePartyIds"] = (source.get("activePartyIds", []) as Array).duplicate()
	roster["bits"] = maxi(0, int(source.get("bits", 0)))
	for dictionary_key: String in ["digiData", "progressionFlags", "questStates"]:
		var raw_value = source.get(dictionary_key, {})
		if raw_value is Dictionary:
			roster[dictionary_key] = (raw_value as Dictionary).duplicate(true)
	return result
