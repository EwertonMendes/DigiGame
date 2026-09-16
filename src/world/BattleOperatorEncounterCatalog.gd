extends RefCounted
class_name BattleOperatorEncounterCatalog

const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")
const READY_RANKS: Array[String] = ["Fresh", "In-Training", "Rookie", "Champion", "Ultimate", "Mega"]
const ENEMY_COUNT := 3
const MAX_LEVEL := 99

var _action_database = ActionDatabaseScript.new()
var _ready_by_rank: Dictionary = {}
var _prepared := false


func prepare(database) -> void:
	if _prepared:
		return
	_prepared = true
	for rank: String in READY_RANKS:
		_ready_by_rank[rank] = []
	if database == null or not database.is_loaded():
		return
	if not _action_database.load_default():
		return
	if not FileAccess.file_exists(DigimonDatabase.DATABASE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DigimonDatabase.DATABASE_PATH))
	if not parsed is Array:
		return
	for raw_entry in parsed:
		if not raw_entry is Dictionary:
			continue
		var raw := raw_entry as Dictionary
		var seed := String(raw.get("seed", "")).strip_edges()
		if seed.is_empty():
			continue
		var species: Dictionary = database.get_by_seed(seed)
		if species.is_empty():
			continue
		var rank := String(species.get("rank", "")).strip_edges()
		if not READY_RANKS.has(rank):
			continue
		var candidate := _validated_candidate(species)
		if candidate.is_empty():
			continue
		var bucket: Array = _ready_by_rank[rank]
		bucket.append(candidate)
		_ready_by_rank[rank] = bucket

	for rank: String in READY_RANKS:
		var bucket: Array = _ready_by_rank.get(rank, [])
		bucket.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("name", "")) < String(b.get("name", ""))
		)


func ready_count(rank: String, database = null) -> int:
	if not _prepared and database != null:
		prepare(database)
	return Array(_ready_by_rank.get(_normalize_rank(rank), [])).size()


func ready_species(rank: String, database = null) -> Array[Dictionary]:
	if not _prepared and database != null:
		prepare(database)
	var result: Array[Dictionary] = []
	for raw_candidate in Array(_ready_by_rank.get(_normalize_rank(rank), [])):
		if raw_candidate is Dictionary:
			result.append((raw_candidate as Dictionary).duplicate(true))
	return result


func build_rank_encounter(rank: String, database, party_level: int, rng: RandomNumberGenerator) -> Dictionary:
	prepare(database)
	var normalized_rank := _normalize_rank(rank)
	if not READY_RANKS.has(normalized_rank):
		return {"ok": false, "error": "Unsupported battle rank: %s" % rank}
	var candidates: Array = Array(_ready_by_rank.get(normalized_rank, [])).duplicate(true)
	if candidates.size() < ENEMY_COUNT:
		return {
			"ok": false,
			"error": "Not enough verified %s Digimon are battle-ready yet (%d/%d)." % [normalized_rank, candidates.size(), ENEMY_COUNT],
		}
	var local_rng := rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()
	_shuffle(candidates, local_rng)

	var preferred_level := clampi(party_level, 1, MAX_LEVEL)
	var enemies: Array[Dictionary] = []
	var names: Array[String] = []
	for index in range(ENEMY_COUNT):
		var candidate := candidates[index] as Dictionary
		var battle_level := clampi(maxi(preferred_level, int(candidate.get("minimum_battle_level", 1))), 1, MAX_LEVEL)
		enemies.append({
			"species_seed": String(candidate.get("seed", "")),
			"level": battle_level,
			"profile": "wild",
			"tier": "E",
			"footprint": "single",
		})
		names.append(String(candidate.get("name", "")))

	var encounter_id := "battle_operator_random_%s" % normalized_rank.to_lower().replace("-", "_").replace(" ", "_")
	return {
		"ok": true,
		"rank": normalized_rank,
		"names": names,
		"config": {
			"encounter_id": encounter_id,
			"enemy_party": enemies,
			"reward_modifier": 1.0,
			"repeatable": true,
		},
	}


func _validated_candidate(species: Dictionary) -> Dictionary:
	var seed := String(species.get("seed", "")).strip_edges()
	var name := String(species.get("name", "")).strip_edges()
	if seed.is_empty() or name.is_empty():
		return {}
	# Use the exact visual-resource convention used by DigimonRuntimeController.
	# A species only enters the operator pool when the same runtime resource that
	# battle would load exists and satisfies the canonical complete DS contract.
	var resource_path := "res://assets/resources/%s.tres" % name.to_lower()
	if not ResourceLoader.exists(resource_path):
		return {}
	var resource := load(resource_path) as Digimon
	if resource == null or resource.texture == null:
		return {}
	if resource.sprite_layout != "directional_12" or resource.sprite_hframes != 12 or resource.sprite_vframes != 1:
		return {}

	# A complete sprite is not enough: the enemy also needs at least one valid,
	# ready battle action. This keeps placeholder/incomplete catalogue entries out
	# of random encounters and prevents the operator from surfacing broken units.
	var minimum_level := _minimum_ready_action_level(seed)
	if minimum_level < 1:
		return {}
	return {
		"seed": seed,
		"name": name,
		"rank": String(species.get("rank", "")),
		"resource": resource_path,
		"minimum_battle_level": minimum_level,
	}


func _minimum_ready_action_level(species_seed: String) -> int:
	var minimum_level := MAX_LEVEL + 1
	for entry: Dictionary in _action_database.get_learnset_entries(species_seed):
		var skill_id := _action_database.resolve_skill_id(species_seed, String(entry.get("skill", "")))
		if skill_id.is_empty():
			continue
		var action := _action_database.get_action(skill_id)
		if action.is_empty() or String(action.get("availability", "ready")) != "ready":
			continue
		minimum_level = mini(minimum_level, clampi(int(entry.get("level", 1)), 1, MAX_LEVEL))
	return -1 if minimum_level > MAX_LEVEL else minimum_level


func _normalize_rank(rank: String) -> String:
	var clean := rank.strip_edges()
	if clean.to_lower() == "baby":
		return "In-Training"
	for canonical: String in READY_RANKS:
		if clean.to_lower() == canonical.to_lower():
			return canonical
	return clean


func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temp
