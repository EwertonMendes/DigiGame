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
const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const PartyServiceScript = preload("res://src/collection/PartyService.gd")
const SaveServiceScript = preload("res://src/save/SaveService.gd")
const MigrationScript = preload("res://src/save/SaveMigration.gd")
const EncounterScript = preload("res://src/world/BattleEncounterDefinition.gd")
const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")
const TechniqueRecordServiceScript = preload("res://src/collection/TechniqueRecordService.gd")

const TEST_SAVE_PATH := "user://digigame-progression-regression.json"

func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)
	var database: DigimonDatabase = DatabaseScript.new()
	assert(database.load_default(), "Species database must load")
	assert(database.species_count() > 100, "Canonical catalogue must contain the inherited species set")
	var factory: DigimonFactory = FactoryScript.new(database)
	var progression: DigimonProgressionService = ProgressionServiceScript.new(database)
	var progression_curve: DigimonProgression = ProgressionScript.new()
	var xp: ExperienceCalculator = ExperienceCalculatorScript.new()
	var evolution: DigimonEvolutionService = EvolutionServiceScript.new()
	var graph_service: EvolutionGraphService = EvolutionGraphServiceScript.new()
	var requirements: EvolutionRequirementEvaluator = RequirementEvaluatorScript.new()
	var calculator: DigimonStatCalculator = StatCalculatorScript.new()
	var training: DigimonTrainingService = TrainingServiceScript.new()
	var reward_service: BattleRewardService = RewardServiceScript.new(database)
	var balance: ProgressionBalance = BalanceScript.new()
	var party_service: PartyService = PartyServiceScript.new()

	_test_xp_and_stats(database, factory, progression, progression_curve, calculator, balance)
	_test_rewards(database, factory, xp, reward_service)
	_test_evolution(database, factory, progression, evolution, graph_service, requirements, calculator)
	_test_training(database, factory, training, calculator)
	_test_technique_library(database, factory, progression, evolution, calculator)
	_test_collection_party_save_and_migration(factory, party_service, training)
	_test_overworld_digi_data()
	_test_encounter_definition(database)
	print("digimon progression regression passed")
	get_tree().quit()

func _test_xp_and_stats(database: DigimonDatabase, factory: DigimonFactory, progression: DigimonProgressionService, progression_curve: DigimonProgression, calculator: DigimonStatCalculator, balance: ProgressionBalance) -> void:
	var agumon: DigimonInstance = factory.create_player_by_name("agumon", 1, 100)
	assert(agumon != null, "Agumon instance must be generated from species data")
	var species: Dictionary = database.get_by_seed(agumon.species_seed)
	for stat_key: String in DigimonInstance.STAT_KEYS:
		agumon.aptitudes[stat_key] = 0
		agumon.training[stat_key] = 0
	assert(calculator.get_all_stats(agumon, species) == calculator.get_all_stats(agumon, species), "Stat calculation must be deterministic")
	var required: int = progression.exp_to_next_level(agumon)
	var level_result: Dictionary = progression.apply_experience(agumon, required)
	assert(agumon.level == 2 and int(level_result.get("levels_gained", 0)) == 1, "Exact threshold must level once")
	assert(agumon.exp == 0, "Exact threshold must leave no overflow")
	assert((level_result.get("stat_deltas", {}) as Dictionary).has("hp"), "Level result must expose stat deltas")
	var multi: DigimonInstance = factory.create_player_by_name("agumon", 1, 100)
	var l1 := progression_curve.exp_to_next_level_for_level(1, species)
	var l2 := progression_curve.exp_to_next_level_for_level(2, species)
	var multi_result := progression.apply_experience(multi, l1 + l2 + 7)
	assert(multi.level == 3 and multi.exp == 7 and int(multi_result.get("levels_gained", 0)) == 2, "Multi-level XP must preserve overflow")
	var capped: DigimonInstance = factory.create_player_by_name("agumon", balance.max_level(), 100)
	capped.exp = 123
	progression.apply_experience(capped, 9999999)
	assert(capped.level == balance.max_level() and capped.exp == 0, "Max-level XP must remain normalized")

func _test_rewards(database: DigimonDatabase, factory: DigimonFactory, xp: ExperienceCalculator, reward_service: BattleRewardService) -> void:
	var enemy: DigimonInstance = factory.create_enemy_by_name("veemon", 5, "wild")
	var species := database.get_by_seed(enemy.species_seed)
	assert(xp.reward_for_enemy(5, 5, species, "wild") > xp.reward_for_enemy(30, 5, species, "wild"), "Overleveled farming must be devalued")
	var players: Array[Dictionary] = [{"instance_id": "a", "level": 5, "knocked_out": false}, {"instance_id": "b", "level": 5, "knocked_out": true}]
	var enemies: Array[Dictionary] = [{"species_seed": enemy.species_seed, "level": 5, "profile": "wild", "reward_modifier": 1.0}]
	var rewards := reward_service.calculate_for_snapshots(players, enemies)
	assert(int(rewards.xp_by_instance.get("a", 0)) > 0 and int(rewards.xp_by_instance.get("b", 0)) > 0, "Configured participants must receive XP")
	assert(rewards.bits > 0 and int(rewards.digi_data.get(String(species.get("name", "")), 0)) > 0, "Victory must emit Bits and Digi Data")
	var boosted: Array[Dictionary] = [{"species_seed": enemy.species_seed, "level": 5, "profile": "wild", "reward_modifier": 2.0}]
	var boosted_rewards := reward_service.calculate_for_snapshots(players, boosted)
	assert(int(boosted_rewards.xp_by_instance.get("a", 0)) > int(rewards.xp_by_instance.get("a", 0)) and boosted_rewards.bits > rewards.bits, "Encounter modifier must scale rewards")

func _test_evolution(database: DigimonDatabase, factory: DigimonFactory, progression: DigimonProgressionService, evolution: DigimonEvolutionService, graph_service: EvolutionGraphService, requirements: EvolutionRequirementEvaluator, calculator: DigimonStatCalculator) -> void:
	var blocked := factory.create_player_by_name("koromon", 1, 100)
	var blocked_routes := progression.get_evolution_routes(blocked)
	assert(not blocked_routes.is_empty(), "Evolution routes must be visible before unlock")
	var has_locked := false
	for route: Dictionary in blocked_routes:
		if not bool(route.get("unlocked", false)):
			has_locked = true
	assert(has_locked, "Low-level evolution must be blocked")
	var koromon := factory.create_player_by_name("koromon", 5, 100)
	koromon.link = 63
	var unlocked: Dictionary = {}
	for route: Dictionary in progression.get_evolution_routes(koromon):
		if bool(route.get("unlocked", false)):
			unlocked = route
			break
	assert(not unlocked.is_empty(), "Koromon level 5 must expose an unlocked route")
	var current_species := database.get_by_seed(koromon.species_seed)
	assert(bool(requirements.evaluate(koromon, current_species, {"type": "link", "value": 50}, calculator).get("is_met", false)), "Link requirement must use persistent state")
	var original_id := koromon.id
	var original_link := koromon.link
	var original_seed := koromon.species_seed
	koromon.tier = "S"
	koromon.expansion_unlocked = true
	assert(koromon.set_battle_footprint("large_2x2"), "Unlocked individual must accept its expanded footprint")
	var target_seed := String(unlocked.get("targetSeed", ""))
	assert(graph_service.find_shortest_path(original_seed, target_seed, database).size() == 2, "Direct evolution must remain a graph edge")
	assert(evolution.digivolve(koromon, target_seed, database, calculator), "Unlocked evolution must succeed")
	assert(koromon.id == original_id and koromon.level == 1 and koromon.exp == 0 and koromon.link == original_link, "Evolution must preserve identity/Link and reset level/XP")
	assert(koromon.tier == "S" and koromon.is_expanded(), "Evolution must preserve Tier and Expansion")
	assert(koromon.species_history.size() >= 2, "Evolution must append species history")
	var degeneration_target := ""
	for route: Dictionary in evolution.get_available_degenerations(koromon, database, calculator):
		if bool(route.get("unlocked", false)):
			degeneration_target = String(route.get("targetSeed", ""))
			break
	assert(not degeneration_target.is_empty(), "Degeneration must be a first-class route")
	koromon.level = 8
	assert(evolution.degenerate(koromon, degeneration_target, database, calculator), "Degeneration must succeed")
	assert(koromon.id == original_id and koromon.level == 1 and koromon.link == original_link, "Degeneration must preserve individual state")
	assert(koromon.tier == "S" and koromon.is_expanded(), "Degeneration must preserve Tier and Expansion")

func _test_training(database: DigimonDatabase, factory: DigimonFactory, training: DigimonTrainingService, calculator: DigimonStatCalculator) -> void:
	var agumon := factory.create_player_by_name("agumon", 10, 100)
	for stat_key: String in DigimonInstance.STAT_KEYS:
		agumon.aptitudes[stat_key] = 0
		agumon.training[stat_key] = 0
	agumon.potential = 40
	var species := database.get_by_seed(agumon.species_seed)
	var before := calculator.get_all_stats(agumon, species)
	assert(training.capacity_for(agumon) == 30, "Potential 40 must provide 30 Training Capacity")
	var plan := {"atk": 5, "speed": 5}
	assert(training.validate_plan(agumon, plan, 0).is_empty(), "Valid stat training plan must pass")
	assert(training.apply_plan(agumon, plan, 0), "Valid training plan must apply atomically")
	var after := calculator.get_all_stats(agumon, species)
	assert(int(after.get("atk", 0)) > int(before.get("atk", 0)) and int(after.get("speed", 0)) > int(before.get("speed", 0)), "Training must affect final stats")
	assert(training.used_capacity(agumon) == 10, "Applied points must consume Training Capacity")
	assert(not training.validate_plan(agumon, {"atk": 100}, 0).is_empty(), "Per-stat cap must reject invalid plans")
	agumon.potential = 70
	assert(training.validate_plan(agumon, {}, 1).is_empty(), "Potential 70 with enough capacity must allow first MOV training")
	var before_mov := calculator.get_mov(agumon, species)
	assert(training.apply_plan(agumon, {}, 1), "MOV training plan must apply")
	assert(calculator.get_mov(agumon, species) == before_mov + 1, "MOV training must increase tactical movement")


func _test_technique_library(database: DigimonDatabase, factory: DigimonFactory, progression: DigimonProgressionService, evolution: DigimonEvolutionService, calculator: DigimonStatCalculator) -> void:
	var actions: BattleActionDatabase = ActionDatabaseScript.new()
	assert(actions.load_default(), "Technique databases must load")
	assert(actions.get_all_actions(true).size() > 1000, "The complete DS technique catalogue must be available")
	var agumon := factory.create_player_by_name("agumon", 30, 100)
	var learnset := actions.get_learnset_entries(agumon.species_seed)
	assert(learnset.size() == 3, "Rookie learnsets must contain one signature and two inherited techniques")
	assert(agumon.learned_skills.size() == 1 and agumon.favorite_skills == agumon.learned_skills, "Reconstruction must grant only the current signature and favorite it")
	var signature := agumon.learned_skills[0]
	agumon.record_effective_skill_uses(signature, 8)
	assert(agumon.get_skill_mastery_grade(signature) == "experienced", "Eight effective uses must reach Experienced")
	agumon.record_effective_skill_uses(signature, 99)
	assert(agumon.get_skill_mastery_points(signature) == 24 and agumon.get_skill_mastery_grade(signature) == "mastered", "Mastery must cap at 24")
	assert(agumon.archive_skill(signature) and agumon.learned_skills.has(signature), "Archiving must never forget a technique")
	assert(agumon.restore_skill(signature), "Archived techniques must be restorable")
	var level_result := progression.apply_experience(agumon, 999999)
	assert(agumon.learned_skills.size() >= 3 and not (level_result.get("learned_skills", []) as Array).is_empty(), "Level-up must permanently learn inherited techniques")
	var known_before := agumon.learned_skills.duplicate()
	var route := progression.get_evolution_routes(agumon).filter(func(candidate: Dictionary): return bool(candidate.get("unlocked", false)))
	if not route.is_empty():
		assert(evolution.digivolve(agumon, String((route[0] as Dictionary).get("targetSeed", "")), database, calculator), "Technique persistence evolution fixture must evolve")
		for known_skill: String in known_before:
			assert(agumon.learned_skills.has(known_skill), "Evolution must preserve every learned technique")
		assert(agumon.level == 1, "Evolution still resets level to one")

	var collection: PlayerCollection = CollectionScript.new()
	var tutor_target := factory.create_player_by_name("gabumon", 1, 100)
	collection.add_instance(tutor_target, "tutor", "Gabumon")
	collection.bits = 10000
	var records: TechniqueRecordService = TechniqueRecordServiceScript.new()
	var teachable: Dictionary = {}
	var species := database.get_by_seed(tutor_target.species_seed)
	for candidate: Dictionary in records.get_teachable_records(collection, tutor_target, species):
		var record = candidate.get("record", {})
		if record is Dictionary and bool(record.get("teachable", false)) and String(record.get("recordLevel", "")) == "common" and bool(candidate.get("compatible", false)):
			teachable = candidate
			break
	assert(not teachable.is_empty(), "Tutor test requires a compatible Common record")
	var teachable_id := String(teachable.get("id", ""))
	collection.add_technique_research(teachable_id)
	collection.add_technique_research(teachable_id)
	var unlocked := collection.add_technique_research(teachable_id)
	assert(bool(unlocked.get("unlocked", false)) and collection.has_technique_record(teachable_id), "Three victories worth of insight must unlock a Common record")
	var bits_before := collection.bits
	var taught := records.teach(collection, tutor_target, species, teachable_id)
	assert(bool(taught.get("success", false)) and tutor_target.learned_skills.has(teachable_id), "Unlocked compatible Records must teach permanently")
	assert(collection.bits == bits_before - 300, "Common Records must cost exactly 300 Bits")

func _test_collection_party_save_and_migration(factory: DigimonFactory, party_service: PartyService, training: DigimonTrainingService) -> void:
	var collection: PlayerCollection = CollectionScript.new()
	var first := factory.create_player_by_name("agumon", 4, 100)
	var second := factory.create_player_by_name("agumon", 7, 100)
	var third := factory.create_player_by_name("gabumon", 6, 100)
	var fourth := factory.create_player_by_name("veemon", 5, 100)
	assert(first.id != second.id, "Same-species Digimon need unique UUIDs")
	first.exp = 33
	first.link = 42
	first.potential = 40
	assert(training.apply_plan(first, {"atk": 3}, 0), "Training state must be persistable")
	collection.add_instance(first, "agumon", "Agumon")
	collection.add_instance(second, "agumon", "Agumon")
	collection.add_instance(third, "gabumon", "Gabumon")
	collection.add_instance(fourth, "veemon", "Veemon")
	var party_ids: Array[String] = [first.id, second.id, third.id]
	assert(party_service.set_party(collection, party_ids), "Valid party must be accepted")
	var duplicates: Array[String] = [first.id, first.id]
	assert(not party_service.set_party(collection, duplicates), "Duplicate individual must be rejected")
	assert(not party_service.add_to_party(collection, fourth.id), "Party limit must be enforced")
	assert(party_service.remove_from_party(collection, third.id) and party_service.add_to_party(collection, fourth.id), "Party swap flow must work")
	assert(collection.get_reserve_instances().size() == 1, "Non-active Digimon must remain in Storage")
	collection.bits = 321
	collection.add_digi_data(first.species_seed, 87)
	var save_service: SaveService = SaveServiceScript.new()
	save_service.delete_save(TEST_SAVE_PATH)
	collection.add_item("expansion_fragment", 4)
	assert(save_service.save_collection(collection, TEST_SAVE_PATH), "Collection save v5 must write")
	var loaded: PlayerCollection = save_service.load_collection(TEST_SAVE_PATH)
	assert(loaded != null and loaded.get_instances().size() == collection.get_instances().size(), "Save/load must preserve collection")
	var restored := loaded.get_instance(first.id)
	assert(restored != null and restored.level == first.level and restored.exp == first.exp and restored.link == first.link, "Save/load must preserve individual progression")
	assert(int(restored.training.get("atk", 0)) == 3, "Save/load must preserve permanent Training")
	assert(loaded.get_digi_data(first.species_seed) == 87 and loaded.bits == 321, "Save/load must preserve account rewards")
	assert(loaded.get_active_party_ids() == collection.get_active_party_ids(), "Save/load must preserve party order")
	assert(loaded.get_item_count("expansion_fragment") == 4, "Save/load must preserve generic inventory")
	var save_data := save_service.load_data(TEST_SAVE_PATH)
	assert(save_data != null and save_data.save_version == 5 and not save_data.collection.is_empty(), "New saves must use v5 collection schema")
	assert(save_service.delete_save(TEST_SAVE_PATH), "Regression save must be removable")

	# Legacy vocabulary exists only in this fixture because it verifies that real
	# v1 saves are migrated without data loss. New v5 data must never write it.
	var migration: SaveMigration = MigrationScript.new()
	var legacy_v1_instance := first.to_dict()
	legacy_v1_instance.erase("tier")
	legacy_v1_instance.erase("expansionUnlocked")
	legacy_v1_instance.erase("battleFootprintId")
	legacy_v1_instance.erase("hospitalRecovery")
	var legacy_entry := {"rosterKey": "legacy_agumon", "instance": legacy_v1_instance}
	var migrated := migration.migrate({"save_version": 1, "roster": {"instances": [legacy_entry], "activePartyIds": [first.id], "bits": 19, "digiData": {first.species_seed: 4}}})
	assert(int(migrated.get("save_version", 0)) == 5, "v1 save must migrate through v5")
	var migrated_collection := migrated.get("collection", {}) as Dictionary
	assert(int(migrated_collection.get("bits", 0)) == 19, "Migration must retain legacy values")
	var migrated_entries := migrated_collection.get("instances", []) as Array
	assert(migrated_entries.size() == 1 and String((migrated_entries[0] as Dictionary).get("collectionKey", "")) == "legacy_agumon", "Migration must rename legacy entry key")
	assert(not (migrated_entries[0] as Dictionary).has("rosterKey"), "v5 save must not write legacy key names")
	var migrated_individual := (migrated_entries[0] as Dictionary).get("instance", {}) as Dictionary
	assert(String(migrated_individual.get("tier", "")) == "E" and not bool(migrated_individual.get("expansionUnlocked", true)) and String(migrated_individual.get("battleFootprintId", "")) == "single", "Old saves must initialize Tier E and a locked 1x1 footprint")
	assert((migrated_individual.get("hospitalRecovery", {}) as Dictionary).is_empty(), "Old saves must initialize without active Hospital recovery")
	var legacy_v2_instance := first.to_dict()
	legacy_v2_instance.erase("tier")
	legacy_v2_instance.erase("expansionUnlocked")
	legacy_v2_instance.erase("battleFootprintId")
	legacy_v2_instance.erase("hospitalRecovery")
	legacy_v2_instance["equippedSkills"] = ["pepper_breath", "guard_charge"]
	legacy_v2_instance.erase("favoriteSkills")
	legacy_v2_instance.erase("archivedSkills")
	legacy_v2_instance.erase("skillMastery")
	var migrated_v2 := migration.migrate({"save_version": 2, "collection": {"instances": [{"collectionKey": "legacy", "instance": legacy_v2_instance}]}})
	var migrated_v2_collection := migrated_v2.get("collection", {}) as Dictionary
	var migrated_v2_entries := migrated_v2_collection.get("instances", []) as Array
	var migrated_v2_entry := migrated_v2_entries[0] as Dictionary
	var migrated_instance := migrated_v2_entry.get("instance", {}) as Dictionary
	assert((migrated_instance.get("favoriteSkills", []) as Array) == ["pepper_breath", "guard_charge"], "v2 equipped order must become v3 Favorites")
	assert(not migrated_instance.has("equippedSkills") and (migrated_instance.get("archivedSkills", []) as Array).is_empty(), "v3 migration must remove slots and initialize Archive")
	assert(String(migrated_instance.get("tier", "")) == "E" and not bool(migrated_instance.get("expansionUnlocked", true)) and String(migrated_instance.get("battleFootprintId", "")) == "single", "v2 migration must initialize v4 individual defaults")
	assert((migrated_instance.get("hospitalRecovery", {}) as Dictionary).is_empty(), "v2 migration must initialize v5 Hospital defaults")

func _test_overworld_digi_data() -> void:
	assert(OverworldState.get_active_instances().size() == 3, "Production flow must start with three active instances")
	var collection_before := OverworldState.get_collection_instances().size()
	var first_progress := OverworldState.apply_account_rewards(0, {"Agumon": 40})
	var second_progress := OverworldState.apply_account_rewards(0, {"Agumon": 60})
	assert(OverworldState.get_digi_data_for("Agumon") == 100, "Digi Data must accumulate")
	var seed := String(OverworldState.get_database().get_by_name("Agumon").get("seed", ""))
	assert(not bool((first_progress.get(seed, {}) as Dictionary).get("ready", false)), "Below threshold remains collecting")
	assert(bool((second_progress.get(seed, {}) as Dictionary).get("newly_ready", false)), "Crossing threshold must report ready")
	var created := OverworldState.reconstruct_digimon("Agumon", 100)
	assert(created != null and created.level == 1 and created.exp == 0, "Reconstruction must create Level 1 individual")
	assert(OverworldState.get_collection_instances().size() == collection_before + 1, "Created Digimon must join the collection")
	assert(OverworldState.get_digi_data_for("Agumon") == 0 and not OverworldState.get_active_party_ids().has(created.id), "Creation must consume data and place Digimon in Storage")

func _test_encounter_definition(database: DigimonDatabase) -> void:
	var encounter: BattleEncounterDefinition = EncounterScript.new()
	encounter.encounter_id = "regression_agumon_pack"
	encounter.reward_modifier = 1.25
	encounter.repeatable = true
	encounter.battle_map = "res://scenes/battle.tscn"
	encounter.enemy_party.append({"species": "Agumon", "level_min": 3, "level_max": 5, "profile": "wild"})
	assert(encounter.validate(database).is_empty(), "Valid encounter definition must pass validation")
	var restored: BattleEncounterDefinition = BattleEncounterDefinition.from_dict(encounter.to_dict())
	assert(restored.encounter_id == encounter.encounter_id and is_equal_approx(restored.reward_modifier, encounter.reward_modifier), "Encounter definition must round-trip")
