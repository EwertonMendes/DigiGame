extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")
const ExperienceCalculatorScript = preload("res://src/digimon/ExperienceCalculator.gd")
const EvolutionServiceScript = preload("res://src/digimon/DigimonEvolutionService.gd")
const EvolutionGraphServiceScript = preload("res://src/digimon/EvolutionGraphService.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const TrainingServiceScript = preload("res://src/digimon/DigimonTrainingService.gd")


func _ready() -> void:
	var database = DatabaseScript.new()
	assert(database.load_default(), "Species database must load")
	assert(database.species_count() > 100, "Canonical catalogue must contain the full inherited species set")
	var factory = FactoryScript.new(database)
	var progression = ProgressionServiceScript.new(database)
	var xp = ExperienceCalculatorScript.new()
	var evolution = EvolutionServiceScript.new()
	var graph_service = EvolutionGraphServiceScript.new()
	var calculator = StatCalculatorScript.new()
	var training = TrainingServiceScript.new()

	var agumon: DigimonInstance = factory.create_player_by_name("agumon", 1, 100)
	assert(agumon != null, "Agumon instance must be generated from species data")
	var agumon_species: Dictionary = database.get_by_seed(agumon.species_seed)
	assert(int(agumon_species.get("hp", 0)) > 0, "Species base stats must remain canonical data")
	var required := progression.exp_to_next_level(agumon)
	assert(required > 0, "Level 1 must require XP")
	var level_result: Dictionary = progression.apply_experience(agumon, required)
	assert(agumon.level == 2, "Exact level threshold must level up")
	assert(int(level_result.get("levels_gained", 0)) == 1, "Progression result must report gained level")
	assert(int(level_result.get("old_level", 0)) == 1 and int(level_result.get("new_level", 0)) == 2, "Progression result must preserve before/after levels for result UI")
	assert(int(level_result.get("old_exp", -1)) == 0 and int(level_result.get("new_exp", -1)) == 0, "Progression result must preserve before/after XP for result UI")
	var level_steps = level_result.get("level_steps", [])
	assert(level_steps is Array and level_steps.size() == 1, "Exact threshold must expose one XP animation segment")
	var first_step: Dictionary = level_steps[0] as Dictionary
	assert(bool(first_step.get("leveled_up", false)), "XP animation segment must explicitly mark level-up boundaries")
	assert(int(first_step.get("required", 0)) == required, "XP animation segment must use the canonical XP threshold")
	assert(String(level_result.get("species_name", "")).to_lower() == "agumon", "Progression result must include display species metadata")

	var graph: Dictionary = graph_service.build_connected_graph(agumon.species_seed, database)
	assert((graph.get("nodes", []) as Array).size() > 1, "Evolution constellation must traverse beyond the next form")
	assert(not (graph.get("edges", []) as Array).is_empty(), "Evolution constellation must expose connected routes")
	var direct_routes: Array[Dictionary] = progression.get_evolution_routes(agumon)
	if not direct_routes.is_empty():
		var graph_target := String(direct_routes[0].get("targetSeed", ""))
		var path: Array[String] = graph_service.find_shortest_path(agumon.species_seed, graph_target, database)
		assert(path.size() == 2, "A direct evolution must be represented as a two-node constellation path")
		agumon.evolution_goal_seed = graph_target
		var restored := DigimonInstance.from_dict(agumon.to_dict())
		assert(restored.evolution_goal_seed == graph_target, "Evolution planning target must persist through serialization")

	var rookie_enemy: DigimonInstance = factory.create_enemy_by_name("veemon", 5, "wild")
	var enemy_species: Dictionary = database.get_by_seed(rookie_enemy.species_seed)
	var relevant_reward := xp.reward_for_enemy(5, 5, enemy_species, "wild")
	var farm_reward := xp.reward_for_enemy(30, 5, enemy_species, "wild")
	assert(relevant_reward > farm_reward, "Overleveled farming must be strongly devalued")

	var koromon: DigimonInstance = factory.create_player_by_name("koromon", 5, 100)
	var routes: Array[Dictionary] = progression.get_evolution_routes(koromon)
	assert(not routes.is_empty(), "Legacy evolution lists must normalize into target-specific routes")
	var unlocked_route: Dictionary = {}
	for route: Dictionary in routes:
		if bool(route.get("unlocked", false)):
			unlocked_route = route
			break
	assert(not unlocked_route.is_empty(), "Koromon level 5 must have an available Rookie route")
	var original_id := koromon.id
	var target_seed := String(unlocked_route.get("targetSeed", ""))
	assert(evolution.digivolve(koromon, target_seed, database, calculator), "Available route must Digivolve")
	assert(koromon.id == original_id, "Digivolution must preserve individual identity")
	assert(koromon.species_seed == target_seed, "Digivolution must change species seed")
	assert(koromon.level == 1 and koromon.exp == 0, "Digivolution must reset level and XP")
	assert(not koromon.evolution_history.is_empty(), "Digivolution must append persistent history")

	var before_capacity := training.capacity_for(koromon)
	koromon.potential = 20
	assert(training.capacity_for(koromon) > before_capacity, "Potential must increase training capacity")
	assert(training.can_allocate_stat(koromon, "int", 1), "INT must be a trainable build stat")
	assert(training.allocate_stat(koromon, "int", 1), "INT training allocation must succeed")

	var persistent_party: Array[DigimonInstance] = OverworldState.get_active_instances()
	assert(persistent_party.size() == 3, "Overworld must own three persistent starter instances")
	var persistent_id := persistent_party[0].id
	assert(OverworldState.get_instance_by_id(persistent_id) == persistent_party[0], "Roster lookup must return the same persistent object")

	var roster_before := OverworldState.get_roster_instances().size()
	OverworldState.apply_account_rewards(0, {"Agumon": 200})
	assert(OverworldState.can_reconstruct_digimon("Agumon", 150), "DigiLab must allow reconstruction when enough species data exists")
	var reconstructed: DigimonInstance = OverworldState.reconstruct_digimon("Agumon", 150)
	assert(reconstructed != null, "DigiLab reconstruction must create a persistent individual")
	assert(reconstructed.level == 1 and reconstructed.potential == factory.potential_from_scan_percent(150), "Reconstruction quality must map Digi Data investment to starting Potential")
	assert(OverworldState.get_roster_instances().size() == roster_before + 1, "DigiLab must support an additional individual even when that species already exists")
	assert(OverworldState.get_digi_data_for("Agumon") == 50, "DigiLab reconstruction must consume the selected Digi Data amount")

	print("digimon progression regression passed")
	get_tree().quit()
