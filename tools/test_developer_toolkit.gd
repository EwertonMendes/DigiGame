extends Node

const ProgressionToolsScript = preload("res://src/debug/DebugProgressionTools.gd")
const StateToolsScript = preload("res://src/debug/DebugStateTools.gd")
const RosterToolsScript = preload("res://src/debug/DebugRosterTools.gd")
const AccessScript = preload("res://src/debug/DebugToolkitAccess.gd")

func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)

	assert(not AccessScript.is_available(), "Developer toolkit must stay unavailable in headless validation")
	var progression := ProgressionToolsScript.new() as DebugProgressionTools
	var state := StateToolsScript.new() as DebugStateTools
	var roster := RosterToolsScript.new() as DebugRosterTools
	var party := OverworldState.get_active_instances()
	assert(not party.is_empty(), "Debug regression requires the normal starter party")
	var selected: DigimonInstance = party[0]
	var original_id := selected.id

	assert(progression.set_level(original_id, 7), "Debug level setter must work")
	assert(selected.level == 7 and selected.exp == 0, "Setting a level must normalize XP")
	assert(progression.set_exp(original_id, 77) and selected.exp == 77, "Exact XP editing must persist")
	var xp_result := progression.add_xp(original_id, 500)
	assert(not xp_result.is_empty(), "Debug XP must go through the real progression service")
	assert(progression.set_potential(original_id, 42) and selected.potential == 42, "Potential editing must persist on the individual")
	assert(progression.set_link(original_id, 37) and selected.link == 37, "Link editing must persist on the individual")
	assert(progression.set_training(original_id, {"atk": 25, "speed": 11, "mov": 2}), "Exact training editing must work")
	assert(int(selected.training.get("atk", 0)) == 25 and int(selected.training.get("mov", 0)) == 2, "Training edits must persist")
	assert(progression.set_critical(original_id), "Critical-resource preset must apply")
	assert(selected.current_hp == 1 and selected.current_mp == 0, "Critical preset must set deterministic resources")
	assert(progression.heal(original_id), "Heal must use calculated form resources")
	var stats := progression.final_stats(original_id)
	assert(selected.current_hp == int(stats.get("hp", -1)), "Heal must refill current HP to calculated HP")
	assert(selected.current_mp == int(stats.get("mp", -1)), "Heal must refill current SP to calculated SP")
	assert(progression.set_resources(original_id, 2, 3), "Exact HP/SP editing must work")
	assert(selected.current_hp == 2 and selected.current_mp == mini(3, int(stats.get("mp", 0))), "Exact HP/SP must clamp to calculated maxima")
	assert(progression.set_knocked_out(original_id), "Knock-out preset must work")
	assert(selected.current_hp == 0 and selected.current_mp == 0, "Knock-out preset must clear resources")

	state.set_bits(12345)
	assert(OverworldState.get_bits() == 12345, "Debug Bits editing must reach persistent account state")
	assert(state.set_digi_data(selected.species_seed, 177), "Debug Digi Data editing must resolve canonical species")
	assert(OverworldState.get_digi_data_for(selected.species_seed) == 177, "Debug Digi Data value must be exact")
	assert(state.set_flag("debug_regression_flag", true), "Debug flag editing must accept a non-empty id")
	assert(bool(state.progression_flags().get("debug_regression_flag", false)), "Debug flag must be visible in persistent progression flags")

	var catalog := roster.catalog()
	assert(catalog.size() > 100, "Visual debug picker must receive the canonical species catalog")
	var metalgreymon := roster.database.get_by_name("Metal Greymon")
	assert(not metalgreymon.is_empty(), "Storage spawn regression requires Metal Greymon")
	var spawned := roster.create_storage_instance({
		"species_seed": String(metalgreymon.get("seed", "")),
		"level": 35,
		"exp": 123,
		"potential": 64,
		"link": 72,
		"resource_state": "critical",
	})
	assert(spawned != null, "Debug roster tool must create any canonical Digimon directly in Storage")
	assert(spawned.level == 35 and spawned.exp == 123 and spawned.potential == 64 and spawned.link == 72, "Spawned Storage Digimon must keep the requested state")
	assert(spawned.current_hp == 1 and spawned.current_mp == 0, "Spawned Storage Digimon must honor resource presets")
	assert(not OverworldState.get_active_party_ids().has(spawned.id), "Debug-created Digimon must start in Storage rather than silently replacing the party")

	var mixed_enemy_team: Array[Dictionary] = []
	for entry in [["Agumon", 5, "wild"], ["Gabumon", 9, "trained"], ["Veemon", 12, "elite"], ["Greymon", 20, "boss"]]:
		var species := roster.database.get_by_name(String(entry[0]))
		var descriptor := roster.make_enemy_descriptor(String(species.get("seed", "")), int(entry[1]), String(entry[2]))
		assert(not descriptor.is_empty(), "Battle roster descriptor must resolve a selected species")
		mixed_enemy_team.append(descriptor)
	assert(mixed_enemy_team.size() == 4, "Battle sandbox must support mixed teams larger than three")
	assert(String(mixed_enemy_team[0].get("species_seed", "")) != String(mixed_enemy_team[1].get("species_seed", "")), "Battle sandbox rows must be independently configurable")

	assert(state.capture_snapshot("Regression Snapshot"), "Debug snapshot must serialize the current collection")
	var snapshot_level := selected.level
	assert(progression.set_level(original_id, 20), "State must be mutable after snapshot")
	assert(state.restore_snapshot("Regression Snapshot"), "Snapshot must restore a valid collection")
	selected = OverworldState.get_instance_by_id(original_id)
	assert(selected != null, "Snapshot restore must preserve individual UUIDs")
	assert(selected.level == snapshot_level, "Snapshot restore must restore the captured level")
	assert(OverworldState.get_bits() == 12345, "Snapshot restore must include account state")
	assert(state.delete_snapshot("Regression Snapshot"), "Regression snapshot should be removable")

	var routes := progression.routes(original_id, false)
	assert(not routes.is_empty(), "Starter Digimon should expose graph evolution routes")
	var first_route: Dictionary = routes[0]
	var target_seed := String(first_route.get("targetSeed", ""))
	assert(not target_seed.is_empty(), "Evolution route must have a target seed")
	assert(progression.set_level(original_id, 1), "Evolution test should begin from a deliberately blocked level")
	var prepared := progression.meet_requirements(original_id, target_seed, false)
	assert(bool(prepared.get("success", false)), "Meet Requirements should prepare the first real evolution route")
	assert(progression.transition(original_id, target_seed, false, false), "Prepared evolution must execute through the normal service")
	selected = OverworldState.get_instance_by_id(original_id)
	assert(selected != null and selected.species_seed == target_seed, "Normal debug transition must keep UUID and apply target form")
	assert(selected.level == 1 and selected.exp == 0, "Debug-triggered real evolution must preserve level-reset invariant")

	OverworldState.reset_progress_for_tests(false)
	selected = OverworldState.get_active_instances()[0]
	var force_routes := progression.routes(selected.id, false)
	assert(not force_routes.is_empty(), "Force-transition test requires a real graph edge")
	var force_target := String(force_routes[0].get("targetSeed", ""))
	assert(selected.level == 1, "Force-transition test must start below normal requirements")
	assert(progression.transition(selected.id, force_target, false, true), "Force transition should bypass requirements for a valid graph edge")
	var forced := OverworldState.get_instance_by_id(selected.id)
	assert(forced.species_seed == force_target, "Force transition must still execute the real transition pipeline")
	assert(forced.level == 1 and forced.exp == 0, "Forced debug transition must keep evolution reset invariants")

	print("developer toolkit regression passed")
	get_tree().quit()
