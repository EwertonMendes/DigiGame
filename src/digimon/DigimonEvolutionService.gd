extends RefCounted
class_name DigimonEvolutionService

const ProgressionScript = preload("res://src/digimon/DigimonProgression.gd")

var _progression = ProgressionScript.new()


func can_digivolve(instance: DigimonInstance, target_seed: String, database, calculator) -> bool:
	return _can_transition(instance, target_seed, database, calculator, false)


func can_degenerate(instance: DigimonInstance, target_seed: String, database, calculator) -> bool:
	return _can_transition(instance, target_seed, database, calculator, true)


func digivolve(instance: DigimonInstance, target_seed: String, database, calculator) -> bool:
	if not can_digivolve(instance, target_seed, database, calculator):
		return false
	return _apply_transition(instance, target_seed, database, calculator, false)


func degenerate(instance: DigimonInstance, target_seed: String, database, calculator) -> bool:
	if not can_degenerate(instance, target_seed, database, calculator):
		return false
	return _apply_transition(instance, target_seed, database, calculator, true)


func _can_transition(instance: DigimonInstance, target_seed: String, database, calculator, degenerating: bool) -> bool:
	if instance == null or database == null or calculator == null:
		return false
	var current_species: Dictionary = database.get_by_seed(instance.species_seed)
	var target_species: Dictionary = database.get_by_seed(target_seed)
	if current_species.is_empty() or target_species.is_empty():
		return false
	var relation_key := "degenerateSeedList" if degenerating else "digiEvolutionSeedList"
	var allowed = current_species.get(relation_key, [])
	if not allowed is Array or not allowed.has(target_seed):
		return false
	if degenerating:
		return true
	return _requirements_met(instance, current_species, database, calculator)


func _requirements_met(instance: DigimonInstance, species: Dictionary, database, calculator) -> bool:
	var requirements = species.get("evolutionRequirements", [])
	if not requirements is Array:
		return true
	for requirement in requirements:
		if not requirement is Dictionary:
			continue
		if not _requirement_met(instance, species, requirement, calculator):
			return false
	return true


func _requirement_met(instance: DigimonInstance, species: Dictionary, requirement: Dictionary, calculator) -> bool:
	var requirement_type := String(requirement.get("type", "")).to_lower()
	var required_value := int(requirement.get("value", 0))
	match requirement_type:
		"level":
			return instance.level >= required_value
		"potential", "abi":
			return instance.potential >= required_value
		"hp", "mp", "atk", "def", "speed":
			return int(calculator.get_stat(instance, species, requirement_type)) >= required_value
		"attack":
			return int(calculator.get_stat(instance, species, "atk")) >= required_value
		"defense":
			return int(calculator.get_stat(instance, species, "def")) >= required_value
		"item":
			# Inventory integration will resolve item requirements later. Never
			# silently bypass a requirement we cannot currently validate.
			return false
		"":
			return true
	return false


func _apply_transition(instance: DigimonInstance, target_seed: String, database, calculator, degenerating: bool) -> bool:
	var old_species := database.get_by_seed(instance.species_seed)
	var target_species := database.get_by_seed(target_seed)
	if old_species.is_empty() or target_species.is_empty():
		return false

	var old_level := instance.level
	var potential_gain := (
		_progression.potential_gain_for_degeneration(old_level)
		if degenerating
		else _progression.potential_gain_for_digivolution(old_level)
	)
	instance.evolution_history.append({
		"fromSeed": instance.species_seed,
		"toSeed": target_seed,
		"fromLevel": old_level,
		"direction": "degeneration" if degenerating else "digivolution",
		"potentialGain": potential_gain,
	})
	instance.species_seed = target_seed
	instance.level = 1
	instance.exp = 0
	_progression.add_potential(instance, potential_gain)
	calculator.refill_instance(instance, target_species)
	return true
