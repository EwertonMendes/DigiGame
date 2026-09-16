extends Node

# Scene transitions destroy the Hub before the battle runtime is created. This
# tiny session object owns the one-shot encounter payload that crosses that
# boundary. It intentionally contains no encounter-generation logic: producers
# stage validated data, and the battle runtime consumes it exactly once.
var _pending_encounter: Dictionary = {}


func stage_encounter(config: Dictionary) -> bool:
	if config.is_empty():
		return false
	_pending_encounter = config.duplicate(true)
	return true


func has_pending_encounter() -> bool:
	return not _pending_encounter.is_empty()


func peek_pending_encounter() -> Dictionary:
	return _pending_encounter.duplicate(true)


func consume_pending_encounter() -> Dictionary:
	var result := _pending_encounter.duplicate(true)
	_pending_encounter.clear()
	return result


func clear_pending_encounter() -> void:
	_pending_encounter.clear()
