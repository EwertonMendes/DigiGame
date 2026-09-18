extends Node

signal active_party_changed(active_party: Array)
signal squad_changed(active_ids: Array, reserve_ids: Array)
signal collection_changed
signal account_rewards_changed(bits: int, digi_data: Dictionary)
signal technique_progress_changed
signal inventory_changed(inventory: Dictionary)
signal hospital_state_changed(instance_id: String, status: String)
signal progress_saved

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const PartyServiceScript = preload("res://src/collection/PartyService.gd")
const TrainingServiceScript = preload("res://src/digimon/DigimonTrainingService.gd")
const SaveServiceScript = preload("res://src/save/SaveService.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const TechniqueRecordServiceScript = preload("res://src/collection/TechniqueRecordService.gd")
const AscensionServiceScript = preload("res://src/digimon/DigimonAscensionService.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const HospitalCalculatorScript = preload("res://src/hospital/HospitalRecoveryCalculator.gd")
const HospitalServiceScript = preload("res://src/hospital/HospitalService.gd")

const DEFAULT_ACTIVE_PARTY := ["agumon", "gabumon", "greymon"]

var _database = DatabaseScript.new()
var _factory = null
var _collection: PlayerCollection = CollectionScript.new()
var _party_service: PartyService = PartyServiceScript.new()
var _training_service: DigimonTrainingService = TrainingServiceScript.new()
var _save_service: SaveService = SaveServiceScript.new()
var _balance = BalanceScript.new()
var _technique_records = TechniqueRecordServiceScript.new()
var _ascension = AscensionServiceScript.new()
var _stat_calculator: DigimonStatCalculator = StatCalculatorScript.new()
var _hospital_calculator: HospitalRecoveryCalculator = HospitalCalculatorScript.new()
var _hospital_service: HospitalService = HospitalServiceScript.new(_hospital_calculator)
var _persistence_enabled := true

func _ready() -> void:
	_ensure_database()
	if not load_progress():
		_ensure_starter_collection()
		save_progress()
	else:
		_repair_loaded_collection()
		process_hospital_recoveries()

func get_active_party() -> Array[String]:
	_ensure_starter_collection()
	var result: Array[String] = []
	for instance_id: String in _collection.get_active_party_ids():
		result.append(_collection.get_key_for_instance(instance_id))
	return result

func get_active_party_ids() -> Array[String]:
	_ensure_starter_collection()
	return _collection.get_active_party_ids()

func get_active_instances() -> Array[DigimonInstance]:
	_ensure_starter_collection()
	return _collection.get_active_instances()


func get_reserve_party_ids() -> Array[String]:
	_ensure_starter_collection()
	return _collection.get_reserve_party_ids()


func get_reserve_party_instances() -> Array[DigimonInstance]:
	_ensure_starter_collection()
	return _collection.get_reserve_party_instances()


func get_squad_ids() -> Array[String]:
	_ensure_starter_collection()
	return _collection.get_squad_ids()


func get_squad_instances() -> Array[DigimonInstance]:
	_ensure_starter_collection()
	return _collection.get_squad_instances()


func get_battle_ready_active_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance: DigimonInstance in get_active_instances():
		if not instance.is_fainted():
			result.append(instance)
	return result


func get_battle_ready_reserve_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance: DigimonInstance in get_reserve_party_instances():
		if not instance.is_fainted():
			result.append(instance)
	return result

func get_hospital_instances() -> Array[DigimonInstance]:
	_ensure_starter_collection()
	return _collection.get_hospital_instances()

func get_hospital_ids() -> Array[String]:
	_ensure_starter_collection()
	return _collection.get_hospital_ids()

func get_storage_instances() -> Array[DigimonInstance]:
	_ensure_starter_collection()
	return _collection.get_storage_instances()


# Compatibility for prototype callers that used "reserve" to mean Storage.
# New gameplay code must use get_reserve_party_instances() for the battle bench.
func get_reserve_instances() -> Array[DigimonInstance]:
	return get_storage_instances()

func get_collection_instances() -> Array[DigimonInstance]:
	_ensure_starter_collection()
	return _collection.get_instances()

func get_instance_by_id(instance_id: String) -> DigimonInstance:
	_ensure_starter_collection()
	return _collection.get_instance(instance_id)

func get_instance_for_party_key(key: String) -> DigimonInstance:
	_ensure_starter_collection()
	return _collection.get_instance_by_key(key)

func get_collection_key(instance_id: String) -> String:
	_ensure_starter_collection()
	return _collection.get_key_for_instance(instance_id)

func get_collection_location(instance_id: String) -> String:
	_ensure_starter_collection()
	return _collection.get_location(instance_id)


func get_squad_role(instance_id: String) -> String:
	_ensure_starter_collection()
	return _collection.get_squad_role(instance_id)

func set_active_party(party: Array) -> bool:
	_ensure_starter_collection()
	var ids: Array[String] = []
	for raw_value in party:
		var token := String(raw_value).strip_edges()
		if token.is_empty():
			return false
		var instance := _collection.get_instance(token)
		if instance == null:
			instance = _collection.get_instance_by_key(token)
		if instance == null or ids.has(instance.id):
			return false
		ids.append(instance.id)

	var reserve := _collection.get_reserve_party_ids()
	for instance_id: String in ids:
		reserve.erase(instance_id)
	if not _party_service.set_squad(_collection, ids, reserve):
		return false
	_emit_squad_changed()
	_save_after_mutation()
	return true


func add_to_active_party(instance_id: String) -> bool:
	_ensure_starter_collection()
	if not _party_service.add_to_active(_collection, instance_id):
		return false
	_emit_squad_changed()
	_save_after_mutation()
	return true


func add_to_reserve_party(instance_id: String) -> bool:
	_ensure_starter_collection()
	if not _party_service.add_to_reserve(_collection, instance_id):
		return false
	_emit_squad_changed()
	_save_after_mutation()
	return true


func remove_from_active_party(instance_id: String) -> bool:
	_ensure_starter_collection()
	if not _party_service.move_to_storage(_collection, instance_id):
		return false
	_emit_squad_changed()
	_save_after_mutation()
	return true


func move_squad_member_to_storage(instance_id: String) -> bool:
	_ensure_starter_collection()
	if not _party_service.move_to_storage(_collection, instance_id):
		return false
	_emit_squad_changed()
	_save_after_mutation()
	return true


func assign_squad_slot(instance_id: String, role: String, slot_index: int) -> bool:
	_ensure_starter_collection()
	if not _party_service.assign_to_slot(_collection, instance_id, role, slot_index):
		return false
	_emit_squad_changed()
	_save_after_mutation()
	return true


func swap_party_with_reserve(active_instance_id: String, reserve_instance_id: String) -> bool:
	_ensure_starter_collection()
	if not _party_service.swap_with_reserve(_collection, active_instance_id, reserve_instance_id):
		return false
	_emit_squad_changed()
	_save_after_mutation()
	return true


func move_active_party_member(instance_id: String, new_index: int) -> bool:
	_ensure_starter_collection()
	if _collection.get_squad_role(instance_id) != PlayerCollection.SQUAD_ROLE_ACTIVE:
		return false
	if not _party_service.move(_collection, instance_id, new_index):
		return false
	_emit_squad_changed()
	_save_after_mutation()
	return true


func move_reserve_party_member(instance_id: String, new_index: int) -> bool:
	_ensure_starter_collection()
	if _collection.get_squad_role(instance_id) != PlayerCollection.SQUAD_ROLE_RESERVE:
		return false
	if not _party_service.move(_collection, instance_id, new_index):
		return false
	_emit_squad_changed()
	_save_after_mutation()
	return true


func party_validation_error(instance_ids: Array[String]) -> String:
	_ensure_starter_collection()
	return _party_service.validation_error(_collection, instance_ids)

func reset_active_party() -> void:
	_ensure_starter_collection()
	var ids: Array[String] = []
	for key in DEFAULT_ACTIVE_PARTY:
		var instance := _collection.get_instance_by_key(String(key))
		if instance != null and not _collection.is_hospitalized(instance.id):
			ids.append(instance.id)
	if ids.is_empty() or ids == _collection.get_active_party_ids():
		return
	if _party_service.set_party(_collection, ids):
		active_party_changed.emit(get_active_party())
		_save_after_mutation()

func replace_or_add_instance(instance: DigimonInstance, collection_key: String = "") -> bool:
	if instance == null:
		return false
	_ensure_database()
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return false
	var key := collection_key.to_lower().strip_edges()
	var success := false
	if key.is_empty():
		success = not _collection.add_instance(instance, "", String(species.get("name", "digimon"))).is_empty()
	else:
		success = _collection.replace_at_key(instance, key, String(species.get("name", "digimon")))
	if success:
		collection_changed.emit()
		_emit_squad_changed()
		_save_after_mutation()
	return success

func add_collection_instance(instance: DigimonInstance, preferred_key: String = "") -> String:
	if instance == null:
		return ""
	_ensure_database()
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		return ""
	var key := _collection.add_instance(instance, preferred_key, String(species.get("name", "digimon")))
	if not key.is_empty():
		collection_changed.emit()
		_save_after_mutation()
	return key

func notify_collection_changed() -> void:
	collection_changed.emit()
	_save_after_mutation()

func apply_training_plan(instance_id: String, stat_additions: Dictionary, mobility_steps: int) -> bool:
	_ensure_starter_collection()
	var instance := _collection.get_instance(instance_id)
	if instance == null or not _training_service.apply_plan(instance, stat_additions, mobility_steps):
		return false
	collection_changed.emit()
	_save_after_mutation()
	return true

func get_max_active_party_size() -> int:
	return _party_service.maximum_active_size()


func get_max_reserve_party_size() -> int:
	return _party_service.maximum_reserve_size()


func get_max_squad_size() -> int:
	return _party_service.maximum_squad_size()

func get_database():
	_ensure_database()
	return _database

func get_bits() -> int:
	return _collection.bits


func get_hospital_preview(instance_id: String, now_unix: int = -1) -> Dictionary:
	_ensure_starter_collection()
	var instance := _collection.get_instance(instance_id)
	if instance == null:
		return {"status": "unavailable", "can_admit": false, "can_recover_now": false, "can_discharge": false}
	return _hospital_service.preview(instance, _max_hp_for(instance), _max_sp_for(instance), _collection.bits, now_unix, _collection.get_location(instance_id))


func admit_to_hospital(instance_id: String, now_unix: int = -1) -> Dictionary:
	_ensure_starter_collection()
	process_hospital_recoveries(now_unix)
	var instance := _collection.get_instance(instance_id)
	var result := _hospital_service.admit(_collection, instance, _max_hp_for(instance), now_unix)
	if bool(result.get("success", false)):
		_emit_squad_changed()
		collection_changed.emit()
		hospital_state_changed.emit(instance_id, "recovering")
		_save_after_mutation()
	return result


func recover_from_hospital_now(instance_id: String, now_unix: int = -1) -> Dictionary:
	_ensure_starter_collection()
	var instance := _collection.get_instance(instance_id)
	var result := _hospital_service.recover_now(_collection, instance, _max_hp_for(instance), _max_sp_for(instance), now_unix)
	if bool(result.get("success", false)):
		_emit_squad_changed()
		collection_changed.emit()
		account_rewards_changed.emit(_collection.bits, get_digi_data())
		hospital_state_changed.emit(instance_id, "ready")
		_save_after_mutation()
	return result


func discharge_from_hospital(instance_id: String, now_unix: int = -1) -> Dictionary:
	_ensure_starter_collection()
	process_hospital_recoveries(now_unix)
	var instance := _collection.get_instance(instance_id)
	var result := _hospital_service.discharge(
		_collection,
		instance,
		_max_hp_for(instance),
		_party_service.maximum_active_size(),
		_party_service.maximum_reserve_size(),
		now_unix
	)
	if bool(result.get("success", false)):
		_emit_squad_changed()
		collection_changed.emit()
		hospital_state_changed.emit(instance_id, String(result.get("destination", "storage")))
		_save_after_mutation()
	return result


func process_hospital_recoveries(now_unix: int = -1, persist: bool = true) -> Array[String]:
	_ensure_starter_collection()
	var completed: Array[String] = []
	for instance: DigimonInstance in _collection.get_hospital_instances():
		if _hospital_service.complete_if_ready(instance, _max_hp_for(instance), _max_sp_for(instance), now_unix, PlayerCollection.LOCATION_HOSPITAL):
			completed.append(instance.id)
	if completed.is_empty():
		return completed
	collection_changed.emit()
	for instance_id: String in completed:
		hospital_state_changed.emit(instance_id, "ready")
	if persist:
		_save_after_mutation()
	return completed


func battle_party_validation_error(now_unix: int = -1) -> String:
	_ensure_starter_collection()
	process_hospital_recoveries(now_unix)
	var invariant_error := _collection.location_invariant_error()
	if not invariant_error.is_empty():
		return invariant_error
	var active_ids := _collection.get_active_party_ids()
	if active_ids.is_empty():
		return "You need at least one available Digimon in your party to start a battle."
	var party_error := _party_service.validation_error(_collection, active_ids)
	if not party_error.is_empty():
		return party_error
	if get_battle_ready_active_instances().is_empty():
		return "You need at least one available Digimon in your party to start a battle."
	return ""


func get_inventory() -> Dictionary:
	return _collection.get_inventory()


func get_item_count(item_id: String) -> int:
	return _collection.get_item_count(item_id)


func get_tier_promotion_preview(target_id: String, donor_id: String = "") -> Dictionary:
	_ensure_database()
	return _ascension.promotion_preview(_collection, _database, target_id, donor_id)


func get_tier_donors(target_id: String) -> Array[DigimonInstance]:
	return _ascension.eligible_donors(_collection, target_id)


func promote_digimon_tier(target_id: String, donor_id: String = "") -> Dictionary:
	_ensure_database()
	var result: Dictionary = _ascension.promote(_collection, _database, target_id, donor_id)
	if bool(result.get("success", false)):
		collection_changed.emit()
		account_rewards_changed.emit(_collection.bits, get_digi_data())
		_save_after_mutation()
	return result


func craft_expansion_core() -> Dictionary:
	var result: Dictionary = _ascension.craft_expansion_core(_collection)
	if bool(result.get("success", false)):
		inventory_changed.emit(get_inventory())
		account_rewards_changed.emit(_collection.bits, get_digi_data())
		_save_after_mutation()
	return result


func unlock_digimon_expansion(target_id: String) -> Dictionary:
	_ensure_database()
	var result: Dictionary = _ascension.unlock_expansion(_collection, _database, target_id)
	if bool(result.get("success", false)):
		collection_changed.emit()
		inventory_changed.emit(get_inventory())
		_save_after_mutation()
	return result


func set_digimon_expanded(target_id: String, expanded: bool) -> Dictionary:
	_ensure_database()
	var target := _collection.get_instance(target_id)
	var result: Dictionary = _ascension.set_expanded(_database, target, expanded)
	if bool(result.get("success", false)):
		collection_changed.emit()
		_emit_squad_changed()
		_save_after_mutation()
	return result


func has_technique_record(skill_id: String) -> bool:
	return _collection.has_technique_record(skill_id)


func unlock_technique_record(skill_id: String) -> bool:
	if not _collection.unlock_technique_record(skill_id):
		return false
	technique_progress_changed.emit()
	_save_after_mutation()
	return true


func get_technique_research(skill_id: String) -> int:
	return _collection.get_technique_research(skill_id)


func get_teachable_techniques(instance_id: String) -> Array[Dictionary]:
	var instance := get_instance_by_id(instance_id)
	if instance == null:
		return []
	var species := _database.get_by_seed(instance.species_seed)
	return _technique_records.get_teachable_records(_collection, instance, species)


func teach_technique(instance_id: String, skill_id: String) -> Dictionary:
	var instance := get_instance_by_id(instance_id)
	var species := _database.get_by_seed(instance.species_seed) if instance != null else {}
	var result: Dictionary = _technique_records.teach(_collection, instance, species, skill_id)
	if bool(result.get("success", false)):
		collection_changed.emit()
		account_rewards_changed.emit(_collection.bits, get_digi_data())
		technique_progress_changed.emit()
		_save_after_mutation()
	return result


func apply_technique_battle_progress(mastery_uses: Dictionary, observed_techniques: Array[String]) -> Dictionary:
	var mastery_results: Array[Dictionary] = []
	for raw_instance_id in mastery_uses.keys():
		var instance := _collection.get_instance(String(raw_instance_id))
		var uses = mastery_uses[raw_instance_id]
		if instance == null or not uses is Dictionary:
			continue
		for raw_skill_id in uses.keys():
			var skill_id := String(raw_skill_id)
			var before := instance.get_skill_mastery_points(skill_id)
			var after := instance.record_effective_skill_uses(skill_id, mini(2, maxi(0, int(uses[raw_skill_id]))))
			if after > before:
				mastery_results.append({
					"instance_id": instance.id,
					"skill_id": skill_id,
					"before": before,
					"after": after,
					"grade": instance.get_skill_mastery_grade(skill_id),
				})
	var research_results := _technique_records.apply_research_insights(_collection, observed_techniques)
	if not mastery_results.is_empty() or not research_results.is_empty():
		collection_changed.emit()
		technique_progress_changed.emit()
		_save_after_mutation()
	return {"mastery": mastery_results, "research": research_results}


func favorite_technique(instance_id: String, skill_id: String) -> bool:
	var instance := get_instance_by_id(instance_id)
	if instance == null or not instance.favorite_skill(skill_id):
		return false
	notify_collection_changed()
	return true


func unfavorite_technique(instance_id: String, skill_id: String) -> bool:
	var instance := get_instance_by_id(instance_id)
	if instance == null or not instance.unfavorite_skill(skill_id):
		return false
	notify_collection_changed()
	return true


func move_favorite_technique(instance_id: String, skill_id: String, new_index: int) -> bool:
	var instance := get_instance_by_id(instance_id)
	if instance == null or not instance.move_favorite(skill_id, new_index):
		return false
	notify_collection_changed()
	return true


func archive_technique(instance_id: String, skill_id: String) -> bool:
	var instance := get_instance_by_id(instance_id)
	if instance == null or not instance.archive_skill(skill_id):
		return false
	notify_collection_changed()
	return true


func restore_technique(instance_id: String, skill_id: String) -> bool:
	var instance := get_instance_by_id(instance_id)
	if instance == null or not instance.restore_skill(skill_id):
		return false
	notify_collection_changed()
	return true

func get_digi_data() -> Dictionary:
	_ensure_database()
	var result: Dictionary = {}
	for raw_seed in _collection.get_all_digi_data().keys():
		var seed := String(raw_seed)
		var species := _database.get_by_seed(seed)
		if species.is_empty():
			continue
		result[String(species.get("name", seed))] = _collection.get_digi_data(seed)
	return result

func get_digi_data_for(species_name_or_seed: String) -> int:
	var seed := _resolve_species_seed(species_name_or_seed)
	return _collection.get_digi_data(seed) if not seed.is_empty() else 0

func get_reconstruction_requirement(species_name_or_seed: String) -> int:
	var seed := _resolve_species_seed(species_name_or_seed)
	if seed.is_empty():
		return _balance.reconstruction_int("defaultRequired", 100)
	var species := _database.get_by_seed(seed)
	return maxi(1, int(species.get("dataRequired", _balance.reconstruction_int("defaultRequired", 100))))

func apply_account_rewards(bits: int, digi_data: Dictionary, items: Dictionary = {}) -> Dictionary:
	_ensure_database()
	_collection.bits += maxi(0, bits)
	var progress: Dictionary = {}
	for raw_species in digi_data.keys():
		var token := String(raw_species)
		var seed := _resolve_species_seed(token)
		if seed.is_empty():
			continue
		var before := _collection.get_digi_data(seed)
		var after := _collection.add_digi_data(seed, maxi(0, int(digi_data[raw_species])))
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
	for raw_item_id in items.keys():
		var item_id := String(raw_item_id).strip_edges()
		var amount := maxi(0, int(items[raw_item_id]))
		if not item_id.is_empty() and amount > 0:
			_collection.add_item(item_id, amount)
	account_rewards_changed.emit(_collection.bits, get_digi_data())
	if not items.is_empty():
		inventory_changed.emit(get_inventory())
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
	return _collection.get_digi_data(seed) >= amount

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
	if _collection.get_digi_data(seed) < amount:
		return null
	var instance: DigimonInstance = _factory.create_player_by_seed(seed, 1, amount)
	if instance == null:
		return null
	if _balance.reconstruction_bool("consumeData", true) and not _collection.consume_digi_data(seed, amount):
		return null
	_collection.add_instance(instance, String(species.get("name", "digimon")).to_lower().replace(" ", "_"), String(species.get("name", "digimon")))
	collection_changed.emit()
	account_rewards_changed.emit(_collection.bits, get_digi_data())
	_save_after_mutation()
	return instance

func save_progress() -> bool:
	if not _persistence_enabled:
		return true
	var success := _save_service.save_collection(_collection)
	if success:
		progress_saved.emit()
	return success

func load_progress() -> bool:
	if not _persistence_enabled:
		return false
	var loaded: PlayerCollection = _save_service.load_collection()
	if loaded == null or loaded.is_empty():
		return false
	_collection = loaded
	return true

func set_persistence_enabled(enabled: bool) -> void:
	_persistence_enabled = enabled

func reset_progress_for_tests(delete_disk_save: bool = false) -> void:
	_collection = CollectionScript.new()
	if delete_disk_save:
		_save_service.delete_save()
	_ensure_starter_collection()
	_emit_squad_changed()
	collection_changed.emit()
	account_rewards_changed.emit(_collection.bits, get_digi_data())
	inventory_changed.emit(get_inventory())

func _ensure_starter_collection() -> void:
	if not _collection.is_empty():
		return
	_ensure_database()
	if _factory == null:
		return
	var starter_ids: Array[String] = []
	for key in DEFAULT_ACTIVE_PARTY:
		var species_key := String(key)
		var instance: DigimonInstance = _factory.create_player_by_name(species_key, 1, 100)
		if instance != null:
			_collection.add_instance(instance, species_key, species_key)
			starter_ids.append(instance.id)
	if not starter_ids.is_empty():
		_party_service.set_party(_collection, starter_ids)
	collection_changed.emit()

func _repair_loaded_collection() -> void:
	_ensure_database()
	if _collection.is_empty():
		_ensure_starter_collection()
		save_progress()
		return

	var changed := false
	var seen: Dictionary = {}
	var valid_active: Array[String] = []
	var valid_reserve: Array[String] = []

	for instance_id: String in _collection.get_active_party_ids():
		var instance := _collection.get_instance(instance_id)
		if (
			instance == null
			or _collection.is_hospitalized(instance_id)
			or _database.get_by_seed(instance.species_seed).is_empty()
			or seen.has(instance_id)
		):
			changed = true
			continue
		if valid_active.size() < _party_service.maximum_active_size():
			valid_active.append(instance_id)
			seen[instance_id] = true
		else:
			changed = true

	for instance_id: String in _collection.get_reserve_party_ids():
		var instance := _collection.get_instance(instance_id)
		if (
			instance == null
			or _collection.is_hospitalized(instance_id)
			or _database.get_by_seed(instance.species_seed).is_empty()
			or seen.has(instance_id)
		):
			changed = true
			continue
		if valid_reserve.size() < _party_service.maximum_reserve_size():
			valid_reserve.append(instance_id)
			seen[instance_id] = true
		else:
			changed = true

	if valid_active != _collection.get_active_party_ids() or valid_reserve != _collection.get_reserve_party_ids():
		_collection.set_squad_ids(
			valid_active,
			valid_reserve,
			0,
			_party_service.maximum_active_size(),
			_party_service.maximum_reserve_size()
		)
		changed = true

	var invariant_error := _collection.location_invariant_error()
	if not invariant_error.is_empty():
		push_error("Loaded collection has invalid Digimon locations: %s" % invariant_error)
	if changed:
		save_progress()


func _emit_squad_changed() -> void:
	active_party_changed.emit(get_active_party())
	squad_changed.emit(_collection.get_active_party_ids(), _collection.get_reserve_party_ids())


func _ensure_database() -> void:
	if not _database.is_loaded():
		if not _database.load_default():
			push_error("Could not initialize persistent Digimon collection database")
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


func _max_hp_for(instance: DigimonInstance) -> int:
	if instance == null:
		return 1
	_ensure_database()
	var species := _database.get_by_seed(instance.species_seed)
	return maxi(1, _stat_calculator.get_stat(instance, species, "hp"))


func _max_sp_for(instance: DigimonInstance) -> int:
	if instance == null:
		return 0
	_ensure_database()
	var species := _database.get_by_seed(instance.species_seed)
	return maxi(0, _stat_calculator.get_stat(instance, species, "mp"))


func _save_after_mutation() -> void:
	if not save_progress() and _persistence_enabled:
		push_warning("Player progression changed but could not be persisted")