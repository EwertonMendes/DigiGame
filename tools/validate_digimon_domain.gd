extends SceneTree

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const CalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const TrainingScript = preload("res://src/digimon/DigimonTrainingService.gd")
const ProgressionScript = preload("res://src/digimon/DigimonProgression.gd")
const EvolutionScript = preload("res://src/digimon/DigimonEvolutionService.gd")


func _init() -> void:
	var database = DatabaseScript.new()
	_require(database.load_default(), "species database should load")
	_require(database.species_count() >= 400, "species database should contain the full catalogue")

	var factory = FactoryScript.new(database)
	var calculator = CalculatorScript.new()
	var training = TrainingScript.new()
	var progression = ProgressionScript.new()
	var evolution = EvolutionScript.new()

	var agumon = factory.create_player_by_name("Agumon", 10, 200)
	var second_agumon = factory.create_player_by_name("Agumon", 10, 100)
	_require(agumon != null and second_agumon != null, "factory should create player instances")
	_require(not agumon.id.is_empty() and agumon.id != second_agumon.id, "each Digimon instance should have a unique UUID")
	_require(agumon.species_seed == second_agumon.species_seed, "same species should share species seed")
	_require(agumon.potential == 5, "200 percent scan should grant initial potential without changing species")

	var species: Dictionary = database.get_by_seed(agumon.species_seed)
	_require(int(species.get("MOV", 0)) > 0, "species should expose base MOV")
	_require(not String(species.get("movementType", "")).is_empty(), "species should expose movement type")
	_require(calculator.get_stat(agumon, species, "hp") > int(species.get("hp", 0)), "level should increase calculated stats")

	agumon.potential = 70
	_require(training.can_train_mobility(agumon), "Potential 70 Digimon should qualify for Mobility Training I")
	_require(training.train_mobility(agumon), "Mobility Training I should apply")
	_require(calculator.get_mov(agumon, species) == int(species.get("MOV", 4)) + 1, "individual mobility training should modify final MOV")

	var before_level: int = int(agumon.level)
	var required_xp: int = int(progression.exp_to_next_level(agumon, species))
	progression.add_experience(agumon, species, required_xp)
	_require(agumon.level == before_level + 1, "XP should level the individual Digimon")

	var evolutions = species.get("digiEvolutionSeedList", [])
	if evolutions is Array and not evolutions.is_empty():
		var target_seed: String = String(evolutions[0])
		var old_id: String = String(agumon.id)
		var old_training: int = int(agumon.training.get("mov", 0))
		# The database may require a higher level. Raise only for this domain check.
		agumon.level = 99
		if evolution.can_digivolve(agumon, target_seed, database, calculator):
			_require(evolution.digivolve(agumon, target_seed, database, calculator), "valid Digivolution should succeed")
			_require(agumon.id == old_id, "Digivolution must preserve individual identity")
			_require(agumon.level == 1 and agumon.exp == 0, "Digivolution should reset level and EXP")
			_require(int(agumon.training.get("mov", 0)) == old_training, "Digivolution should preserve individual training")

	print("Digimon domain validation passed: %d species" % database.species_count())
	quit(0)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("DIGIMON DOMAIN VALIDATION FAILED: %s" % message)
	quit(1)
