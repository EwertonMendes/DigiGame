extends RefCounted
class_name DigimonFactory

const InstanceScript = preload("res://src/digimon/DigimonInstance.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const STAT_KEYS: Array[String] = ["hp", "mp", "atk", "def", "speed"]

var _database
var _calculator = StatCalculatorScript.new()
var _rng := RandomNumberGenerator.new()


func _init(database) -> void:
	_database = database
	_rng.randomize()


func create_player_by_name(name: String, level: int = 1, scan_percent: int = 100) -> DigimonInstance:
	var species: Dictionary = _database.get_by_name(name) if _database != null else {}
	if species.is_empty():
		return null
	var initial_potential := potential_from_scan_percent(scan_percent)
	return _create_instance(species, level, initial_potential, "digilab")


func create_player_by_seed(seed: String, level: int = 1, scan_percent: int = 100) -> DigimonInstance:
	var species: Dictionary = _database.get_by_seed(seed) if _database != null else {}
	if species.is_empty():
		return null
	return _create_instance(species, level, potential_from_scan_percent(scan_percent), "digilab")


func create_enemy_by_name(name: String, level: int, profile: String = "wild") -> DigimonInstance:
	var species: Dictionary = _database.get_by_name(name) if _database != null else {}
	if species.is_empty():
		return null
	var instance := _create_instance(species, level, _profile_potential(profile), "encounter:%s" % profile)
	_apply_enemy_profile(instance, profile)
	_calculator.refill_instance(instance, species)
	return instance


func create_enemy_by_seed(seed: String, level: int, profile: String = "wild") -> DigimonInstance:
	var species: Dictionary = _database.get_by_seed(seed) if _database != null else {}
	if species.is_empty():
		return null
	var instance := _create_instance(species, level, _profile_potential(profile), "encounter:%s" % profile)
	_apply_enemy_profile(instance, profile)
	_calculator.refill_instance(instance, species)
	return instance


func potential_from_scan_percent(scan_percent: int) -> int:
	var scan := clampi(scan_percent, 100, 200)
	if scan >= 200:
		return 5
	if scan >= 175:
		return 3
	if scan >= 150:
		return 2
	if scan >= 125:
		return 1
	return 0


func _create_instance(species: Dictionary, level: int, initial_potential: int, source: String) -> DigimonInstance:
	var instance: DigimonInstance = InstanceScript.new()
	instance.species_seed = String(species.get("seed", ""))
	instance.level = clampi(level, 1, 99)
	instance.exp = 0
	instance.potential = clampi(initial_potential, 0, DigimonInstance.MAX_POTENTIAL)
	instance.origin = source
	_randomize_aptitudes(instance)
	_calculator.refill_instance(instance, species)
	return instance


func _randomize_aptitudes(instance: DigimonInstance) -> void:
	for stat_key: String in STAT_KEYS:
		instance.aptitudes[stat_key] = _rng.randi_range(-3, 3)


func _profile_potential(profile: String) -> int:
	match profile.to_lower():
		"trained": return 30
		"elite": return 55
		"boss": return 75
	return 0


func _apply_enemy_profile(instance: DigimonInstance, profile: String) -> void:
	if instance == null:
		return
	match profile.to_lower():
		"trained":
			instance.training["atk"] = 5
			instance.training["def"] = 5
		"elite":
			instance.training["atk"] = 8
			instance.training["speed"] = 8
			instance.training["mov"] = 1
		"boss":
			instance.training["atk"] = 10
			instance.training["def"] = 10
			instance.training["mov"] = 1
