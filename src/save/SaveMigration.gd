extends RefCounted
class_name SaveMigration

const CURRENT_VERSION := 2
const SAVE_FORMAT := "world-v2"
const PREVIOUS_VERSION := 1
const PREVIOUS_FORMAT := "squad-v1"


func migrate(raw_data: Dictionary) -> Dictionary:
	if raw_data.is_empty():
		return {}
	var version := int(raw_data.get("save_version", -1))
	var format := String(raw_data.get("save_format", ""))

	if version == CURRENT_VERSION and format == SAVE_FORMAT:
		var raw_collection = raw_data.get("collection", {})
		if not raw_collection is Dictionary:
			push_error("Player save collection must be an object")
			return {}
		return {
			"save_version": CURRENT_VERSION,
			"save_format": SAVE_FORMAT,
			"collection": _normalize_collection(raw_collection as Dictionary),
			"world": _normalize_world(_dictionary_copy(raw_data.get("world", {}))),
		}

	if version == PREVIOUS_VERSION and format == PREVIOUS_FORMAT:
		var legacy_collection = raw_data.get("collection", {})
		if not legacy_collection is Dictionary:
			return {}
		return {
			"save_version": CURRENT_VERSION,
			"save_format": SAVE_FORMAT,
			"collection": _normalize_collection(legacy_collection as Dictionary),
			"world": _normalize_world({}),
		}

	push_warning(
		"Discarding incompatible prototype save (version=%d, format=%s); expected %s or migratable %s."
		% [version, format, SAVE_FORMAT, PREVIOUS_FORMAT]
	)
	return {}


func _normalize_collection(source: Dictionary) -> Dictionary:
	var collection := {
		"instances": [],
		"activeSquadIds": [],
		"reserveSquadIds": [],
		"hospitalIds": [],
		"hospitalReturnSlots": {},
		"bits": maxi(0, int(source.get("bits", 0))),
		"digiData": {},
		"progressionFlags": {},
		"questStates": {},
		"unlockedTechniqueRecords": [],
		"techniqueResearch": {},
		"inventory": {},
	}

	var raw_instances = source.get("instances", [])
	if raw_instances is Array:
		collection["instances"] = (raw_instances as Array).duplicate(true)

	for array_key: String in ["activeSquadIds", "reserveSquadIds", "hospitalIds", "unlockedTechniqueRecords"]:
		var raw_value = source.get(array_key, [])
		if raw_value is Array:
			collection[array_key] = (raw_value as Array).duplicate(true)

	for dictionary_key: String in [
		"hospitalReturnSlots",
		"digiData",
		"progressionFlags",
		"questStates",
		"techniqueResearch",
		"inventory",
	]:
		var raw_value = source.get(dictionary_key, {})
		if raw_value is Dictionary:
			collection[dictionary_key] = (raw_value as Dictionary).duplicate(true)
	return collection


func _normalize_world(source: Dictionary) -> Dictionary:
	return {
		"region": String(source.get("region", "central_city")),
		"area": String(source.get("area", "central_city")),
		"chunk": _pair(source.get("chunk", []), [0, 0]),
		"position": _pair(source.get("position", []), [0.0, 224.0]),
		"facing": String(source.get("facing", "south")),
		"story_flags": _dictionary_copy(source.get("story_flags", {})),
		"world_variants": _dictionary_copy(source.get("world_variants", {})),
		"opened_objects": _dictionary_copy(source.get("opened_objects", {})),
	}


func _pair(raw, fallback: Array) -> Array:
	if raw is Array and raw.size() >= 2:
		return [raw[0], raw[1]]
	return fallback.duplicate()


func _dictionary_copy(raw) -> Dictionary:
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
