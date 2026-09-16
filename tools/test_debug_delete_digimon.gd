extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const CollectionToolsScript = preload("res://src/debug/DebugCollectionTools.gd")


func _ready() -> void:
	_test_collection_removal_cleans_every_location()
	_test_debug_tool_deletes_persistent_player_instances()
	print("debug delete Digimon regression passed")
	get_tree().quit()


func _test_collection_removal_cleans_every_location() -> void:
	var database: DigimonDatabase = DatabaseScript.new()
	assert(database.load_default(), "Delete Digimon regression requires the Digimon database")
	var factory: DigimonFactory = FactoryScript.new(database)
	var collection: PlayerCollection = CollectionScript.new()
	var party_member := factory.create_player_by_name("agumon", 5, 100)
	var patient := factory.create_player_by_name("gabumon", 5, 100)
	var reserve := factory.create_player_by_name("veemon", 5, 100)
	collection.add_instance(party_member, "agumon", "Agumon")
	collection.add_instance(patient, "gabumon", "Gabumon")
	collection.add_instance(reserve, "veemon", "Veemon")
	assert(collection.set_active_party_ids([party_member.id, patient.id], 1, 6), "Delete regression must configure Party")
	assert(collection.admit_to_hospital(patient.id), "Delete regression must configure Hospital")

	var reserve_key := collection.get_key_for_instance(reserve.id)
	assert(collection.remove_instance(reserve.id), "Storage Digimon must be removable")
	assert(collection.get_instance(reserve.id) == null, "Removed Storage UUID must leave the instance index")
	assert(collection.get_instance_by_key(reserve_key) == null, "Removed Storage UUID must leave the collection-key index")
	assert(not collection.get_reserve_instances().has(reserve), "Removed Storage Digimon must not remain in reserve results")

	assert(collection.remove_instance(patient.id), "Hospital Digimon must be removable")
	assert(collection.get_instance(patient.id) == null, "Removed Hospital UUID must leave the instance index")
	assert(not collection.get_hospital_ids().has(patient.id), "Removed Hospital UUID must leave Hospital membership")

	assert(collection.remove_instance(party_member.id), "Party Digimon must be removable")
	assert(collection.get_instance(party_member.id) == null, "Removed Party UUID must leave the instance index")
	assert(not collection.get_active_party_ids().has(party_member.id), "Removed Party UUID must leave Party membership")
	assert(collection.is_empty(), "Removing every test instance must leave the standalone collection empty")
	assert(collection.location_invariant_error().is_empty(), "Deletion must preserve collection location invariants")


func _test_debug_tool_deletes_persistent_player_instances() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)
	var tools: DebugCollectionTools = CollectionToolsScript.new() as DebugCollectionTools
	var initial_instances := OverworldState.get_collection_instances()
	assert(initial_instances.size() >= 2, "Debug delete regression requires at least two starter Digimon")

	var first_id := initial_instances[0].id
	var first_location := OverworldState.get_collection_location(first_id)
	var first_result := tools.delete_instance(first_id)
	assert(first_result.get("success", false), "Debug tool must delete an owned Digimon")
	assert(String(first_result.get("previous_location", "")) == first_location, "Debug tool must report the deleted Digimon's previous location")
	assert(OverworldState.get_instance_by_id(first_id) == null, "Deleted UUID must disappear from OverworldState")
	assert(not OverworldState.get_active_party_ids().has(first_id), "Deleted UUID must not remain in Party")
	assert(not OverworldState.get_hospital_ids().has(first_id), "Deleted UUID must not remain in Hospital")

	while OverworldState.get_collection_instances().size() > 1:
		var candidate := OverworldState.get_collection_instances()[0]
		var result := tools.delete_instance(candidate.id)
		assert(result.get("success", false), "Debug cleanup must continue deleting until one owned Digimon remains")

	var last_instance := OverworldState.get_collection_instances()[0]
	var blocked := tools.delete_instance(last_instance.id)
	assert(not blocked.get("success", true), "Deleting the final owned Digimon must be blocked")
	assert(String(blocked.get("reason", "")) == "last_owned_digimon", "Final Digimon protection must return an explicit reason")
	assert(OverworldState.get_instance_by_id(last_instance.id) != null, "Blocked final deletion must not mutate player data")

	OverworldState.reset_progress_for_tests(false)
