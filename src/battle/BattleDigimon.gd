extends RefCounted
class_name BattleDigimon

var instance: DigimonInstance
var team: String = "player"
var current_hp: int = 1
# Kept as current_mp internally for compatibility; gameplay presents this as SP.
var current_mp: int = 0
var initiative: float = 0.0
var last_recovery_cost: float = 100.0
var temporary_modifiers: Dictionary = {
	"hp": 0,
	"mp": 0,
	"atk": 0,
	"def": 0,
	"int": 0,
	"speed": 0,
	"mov": 0,
}
var status_percent_modifiers: Dictionary = {
	"hp": 0.0,
	"mp": 0.0,
	"atk": 0.0,
	"def": 0.0,
	"int": 0.0,
	"speed": 0.0,
	"mov": 0.0,
}
var statuses: Array[Dictionary] = []


func _init(source_instance: DigimonInstance = null, battle_team: String = "player") -> void:
	instance = source_instance
	team = battle_team
	if instance != null:
		current_hp = instance.current_hp
		current_mp = instance.current_mp


func get_stat(calculator, species: Dictionary, stat_key: String) -> int:
	if instance == null or calculator == null:
		return 0
	var key := "mp" if stat_key.to_lower() == "sp" else stat_key.to_lower()
	var base_value := int(calculator.get_stat(instance, species, key))
	var additive := int(temporary_modifiers.get(key, 0))
	var percent := float(status_percent_modifiers.get(key, 0.0))
	return maxi(0, int(round(float(base_value + additive) * (1.0 + percent / 100.0))))


func get_mov(calculator, species: Dictionary) -> int:
	if instance == null or calculator == null:
		return 0
	var base_value := int(calculator.get_mov(instance, species)) + int(temporary_modifiers.get("mov", 0))
	var percent := float(status_percent_modifiers.get("mov", 0.0))
	return clampi(int(round(float(base_value) * (1.0 + percent / 100.0))), 0, 8)


func get_current_sp() -> int:
	return current_mp


func spend_sp(amount: int) -> bool:
	var cost := maxi(0, amount)
	if current_mp < cost:
		return false
	current_mp -= cost
	return true


func restore_sp(amount: int, maximum: int) -> int:
	var before := current_mp
	current_mp = clampi(current_mp + maxi(0, amount), 0, maxi(0, maximum))
	return current_mp - before


func take_damage(amount: int) -> int:
	var damage := maxi(0, amount)
	var before := current_hp
	current_hp = maxi(0, current_hp - damage)
	return before - current_hp


func heal(amount: int, maximum: int) -> int:
	var before := current_hp
	current_hp = clampi(current_hp + maxi(0, amount), 0, maxi(1, maximum))
	return current_hp - before


func is_knocked_out() -> bool:
	return current_hp <= 0


func set_initiative(value: float) -> void:
	initiative = value


func consume_initiative(recovery_cost: float) -> void:
	last_recovery_cost = maxf(0.0, recovery_cost)
	initiative -= last_recovery_cost


func add_status(status_id: String, duration: int, source_id: String, definition: Dictionary) -> void:
	for index in range(statuses.size()):
		if String(statuses[index].get("id", "")) == status_id:
			statuses[index]["duration"] = maxi(1, duration)
			statuses[index]["source_id"] = source_id
			statuses[index]["definition"] = definition.duplicate(true)
			statuses[index]["fresh"] = true
			return
	statuses.append({
		"id": status_id,
		"duration": maxi(1, duration),
		"source_id": source_id,
		"definition": definition.duplicate(true),
		"fresh": true,
	})


func remove_status(status_id: String) -> bool:
	for index in range(statuses.size() - 1, -1, -1):
		if String(statuses[index].get("id", "")) != status_id:
			continue
		statuses.remove_at(index)
		return true
	return false


func has_status(status_id: String) -> bool:
	for status: Dictionary in statuses:
		if String(status.get("id", "")) == status_id:
			return true
	return false


func get_statuses() -> Array[Dictionary]:
	return statuses.duplicate(true)


func tick_status_durations() -> Array[String]:
	var expired: Array[String] = []
	for index in range(statuses.size() - 1, -1, -1):
		if bool(statuses[index].get("fresh", false)):
			statuses[index]["fresh"] = false
			continue
		statuses[index]["duration"] = int(statuses[index].get("duration", 1)) - 1
		if int(statuses[index]["duration"]) > 0:
			continue
		expired.append(String(statuses[index].get("id", "")))
		statuses.remove_at(index)
	return expired


func set_status_percent_modifiers(modifiers: Dictionary) -> void:
	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed", "mov"]:
		status_percent_modifiers[stat_key] = float(modifiers.get(stat_key, 0.0))


func commit_resources_to_instance() -> void:
	if instance == null:
		return
	instance.current_hp = maxi(0, current_hp)
	instance.current_mp = maxi(0, current_mp)
