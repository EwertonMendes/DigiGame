extends Node

signal active_party_changed(active_party: Array)

const MAX_ACTIVE_PARTY_SIZE := 3
const MIN_ACTIVE_PARTY_SIZE := 1
const DEFAULT_ACTIVE_PARTY := ["agumon", "gabumon", "greymon"]
const DIGIMON_RESOURCE_TEMPLATE := "res://assets/resources/%s.tres"

var _active_party: Array[String] = ["agumon", "gabumon", "greymon"]


func get_active_party() -> Array[String]:
	return _active_party.duplicate()


func set_active_party(party: Array) -> bool:
	var normalized: Array[String] = []
	for raw_key in party:
		var key := String(raw_key).strip_edges().to_lower()
		if key.is_empty():
			continue
		if not _is_valid_digimon_key(key):
			return false
		normalized.append(key)

	if normalized.size() < MIN_ACTIVE_PARTY_SIZE or normalized.size() > MAX_ACTIVE_PARTY_SIZE:
		return false
	if normalized == _active_party:
		return true

	_active_party = normalized
	active_party_changed.emit(get_active_party())
	return true


func reset_active_party() -> void:
	if _active_party == DEFAULT_ACTIVE_PARTY:
		return
	_active_party = []
	for key in DEFAULT_ACTIVE_PARTY:
		_active_party.append(String(key))
	active_party_changed.emit(get_active_party())


func get_max_active_party_size() -> int:
	return MAX_ACTIVE_PARTY_SIZE


func _is_valid_digimon_key(key: String) -> bool:
	return ResourceLoader.exists(DIGIMON_RESOURCE_TEMPLATE % key)
