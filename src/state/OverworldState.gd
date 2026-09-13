extends Node

signal active_party_changed(active_party: Array)
signal roster_changed
signal account_rewards_changed(bits: int, digi_data: Dictionary)
signal progress_saved

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const RosterScript = preload("res://src/collection/PlayerRoster.gd")
const PartyServiceScript = preload("res://src/collection/PartyService.gd")
const SaveServiceScript = preload("res://src/save/SaveService.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")

const DEFAULT_ACTIVE_PARTY := ["agumon", "gabumon", "greymon"]

var _database = DatabaseScript.new()
var _factory = null
var _roster: PlayerRoster = RosterScript.new()
var _party_service: PartyService = PartyServiceScript.new()
var _save_service: SaveService = SaveServiceScript.new()
var _balance = BalanceScript.new()
var _persistence_enabled := true


func _ready() -> void:
	_ensure_database()
	if not load_progress():
		_ensure_starter_roster()
		save_progress()
	else:
		_repair_loaded_roster()


func get_active_party() -> Array[String]:
	_ensure_starter_roster()
	var result: Array[String] = []
	for instance_id: String in _roster.get_active_party_ids():
		result.append(_roster.get_key_for_instance(instance_id))
	return result


func get_active_party_ids() -> Array[String]:
	_ensure_starter_roster()
	return _roster.get_active_party_ids()


func get_active_instances() -> Array[DigimonInstance]:
	_ensure_starter_roster()
	return _roster.get_active_instances()


func get_reserve_instances() -> Array[DigimonInstance]:
	_ensure_starter_roster()
	return _roster.get_reserve_instances()


func get_roster_instances() -> Array[DigimonInstance]:
	_ensure_starter_roster()
	return _roster.get_instances()


func get_instance_by_id(instance_id: String) -> DigimonInstance:
	_ensure_starter_roster()
	return _roster.get_instance(instance_id)


func get_instance_for_party_key(key: String) -> DigimonInstance:
	_ensure_starter_roster()
	return _roster.get_instance_by_key(key)


func get_roster_key(instance_id: String) -> String:
	_ensure_starter_roster()
	return _roster.get_key_for_instance(instance_id)


func set_active_party(party: Array) -> bool:
	_ensure_starter_roster()
	var ids: Array[String] = []
	for raw_value in party:
		var token := String(raw_value).strip_edges()
		if token.is_empty():
			return false
		var instance := _roster.get_instance(token)
		if instance == null:
			instance = _roster.get_instance_by_key(token)
		if instance == null or ids.has(instance.id):
			return false
		ids.append(instance.id)
	if not _party_service.set_party(_roster, ids):
		return false
	active_party_changed.emit(get_active_party())
	_save_after_mutation()
	return true


func add_to_active_party(instance_id: String) -> bool:
	_ensure_starter_roster()
	if not _party_service.add_to_party(_roster, instance_id):
		return false
	active_party_changed.emit(get_active_party())
	_save_after_mutation()
	return true


func remove_from_active_party(instance_id: String) -> bool:
	_ensure_starter_roster()
	if not _party_service.remove_from_party(_roster, instance_id):
		return false
	active_party_changed.emit(get_active_party())
	_save_after_mutation()
	return true


func swap_party_with_reserve(active_instance_id: String, reserve_instance_id: String) -> bool:
	_ensure_starter_roster()
	if not _party_service.swap_with_reserve(_roster, active_instance_id, reserve_instance_id):
		return false
	active_party_changed.emit(get_active_party())
	_save_after_mutation()
	return true


func move_active_party_member(instance_id: String, new_index: int) -> bool:
	_ensure_starter_roster()
	if not _party_service.move(_roster, instance_id, new_index):
		return false
	active_party_changed.emit(get_active_party())
	_save_after_mutation()
	return true


func party_validation_error(instance_ids: Array[String]) -> String:
	_ensure_starter_roster()
	return _party_service.validation_error(_roster, instance_ids)


func reset_active_party() -> void:
	_ensure_starter_roster()
	var ids: Array[String] = []
	for key in DEFAULT_ACTIVE_PARTY:
		var instance := _roster.get_instance_by_key(String(key))
		if instance != null:
			ids.append(instance.id)
	if ids.is_empty():
		return
	if ids == _roster.get_active_party_ids():
		return
	if _party_service.set_party(_roster, ids):
		active_party_changed.emit(get_active_party())
		_save_after_mutation()


func replace_or_add_instance(instance: DigimonInstance, party_key: String = "") -> bool:
	if instance == null:
		return false
	_ensure_database()
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return false
	var key := party_key.to_lower().strip_edges()
	var success := false
	if key.is_empty():
		success = not _roster.add_instance(instance, "", String(species.get("name", "digimon"))).is_empty()
	else:
		success = _roster.replace_at_key(instance, key, String(species.get("name", "digimon")))
	if success:
		roster_changed.emit()
		active_party_changed.emit(get_active_party())
		_save_after_mutation()
	return success


func add_roster_instance(instance: DigimonInstance, preferred_key: String = "") -> String:
	if instance == null:
		return ""
	_ensure_database()
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return ""
	var key := _roster.add_instance(instance, preferred_key, String(species.get("name", "digimon")))
	if not key.is_empty():
		roster_changed.emit()
		_save_after_mutation()
	return key


func notify_roster_changed() -> void:
	roster_changed.emit()
	_save_after_mutation()


func get_max_active_party_size() -> int:
	return _party_service.maximum_size()


func get_database():
	_ensure_database()
	return _database


func get_bits() -> int:
	return _roster.bits


func get_digi_data() -> Dictionary:
	_ensure_database()
	var result: Dictionary = {}
	for raw_seed in _roster.get_all_digi_data().keys():
		var seed := String(raw_seed)
		var species := _database.get_by_seed(seed)
		if species.is_empty():
			continue
		result[String(species.get("name", seed))] = _roster.get_digi_data(seed)
	return result


func get_digi_data_for(species_name_or_seed: String) -> int:
	var seed := _resolve_species_seed(species_name_or_seed)
	return _roster.get_digi_data(seed) if not seed.is_empty() else 0


func get_reconstruction_requirement(species_name_or_seed: String) -> int:
	var seed := _resolve_species_seed(species_name_or_seed)
	if seed.is_empty():
		return _balance.reconstruction_int("defaultRequired", 100)
	var species := _database.get_by_seed(seed)
	return maxi(1, int(species.get("dataRequired", _balance.reconstruction_int("defaultRequired", 100))))


func apply_account_rewards(bits: int, digi_data: Dictionary) -> Dictionary:
	_ensure_database()
	_roster.bits += maxi(0, bits)
	var progress: Dictionary = {}
	for raw_species in digi_data.keys():
		var token := String(raw_species)
		var seed := _resolve_species_seed(token)
		if seed.is_empty():
			continue
		var before := _roster.get_digi_data(seed)
		var after := _roster.add_digi_data(seed, maxi(0, int(digi_data[raw_species])))
		var species := _database.get_by_seed(seed)
		var name := String(species.get("name", token))
		var required := get_reconstruction_requirement(seed)
		progress[seed] = {
			"species_seed": seed,
			"species_name": name,
			"gained": after - before,
			"before": before,
			"after": after,
			"required": required,
			"before_percent": minf(100.0, float(before) * 100.0 / float(required)),
			"after_percent": minf(100.0, float(after) * 100.0 / float(required)),
			"ready": after >= required,
			"newly_ready": before < required and after >= required,
		}
	account_rewards_changed.emit(_roster.bits, get_digi_data())
	_save_after_mutation()
	return progress


func can_reconstruct_digimon(species_name: String, data_amount: int = -1) -> bool:
	var seed := _resolve_species_seed(species_name)
	if seed.is_empty():
		return false
	var required := get_reconstruction_requirement(seed)
	var amount := required if data_amount < 0 else data_amount
	var minimum_spend := maxi(required, _balance.reconstruction_int("minSpend", required))
	var maximum_spend := maxi(minimum_spend, _balance.reconstruction_int("maxSpend", 200))
	amount = clampi(amount, minimum_spend, maximum_spend)
	return _roster.get_digi_data(seed) >= amount


func reconstruct_digimon(species_name: String, data_amount: int = -1) -> DigimonInstance:
	_ensure_database()
	if _factory == null:
		return null
	var species := _database.get_by_name(species_name)
	if species.is_empty():
		species = _database.get_by_seed(species_name)
	if species.is_empty():
		return null
	var seed := String(species.get("seed", ""))
	var required := get_reconstruction_requirement(seed)
	var amount := required if data_amount < 0 else data_amount
	var minimum_spend := maxi(required, _balance.reconstruction_int("minSpend", required))
	var maximum_spend := maxi(minimum_spend, _balance.reconstruction_int("maxSpend", 200))
	amount = clampi(amount, minimum_spend, maximum_spend)
	if _roster.get_digi_data(seed) < amount:
		return null
	var instance: DigimonInstance = _factory.create_player_by_seed(seed, 1, amount)
	if instance == null:
		return null
	if _balance.reconstruction_bool("consumeData", true) and not _roster.consume_digi_data(seed, amount):
		return null
	_roster.add_instance(instance, String(species.get("name", "digimon")).to_lower().replace(" ", "_"), String(species.get("name", "digimon")))
	roster_changed.emit()
	account_rewards_changed.emit(_roster.bits, get_digi_data())
	_save_after_mutation()
	return instance


func save_progress() -> bool:
	if not _persistence_enabled:
		return true
	var success := _save_service.save_roster(_roster)
	if success:
		progress_saved.emit()
	return success


func load_progress() -> bool:
	if not _persistence_enabled:
		return false
	var loaded: PlayerRoster = _save_service.load_roster()
	if loaded == null or loaded.is_empty():
		return false
	_roster = loaded
	return true


func set_persistence_enabled(enabled: bool) -> void:
	_persistence_enabled = enabled


func reset_progress_for_tests(delete_disk_save: bool = false) -> void:
	_roster = RosterScript.new()
	if delete_disk_save:
		_save_service.delete_save()
	_ensure_starter_roster()
	active_party_changed.emit(get_active_party())
	roster_changed.emit()
	account_rewards_changed.emit(_roster.bits, get_digi_data())


func _ensure_starter_roster() -> void:
	if not _roster.is_empty():
		return
	_ensure_database()
	if _factory == null:
		return
	var starter_ids: Array[String] = []
	for key in DEFAULT_ACTIVE_PARTY:
		var species_key := String(key)
		var instance: DigimonInstance = _factory.create_player_by_name(species_key, 1, 100)
		if instance != null:
			_roster.add_instance(instance, species_key, species_key)
			starter_ids.append(instance.id)
	if not starter_ids.is_empty():
		_party_service.set_party(_roster, starter_ids)
	roster_changed.emit()


func _repair_loaded_roster() -> void:
	_ensure_database()
	if _roster.is_empty():
		_ensure_starter_roster()
		save_progress()
		return
	var valid_ids: Array[String] = []
	for instance_id: String in _roster.get_active_party_ids():
		var instance := _roster.get_instance(instance_id)
		if instance != null and not _database.get_by_seed(instance.species_seed).is_empty():
			valid_ids.append(instance_id)
	if valid_ids.size() < _party_service.minimum_size():
		for instance: DigimonInstance in _roster.get_instances():
			if _database.get_by_seed(instance.species_seed).is_empty() or valid_ids.has(instance.id):
				continue
			valid_ids.append(instance.id)
			if valid_ids.size() >= _party_service.minimum_size():
				break
	if valid_ids.size() > _party_service.maximum_size():
		valid_ids.resize(_party_service.maximum_size())
	if valid_ids != _roster.get_active_party_ids() and not valid_ids.is_empty():
		_party_service.set_party(_roster, valid_ids)
		save_progress()


func _ensure_database() -> void:
	if not _database.is_loaded():
		if not _database.load_default():
			push_error("Could not initialize persistent Digimon roster database")
			return
	if _factory == null:
		_factory = FactoryScript.new(_database)


func _resolve_species_seed(species_name_or_seed: String) -> String:
	_ensure_database()
	var token := species_name_or_seed.strip_edges()
	if token.is_empty():
		return ""
	if _database.has_seed(token):
		return token
	var species := _database.get_by_name(token)
	return String(species.get("seed", "")) if not species.is_empty() else ""


func _save_after_mutation() -> void:
	if not save_progress() and _persistence_enabled:
		push_warning("Player progression changed but could not be persisted")
