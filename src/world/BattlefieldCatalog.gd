extends RefCounted
class_name BattlefieldCatalog

const DefinitionScript = preload("res://src/world/BattlefieldDefinition.gd")
const DATABASE_PATH := "res://database/battlefields.json"

var _definitions: Dictionary = {}
var _order: Array[String] = []
var _default_id := ""
var _loaded := false
var _errors := PackedStringArray()


func load_default() -> bool:
	if _loaded:
		return _errors.is_empty() and not _definitions.is_empty()
	_loaded = true
	_definitions.clear()
	_order.clear()
	_errors.clear()

	if not FileAccess.file_exists(DATABASE_PATH):
		_errors.append("Battlefield catalog is missing: %s" % DATABASE_PATH)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATABASE_PATH))
	if not parsed is Dictionary:
		_errors.append("Battlefield catalog root must be a JSON object.")
		return false

	var root := parsed as Dictionary
	_default_id = String(root.get("default", "")).strip_edges()
	var raw_definitions = root.get("battlefields", [])
	if not raw_definitions is Array:
		_errors.append("Battlefield catalog requires a 'battlefields' array.")
		return false

	for raw_definition in raw_definitions:
		if not raw_definition is Dictionary:
			_errors.append("Battlefield catalog contains a non-object entry.")
			continue
		var definition := DefinitionScript.from_dict(raw_definition as Dictionary) as BattlefieldDefinition
		var definition_errors := definition.validate()
		for error in definition_errors:
			_errors.append(String(error))
		if definition.battlefield_id.is_empty() or _definitions.has(definition.battlefield_id):
			if _definitions.has(definition.battlefield_id):
				_errors.append("Duplicate battlefield id '%s'." % definition.battlefield_id)
			continue
		_definitions[definition.battlefield_id] = definition
		_order.append(definition.battlefield_id)

	if _default_id.is_empty() and not _order.is_empty():
		_default_id = _order[0]
	if not _default_id.is_empty() and not _definitions.has(_default_id):
		_errors.append("Battlefield catalog default '%s' does not exist." % _default_id)
	return _errors.is_empty() and not _definitions.is_empty()


func validation_errors() -> PackedStringArray:
	load_default()
	return _errors.duplicate()


func all_definitions() -> Array[BattlefieldDefinition]:
	load_default()
	var result: Array[BattlefieldDefinition] = []
	for battlefield_id: String in _order:
		var definition := _definitions.get(battlefield_id) as BattlefieldDefinition
		if definition != null:
			result.append(definition)
	return result


func get_by_id(battlefield_id: String) -> BattlefieldDefinition:
	load_default()
	return _definitions.get(battlefield_id.strip_edges()) as BattlefieldDefinition


func default_definition() -> BattlefieldDefinition:
	load_default()
	return get_by_id(_default_id)


func compatible_definitions(player_footprints: Array, enemy_footprints: Array) -> Array[BattlefieldDefinition]:
	var result: Array[BattlefieldDefinition] = []
	for definition: BattlefieldDefinition in all_definitions():
		if definition.supports_teams(player_footprints, enemy_footprints):
			result.append(definition)
	return result


func select_for_battle(
	player_footprints: Array,
	enemy_footprints: Array,
	preferred_id: String = "",
	deterministic_seed: int = 0
) -> BattlefieldDefinition:
	load_default()
	var preferred := get_by_id(preferred_id)
	if preferred != null:
		return preferred

	var compatible := compatible_definitions(player_footprints, enemy_footprints)
	if compatible.is_empty():
		return default_definition()

	var fallback := default_definition()
	if deterministic_seed == 0 and fallback != null and compatible.has(fallback):
		return fallback
	if deterministic_seed == 0:
		return compatible[0]

	var index := absi(deterministic_seed) % compatible.size()
	return compatible[index]
