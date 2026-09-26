extends RefCounted
class_name FusionCatalog

const DATABASE_PATH := "res://database/fusions.json"

var _by_id: Dictionary = {}
var _ordered_ids: Array[String] = []
var _by_result_seed: Dictionary = {}
var _loaded := false


func load_default(database: DigimonDatabase = null) -> bool:
	_by_id.clear()
	_ordered_ids.clear()
	_by_result_seed.clear()
	_loaded = false
	if not FileAccess.file_exists(DATABASE_PATH):
		push_error("Missing Fusion database: %s" % DATABASE_PATH)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATABASE_PATH))
	if not parsed is Array:
		push_error("Fusion database root must be an array")
		return false
	for raw in parsed:
		if not raw is Dictionary:
			push_error("Fusion database contains a non-object definition")
			return false
		var definition := _normalize(raw as Dictionary)
		var error := _validation_error(definition, database)
		if not error.is_empty():
			push_error(error)
			return false
		var fusion_id := String(definition["id"])
		var result_seed := String(definition["resultSeed"])
		if _by_id.has(fusion_id):
			push_error("Duplicate Fusion id: %s" % fusion_id)
			return false
		if _by_result_seed.has(result_seed):
			push_error("Duplicate Fusion result species: %s" % result_seed)
			return false
		_by_id[fusion_id] = definition
		_by_result_seed[result_seed] = fusion_id
		_ordered_ids.append(fusion_id)
	_loaded = true
	return true


func is_loaded() -> bool:
	return _loaded


func get_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fusion_id: String in _ordered_ids:
		result.append((_by_id[fusion_id] as Dictionary).duplicate(true))
	return result


func get_by_id(fusion_id: String) -> Dictionary:
	var key := fusion_id.to_lower().strip_edges()
	return (_by_id[key] as Dictionary).duplicate(true) if _by_id.has(key) else {}


func get_by_result_seed(seed: String) -> Dictionary:
	var fusion_id := String(_by_result_seed.get(seed.strip_edges(), ""))
	return get_by_id(fusion_id) if not fusion_id.is_empty() else {}


func has_id(fusion_id: String) -> bool:
	return _by_id.has(fusion_id.to_lower().strip_edges())


func _normalize(raw: Dictionary) -> Dictionary:
	var definition := raw.duplicate(true)
	definition["id"] = String(definition.get("id", "")).to_lower().strip_edges()
	definition["resultSeed"] = String(definition.get("resultSeed", "")).strip_edges()
	var materials: Array[Dictionary] = []
	var raw_materials = definition.get("materials", [])
	if raw_materials is Array:
		for raw_material in raw_materials:
			if not raw_material is Dictionary:
				continue
			var material := (raw_material as Dictionary).duplicate(true)
			material["type"] = String(material.get("type", "digimon")).to_lower().strip_edges()
			material["amount"] = maxi(1, int(material.get("amount", 1)))
			if String(material["type"]) == "digimon":
				material["speciesSeed"] = String(material.get("speciesSeed", "")).strip_edges()
				material["minLevel"] = clampi(int(material.get("minLevel", 1)), 1, 99)
			else:
				material["itemId"] = String(material.get("itemId", "")).strip_edges()
				material["consume"] = bool(material.get("consume", true))
			materials.append(material)
	definition["materials"] = materials
	return definition


func _validation_error(definition: Dictionary, database: DigimonDatabase) -> String:
	var fusion_id := String(definition.get("id", ""))
	var result_seed := String(definition.get("resultSeed", ""))
	if fusion_id.is_empty():
		return "Fusion id cannot be empty"
	if result_seed.is_empty():
		return "%s: resultSeed is required" % fusion_id
	var digimon_count := 0
	for material: Dictionary in definition.get("materials", []):
		var kind := String(material.get("type", ""))
		if kind == "digimon":
			var seed := String(material.get("speciesSeed", ""))
			if seed.is_empty():
				return "%s: Digimon material is missing speciesSeed" % fusion_id
			if seed == result_seed:
				return "%s: Fusion result cannot directly consume itself" % fusion_id
			digimon_count += maxi(1, int(material.get("amount", 1)))
			if database != null and database.get_by_seed(seed).is_empty():
				return "%s: unknown material species %s" % [fusion_id, seed]
		elif kind == "item":
			if String(material.get("itemId", "")).is_empty():
				return "%s: item material is missing itemId" % fusion_id
		else:
			return "%s: unsupported material type %s" % [fusion_id, kind]
	if digimon_count < 2:
		return "%s: Fusion requires at least two Digimon materials" % fusion_id
	if database != null:
		var result_species := database.get_by_seed(result_seed)
		if result_species.is_empty():
			return "%s: unknown result species %s" % [fusion_id, result_seed]
		if String(result_species.get("rank", "")) != "Fusion":
			return "%s: result species must use rank Fusion" % fusion_id
		if bool(result_species.get("reconstructable", true)):
			return "%s: Fusion result must not be reconstructable" % fusion_id
	return ""
