extends RefCounted
class_name DigimonDatabase

const DATABASE_PATH := "res://database/base-digimon-list.json"
const DEFAULT_MOV := 4
const MOV_BY_RANK := {
	"Fresh": 2,
	"In-Training": 3,
	"Rookie": 4,
	"Champion": 4,
	"Ultimate": 4,
	"Mega": 5,
	"Ultra": 5,
	"Armor": 4,
	"Hybrid": 5,
}
const MOV_OVERRIDES_BY_NAME := {
	"agumon": 4,
	"gabumon": 4,
	"greymon": 4,
	"koromon": 3,
	"tanemon": 3,
	"veemon": 5,
}
const MOVEMENT_TYPE_OVERRIDES_BY_NAME := {
	"birdramon": "flying",
	"garudamon": "flying",
	"aeroveedramon": "flying",
	"megadramon": "flying",
	"airdramon": "flying",
	"seadramon": "aquatic",
	"whamon": "aquatic",
	"gomamon": "amphibious",
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
			continue
		var species := _normalize_species(raw_entry)
		var seed := String(species.get("seed", ""))
		var name_key := String(species.get("name", "")).to_lower()
		if seed.is_empty() or name_key.is_empty():
			continue
		if _species_by_seed.has(seed):
			push_error("Duplicate Digimon species seed: %s" % seed)
			continue
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


func get_base_stat(species: Dictionary, stat_key: String) -> int:
	match stat_key:
		"hp": return maxi(1, int(species.get("hp", 1)))
		"mp": return maxi(0, int(species.get("mp", 0)))
		"atk": return maxi(1, int(species.get("atk", species.get("attack", 1))))
		"def": return maxi(1, int(species.get("def", species.get("defense", 1))))
		"speed": return maxi(1, int(species.get("speed", 1)))
	return 0


func get_base_mov(species: Dictionary) -> int:
	return clampi(int(species.get("MOV", DEFAULT_MOV)), 1, 8)


func get_movement_type(species: Dictionary) -> String:
	return String(species.get("movementType", "ground"))


func _normalize_species(raw_entry: Dictionary) -> Dictionary:
	var species := raw_entry.duplicate(true)
	if not species.has("MOV"):
		species["MOV"] = _derive_mov(species)
	if not species.has("movementType"):
		species["movementType"] = _derive_movement_type(species)
	return species


func _derive_mov(species: Dictionary) -> int:
	var name_key := String(species.get("name", "")).to_lower()
	if MOV_OVERRIDES_BY_NAME.has(name_key):
		return int(MOV_OVERRIDES_BY_NAME[name_key])

	var rank := String(species.get("rank", ""))
	var mov := int(MOV_BY_RANK.get(rank, DEFAULT_MOV))
	var speed := int(species.get("speed", 50))
	if speed >= 90:
		mov += 1
	elif speed <= 20:
		mov -= 1
	return clampi(mov, 2, 6)


func _derive_movement_type(species: Dictionary) -> String:
	var name_key := String(species.get("name", "")).to_lower()
	return String(MOVEMENT_TYPE_OVERRIDES_BY_NAME.get(name_key, "ground"))
