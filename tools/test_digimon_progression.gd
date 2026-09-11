extends Node

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const ProgressionServiceScript = preload("res://src/digimon/DigimonProgressionService.gd")
const ExperienceCalculatorScript = preload("res://src/digimon/ExperienceCalculator.gd")
const EvolutionServiceScript = preload("res://src/digimon/DigimonEvolutionService.gd")
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

	print("digimon progression regression passed")
	get_tree().quit()
