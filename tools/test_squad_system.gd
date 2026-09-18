extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const PartyServiceScript = preload("res://src/collection/PartyService.gd")
const MigrationScript = preload("res://src/save/SaveMigration.gd")


func _ready() -> void:
	var database: DigimonDatabase = DatabaseScript.new()
	assert(database.load_default(), "Squad regression requires the Digimon database")
	var factory: DigimonFactory = FactoryScript.new(database)
	var collection: PlayerCollection = CollectionScript.new()
	var party: PartyService = PartyServiceScript.new()

	var owned: Array[DigimonInstance] = []
	for species_name: String in ["agumon", "gabumon", "veemon", "agumon", "gabumon", "veemon", "agumon"]:
		var instance := factory.create_player_by_name(species_name, 5, 100)
		assert(instance != null, "Squad regression species must resolve: %s" % species_name)
		collection.add_instance(instance, "%s_%d" % [species_name, owned.size()], species_name)
		owned.append(instance)

	var active: Array[String] = [owned[0].id, owned[1].id, owned[2].id]
	var reserve: Array[String] = [owned[3].id, owned[4].id, owned[5].id]
	assert(party.set_squad(collection, active, reserve), "3 Active + 3 Reserve must be a valid Squad")
	assert(collection.get_active_party_ids() == active, "Active slot order must be stable")
	assert(collection.get_reserve_party_ids() == reserve, "Reserve slot order must be stable")
	assert(collection.get_storage_instances().size() == 1 and collection.get_storage_instances()[0].id == owned[6].id, "The seventh Digimon must remain in Storage")
	assert(collection.get_squad_role(owned[0].id) == PlayerCollection.SQUAD_ROLE_ACTIVE, "Active role must be explicit")
	assert(collection.get_squad_role(owned[3].id) == PlayerCollection.SQUAD_ROLE_RESERVE, "Reserve role must be explicit")
	assert(collection.get_location(owned[3].id) == PlayerCollection.LOCATION_PARTY, "Reserve is part of the Squad location, not Storage")
	assert(not party.add_to_active(collection, owned[6].id), "A fourth Active member must be rejected")
	assert(not party.add_to_reserve(collection, owned[6].id), "A fourth Reserve member must be rejected")

	# Assigning a Storage Digimon into a filled Reserve slot displaces that exact
	# occupant to Storage; no hidden auto-promotion/reordering is allowed.
	assert(party.assign_to_slot(collection, owned[6].id, PlayerCollection.SQUAD_ROLE_RESERVE, 1), "Storage Digimon must be assignable to an explicit Reserve slot")
	assert(collection.get_reserve_party_ids()[1] == owned[6].id, "Selected Reserve slot must receive the selected Digimon")
	assert(collection.get_location(owned[4].id) == PlayerCollection.LOCATION_STORAGE, "Displaced Reserve member must move to Storage")
	assert(collection.location_invariant_error().is_empty(), "Squad slot assignment must preserve location invariants")

	# Cross-role assignment swaps exact slots so a full 3+3 Squad never loses a
	# member or silently sends the opposite role to Storage.
	var active_zero := collection.get_active_party_ids()[0]
	var reserve_zero := collection.get_reserve_party_ids()[0]
	assert(party.assign_to_slot(collection, reserve_zero, PlayerCollection.SQUAD_ROLE_ACTIVE, 0), "Reserve must be promotable into a filled Active slot")
	assert(collection.get_active_party_ids()[0] == reserve_zero, "Promoted Reserve must occupy the selected Active slot")
	assert(collection.get_reserve_party_ids()[0] == active_zero, "Displaced Active must occupy the source Reserve slot")
	assert(collection.location_invariant_error().is_empty(), "Cross-role swap must preserve location invariants")

	var payload := collection.to_dict()
	assert((payload.get("activeSquadIds", []) as Array).size() == 3, "Squad save payload must write Active IDs")
	assert((payload.get("reserveSquadIds", []) as Array).size() == 3, "Squad save payload must write Reserve IDs")
	assert(not payload.has("activePartyIds"), "Squad v1 must not write the prototype activePartyIds field")

	var restored: PlayerCollection = CollectionScript.new()
	restored.load_dict(payload)
	assert(restored.get_active_party_ids() == collection.get_active_party_ids(), "Collection round-trip must preserve Active order")
	assert(restored.get_reserve_party_ids() == collection.get_reserve_party_ids(), "Collection round-trip must preserve Reserve order")
	assert(restored.get_storage_instances().size() == 1, "Collection round-trip must preserve Storage separation")
	assert(restored.location_invariant_error().is_empty(), "Restored Squad must satisfy location invariants")

	var migration: SaveMigration = MigrationScript.new()
	var normalized := migration.migrate({
		"save_version": 1,
		"save_format": "squad-v1",
		"collection": payload,
	})
	assert(not normalized.is_empty(), "Current Squad v1 save contract must be accepted")
	assert(migration.migrate({"save_version": 6, "collection": payload}).is_empty(), "Prototype v6 saves must be invalid after the reset")
	assert(migration.migrate({"save_version": 1, "collection": payload}).is_empty(), "A pre-Squad payload without the format marker must not masquerade as v1")

	print("squad system regression passed")
	get_tree().quit()
