extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const HospitalCalculatorScript = preload("res://src/hospital/HospitalRecoveryCalculator.gd")
const HospitalServiceScript = preload("res://src/hospital/HospitalService.gd")
const BattleDigimonScript = preload("res://src/battle/BattleDigimon.gd")
const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const SaveServiceScript = preload("res://src/save/SaveService.gd")
const MigrationScript = preload("res://src/save/SaveMigration.gd")

const TEST_SAVE_PATH := "user://digigame-hospital-regression.json"


func _ready() -> void:
	var database: DigimonDatabase = DatabaseScript.new()
	assert(database.load_default(), "Hospital tests require the Digimon database")
	var factory: DigimonFactory = FactoryScript.new(database)
	var stats: DigimonStatCalculator = StatCalculatorScript.new()
	var calculator: HospitalRecoveryCalculator = HospitalCalculatorScript.new()
	var hospital: HospitalService = HospitalServiceScript.new(calculator)

	_test_derived_health_and_scaling(database, factory, stats, calculator, hospital)
	_test_battle_damage_commits_fainted_state(database, factory, stats)
	_test_party_storage_and_admission(database, factory, stats, hospital)
	_test_last_party_member_can_be_admitted(database, factory, stats, hospital)
	_test_offline_completion_waits_for_discharge(database, factory, stats, hospital)
	_test_instant_recovery_is_atomic_and_idempotent(database, factory, stats, hospital)
	_test_discharge_destinations(database, factory, stats, hospital)
	_test_save_load_preserves_locations(database, factory, stats, hospital)
	_test_overworld_battle_gate_and_runtime_roster()
	_test_pre_squad_saves_are_rejected(factory)

	print("hospital system regression passed")
	get_tree().quit()


func _test_derived_health_and_scaling(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, calculator: HospitalRecoveryCalculator, hospital: HospitalService) -> void:
	var injured := factory.create_player_by_name("agumon", 12, 100)
	var critical := factory.create_player_by_name("agumon", 12, 100)
	var species := database.get_by_seed(injured.species_seed)
	var max_hp := stats.get_stat(injured, species, "hp")
	var max_sp := stats.get_stat(injured, species, "mp")
	injured.current_hp = int(round(float(max_hp) * 0.6))
	critical.current_hp = 0
	assert(hospital.status_for(injured, max_hp, 1000, PlayerCollection.LOCATION_PARTY) == "injured", "Partial HP must derive Injured")
	assert(hospital.status_for(critical, max_hp, 1000, PlayerCollection.LOCATION_PARTY) == "critical", "Zero HP outside battle must derive Critical")
	assert(calculator.instant_cost(critical, max_hp) > calculator.instant_cost(injured, max_hp), "Instant cost must increase with missing HP")
	assert(calculator.recovery_seconds(critical, max_hp) > calculator.recovery_seconds(injured, max_hp), "Recovery time must increase with missing HP")
	var moderately_injured := factory.create_player_by_name("veemon", 3, 100)
	moderately_injured.current_hp = 64
	assert(calculator.instant_cost(moderately_injured, 100) == 234, "A level 3 Digimon missing 36% HP must have a meaningful 234 Bits instant cost")
	var lightly_injured := factory.create_player_by_name("agumon", 4, 100)
	lightly_injured.current_hp = 93
	assert(calculator.instant_cost(lightly_injured, 100) == 100, "Minor injuries must still pay the 100 Bits instant-service minimum")
	injured.current_hp = max_hp
	var healthy_preview := hospital.preview(injured, max_hp, max_sp, 9999, 1000, PlayerCollection.LOCATION_PARTY)
	assert(String(healthy_preview.get("status", "")) == "healthy", "Full HP must derive Healthy")
	assert(not bool(healthy_preview.get("can_admit", true)) and int(healthy_preview.get("instant_cost", -1)) == 0, "Healthy Digimon must not expose treatment")
	var serialized := critical.to_dict()
	assert(not serialized.has("dead") and not serialized.has("isDead") and not serialized.has("critical"), "Health must not create persistent death or condition flags")


func _test_battle_damage_commits_fainted_state(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator) -> void:
	var instance := factory.create_player_by_name("agumon", 5, 100)
	var max_hp := stats.get_stat(instance, database.get_by_seed(instance.species_seed), "hp")
	var battle_state: BattleDigimon = BattleDigimonScript.new(instance, "player")
	battle_state.take_damage(max_hp)
	assert(instance.current_hp == max_hp, "Battle damage must remain isolated until the battle state is committed")
	battle_state.commit_resources_to_instance()
	assert(instance.is_fainted() and instance.current_hp == 0, "Committed knockout damage must persist as the canonical fainted state")


func _test_party_storage_and_admission(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, hospital: HospitalService) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var active_patient := factory.create_player_by_name("agumon", 8, 100)
	var reserve_patient := factory.create_player_by_name("veemon", 8, 100)
	var storage_digimon := factory.create_player_by_name("gabumon", 8, 100)
	active_patient.current_hp = 0
	reserve_patient.current_hp = 0
	storage_digimon.current_hp = 0
	collection.add_instance(active_patient, "agumon", "Agumon")
	collection.add_instance(reserve_patient, "veemon", "Veemon")
	collection.add_instance(storage_digimon, "gabumon", "Gabumon")
	assert(
		collection.set_squad_ids([active_patient.id], [reserve_patient.id], 1, 3, 3),
		"Hospital fixture must configure Active and Reserve explicitly"
	)
	assert(collection.get_active_instances() == [active_patient], "Active treatment candidate must remain Active")
	assert(collection.get_reserve_party_instances() == [reserve_patient], "Reserve must be a real Squad role")
	assert(collection.get_storage_instances() == [storage_digimon], "Storage must remain outside the Squad")

	var active_max_hp := stats.get_stat(active_patient, database.get_by_seed(active_patient.species_seed), "hp")
	var active_admission := hospital.admit(collection, active_patient, active_max_hp, 5000)
	assert(bool(active_admission.get("success", false)), "Critical Active Digimon must be admissible")
	assert(collection.get_squad_role(active_patient.id).is_empty(), "Hospital admission must remove Active role")
	assert(collection.get_hospital_ids().has(active_patient.id), "Admission must add the UUID to Hospital")
	assert(collection.get_reserve_party_ids() == [reserve_patient.id], "Admitting Active must not mutate Reserve order")

	var reserve_max_hp := stats.get_stat(reserve_patient, database.get_by_seed(reserve_patient.species_seed), "hp")
	var reserve_admission := hospital.admit(collection, reserve_patient, reserve_max_hp, 5100)
	assert(bool(reserve_admission.get("success", false)), "Critical Reserve Digimon must also be admissible")
	assert(not collection.get_reserve_party_ids().has(reserve_patient.id), "Hospital admission must remove Reserve role")
	var return_slots := collection.to_dict().get("hospitalReturnSlots", {}) as Dictionary
	assert(String((return_slots.get(active_patient.id, {}) as Dictionary).get("role", "")) == PlayerCollection.SQUAD_ROLE_ACTIVE, "Hospital must remember Active origin")
	assert(String((return_slots.get(reserve_patient.id, {}) as Dictionary).get("role", "")) == PlayerCollection.SQUAD_ROLE_RESERVE, "Hospital must remember Reserve origin")
	assert(collection.get_storage_instances() == [storage_digimon], "Hospitalized Squad members must never leak into Storage")
	assert(collection.location_invariant_error().is_empty(), "Active, Reserve, Hospital and Storage UUIDs must remain exclusive")

	var storage_preview := hospital.preview(
		storage_digimon,
		stats.get_stat(storage_digimon, database.get_by_seed(storage_digimon.species_seed), "hp"),
		stats.get_stat(storage_digimon, database.get_by_seed(storage_digimon.species_seed), "mp"),
		9999,
		5000,
		collection.get_location(storage_digimon.id)
	)
	assert(not storage_preview.get("can_admit", true), "Storage Digimon must not be admissible from Hospital UI")
	assert(not hospital.admit(collection, storage_digimon, 100, 5000).get("success", true), "Storage Digimon cannot be admitted directly")

func _test_last_party_member_can_be_admitted(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, hospital: HospitalService) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var patient := factory.create_player_by_name("veemon", 6, 100)
	var patient_species := database.get_by_seed(patient.species_seed)
	var max_hp := stats.get_stat(patient, patient_species, "hp")
	var max_sp := stats.get_stat(patient, patient_species, "mp")
	patient.current_hp = 0
	patient.set_current_sp(0)
	collection.add_instance(patient, "veemon", "Veemon")
	assert(collection.set_active_party_ids([patient.id], 1, 6), "Last-member test must begin with one Party member")
	assert(hospital.admit(collection, patient, max_hp, 6000).get("success", false), "Hospital admission must be allowed to remove the last Party member")
	assert(collection.get_active_party_ids().is_empty(), "Admitting the last member must leave Party empty without corruption")
	assert(collection.get_hospital_ids() == [patient.id], "The last member must exist exactly once in Hospital")
	assert(collection.location_invariant_error().is_empty(), "Empty Party with Hospital patient must preserve invariants")


func _test_offline_completion_waits_for_discharge(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, hospital: HospitalService) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var patient := factory.create_player_by_name("gabumon", 8, 100)
	var species := database.get_by_seed(patient.species_seed)
	var max_hp := stats.get_stat(patient, species, "hp")
	var max_sp := stats.get_stat(patient, species, "mp")
	patient.current_hp = 0
	patient.set_current_sp(0)
	collection.add_instance(patient, "gabumon", "Gabumon")
	collection.set_active_party_ids([patient.id], 1, 6)
	var admission := hospital.admit(collection, patient, max_hp, 7000)
	var completes_at := int(admission.get("completes_at", 0))
	assert(patient.has_hospital_recovery() and completes_at > 7000, "Admission must persist a valid recovery interval")
	assert(hospital.status_for(patient, max_hp, 7001, PlayerCollection.LOCATION_HOSPITAL) == "recovering", "Admitted Digimon must derive Recovering")
	var midpoint := 7000 + int((completes_at - 7000) / 2)
	var midpoint_preview := hospital.preview(patient, max_hp, max_sp, 9999, midpoint, PlayerCollection.LOCATION_HOSPITAL)
	assert(int(midpoint_preview.get("current_hp", 0)) > 0 and int(midpoint_preview.get("current_hp", 0)) < max_hp, "Timed recovery preview must increase HP before completion")
	assert(int(midpoint_preview.get("current_sp", 0)) > 0 and int(midpoint_preview.get("current_sp", 0)) < max_sp, "Timed recovery preview must increase SP before completion")
	assert(float(midpoint_preview.get("recovery_progress", 0.0)) > 0.0 and float(midpoint_preview.get("recovery_progress", 0.0)) < 1.0, "Timed recovery preview must expose in-progress feedback")
	assert(not hospital.complete_if_ready(patient, max_hp, max_sp, completes_at - 1, PlayerCollection.LOCATION_HOSPITAL), "Recovery must not complete early")
	assert(hospital.complete_if_ready(patient, max_hp, max_sp, completes_at, PlayerCollection.LOCATION_HOSPITAL), "Offline timestamp completion must restore HP and SP")
	assert(patient.current_hp == max_hp and patient.get_current_sp() == max_sp and patient.has_hospital_recovery(), "Completed recovery must fully restore HP and SP while keeping its interval until discharge")
	assert(collection.is_hospitalized(patient.id), "Completed recovery must remain in Hospital")
	assert(hospital.status_for(patient, max_hp, completes_at, PlayerCollection.LOCATION_HOSPITAL) == "ready", "Completed patient must become Ready")
	assert(not hospital.complete_if_ready(patient, max_hp, max_sp, completes_at + 1, PlayerCollection.LOCATION_HOSPITAL), "Repeated completion processing must be idempotent")


func _test_instant_recovery_is_atomic_and_idempotent(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, hospital: HospitalService) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var patient := factory.create_player_by_name("veemon", 15, 100)
	var species := database.get_by_seed(patient.species_seed)
	var max_hp := stats.get_stat(patient, species, "hp")
	var max_sp := stats.get_stat(patient, species, "mp")
	patient.current_hp = 1
	patient.set_current_sp(0)
	collection.add_instance(patient, "veemon", "Veemon")
	collection.set_active_party_ids([patient.id], 1, 6)
	collection.bits = 10000
	var expected_cost := int(hospital.preview(patient, max_hp, max_sp, collection.bits, 8000, PlayerCollection.LOCATION_PARTY).get("instant_cost", 0))
	var before_bits := collection.bits
	var result := hospital.recover_now(collection, patient, max_hp, max_sp, 8000)
	assert(bool(result.get("success", false)) and int(result.get("bits_spent", 0)) == expected_cost, "Immediate recovery must use centralized cost")
	assert(collection.bits == before_bits - expected_cost and patient.current_hp == max_hp and patient.get_current_sp() == max_sp, "Immediate recovery must deduct Bits once and restore HP and SP")
	assert(collection.is_hospitalized(patient.id) and collection.get_active_party_ids().is_empty(), "Immediate recovery from Party must move the Digimon into Hospital")
	assert(hospital.status_for(patient, max_hp, 8000, PlayerCollection.LOCATION_HOSPITAL) == "ready", "Immediate recovery must finish ready for discharge")
	var after_first := collection.bits
	var repeated := hospital.recover_now(collection, patient, max_hp, max_sp, 8000)
	assert(not repeated.get("success", true) and String(repeated.get("reason", "")) == "already_ready", "Repeated instant recovery must be rejected idempotently")
	assert(collection.bits == after_first, "Repeated instant recovery must not debit Bits twice")

	var poor_collection: PlayerCollection = CollectionScript.new()
	var poor_patient := factory.create_player_by_name("agumon", 5, 100)
	var poor_species := database.get_by_seed(poor_patient.species_seed)
	var poor_max_hp := stats.get_stat(poor_patient, poor_species, "hp")
	var poor_max_sp := stats.get_stat(poor_patient, poor_species, "mp")
	poor_patient.current_hp = 0
	poor_patient.set_current_sp(0)
	poor_collection.add_instance(poor_patient, "agumon", "Agumon")
	poor_collection.set_active_party_ids([poor_patient.id], 1, 6)
	poor_collection.bits = 0
	var failed := hospital.recover_now(poor_collection, poor_patient, poor_max_hp, poor_max_sp, 8000)
	assert(not failed.get("success", true) and String(failed.get("reason", "")) == "insufficient_bits", "Insufficient Bits must reject immediate recovery")
	assert(poor_collection.get_location(poor_patient.id) == PlayerCollection.LOCATION_PARTY and poor_patient.current_hp == 0, "Rejected transaction must not mutate location or HP")


func _test_discharge_destinations(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, hospital: HospitalService) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var active_patient := factory.create_player_by_name("agumon", 10, 100)
	var teammate := factory.create_player_by_name("gabumon", 10, 100)
	var reserve_patient := factory.create_player_by_name("veemon", 10, 100)
	for instance: DigimonInstance in [active_patient, teammate, reserve_patient]:
		collection.add_instance(instance, instance.species_seed, "Digimon")
	assert(collection.set_squad_ids([active_patient.id, teammate.id], [reserve_patient.id], 1, 3, 3), "Discharge fixture must configure Squad roles")

	var active_species := database.get_by_seed(active_patient.species_seed)
	var active_max_hp := stats.get_stat(active_patient, active_species, "hp")
	var active_max_sp := stats.get_stat(active_patient, active_species, "mp")
	active_patient.current_hp = 0
	active_patient.set_current_sp(0)
	var admission := hospital.admit(collection, active_patient, active_max_hp, 9000)
	var completes_at := int(admission.get("completes_at", 0))
	hospital.complete_if_ready(active_patient, active_max_hp, active_max_sp, completes_at, PlayerCollection.LOCATION_HOSPITAL)
	var discharge := hospital.discharge(collection, active_patient, active_max_hp, 3, 3, completes_at)
	assert(discharge.get("success", false), "Recovered Active patient must discharge")
	assert(String(discharge.get("squad_role", "")) == PlayerCollection.SQUAD_ROLE_ACTIVE, "Recovered Active patient must prefer its original role")
	assert(collection.get_active_party_ids() == [active_patient.id, teammate.id], "Active discharge must restore original slot order")

	var reserve_species := database.get_by_seed(reserve_patient.species_seed)
	var reserve_max_hp := stats.get_stat(reserve_patient, reserve_species, "hp")
	var reserve_max_sp := stats.get_stat(reserve_patient, reserve_species, "mp")
	reserve_patient.current_hp = 0
	reserve_patient.set_current_sp(0)
	var reserve_admission := hospital.admit(collection, reserve_patient, reserve_max_hp, 10000)
	var reserve_complete := int(reserve_admission.get("completes_at", 0))
	hospital.complete_if_ready(reserve_patient, reserve_max_hp, reserve_max_sp, reserve_complete, PlayerCollection.LOCATION_HOSPITAL)
	var reserve_discharge := hospital.discharge(collection, reserve_patient, reserve_max_hp, 3, 3, reserve_complete)
	assert(reserve_discharge.get("success", false), "Recovered Reserve patient must discharge")
	assert(String(reserve_discharge.get("squad_role", "")) == PlayerCollection.SQUAD_ROLE_RESERVE, "Recovered Reserve patient must return to Reserve")
	assert(collection.get_reserve_party_ids() == [reserve_patient.id], "Reserve discharge must restore original slot")

	# Capacity fallback is deterministic: when neither Squad role has a free
	# slot under the supplied limits, the recovered individual goes to Storage.
	active_patient.current_hp = 0
	var second_admission := hospital.admit(collection, active_patient, active_max_hp, 11000)
	var second_complete := int(second_admission.get("completes_at", 0))
	hospital.complete_if_ready(active_patient, active_max_hp, active_max_sp, second_complete, PlayerCollection.LOCATION_HOSPITAL)
	var storage_discharge := hospital.discharge(collection, active_patient, active_max_hp, 1, 1, second_complete)
	assert(storage_discharge.get("success", false) and String(storage_discharge.get("destination", "")) == PlayerCollection.LOCATION_STORAGE, "Full Active and Reserve capacities must fall back to Storage")
	assert(collection.get_location(active_patient.id) == PlayerCollection.LOCATION_STORAGE, "Storage fallback must leave one derived location")
	assert(collection.location_invariant_error().is_empty(), "Discharge must preserve location invariants")

func _test_save_load_preserves_locations(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, hospital: HospitalService) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var patient := factory.create_player_by_name("agumon", 7, 100)
	var party_member := factory.create_player_by_name("gabumon", 7, 100)
	var reserve_member := factory.create_player_by_name("veemon", 7, 100)
	var storage_member := factory.create_player_by_name("agumon", 7, 100)
	var max_hp := stats.get_stat(patient, database.get_by_seed(patient.species_seed), "hp")
	patient.current_hp = 0
	for instance: DigimonInstance in [patient, party_member, reserve_member, storage_member]:
		collection.add_instance(instance, instance.species_seed, "Digimon")
	assert(collection.set_squad_ids([patient.id, party_member.id], [reserve_member.id], 1, 3, 3), "Save fixture must configure Squad")
	var admission := hospital.admit(collection, patient, max_hp, 11000)
	assert(admission.get("success", false), "Save test patient must be admitted")
	var return_slots := collection.to_dict().get("hospitalReturnSlots", {}) as Dictionary
	var return_slot := return_slots.get(patient.id, {}) as Dictionary
	assert(String(return_slot.get("role", "")) == PlayerCollection.SQUAD_ROLE_ACTIVE and int(return_slot.get("index", -1)) == 0, "Hospital save data must remember exact Squad role and slot")

	var save_service: SaveService = SaveServiceScript.new()
	save_service.delete_save(TEST_SAVE_PATH)
	assert(save_service.save_collection(collection, TEST_SAVE_PATH), "Hospital Squad locations must be saveable atomically")
	var loaded := save_service.load_collection(TEST_SAVE_PATH)
	assert(loaded != null, "Hospital save must load")
	assert(loaded.get_location(patient.id) == PlayerCollection.LOCATION_HOSPITAL, "Save/load must preserve Hospital location")
	assert(loaded.get_squad_role(party_member.id) == PlayerCollection.SQUAD_ROLE_ACTIVE, "Save/load must preserve Active role")
	assert(loaded.get_squad_role(reserve_member.id) == PlayerCollection.SQUAD_ROLE_RESERVE, "Save/load must preserve Reserve role")
	assert(loaded.get_location(storage_member.id) == PlayerCollection.LOCATION_STORAGE, "Save/load must preserve Storage")
	var loaded_slots := loaded.to_dict().get("hospitalReturnSlots", {}) as Dictionary
	assert(String((loaded_slots.get(patient.id, {}) as Dictionary).get("role", "")) == PlayerCollection.SQUAD_ROLE_ACTIVE, "Save/load must preserve Hospital return role")
	assert(loaded.get_instance(patient.id).has_hospital_recovery(), "Save/load must preserve Hospital timestamps")
	assert(loaded.location_invariant_error().is_empty(), "Loaded save must preserve exclusive UUID locations")
	assert(save_service.delete_save(TEST_SAVE_PATH), "Hospital regression save must be removable")

func _test_overworld_battle_gate_and_runtime_roster() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests()
	var initial_ids := OverworldState.get_active_party_ids()
	assert(not initial_ids.is_empty(), "Starter Party is required for battle gate regression")
	var active_instances := OverworldState.get_active_instances()
	for instance: DigimonInstance in active_instances:
		instance.current_hp = 0
	assert(OverworldState.get_active_party_ids() == initial_ids, "Fainted Digimon must remain assigned to the active Party")
	assert(OverworldState.get_battle_ready_active_instances().is_empty(), "Fainted Party members must be excluded from the deployable battle roster")
	assert(OverworldState.battle_party_validation_error(11999) == "You need at least one available Digimon in your party to start a battle.", "An all-fainted Party must block battle before transition")
	active_instances[0].current_hp = 1
	assert(OverworldState.get_battle_ready_active_instances() == [active_instances[0]], "Healthy Party members must remain deployable when teammates are fainted")
	assert(OverworldState.battle_party_validation_error(11999).is_empty(), "A mixed Party must battle using only available members")
	active_instances[0].current_hp = 0
	var hospitalized_ids: Array[String] = []
	while not OverworldState.get_active_instances().is_empty():
		var patient := OverworldState.get_active_instances()[0]
		patient.current_hp = 0
		var admission := OverworldState.admit_to_hospital(patient.id, 12000)
		assert(admission.get("success", false), "Every current Party member must be admissible while injured")
		hospitalized_ids.append(patient.id)
		assert(not OverworldState.get_active_party_ids().has(patient.id), "Hospitalized UUID must disappear from battle Party immediately")
	assert(OverworldState.get_active_party_ids().is_empty(), "Admitting every member must leave the Party empty")
	assert(OverworldState.battle_party_validation_error(12001) == "You need at least one available Digimon in your party to start a battle.", "Empty Party must block battle before transition with clear copy")
	for hospital_id: String in hospitalized_ids:
		assert(OverworldState.get_hospital_ids().has(hospital_id), "Hospitalized UUID must remain outside the battle runtime roster")

	var first_id := hospitalized_ids[0]
	var preview := OverworldState.get_hospital_preview(first_id, 12001)
	var completes_at := int(preview.get("completes_at", 0))
	OverworldState.process_hospital_recoveries(completes_at)
	var discharge := OverworldState.discharge_from_hospital(first_id, completes_at)
	assert(discharge.get("success", false) and String(discharge.get("destination", "")) == PlayerCollection.LOCATION_PARTY, "Recovered first patient must be dischargeable back to Party")
	assert(OverworldState.battle_party_validation_error(completes_at).is_empty(), "A valid non-empty Party must pass battle validation")
	assert(OverworldState.get_active_party_ids() == [first_id], "Battle roster must contain only actual Party UUIDs")
	OverworldState.reset_progress_for_tests()


func _test_pre_squad_saves_are_rejected(factory: DigimonFactory) -> void:
	var legacy := factory.create_player_by_name("agumon", 5, 100)
	var migration := MigrationScript.new()
	var old_v6 := {
		"save_version": 6,
		"collection": {
			"instances": [{"collectionKey": "agumon", "instance": legacy.to_dict()}],
			"activePartyIds": [legacy.id],
		},
	}
	assert(migration.migrate(old_v6).is_empty(), "Pre-Squad v6 saves must be intentionally rejected")
	var fake_v1_without_format := {
		"save_version": 1,
		"collection": {
			"instances": [{"collectionKey": "agumon", "instance": legacy.to_dict()}],
			"activePartyIds": [legacy.id],
		},
	}
	assert(migration.migrate(fake_v1_without_format).is_empty(), "Old data cannot masquerade as Squad v1 without the format marker")

