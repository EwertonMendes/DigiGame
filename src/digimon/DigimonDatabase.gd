extends RefCounted
class_name DigimonDatabase

const DATABASE_PATH := "res://database/base-digimon-list.json"
const REQUIRED_CANONICAL_FIELDS: Array[String] = [
	"seed",
	"name",
	"hp",
	"mp",
	"atk",
	"def",
	"int",
	"speed",
	"bitFarmingRate",
	"MOV",
	"movementType",
]
const ELEMENT_OVERRIDES_BY_NAME := {
	"agumon": "fire",
	"gabumon": "fire",
	"greymon": "fire",
	"koromon": "fire",
	"tanemon": "plant",
	"veemon": "neutral",
}

var _species_by_seed: Dictionary = {}
var _species_by_name: Dictionary = {}
var _loaded := false


func load_default() -> bool:
	_species_by_seed.clear()
	_species_by_name.clear()
	_loaded = false
	if not FileAccess.file_exists(DATABASE_PATH):
		push_error("Missing Digimon database: %s" % DATABASE_PATH)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATABASE_PATH))
	if not parsed is Array:
		push_error("Digimon database root must be an array")
		return false

	for raw_entry in parsed:
		if not raw_entry is Dictionary:
			push_error("Digimon database contains a non-object species entry")
			return false
		var canonical_error := _canonical_species_error(raw_entry)
		if not canonical_error.is_empty():
			push_error(canonical_error)
			return false
		var species := _normalize_species(raw_entry)
		var seed := String(species["seed"])
		var name_key := String(species["name"]).to_lower()
		if _species_by_seed.has(seed):
			push_error("Duplicate Digimon species seed: %s" % seed)
			return false
		if _species_by_name.has(name_key):
			push_error("Duplicate Digimon species name: %s" % String(species["name"]))
			return false
		_species_by_seed[seed] = species
		_species_by_name[name_key] = species

	_loaded = not _species_by_seed.is_empty()
	return _loaded


func is_loaded() -> bool:
	return _loaded


func get_by_seed(seed: String) -> Dictionary:
	if not _species_by_seed.has(seed):
		return {}
	return (_species_by_seed[seed] as Dictionary).duplicate(true)


func get_by_name(name: String) -> Dictionary:
	var key := name.to_lower().strip_edges()
	if not _species_by_name.has(key):
		return {}
	return (_species_by_name[key] as Dictionary).duplicate(true)


func has_seed(seed: String) -> bool:
	return _species_by_seed.has(seed)


func species_count() -> int:
	return _species_by_seed.size()


func get_name_for_seed(seed: String) -> String:
	var species := get_by_seed(seed)
	return String(species.get("name", ""))


func get_evolution_routes(seed: String) -> Array[Dictionary]:
	var species := get_by_seed(seed)
	return _route_array(species.get("evolutions", []))


func get_degeneration_routes(seed: String) -> Array[Dictionary]:
	var species := get_by_seed(seed)
	return _route_array(species.get("degenerations", []))


func get_base_stat(species: Dictionary, stat_key: String) -> int:
	var key := "mp" if stat_key.to_lower() == "sp" else stat_key.to_lower()
	match key:
		"hp": return maxi(1, int(species["hp"]))
		"mp": return maxi(0, int(species["mp"]))
		"atk": return maxi(1, int(species["atk"]))
		"def": return maxi(1, int(species["def"]))
		"int": return maxi(1, int(species["int"]))
		"speed": return maxi(1, int(species["speed"]))
	return 0


func get_base_mov(species: Dictionary) -> int:
	return clampi(int(species["MOV"]), 1, 8)


func get_movement_type(species: Dictionary) -> String:
	return String(species["movementType"])


func _canonical_species_error(species: Dictionary) -> String:
	var display_name := String(species.get("name", "<unnamed>"))
	for key: String in REQUIRED_CANONICAL_FIELDS:
		if not species.has(key):
			return "%s: canonical species field '%s' is missing" % [display_name, key]
	if String(species["seed"]).strip_edges().is_empty():
		return "%s: seed cannot be empty" % display_name
	if String(species["name"]).strip_edges().is_empty():
		return "Digimon species name cannot be empty"
	for stat_key: String in ["hp", "atk", "def", "int", "speed"]:
		if int(species[stat_key]) < 1:
			return "%s: %s must be positive" % [display_name, stat_key]
	if int(species["mp"]) < 0:
		return "%s: mp cannot be negative" % display_name
	if int(species["MOV"]) < 1 or int(species["MOV"]) > 8:
		return "%s: MOV must be between 1 and 8" % display_name
	if String(species["movementType"]).strip_edges().is_empty():
		return "%s: movementType cannot be empty" % display_name
	return ""


func _normalize_species(raw_entry: Dictionary) -> Dictionary:
	var species := raw_entry.duplicate(true)
	var name_key := String(species["name"]).to_lower()
	if not species.has("family"):
		species["family"] = String(species.get("species", "Unknown"))
	if not species.has("type"):
		species["type"] = String(species.get("attribute", "Free"))
	if not species.has("element"):
		species["element"] = String(ELEMENT_OVERRIDES_BY_NAME.get(name_key, "neutral"))

	# Route objects are runtime normalization only. Canonical base stats and
	# movement metadata are never synthesized here; they must exist in the JSON.
	if not species.has("evolutions"):
		species["evolutions"] = _legacy_routes(
			species.get("digiEvolutionSeedList", []),
			species.get("evolutionRequirements", [])
		)
	else:
		species["evolutions"] = _normalize_routes(species.get("evolutions", []))
	if not species.has("degenerations"):
		species["degenerations"] = _legacy_routes(species.get("degenerateSeedList", []), [])
	else:
		species["degenerations"] = _normalize_routes(species.get("degenerations", []))
	return species


func _legacy_routes(raw_seeds, raw_requirements) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_seeds is Array:
		return result
	var requirements: Array = raw_requirements if raw_requirements is Array else []
	for raw_seed in raw_seeds:
		var seed := String(raw_seed).strip_edges()
		if seed.is_empty():
			continue
		result.append({
			"targetSeed": seed,
			"requirements": requirements.duplicate(true),
		})
	return result


func _normalize_routes(raw_routes) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_routes is Array:
		return result
	for raw_route in raw_routes:
		if not raw_route is Dictionary:
			continue
		var route := (raw_route as Dictionary).duplicate(true)
		var target_seed := String(route.get("targetSeed", route.get("seed", ""))).strip_edges()
		if target_seed.is_empty():
			continue
		route["targetSeed"] = target_seed
		if not route.get("requirements", []) is Array:
			route["requirements"] = []
		result.append(route)
	return result


func _route_array(raw) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for route in raw:
			if route is Dictionary:
				result.append((route as Dictionary).duplicate(true))
	return result
