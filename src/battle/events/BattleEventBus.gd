extends RefCounted
class_name BattleEventBus

signal event_emitted(event: Dictionary)

var history: Array[Dictionary] = []


func emit_event(event_type: String, payload: Dictionary = {}) -> Dictionary:
	var event := payload.duplicate(true)
	event["type"] = event_type
	history.append(event)
	if history.size() > 200:
		history.pop_front()
	event_emitted.emit(event)
	return event


func clear() -> void:
	history.clear()
