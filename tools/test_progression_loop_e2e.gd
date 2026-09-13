extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const RewardServiceScript = preload("res://src/digimon/BattleRewardService.gd")
const EvolutionServiceScript = preload("res://src/digimon/DigimonEvolutionService.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const ActorScript = preload("res://src/battle/DigimonBattleActor.gd")
const ResultScreenScript = preload("res://src/ui/RetreatAwareBattleResultScreen.gd")
const RosterScript = preload("res://src/collection/PlayerRoster.gd")
const QuestDefinitionScript = preload("res://src/quests/QuestDefinition.gd")
const QuestServiceScript = preload("res://src/quests/QuestService.gd")

var _database: DigimonDatabase
var _factory: DigimonFactory
var _reward_service: BattleRewardService
var _evolution: DigimonEvolutionService
var _calculator: DigimonStatCalculator


func _ready() -> void:
	_database = DatabaseScript.new() as DigimonDatabase
	assert(_database.load_default(), "E2E progression requires the canonical database")
	_factory = FactoryScript.new(_database) as DigimonFactory
	_reward_service = RewardServiceScript.new(_database) as BattleRewardService
	_evolution = EvolutionServiceScript.new() as DigimonEvolutionService
	_calculator = StatCalculatorScript.new() as DigimonStatCalculator

	# Start from the same production singleton used by Hub, Digilab and battle,
	# but erase any previous runner-local save so the test is deterministic.
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(true)
	OverworldState.set_persistence_enabled(true)
	assert(OverworldState.save_progress(), "Fresh production roster must save")

	await _run_full_progression_loop()
	_test_minimal_quest_foundation()

	# Never leak the E2E save into the following combat regression in this runner.
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(true)
	print("complete progression loop e2e regression passed")
	get_tree().quit()


func _run_full_progression_loop() -> void:
	var initial_party: Array[DigimonInstance] = OverworldState.get_active_instances()
	assert(initial_party.size() == 3, "Hub production flow must begin with a three-Digimon party")
	var starter_id := initial_party[0].id
	var starter_level_before := initial_party[0].level

	# Battle 1: a deterministic defeated Koromon pack yields real XP + species Data.
	var battle_one := _victory(initial_party, "Koromon", 10, "boss", 5)
	var battle_one_xp := battle_one.get("xp_rewards", {}) as Dictionary
	assert(not (battle_one_xp.get("digimon", []) as Array).is_empty(), "Victory must return per-Digimon XP results")
	var data_progress := OverworldState.apply_account_rewards(
		int(battle_one.get("bits", 0)),
		battle_one.get("digi_data", {}) as Dictionary
	)
	battle_one["digi_data_progress"] = data_progress
	battle_one["victory"] = true
	battle_one["outcome"] = "victory"
	battle_one["battle_seed"] = "progression-e2e-1"
	battle_one["acts"] = 1
	assert(OverworldState.get_instance_by_id(starter_id).level > starter_level_before, "Battle XP must level a persistent party member")
	assert(OverworldState.get_digi_data_for("Koromon") >= OverworldState.get_reconstruction_requirement("Koromon"), "Defeated species must reach reconstruction threshold")

	# The same result contract must be consumable by the real Battle Results UI.
	var results_screen := ResultScreenScript.new() as BattleResultScreen
	add_child(results_screen)
	results_screen.show_result(battle_one)
	await get_tree().process_frame
	assert(results_screen.visible, "Victory must open Battle Results before returning to Hub")
	assert((results_screen.get("_cards") as Array).size() == initial_party.size(), "Battle Results must represent every participating Digimon")
	results_screen.hide_result()
	results_screen.free()

	# Simulate closing/reopening the game by serializing and reloading the singleton state.
	assert(OverworldState.save_progress(), "Battle progression must persist")
	assert(OverworldState.load_progress(), "Saved battle progression must reload")
	assert(OverworldState.get_instance_by_id(starter_id).level > starter_level_before, "Reload must preserve gained levels")
	assert(OverworldState.get_digi_data_for("Koromon") >= 100, "Reload must preserve Digi Data")

	# Digilab creation consumes Data and produces a unique Level 1 Storage individual.
	assert(OverworldState.can_reconstruct_digimon("Koromon"), "Threshold must unlock Digilab creation")
	var created: DigimonInstance = OverworldState.reconstruct_digimon("Koromon")
	assert(created != null, "Digilab must create the unlocked species")
	var created_id := created.id
	var original_seed := created.species_seed
	assert(created.level == 1 and created.exp == 0, "Created Digimon must begin at Level 1 with zero XP")
	assert(not OverworldState.get_active_party_ids().has(created_id), "Created Digimon must enter Storage, not silently replace party")
	assert(OverworldState.get_digi_data_for("Koromon") < OverworldState.get_reconstruction_requirement("Koromon"), "Creation must consume required Digi Data")

	# Move the new individual into the real party and persist/reload the party order.
	var replaced_active_id := OverworldState.get_active_party_ids()[0]
	assert(OverworldState.swap_party_with_reserve(replaced_active_id, created_id), "Storage Digimon must be swappable into the party")
	assert(OverworldState.get_active_party_ids().has(created_id), "Created Digimon must now be active")
	assert(OverworldState.save_progress() and OverworldState.load_progress(), "Party mutation must survive reload")
	assert(OverworldState.get_active_party_ids().has(created_id), "Reload must retain created Digimon in party")

	# Battle 2 uses the created individual through the same Battle Runtime Actor bridge.
	var party_with_created: Array[DigimonInstance] = OverworldState.get_active_instances()
	var battle_two := _victory(party_with_created, "Agumon", 10, "boss", 8)
	OverworldState.apply_account_rewards(int(battle_two.get("bits", 0)), battle_two.get("digi_data", {}) as Dictionary)
	var trained_created := OverworldState.get_instance_by_id(created_id)
	assert(trained_created != null and trained_created.level >= 5, "Created Digimon must gain enough battle XP to meet an early evolution route")

	# Choose a real database route; evolution keeps identity/Link and resets level/XP.
	trained_created.link = 37
	var routes: Array[Dictionary] = _evolution.get_available_evolutions(trained_created, _database, _calculator)
	var chosen_route: Dictionary = {}
	for route: Dictionary in routes:
		if bool(route.get("unlocked", false)):
			chosen_route = route
			break
	assert(not chosen_route.is_empty(), "Leveled created Digimon must expose an unlocked evolution route")
	var evolved_seed := String(chosen_route.get("targetSeed", ""))
	assert(_evolution.digivolve(trained_created, evolved_seed, _database, _calculator), "Unlocked Digilab evolution must succeed")
	assert(trained_created.id == created_id and trained_created.species_seed == evolved_seed, "Evolution must keep the same individual and change species")
	assert(trained_created.level == 1 and trained_created.exp == 0 and trained_created.link == 37, "Evolution must reset level/XP and preserve Link")
	OverworldState.notify_roster_changed()
	assert(OverworldState.save_progress() and OverworldState.load_progress(), "Evolved form must survive reload")
	var reloaded_evolved := OverworldState.get_instance_by_id(created_id)
	assert(reloaded_evolved != null and reloaded_evolved.species_seed == evolved_seed, "Reload must retain evolved species on the same UUID")

	# Battle 3 proves the evolved form can become a real battle actor and gain XP.
	var evolved_actor := _actor_for(reloaded_evolved, true)
	assert(String(evolved_actor.call("get_species_seed")) == evolved_seed, "Evolved form must bind into Battle Runtime")
	var evolved_players: Array[Node] = [evolved_actor]
	var evolved_enemy: DigimonInstance = _factory.create_enemy_by_name("Agumon", 5, "wild")
	var evolved_enemy_actor := _actor_for(evolved_enemy, false, "wild")
	var evolved_enemies: Array[Node] = [evolved_enemy_actor]
	var battle_three: Dictionary = _reward_service.apply_victory_rewards(evolved_players, evolved_enemies)
	evolved_actor.free()
	evolved_enemy_actor.free()
	var evolved_xp := int(((battle_three.get("xp_rewards", {}) as Dictionary).get("total_enemy_xp_value", 0)))
	assert(evolved_xp > 0, "Evolved form must receive battle XP")
	OverworldState.apply_account_rewards(int(battle_three.get("bits", 0)), battle_three.get("digi_data", {}) as Dictionary)

	# Degeneration is first-class, outside battle, resets level/XP and persists.
	var degeneration_routes: Array[Dictionary] = _evolution.get_available_degenerations(reloaded_evolved, _database, _calculator)
	var degeneration_seed := ""
	for route: Dictionary in degeneration_routes:
		if bool(route.get("unlocked", false)) and String(route.get("targetSeed", "")) == original_seed:
			degeneration_seed = original_seed
			break
	if degeneration_seed.is_empty():
		for route: Dictionary in degeneration_routes:
			if bool(route.get("unlocked", false)):
				degeneration_seed = String(route.get("targetSeed", ""))
				break
	assert(not degeneration_seed.is_empty(), "Evolved Digimon must expose an unlocked degeneration route")
	assert(_evolution.degenerate(reloaded_evolved, degeneration_seed, _database, _calculator), "Digilab degeneration must succeed")
	assert(reloaded_evolved.id == created_id and reloaded_evolved.level == 1 and reloaded_evolved.exp == 0, "Degeneration must keep UUID and reset level/XP")
	assert(reloaded_evolved.link == 37, "Degeneration must preserve Link")
	OverworldState.notify_roster_changed()
	assert(OverworldState.save_progress() and OverworldState.load_progress(), "Degenerated state must survive reload")
	var final_instance := OverworldState.get_instance_by_id(created_id)
	assert(final_instance != null and final_instance.species_seed == degeneration_seed, "Final reload must retain degeneration")
	assert(final_instance.species_history.size() >= 3, "Evolution history must survive the complete loop")


func _victory(players: Array[DigimonInstance], enemy_name: String, enemy_level: int, profile: String, enemy_count: int) -> Dictionary:
	var player_actors: Array[Node] = []
	for instance: DigimonInstance in players:
		player_actors.append(_actor_for(instance, true))
	var enemy_actors: Array[Node] = []
	for _index in enemy_count:
		var enemy: DigimonInstance = _factory.create_enemy_by_name(enemy_name, enemy_level, profile)
		assert(enemy != null, "E2E enemy species must exist")
		enemy_actors.append(_actor_for(enemy, false, profile))
	var result: Dictionary = _reward_service.apply_victory_rewards(player_actors, enemy_actors)
	for actor: Node in player_actors:
		actor.free()
	for actor: Node in enemy_actors:
		actor.free()
	return result


func _actor_for(instance: DigimonInstance, player_controlled: bool, profile: String = "wild") -> Node:
	var actor := ActorScript.new() as Node
	actor.call("bind_digimon_instance", instance, _database.get_by_seed(instance.species_seed), player_controlled)
	if not player_controlled:
		actor.set_meta("encounter_profile", profile)
		actor.set_meta("reward_modifier", 1.0)
	return actor


func _test_minimal_quest_foundation() -> void:
	var roster: PlayerRoster = RosterScript.new()
	var definition: QuestDefinition = QuestDefinitionScript.new()
	definition.quest_id = "defeat_3_koromon"
	definition.initial_state = "available"
	var koromon_seed := String(_database.get_by_name("Koromon").get("seed", ""))
	definition.objectives.append({"type": "species_defeated", "species_seed": koromon_seed, "amount": 3})
	definition.rewards = {"bits": 25, "digi_data": {koromon_seed: 10}, "flags": {"koromon_trial_complete": true}}
	assert(definition.validate(_database).is_empty(), "Minimal quest definition must validate")
	var quests: QuestService = QuestServiceScript.new()
	assert(quests.start(roster, definition), "Available quest must become active")
	var partial := quests.record_species_defeat(roster, definition, koromon_seed, 2)
	assert(not bool(partial.get("completed", false)), "Quest must remain active before objective target")
	var completed := quests.record_species_defeat(roster, definition, koromon_seed, 1)
	assert(bool(completed.get("completed", false)) and quests.get_state(roster, definition) == "completed", "Quest must complete at objective target")
	assert(roster.bits == 25 and roster.get_digi_data(koromon_seed) == 10, "Quest rewards must use persistent roster currencies")
	assert(bool(roster.progression_flags.get("koromon_trial_complete", false)), "Quest progression flag must persist in roster state")
	var restored := PlayerRoster.new()
	restored.load_dict(roster.to_dict())
	assert(String((restored.quest_states.get(definition.quest_id, {}) as Dictionary).get("state", "")) == "completed", "Quest state must survive roster serialization")
