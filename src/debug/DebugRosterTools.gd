extends RefCounted
class_name DebugRosterTools

const DATABASE_PATH := "res://database/base-digimon-list.json"
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const ProgressionScript = preload("res://src/digimon/DigimonProgression.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

const BATTLE_PROFILES: Array[String] = ["wild", "trained", "elite", "boss"]
const MAX_SANDBOX_ENEMIES := 12

var database: DigimonDatabase
var factory: DigimonFactory
var calculator: DigimonStatCalculator = StatCalculatorScript.new()
var curve: DigimonProgression = ProgressionScript.new()
var balance: ProgressionBalance = BalanceScript.new()
var _catalog_cache: Array[Dictionary] = []

func _init() -> void:
	database = OverworldState.get_database() as DigimonDatabase
	factory = FactoryScript.new(database) as DigimonFactory

func catalog() -> Array[Dictionary]:
	if not _catalog_cache.is_empty():
		return _catalog_cache.duplicate(true)
	if not FileAccess.file_exists(DATABASE_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATABASE_PATH))
	if not parsed is Array:
		return []
	for raw in parsed:
		if not raw is Dictionary:
			continue
		var seed := String((raw as Dictionary).get("seed", "")).strip_edges()
		var name := String((raw as Dictionary).get("name", "")).strip_edges()
		if seed.is_empty() or name.is_empty():
			continue
		_catalog_cache.append({"seed": seed, "name": name, "rank": String((raw as Dictionary).get("rank", "Unknown"))})
	_catalog_cache.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0
	)
	return _catalog_cache.duplicate(true)

func species(seed: String) -> Dictionary:
	return database.get_by_seed(seed) if database != null else {}

func make_enemy_descriptor(seed: String, level: int, profile: String = "wild", tier: String = "E", footprint: String = BattleFootprint.SINGLE) -> Dictionary:
	var species_data := species(seed)
	if species_data.is_empty():
		return {}
	var normalized_profile := profile.to_lower().strip_edges()
	if not BATTLE_PROFILES.has(normalized_profile):
		normalized_profile = "wild"
	return {
		"species_seed": String(species_data.get("seed", seed)),
		"level": clampi(level, 1, curve.max_level()),
		"profile": normalized_profile,
		"tier": balance.normalize_tier(tier),
		"footprint": FootprintScript.normalize_id(footprint),
	}

func create_storage_instance(config: Dictionary) -> DigimonInstance:
	var seed := String(config.get("species_seed", "")).strip_edges()
	var species_data := species(seed)
	if species_data.is_empty() or factory == null:
		return null
	var instance := factory.create_player_by_seed(seed, clampi(int(config.get("level", 1)), 1, curve.max_level()), 100)
	if instance == null:
		return null
	instance.exp = maxi(0, int(config.get("exp", 0)))
	instance.potential = clampi(int(config.get("potential", 0)), 0, DigimonInstance.MAX_POTENTIAL)
	instance.link = clampi(int(config.get("link", 0)), 0, DigimonInstance.MAX_LINK)
	instance.tier = balance.normalize_tier(String(config.get("tier", "E")))
	instance.expansion_unlocked = bool(config.get("expansion_unlocked", false))
	var requested_footprint := FootprintScript.normalize_id(String(config.get("footprint", FootprintScript.SINGLE)))
	if requested_footprint == FootprintScript.LARGE_2X2:
		instance.expansion_unlocked = true
		instance.set_battle_footprint(FootprintScript.LARGE_2X2)
	else:
		instance.set_battle_footprint(FootprintScript.SINGLE)
	var training = config.get("training", {})
	if training is Dictionary:
		for stat_key: String in DigimonInstance.STAT_KEYS:
			instance.training[stat_key] = clampi(int((training as Dictionary).get(stat_key, instance.training.get(stat_key, 0))), 0, 5000)
		instance.training["mov"] = clampi(int((training as Dictionary).get("mov", instance.training.get("mov", 0))), 0, 2)
	var aptitudes = config.get("aptitudes", {})
	if aptitudes is Dictionary:
		for stat_key: String in DigimonInstance.STAT_KEYS:
			instance.aptitudes[stat_key] = clampi(int((aptitudes as Dictionary).get(stat_key, instance.aptitudes.get(stat_key, 0))), -3, 3)
	calculator.refill_instance(instance, species_data)
	match String(config.get("resource_state", "full")):
		"critical":
			instance.current_hp = 1
			instance.current_mp = 0
		"empty":
			instance.current_hp = 0
			instance.current_mp = 0
		"custom":
			instance.current_hp = int(config.get("current_hp", instance.current_hp))
			instance.current_mp = int(config.get("current_sp", instance.current_mp))
			calculator.clamp_resources(instance, species_data)
		_:
			pass
	var key := OverworldState.add_collection_instance(instance)
	return instance if not key.is_empty() else null
