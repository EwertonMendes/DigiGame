extends RefCounted
class_name SaveMigration

# Pre-release save reset: Squad 6 is the first durable save contract.
# Older prototype saves are intentionally invalid and are replaced by a fresh save.
const CURRENT_VERSION := 1
const SAVE_FORMAT := "squad-v1"


func migrate(raw_data: Dictionary) -> Dictionary:
	if raw_data.is_empty():
		return {}
	var version := int(raw_data.get("save_version", -1))
	var format := String(raw_data.get("save_format", ""))
	if version != CURRENT_VERSION or format != SAVE_FORMAT:
		push_warning(
			"Discarding incompatible prototype save (version=%d, format=%s); expected version=%d, format=%s."
			% [version, format, CURRENT_VERSION, SAVE_FORMAT]
		)
		return {}
	var raw_collection = raw_data.get("collection", {})
	if not raw_collection is Dictionary:
		push_error("Player save collection must be an object")
		return {}
	return _normalize_v1(raw_collection as Dictionary)


func _normalize_v1(source: Dictionary) -> Dictionary:
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

	return {
		"save_version": CURRENT_VERSION,
		"save_format": SAVE_FORMAT,
		"collection": collection,
	}
