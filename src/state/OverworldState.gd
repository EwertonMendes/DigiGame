extends Node

signal active_party_changed(active_party: Array)
signal roster_changed
signal account_rewards_changed(bits: int, digi_data: Dictionary)

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const MAX_ACTIVE_PARTY_SIZE := 3
const MIN_ACTIVE_PARTY_SIZE := 1
const DEFAULT_ACTIVE_PARTY := ["agumon", "gabumon", "greymon"]
const MIN_RECONSTRUCTION_DATA := 100
const MAX_RECONSTRUCTION_DATA := 200

var _active_party: Array[String] = ["agumon", "gabumon", "greymon"]
var _roster_by_key: Dictionary = {}
var _database = DatabaseScript.new()
var _factory = null
var _bits := 0
var _digi_data: Dictionary = {}


func _ready() -> void:
	_ensure_roster()


func get_active_party() -> Array[String]:
	return _active_party.duplicate()


func get_active_instances() -> Array[DigimonInstance]:
	_ensure_roster()
	var result: Array[DigimonInstance] = []
	for key: String in _active_party:
		var instance = _roster_by_key.get(key)
		if instance is DigimonInstance:
			result.append(instance)
	return result


func get_roster_instances() -> Array[DigimonInstance]:
	_ensure_roster()
	var result: Array[DigimonInstance] = []
	for key in _roster_by_key.keys():
		var instance = _roster_by_key[key]
		if instance is DigimonInstance:
			result.append(instance)
	return result


func get_instance_by_id(instance_id: String) -> DigimonInstance:
	_ensure_roster()
	for instance: DigimonInstance in get_roster_instances():
		if instance.id == instance_id:
			return instance
	return null


func get_instance_for_party_key(key: String) -> DigimonInstance:
	_ensure_roster()
	var instance = _roster_by_key.get(key.to_lower().strip_edges())
	return instance if instance is DigimonInstance else null


func set_active_party(party: Array) -> bool:
	_ensure_roster()
	_ensure_database()
	var normalized: Array[String] = []
	for raw_key in party:
		var key := String(raw_key).strip_edges().to_lower()
		if key.is_empty():
			continue
		if not _roster_by_key.has(key):
			return false
		var candidate = _roster_by_key.get(key)
		if not candidate is DigimonInstance:
			return false
		if _database.get_by_seed((candidate as DigimonInstance).species_seed).is_empty():
			return false
		if normalized.has(key):
			continue
		normalized.append(key)

	if normalized.size() < MIN_ACTIVE_PARTY_SIZE or normalized.size() > MAX_ACTIVE_PARTY_SIZE:
		return false
	if normalized == _active_party:
		return true
	_active_party = normalized
	active_party_changed.emit(get_active_party())
	return true


func reset_active_party() -> void:
	_ensure_roster()
	var next_party: Array[String] = []
	for key in DEFAULT_ACTIVE_PARTY:
		if _roster_by_key.has(String(key)):
			next_party.append(String(key))
	if next_party == _active_party:
		return
	_active_party = next_party
	active_party_changed.emit(get_active_party())


func replace_or_add_instance(instance: DigimonInstance, party_key: String = "") -> bool:
	if instance == null:
		return false
	_ensure_database()
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return false
	var key := party_key.to_lower().strip_edges()
	if key.is_empty():
		key = String(species.get("name", "")).to_lower()
	_roster_by_key[key] = instance
	roster_changed.emit()
	return true


func add_roster_instance(instance: DigimonInstance, preferred_key: String = "") -> String:
	if instance == null:
		return ""
	_ensure_database()
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return ""
	var base_key := preferred_key.to_lower().strip_edges()
	if base_key.is_empty():
		base_key = String(species.get("name", "digimon")).to_lower().replace(" ", "_")
	var key := _unique_roster_key(base_key)
	_roster_by_key[key] = instance
	roster_changed.emit()
	return key


func notify_roster_changed() -> void:
	roster_changed.emit()


func get_max_active_party_size() -> int:
	return MAX_ACTIVE_PARTY_SIZE


func get_database():
	_ensure_database()
	return _database


func get_bits() -> int:
	return _bits


func get_digi_data() -> Dictionary:
	return _digi_data.duplicate(true)


func get_digi_data_for(species_name: String) -> int:
	var key := _resolve_digi_data_key(species_name)
	return int(_digi_data.get(key, 0)) if not key.is_empty() else 0


func apply_account_rewards(bits: int, digi_data: Dictionary) -> void:
	_bits += maxi(0, bits)
	for raw_name in digi_data.keys():
		var name := String(raw_name)
		_digi_data[name] = int(_digi_data.get(name, 0)) + maxi(0, int(digi_data[raw_name]))
	account_rewards_changed.emit(_bits, get_digi_data())


func can_reconstruct_digimon(species_name: String, data_amount: int = MIN_RECONSTRUCTION_DATA) -> bool:
	var amount := clampi(data_amount, MIN_RECONSTRUCTION_DATA, MAX_RECONSTRUCTION_DATA)
	_ensure_database()
	return not _database.get_by_name(species_name).is_empty() and get_digi_data_for(species_name) >= amount


func reconstruct_digimon(species_name: String, data_amount: int = MIN_RECONSTRUCTION_DATA) -> DigimonInstance:
	var amount := clampi(data_amount, MIN_RECONSTRUCTION_DATA, MAX_RECONSTRUCTION_DATA)
	_ensure_database()
	if _factory == null:
		return null
	var species := _database.get_by_name(species_name)
	if species.is_empty():
		return null
	var data_key := _resolve_digi_data_key(String(species.get("name", species_name)))
	if data_key.is_empty() or int(_digi_data.get(data_key, 0)) < amount:
		return null
	var instance: DigimonInstance = _factory.create_player_by_seed(String(species.get("seed", "")), 1, amount)
	if instance == null:
		return null
	_digi_data[data_key] = int(_digi_data.get(data_key, 0)) - amount
	if int(_digi_data[data_key]) <= 0:
		_digi_data.erase(data_key)
	add_roster_instance(instance, String(species.get("name", "digimon")).to_lower().replace(" ", "_"))
	account_rewards_changed.emit(_bits, get_digi_data())
	return instance


func _ensure_roster() -> void:
	if not _roster_by_key.is_empty():
		return
	_ensure_database()
	if _factory == null:
		return
	for key in DEFAULT_ACTIVE_PARTY:
		var species_key := String(key)
		var instance: DigimonInstance = _factory.create_player_by_name(species_key, 1, 100)
		if instance != null:
			_roster_by_key[species_key] = instance
	roster_changed.emit()


func _ensure_database() -> void:
	if not _database.is_loaded():
		if not _database.load_default():
			push_error("Could not initialize persistent Digimon roster database")
			return
	if _factory == null:
		_factory = FactoryScript.new(_database)


func _unique_roster_key(base_key: String) -> String:
	var clean := base_key.to_lower().strip_edges()
	if clean.is_empty():
		clean = "digimon"
	if not _roster_by_key.has(clean):
		return clean
	var suffix := 2
	while _roster_by_key.has("%s_%d" % [clean, suffix]):
		suffix += 1
	return "%s_%d" % [clean, suffix]


func _resolve_digi_data_key(species_name: String) -> String:
	var normalized := species_name.to_lower().strip_edges()
	for raw_key in _digi_data.keys():
		var key := String(raw_key)
		if key.to_lower().strip_edges() == normalized:
			return key
	return ""
