extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const ProgressionScript = preload("res://src/digimon/DigimonProgression.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")
const ExperienceCalculatorScript = preload("res://src/digimon/ExperienceCalculator.gd")
const EvolutionServiceScript = preload("res://src/digimon/DigimonEvolutionService.gd")
const EvolutionGraphServiceScript = preload("res://src/digimon/EvolutionGraphService.gd")
const RequirementEvaluatorScript = preload("res://src/digimon/EvolutionRequirementEvaluator.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const TrainingServiceScript = preload("res://src/digimon/DigimonTrainingService.gd")
const RewardServiceScript = preload("res://src/digimon/BattleRewardService.gd")
const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")
const RosterScript = preload("res://src/collection/PlayerRoster.gd")
const PartyServiceScript = preload("res://src/collection/PartyService.gd")
const SaveServiceScript = preload("res://src/save/SaveService.gd")
const MigrationScript = preload("res://src/save/SaveMigration.gd")
const EncounterScript = preload("res://src/world/BattleEncounterDefinition.gd")

const TEST_SAVE_PATH := "user://digigame-progression-regression.json"


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)

	var database = DatabaseScript.new()
	assert(database.load_default(), "Species database must load")
	assert(database.species_count() > 100, "Canonical catalogue must contain the full inherited species set")
	var factory = FactoryScript.new(database)
	var progression = ProgressionServiceScript.new(database)
	var progression_curve = ProgressionScript.new()
	var xp = ExperienceCalculatorScript.new()
	var evolution = EvolutionServiceScript.new()
	var graph_service = EvolutionGraphServiceScript.new()
	var requirements = RequirementEvaluatorScript.new()
	var calculator = StatCalculatorScript.new()
	var reward_service = RewardServiceScript.new(database)
	var balance = BalanceScript.new()
	var party_service = PartyServiceScript.new()

	_test_xp_and_stats(database, factory, progression, progression_curve, calculator, balance)
	_test_rewards(database, factory, xp, reward_service)
	_test_evolution(database, factory, progression, evolution, graph_service, requirements, calculator)
	_test_roster_party_and_save(factory, party_service)
	_test_overworld_digi_data()
	_test_encounter_definition(database)

	print("digimon progression regression passed")
	get_tree().quit()


func _test_xp_and_stats(database, factory, progression, progression_curve, calculator, balance) -> void:
	var agumon: DigimonInstance = factory.create_player_by_name("agumon", 1, 100)
	assert(agumon != null, "Agumon instance must be generated from species data")
	var species: Dictionary = database.get_by_seed(agumon.species_seed)
	for stat_key: String in DigimonInstance.STAT_KEYS:
		agumon.aptitudes[stat_key] = 0
		agumon.training[stat_key] = 0
	var level_one_stats := calculator.get_all_stats(agumon, species)
	assert(level_one_stats == calculator.get_all_stats(agumon, species), "Stat calculation must be deterministic")
	var required := progression.exp_to_next_level(agumon)
	var level_result: Dictionary = progression.apply_experience(agumon, required)
	assert(agumon.level == 2 and int(level_result.get("levels_gained", 0)) == 1, "Exact threshold must level up once")
	assert(agumon.exp == 0, "Exact threshold must not lose or invent overflow")
	assert((level_result.get("stat_deltas", {}) as Dictionary).has("hp"), "Level result must expose stat deltas")

	var multi: DigimonInstance = factory.create_player_by_name("agumon", 1, 100)
	var l1 := progression_curve.exp_to_next_level_for_level(1, species)
	var l2 := progression_curve.exp_to_next_level_for_level(2, species)
	var multi_result := progression.apply_experience(multi, l1 + l2 + 7)
	assert(multi.level == 3 and multi.exp == 7, "One grant must support multiple levels and preserve overflow")
	assert(int(multi_result.get("levels_gained", 0)) == 2, "Multi-level grant must report both levels")

	var capped: DigimonInstance = factory.create_player_by_name("agumon", balance.max_level(), 100)
	capped.exp = 123
	progression.apply_experience(capped, 9999999)
	assert(capped.level == balance.max_level() and capped.exp == 0, "Max-level XP must remain capped")


func _test_rewards(database, factory, xp, reward_service) -> void:
	var enemy: DigimonInstance = factory.create_enemy_by_name("veemon", 5, "wild")
	var species: Dictionary = database.get_by_seed(enemy.species_seed)
	assert(xp.reward_for_enemy(5, 5, species, "wild") > xp.reward_for_enemy(30, 5, species, "wild"), "Overleveled farming must be devalued")
	var players: Array[Dictionary] = [
		{"instance_id": "participant-a", "level": 5, "knocked_out": false},
		{"instance_id": "participant-b", "level": 5, "knocked_out": true},
	]
	var enemies: Array[Dictionary] = [{"species_seed": enemy.species_seed, "level": 5, "profile": "wild", "reward_modifier": 1.0}]
	var rewards: BattleRewards = reward_service.calculate_for_snapshots(players, enemies)
	assert(int(rewards.xp_by_instance.get("participant-a", 0)) > 0, "Participant must receive XP")
	assert(int(rewards.xp_by_instance.get("participant-b", 0)) > 0, "KO participant follows configured XP rule")
	assert(rewards.bits > 0 and int(rewards.digi_data.get(String(species.get("name", "")), 0)) > 0, "Victory must emit Bits and Digi Data")
	var boosted_enemies: Array[Dictionary] = [{"species_seed": enemy.species_seed, "level": 5, "profile": "wild", "reward_modifier": 2.0}]
	var boosted: BattleRewards = reward_service.calculate_for_snapshots(players, boosted_enemies)
	assert(int(boosted.xp_by_instance.get("participant-a", 0)) > int(rewards.xp_by_instance.get("participant-a", 0)), "Encounter modifier must scale XP")
	assert(boosted.bits > rewards.bits, "Encounter modifier must scale economic rewards")


func _test_evolution(database, factory, progression, evolution, graph_service, requirements, calculator) -> void:
	var blocked: DigimonInstance = factory.create_player_by_name("koromon", 1, 100)
	var blocked_routes: Array[Dictionary] = progression.get_evolution_routes(blocked)
	assert(not blocked_routes.is_empty(), "Evolution routes must be visible before unlock")
	var has_locked := false
	for route: Dictionary in blocked_routes:
		if not bool(route.get("unlocked", false)):
			has_locked = true
	assert(has_locked, "Low-level evolution must be blocked")

	var koromon: DigimonInstance = factory.create_player_by_name("koromon", 5, 100)
	koromon.link = 63
	var routes: Array[Dictionary] = progression.get_evolution_routes(koromon)
	var unlocked: Dictionary = {}
	for route: Dictionary in routes:
		if bool(route.get("unlocked", false)):
			unlocked = route
			break
	assert(not unlocked.is_empty(), "Koromon level 5 must have an unlocked route")
	var current_species := database.get_by_seed(koromon.species_seed)
	assert(bool(requirements.evaluate(koromon, current_species, {"type": "link", "value": 50}, calculator).get("is_met", false)), "Link requirement must use persistent instance state")
	assert(not bool(requirements.evaluate(koromon, current_species, {"type": "level", "value": 99}, calculator).get("is_met", true)), "Unmet level requirement must block")

	var original_id := koromon.id
	var original_seed := koromon.species_seed
	var original_link := koromon.link
	var target_seed := String(unlocked.get("targetSeed", ""))
	assert(graph_service.find_shortest_path(original_seed, target_seed, database).size() == 2, "Direct evolution must remain a graph edge")
	assert(evolution.digivolve(koromon, target_seed, database, calculator), "Unlocked evolution must succeed")
	assert(koromon.id == original_id and koromon.species_seed == target_seed, "Evolution must preserve UUID and change species")
	assert(koromon.level == 1 and koromon.exp == 0 and koromon.link == original_link, "Evolution must reset level/XP and preserve Link")
	assert(koromon.species_history.size() >= 2, "Evolution must append species history")
	var stats := calculator.get_all_stats(koromon, database.get_by_seed(target_seed))
	assert(koromon.current_hp == int(stats.get("hp", 0)), "Evolution must recalculate/refill stats")

	var degeneration_routes: Array[Dictionary] = evolution.get_available_degenerations(koromon, database, calculator)
	var degeneration_target := ""
	for route: Dictionary in degeneration_routes:
		if bool(route.get("unlocked", false)):
			degeneration_target = String(route.get("targetSeed", ""))
			break
	assert(not degeneration_target.is_empty(), "Degeneration must be a first-class available route")
	koromon.level = 8
	koromon.exp = 25
	assert(evolution.degenerate(koromon, degeneration_target, database, calculator), "Degeneration must succeed")
	assert(koromon.id == original_id and koromon.level == 1 and koromon.exp == 0, "Degeneration must preserve UUID and reset progression")
	assert(koromon.link == original_link, "Degeneration must preserve Link")

	var training = TrainingServiceScript.new()
	var before_capacity := training.capacity_for(koromon)
	koromon.potential = 20
	assert(training.capacity_for(koromon) > before_capacity, "Potential must increase training capacity")
	assert(training.allocate_stat(koromon, "int", 1), "INT training must remain supported")


func _test_roster_party_and_save(factory, party_service) -> void:
	var roster: PlayerRoster = RosterScript.new()
	var first: DigimonInstance = factory.create_player_by_name("agumon", 4, 100)
	var second: DigimonInstance = factory.create_player_by_name("agumon", 7, 100)
	var third: DigimonInstance = factory.create_player_by_name("gabumon", 6, 100)
	var fourth: DigimonInstance = factory.create_player_by_name("veemon", 5, 100)
	assert(first.id != second.id, "Same-species owned Digimon need unique UUIDs")
	first.exp = 33
	first.link = 42
	roster.add_instance(first, "agumon", "Agumon")
	roster.add_instance(second, "agumon", "Agumon")
	roster.add_instance(third, "gabumon", "Gabumon")
	roster.add_instance(fourth, "veemon", "Veemon")
	var party_ids: Array[String] = [first.id, second.id, third.id]
	assert(party_service.set_party(roster, party_ids), "Valid party must be accepted")
	var duplicates: Array[String] = [first.id, first.id]
	assert(not party_service.set_party(roster, duplicates), "Duplicate instance must be rejected")
	assert(not party_service.add_to_party(roster, fourth.id), "Party limit must be enforced")
	assert(party_service.remove_from_party(roster, third.id) and party_service.add_to_party(roster, fourth.id), "Party remove/add must work")
	assert(roster.get_reserve_instances().size() == 1, "Non-active owned Digimon must stay in Storage")

	roster.bits = 321
	roster.add_digi_data(first.species_seed, 87)
	var save_service = SaveServiceScript.new()
	save_service.delete_save(TEST_SAVE_PATH)
	assert(save_service.save_roster(roster, TEST_SAVE_PATH), "Versioned save must write")
	var loaded: PlayerRoster = save_service.load_roster(TEST_SAVE_PATH)
	assert(loaded != null and loaded.get_instances().size() == roster.get_instances().size(), "Save/load must preserve roster")
	var restored := loaded.get_instance(first.id)
	assert(restored != null and restored.level == first.level and restored.exp == first.exp, "Save/load must preserve level/XP")
	assert(restored.link == first.link, "Save/load must preserve Link")
	assert(loaded.get_digi_data(first.species_seed) == 87 and loaded.bits == 321, "Save/load must preserve rewards")
	assert(loaded.get_active_party_ids() == roster.get_active_party_ids(), "Save/load must preserve party order")
	assert(save_service.delete_save(TEST_SAVE_PATH), "Regression save must be removable")

	var migrated := MigrationScript.new().migrate({"ownedDigimon": [], "activePartyIds": [], "bits": 19, "digiData": {first.species_seed: 4}})
	assert(int(migrated.get("save_version", 0)) == 1, "Unversioned save must migrate")
	assert(int((migrated.get("roster", {}) as Dictionary).get("bits", 0)) == 19, "Migration must retain legacy values")


func _test_overworld_digi_data() -> void:
	var persistent_party: Array[DigimonInstance] = OverworldState.get_active_instances()
	assert(persistent_party.size() == 3, "Production flow must start with three active instances")
	var roster_before := OverworldState.get_roster_instances().size()
	var first_progress := OverworldState.apply_account_rewards(0, {"Agumon": 40})
	var second_progress := OverworldState.apply_account_rewards(0, {"Agumon": 60})
	assert(OverworldState.get_digi_data_for("Agumon") == 100, "Digi Data must accumulate")
	var seed := String(OverworldState.get_database().get_by_name("Agumon").get("seed", ""))
	assert(not bool((first_progress.get(seed, {}) as Dictionary).get("ready", false)), "Below threshold remains collecting")
	assert(bool((second_progress.get(seed, {}) as Dictionary).get("newly_ready", false)), "Crossing threshold must report unlock")
	var created: DigimonInstance = OverworldState.reconstruct_digimon("Agumon", 100)
	assert(created != null and created.level == 1 and created.exp == 0, "Creation must produce Level 1 instance")
	assert(OverworldState.get_roster_instances().size() == roster_before + 1, "Created Digimon must join roster")
	assert(OverworldState.get_digi_data_for("Agumon") == 0, "Creation must consume configured Digi Data")
	assert(not OverworldState.get_active_party_ids().has(created.id), "Created Digimon must enter Storage")


func _test_encounter_definition(database) -> void:
	var encounter: BattleEncounterDefinition = EncounterScript.new()
	encounter.encounter_id = "regression_agumon_pack"
	encounter.reward_modifier = 1.25
	encounter.repeatable = true
	encounter.battle_map = "res://scenes/battle.tscn"
	encounter.enemy_party.append({"species": "Agumon", "level_min": 3, "level_max": 5, "profile": "wild"})
	assert(encounter.validate(database).is_empty(), "Valid encounter definition must pass validation")
	var restored := BattleEncounterDefinition.from_dict(encounter.to_dict())
	assert(restored.encounter_id == encounter.encounter_id and is_equal_approx(restored.reward_modifier, encounter.reward_modifier), "Encounter definition must round-trip")
