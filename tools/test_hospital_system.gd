extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const HospitalCalculatorScript = preload("res://src/hospital/HospitalRecoveryCalculator.gd")
const HospitalServiceScript = preload("res://src/hospital/HospitalService.gd")
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
	_test_admission_and_offline_completion(database, factory, stats, hospital)
	_test_instant_recovery_transaction(database, factory, stats, hospital)
	_test_individual_identity_and_save(database, factory, stats, hospital)
	_test_overworld_battle_gate()
	_test_v4_migration(factory)

	print("hospital system regression passed")
	get_tree().quit()


func _test_derived_health_and_scaling(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, calculator: HospitalRecoveryCalculator, hospital: HospitalService) -> void:
	var injured := factory.create_player_by_name("agumon", 12, 100)
	var critical := factory.create_player_by_name("agumon", 12, 100)
	var species := database.get_by_seed(injured.species_seed)
	var max_hp := stats.get_stat(injured, species, "hp")
	injured.current_hp = int(round(float(max_hp) * 0.6))
	critical.current_hp = 0
	assert(hospital.status_for(injured, max_hp, 1000) == "injured", "Partial HP must derive the Injured state")
	assert(hospital.status_for(critical, max_hp, 1000) == "critical", "Zero HP outside battle must derive Critical")
	assert(calculator.instant_cost(critical, max_hp) > calculator.instant_cost(injured, max_hp), "Instant cost must increase with missing HP")
	assert(calculator.recovery_seconds(critical, max_hp) > calculator.recovery_seconds(injured, max_hp), "Recovery time must increase with missing HP")
	injured.current_hp = max_hp
	var healthy_preview := hospital.preview(injured, max_hp, 9999, 1000)
	assert(String(healthy_preview.get("status", "")) == "healthy", "Full HP must derive Healthy")
	assert(not bool(healthy_preview.get("can_admit", true)) and int(healthy_preview.get("instant_cost", -1)) == 0, "Healthy Digimon must not expose treatment")
	var serialized := critical.to_dict()
	assert(not serialized.has("dead") and not serialized.has("isDead") and not serialized.has("critical"), "Health must not create persistent death or condition flags")


func _test_admission_and_offline_completion(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, hospital: HospitalService) -> void:
	var patient := factory.create_player_by_name("gabumon", 8, 100)
	var species := database.get_by_seed(patient.species_seed)
	var max_hp := stats.get_stat(patient, species, "hp")
	patient.current_hp = 0
	var admission := hospital.admit(patient, max_hp, 5000)
	assert(bool(admission.get("success", false)), "Critical Digimon must be admissible")
	var completes_at := int(admission.get("completes_at", 0))
	assert(patient.has_hospital_recovery() and completes_at > 5000, "Admission must persist a valid recovery interval")
	assert(hospital.status_for(patient, max_hp, 5001) == "recovering", "An admitted Digimon must derive Recovering")
	assert(not hospital.battle_eligibility_error(patient, max_hp, "Gabumon", 5001).is_empty(), "Recovering Digimon must be rejected by the battle domain")
	assert(not hospital.complete_if_ready(patient, max_hp, completes_at - 1), "Recovery must not complete before its timestamp")
	assert(hospital.complete_if_ready(patient, max_hp, completes_at), "Recovery must complete at its timestamp")
	assert(patient.current_hp == max_hp and not patient.has_hospital_recovery(), "Completion must restore full HP and remove the recovery interval")
	assert(not hospital.complete_if_ready(patient, max_hp, completes_at + 1), "Repeated completion processing must be idempotent")
	assert(hospital.battle_eligibility_error(patient, max_hp, "Gabumon", completes_at + 1).is_empty(), "Recovered Digimon must become battle eligible")


func _test_instant_recovery_transaction(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, hospital: HospitalService) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var patient := factory.create_player_by_name("veemon", 15, 100)
	var species := database.get_by_seed(patient.species_seed)
	var max_hp := stats.get_stat(patient, species, "hp")
	patient.current_hp = 1
	collection.add_instance(patient, "veemon", "Veemon")
	collection.bits = 10000
	var expected_cost := int(hospital.preview(patient, max_hp, collection.bits, 1000).get("instant_cost", 0))
	var before_bits := collection.bits
	var result := hospital.recover_now(collection, patient, max_hp)
	assert(bool(result.get("success", false)) and int(result.get("bits_spent", 0)) == expected_cost, "Immediate recovery must use the centralized preview cost")
	assert(collection.bits == before_bits - expected_cost and patient.current_hp == max_hp, "Immediate recovery must atomically deduct Bits and restore HP")

	patient.current_hp = 0
	collection.bits = 0
	var failed := hospital.recover_now(collection, patient, max_hp)
	assert(not bool(failed.get("success", true)) and String(failed.get("reason", "")) == "insufficient_bits", "Insufficient Bits must reject immediate recovery")
	assert(collection.bits == 0 and patient.current_hp == 0, "A rejected transaction must not mutate Bits or HP")


func _test_individual_identity_and_save(database: DigimonDatabase, factory: DigimonFactory, stats: DigimonStatCalculator, hospital: HospitalService) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var first := factory.create_player_by_name("agumon", 7, 100)
	var second := factory.create_player_by_name("agumon", 7, 100)
	var species := database.get_by_seed(first.species_seed)
	var max_hp := stats.get_stat(first, species, "hp")
	first.current_hp = 0
	second.current_hp = max_hp
	collection.add_instance(first, "agumon", "Agumon")
	collection.add_instance(second, "agumon", "Agumon")
	var admission := hospital.admit(first, max_hp, 7000)
	assert(bool(admission.get("success", false)), "The first same-species individual must be admissible")
	assert(first.has_hospital_recovery() and not second.has_hospital_recovery(), "Hospital state must belong to the individual UUID, not the species")

	var save_service: SaveService = SaveServiceScript.new()
	save_service.delete_save(TEST_SAVE_PATH)
	assert(save_service.save_collection(collection, TEST_SAVE_PATH), "Hospital recovery must be saveable")
	var loaded := save_service.load_collection(TEST_SAVE_PATH)
	assert(loaded != null, "Hospital save must load")
	var loaded_first := loaded.get_instance(first.id)
	var loaded_second := loaded.get_instance(second.id)
	assert(loaded_first != null and loaded_first.has_hospital_recovery(), "Save/load must preserve the admitted individual's timestamps")
	assert(loaded_second != null and not loaded_second.has_hospital_recovery(), "Save/load must not spread recovery to another same-species individual")
	assert(save_service.delete_save(TEST_SAVE_PATH), "Hospital regression save must be removable")


func _test_overworld_battle_gate() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests()
	var patient := OverworldState.get_active_instances()[0]
	patient.current_hp = 0
	assert("critical condition" in OverworldState.battle_party_validation_error(9000), "The battle domain must reject a critical active-party member")
	var admission := OverworldState.admit_to_hospital(patient.id, 9000)
	assert(bool(admission.get("success", false)), "The Overworld facade must admit a critical active-party member")
	assert("still recovering" in OverworldState.battle_party_validation_error(9001), "The battle domain must reject an admitted active-party member")
	var completes_at := int(admission.get("completes_at", 0))
	var completed := OverworldState.process_hospital_recoveries(completes_at)
	assert(completed == [patient.id], "Offline completion must identify the recovered individual exactly once")
	assert(OverworldState.battle_party_validation_error(completes_at).is_empty(), "A completed recovery must restore battle eligibility")
	OverworldState.reset_progress_for_tests()


func _test_v4_migration(factory: DigimonFactory) -> void:
	var legacy := factory.create_player_by_name("agumon", 5, 100).to_dict()
	legacy.erase("hospitalRecovery")
	var raw := {
		"save_version": 4,
		"collection": {
			"instances": [{"collectionKey": "agumon", "instance": legacy}],
			"activePartyIds": [String(legacy.get("id", ""))],
		}
	}
	var migrated := MigrationScript.new().migrate(raw)
	assert(int(migrated.get("save_version", 0)) == 5, "v4 saves must migrate to the Hospital-aware v5 schema")
	var entries := ((migrated.get("collection", {}) as Dictionary).get("instances", []) as Array)
	var migrated_instance := (entries[0] as Dictionary).get("instance", {}) as Dictionary
	assert(migrated_instance.get("hospitalRecovery", {}) is Dictionary and (migrated_instance.get("hospitalRecovery", {}) as Dictionary).is_empty(), "Existing individuals must migrate with no active recovery")
