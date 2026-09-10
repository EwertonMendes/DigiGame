extends RefCounted
class_name BattleDigimon

var instance: DigimonInstance
var team: String = "player"
var current_hp: int = 1
var current_mp: int = 0
var initiative: float = 0.0
var last_recovery_cost: float = 100.0
var temporary_modifiers: Dictionary = {
	"hp": 0,
	"mp": 0,
	"atk": 0,
	"def": 0,
	"speed": 0,
	"mov": 0,
}
var statuses: Array[String] = []


func _init(source_instance: DigimonInstance = null, battle_team: String = "player") -> void:
	instance = source_instance
	team = battle_team
	if instance != null:
		current_hp = instance.current_hp
		current_mp = instance.current_mp


func get_stat(calculator, species: Dictionary, stat_key: String) -> int:
	if instance == null or calculator == null:
		return 0
	var base_value := int(calculator.get_stat(instance, species, stat_key))
	return maxi(0, base_value + int(temporary_modifiers.get(stat_key, 0)))


func get_mov(calculator, species: Dictionary) -> int:
	if instance == null or calculator == null:
		return 0
	return clampi(int(calculator.get_mov(instance, species)) + int(temporary_modifiers.get("mov", 0)), 0, 8)


func set_initiative(value: float) -> void:
	initiative = value


func consume_initiative(recovery_cost: float) -> void:
	last_recovery_cost = maxf(0.0, recovery_cost)
	initiative -= last_recovery_cost


func commit_resources_to_instance() -> void:
	if instance == null:
		return
	instance.current_hp = maxi(0, current_hp)
	instance.current_mp = maxi(0, current_mp)
