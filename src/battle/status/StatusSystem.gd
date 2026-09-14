extends RefCounted
class_name StatusSystem

const STATUS_PATH := "res://database/statuses.json"

var _definitions: Dictionary = {}


func load_default() -> bool:
	_definitions.clear()
	if not FileAccess.file_exists(STATUS_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATUS_PATH))
	if not parsed is Array:
		return false
	for raw_status in parsed:
		if not raw_status is Dictionary:
			continue
		var status_id := String(raw_status.get("id", ""))
		if not status_id.is_empty():
			_definitions[status_id] = raw_status.duplicate(true)
	return not _definitions.is_empty()


func apply(actor: Node, status_id: String, duration_override: int = -1, source_id: String = "") -> bool:
	if actor == null or not _definitions.has(status_id):
		return false
	var battle_state = actor.get("battle_state")
	if battle_state == null or not battle_state.has_method("add_status"):
		return false
	var definition: Dictionary = (_definitions[status_id] as Dictionary).duplicate(true)
	var duration := duration_override if duration_override > 0 else int(definition.get("duration", 1))
	battle_state.call("add_status", status_id, duration, source_id, definition)
	_refresh_modifiers(actor)
	return true


func remove(actor: Node, status_id: String) -> bool:
	if actor == null:
		return false
	var battle_state = actor.get("battle_state")
	if battle_state == null or not battle_state.has_method("remove_status"):
		return false
	var removed := bool(battle_state.call("remove_status", status_id))
	if removed:
		_refresh_modifiers(actor)
	return removed


func has_status(actor: Node, status_id: String) -> bool:
	return remaining_duration(actor, status_id) > 0


func remaining_duration(actor: Node, status_id: String) -> int:
	for status: Dictionary in get_statuses(actor):
		if String(status.get("id", "")) == status_id:
			return int(status.get("duration", 0))
	return 0


func on_turn_start(actor: Node) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if actor == null:
		return events
	var battle_state = actor.get("battle_state")
	if battle_state == null or not battle_state.has_method("get_statuses"):
		return events
	var max_hp := maxi(1, int(actor.call("get_final_stat", "hp"))) if actor.has_method("get_final_stat") else 1
	for status in battle_state.call("get_statuses"):
		if not status is Dictionary:
			continue
		var definition = status.get("definition", {})
		if not definition is Dictionary:
			continue
		if bool(definition.get("executesOnFinalTurn", false)) and int(status.get("duration", 0)) <= 1:
			var species_raw = actor.get("species_data")
			var species: Dictionary = species_raw if species_raw is Dictionary else {}
			var encounter_profile := String(actor.get_meta("encounter_profile", "")).to_lower()
			var is_boss := encounter_profile == "boss" or bool(species.get("isBoss", species.get("boss", false)))
			var execution_damage := int(battle_state.current_hp)
			if is_boss:
				execution_damage = maxi(1, int(round(float(max_hp) * float(definition.get("bossMaxHpDamagePercent", 12.0)) / 100.0)))
			battle_state.current_hp = maxi(0, int(battle_state.current_hp) - execution_damage)
			events.append({"type": "doom", "status": String(status.get("id", "")), "damage": execution_damage, "target": actor})
			continue
		var percent := float(definition.get("turnDamagePercentMaxHp", 0.0))
		if percent <= 0.0:
			continue
		var damage := maxi(1, int(round(float(max_hp) * percent / 100.0)))
		battle_state.current_hp = maxi(0, int(battle_state.current_hp) - damage)
		events.append({"type": "status_damage", "status": String(status.get("id", "")), "damage": damage, "target": actor})
	return events


func prevents_action(actor: Node) -> bool:
	for status: Dictionary in get_statuses(actor):
		var definition = status.get("definition", {})
		if definition is Dictionary and bool((definition as Dictionary).get("preventsAction", false)):
			return true
	return false


func accuracy_modifier(actor: Node) -> float:
	return _numeric_status_total(actor, "accuracyPercent")


func reaction_percent(actor: Node, damage_class: String) -> float:
	var key := "reflectPercent" if damage_class.to_lower() == "special" else "counterPercent"
	return maxf(0.0, _numeric_status_total(actor, key))


func on_turn_end(actor: Node) -> Array[String]:
	var expired: Array[String] = []
	if actor == null:
		return expired
	var battle_state = actor.get("battle_state")
	if battle_state == null or not battle_state.has_method("tick_status_durations"):
		return expired
	expired = battle_state.call("tick_status_durations")
	_refresh_modifiers(actor)
	return expired


func get_statuses(actor: Node) -> Array[Dictionary]:
	if actor == null:
		return []
	var battle_state = actor.get("battle_state")
	if battle_state != null and battle_state.has_method("get_statuses"):
		return battle_state.call("get_statuses")
	return []


func _numeric_status_total(actor: Node, key: String) -> float:
	var total := 0.0
	for status: Dictionary in get_statuses(actor):
		var definition = status.get("definition", {})
		if definition is Dictionary:
			total += float((definition as Dictionary).get(key, 0.0))
	return total


func _refresh_modifiers(actor: Node) -> void:
	var battle_state = actor.get("battle_state") if actor != null else null
	if battle_state == null or not battle_state.has_method("set_status_percent_modifiers"):
		return
	var totals := {"hp": 0.0, "mp": 0.0, "atk": 0.0, "def": 0.0, "int": 0.0, "speed": 0.0, "mov": 0.0}
	if battle_state.has_method("get_statuses"):
		for status in battle_state.call("get_statuses"):
			if not status is Dictionary:
				continue
			var definition = status.get("definition", {})
			if not definition is Dictionary:
				continue
			var modifiers = definition.get("modifiers", {})
			if not modifiers is Dictionary:
				continue
			for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed", "mov"]:
				var percent_key := "%sPercent" % stat_key
				if modifiers.has(percent_key):
					totals[stat_key] = float(totals.get(stat_key, 0.0)) + float(modifiers[percent_key])
	battle_state.call("set_status_percent_modifiers", totals)
