extends "res://src/Player.gd"

const BattleDigimonScript = preload("res://src/battle/BattleDigimon.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")

var digimon_instance: DigimonInstance = null
var battle_state: BattleDigimon = null
var species_data: Dictionary = {}
var _stat_calculator = StatCalculatorScript.new()


func bind_digimon_instance(instance: DigimonInstance, species: Dictionary, player_controlled: bool) -> void:
	digimon_instance = instance
	species_data = species.duplicate(true)
	is_player_controlled = player_controlled
	digimon_key = String(species_data.get("name", "")).to_lower()
	battle_state = BattleDigimonScript.new(instance, "player" if player_controlled else "enemy")


func get_instance_id() -> String:
	return digimon_instance.id if digimon_instance != null else ""


func get_species_seed() -> String:
	return digimon_instance.species_seed if digimon_instance != null else ""


func get_display_name() -> String:
	var species_name := String(species_data.get("name", digimon_key.capitalize()))
	if digimon_instance == null:
		return species_name
	return digimon_instance.get_display_name(species_name)


func get_level() -> int:
	return digimon_instance.level if digimon_instance != null else 1


func get_potential() -> int:
	return digimon_instance.potential if digimon_instance != null else 0


func get_final_stat(stat_key: String) -> int:
	if digimon_instance == null:
		return 0
	if battle_state != null:
		return battle_state.get_stat(_stat_calculator, species_data, stat_key)
	return _stat_calculator.get_stat(digimon_instance, species_data, stat_key)


func get_final_mov() -> int:
	if digimon_instance == null:
		return 4
	if battle_state != null:
		return battle_state.get_mov(_stat_calculator, species_data)
	return _stat_calculator.get_mov(digimon_instance, species_data)


func get_movement_type() -> String:
	return String(species_data.get("movementType", "ground"))


func get_instance_snapshot() -> Dictionary:
	if digimon_instance == null:
		return {}
	var snapshot := digimon_instance.to_dict()
	snapshot["speciesName"] = String(species_data.get("name", ""))
	snapshot["rank"] = String(species_data.get("rank", ""))
	snapshot["MOV"] = get_final_mov()
	snapshot["movementType"] = get_movement_type()
	snapshot["stats"] = _stat_calculator.get_all_stats(digimon_instance, species_data)
	return snapshot
