extends Node

const ProgressionToolsScript = preload("res://src/debug/DebugProgressionTools.gd")
const StateToolsScript = preload("res://src/debug/DebugStateTools.gd")
const RosterToolsScript = preload("res://src/debug/DebugRosterTools.gd")
const TechniqueToolsScript = preload("res://src/debug/DebugTechniqueTools.gd")
const AccessScript = preload("res://src/debug/DebugToolkitAccess.gd")

func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)

	assert(not AccessScript.is_available(), "Developer toolkit must stay unavailable in headless validation")
	var progression := ProgressionToolsScript.new() as DebugProgressionTools
	var state := StateToolsScript.new() as DebugStateTools
	var roster := RosterToolsScript.new() as DebugRosterTools
	var techniques := TechniqueToolsScript.new() as DebugTechniqueTools
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
	assert(progression.tier_options() == ["E", "D", "C", "B", "A", "S", "SS", "SSS"], "F2 must expose every canonical Tier")
	assert(progression.set_tier_and_expansion(original_id, "S", true, true), "F2 exact state must be able to prepare an expanded Tier S Digimon")
	assert(selected.tier == "S" and selected.expansion_unlocked and selected.is_expanded(), "F2 Tier and Expansion state must persist on the selected individual")
	assert(progression.set_tier_and_expansion(original_id, "A", false, false), "F2 exact state must also reset Tier and footprint deterministically")
	assert(selected.tier == "A" and not selected.expansion_unlocked and not selected.is_expanded(), "F2 exact state must support locked 1x1 states")
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

	var technique_catalog := techniques.catalog(true)
	assert(technique_catalog.size() > 1000, "Skill lab must expose the complete technique catalog")
	var test_skill_id := ""
	for action: Dictionary in technique_catalog:
		var candidate := String(action.get("id", ""))
		if String(action.get("availability", "ready")) == "ready" and not selected.learned_skills.has(candidate):
			test_skill_id = candidate
			break
	assert(not test_skill_id.is_empty(), "Skill lab regression requires an unlearned battle-ready technique")
	assert(techniques.learn(original_id, test_skill_id, false), "Skill lab must be able to grant any catalog technique")
	assert(selected.learned_skills.has(test_skill_id) and not selected.favorite_skills.has(test_skill_id), "Debug-granted technique must enter the permanent library without silently becoming a favorite")
	assert(techniques.set_favorite(original_id, test_skill_id, true), "Skill lab must toggle favorites")
	assert(selected.favorite_skills.has(test_skill_id), "Favorite mutation must persist on the selected individual")
	assert(techniques.set_mastery(original_id, test_skill_id, DigimonInstance.EXPERIENCED_SKILL_MASTERY_POINTS), "Skill lab must edit mastery")
	assert(selected.get_skill_mastery_grade(test_skill_id) == "experienced", "Experienced mastery threshold must be reachable from debug tools")
	assert(techniques.set_mastery(original_id, test_skill_id, DigimonInstance.MAX_SKILL_MASTERY_POINTS), "Skill lab must reach mastered state")
	assert(selected.get_skill_mastery_grade(test_skill_id) == "mastered", "Mastered mastery threshold must be reflected by the real DigimonInstance")
	var mastered_action := techniques.action(test_skill_id, original_id)
	assert(String(mastered_action.get("masteryGrade", "")) == "mastered", "Skill lab preview must use mastery-adjusted action data")
	assert(techniques.set_archived(original_id, test_skill_id, true), "Skill lab must archive learned techniques")
	assert(selected.archived_skills.has(test_skill_id) and not selected.favorite_skills.has(test_skill_id), "Archiving through debug tools must preserve normal archive invariants")
	assert(techniques.set_archived(original_id, test_skill_id, false), "Skill lab must restore archived techniques")
	assert(not selected.archived_skills.has(test_skill_id), "Restored debug technique must leave the archive")
	assert(techniques.forget(original_id, test_skill_id), "Skill lab must support deliberately forgetting a technique for test setup")
	assert(not selected.learned_skills.has(test_skill_id) and not selected.skill_mastery.has(test_skill_id), "Forgetting through debug tools must remove organization and mastery state atomically")
	assert(not techniques.set_mastery(original_id, test_skill_id, 24), "Skill lab must not assign mastery to a technique the Digimon does not know")
	var form_learnset := techniques.current_form_learnset(original_id)
	assert(not form_learnset.is_empty(), "Skill lab must expose the current form learnset for comparison while testing")

	state.set_bits(50000)
	assert(progression.grant_expansion_core(1) == 1, "F2 Account tools must grant Expansion Cores")
	assert(progression.grant_expansion_fragments(5) == 5, "F2 Account tools must grant Expansion Fragments")
	var craft_result := progression.craft_expansion_core()
	assert(bool(craft_result.get("success", false)), "F2 must exercise the real Fragment + Bits Core recipe")
	assert(progression.get_item_count("expansion_core") == 2 and progression.get_item_count("expansion_fragment") == 0, "F2 item controls must reflect the persistent inventory after crafting")
	assert(OverworldState.get_bits() == 0, "Core crafting through F2 must consume the real 50,000 Bits cost")

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
		"tier": "SS",
		"expansion_unlocked": true,
		"footprint": "large_2x2",
		"resource_state": "critical",
	})
	assert(spawned != null, "Debug roster tool must create any canonical Digimon directly in Storage")
	assert(spawned.level == 35 and spawned.exp == 123 and spawned.potential == 64 and spawned.link == 72, "Spawned Storage Digimon must keep the requested state")
	assert(spawned.tier == "SS" and spawned.expansion_unlocked and spawned.is_expanded(), "Storage spawn must expose Tier and 2x2 Expansion setup")
	assert(spawned.current_hp == 1 and spawned.current_mp == 0, "Spawned Storage Digimon must honor resource presets")
	assert(not OverworldState.get_active_party_ids().has(spawned.id), "Debug-created Digimon must start in Storage rather than silently replacing the party")

	var mixed_enemy_team: Array[Dictionary] = []
	var enemy_rows := [["Agumon", 5, "wild", "E", "single"], ["Gabumon", 9, "trained", "C", "single"], ["Veemon", 12, "elite", "S", "large_2x2"], ["Greymon", 20, "boss", "SSS", "large_2x2"]]
	for entry in enemy_rows:
		var species := roster.database.get_by_name(String(entry[0]))
		var descriptor := roster.make_enemy_descriptor(String(species.get("seed", "")), int(entry[1]), String(entry[2]), String(entry[3]), String(entry[4]))
		assert(not descriptor.is_empty(), "Battle roster descriptor must resolve a selected species")
		mixed_enemy_team.append(descriptor)
	assert(mixed_enemy_team.size() == 4, "Battle sandbox must support mixed teams larger than three")
	assert(String(mixed_enemy_team[0].get("species_seed", "")) != String(mixed_enemy_team[1].get("species_seed", "")), "Battle sandbox rows must be independently configurable")
	assert(String(mixed_enemy_team[2].get("tier", "")) == "S" and String(mixed_enemy_team[2].get("footprint", "")) == "large_2x2", "Battle sandbox must preserve per-enemy Tier and footprint")

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