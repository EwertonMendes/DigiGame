extends RefCounted
class_name PlayerRoster

var bits: int = 0
var progression_flags: Dictionary = {}
var quest_states: Dictionary = {}

var _instances_by_id: Dictionary = {}
var _instance_id_by_key: Dictionary = {}
var _roster_key_by_id: Dictionary = {}
var _active_party_ids: Array[String] = []
var _digi_data_by_seed: Dictionary = {}


func is_empty() -> bool:
	return _instances_by_id.is_empty()


func add_instance(instance: DigimonInstance, preferred_key: String = "", species_name: String = "") -> String:
	if instance == null or instance.id.strip_edges().is_empty():
		return ""
	if _instances_by_id.has(instance.id):
		return String(_roster_key_by_id.get(instance.id, ""))
	var base_key := preferred_key.to_lower().strip_edges()
	if base_key.is_empty():
		base_key = species_name.to_lower().strip_edges().replace(" ", "_")
	if base_key.is_empty():
		base_key = "digimon"
	var key := _unique_key(base_key)
	_instances_by_id[instance.id] = instance
	_instance_id_by_key[key] = instance.id
	_roster_key_by_id[instance.id] = key
	return key


func replace_at_key(instance: DigimonInstance, roster_key: String, species_name: String = "") -> bool:
	if instance == null:
		return false
	var key := roster_key.to_lower().strip_edges()
	if key.is_empty():
		return not add_instance(instance, "", species_name).is_empty()
	var old_id := String(_instance_id_by_key.get(key, ""))
	if old_id.is_empty():
		return not add_instance(instance, key, species_name).is_empty()
	if old_id != instance.id and _instances_by_id.has(instance.id):
		return false
	_instances_by_id.erase(old_id)
	_roster_key_by_id.erase(old_id)
	_instances_by_id[instance.id] = instance
	_instance_id_by_key[key] = instance.id
	_roster_key_by_id[instance.id] = key
	var active_index := _active_party_ids.find(old_id)
	if active_index >= 0:
		_active_party_ids[active_index] = instance.id
	return true


func get_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	var keys: Array[String] = []
	for raw_key in _instance_id_by_key.keys():
		keys.append(String(raw_key))
	keys.sort()
	for key: String in keys:
		var instance_id := String(_instance_id_by_key.get(key, ""))
		var instance = _instances_by_id.get(instance_id)
		if instance is DigimonInstance:
			result.append(instance)
	return result


func get_instance(instance_id: String) -> DigimonInstance:
	var instance = _instances_by_id.get(instance_id)
	return instance as DigimonInstance if instance is DigimonInstance else null


func get_instance_by_key(roster_key: String) -> DigimonInstance:
	var instance_id := String(_instance_id_by_key.get(roster_key.to_lower().strip_edges(), ""))
	return get_instance(instance_id)


func get_key_for_instance(instance_id: String) -> String:
	return String(_roster_key_by_id.get(instance_id, ""))


func has_instance(instance_id: String) -> bool:
	return _instances_by_id.has(instance_id)


func get_active_party_ids() -> Array[String]:
	return _active_party_ids.duplicate()


func get_active_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance_id: String in _active_party_ids:
		var instance := get_instance(instance_id)
		if instance != null:
			result.append(instance)
	return result


func get_reserve_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance: DigimonInstance in get_instances():
		if not _active_party_ids.has(instance.id):
			result.append(instance)
	return result


func set_active_party_ids(instance_ids: Array[String], minimum_size: int, maximum_size: int) -> bool:
	if instance_ids.size() < minimum_size or instance_ids.size() > maximum_size:
		return false
	var normalized: Array[String] = []
	for instance_id: String in instance_ids:
		var clean_id := instance_id.strip_edges()
		if clean_id.is_empty() or not _instances_by_id.has(clean_id) or normalized.has(clean_id):
			return false
		normalized.append(clean_id)
	_active_party_ids = normalized
	return true


func add_digi_data(species_seed: String, amount: int) -> int:
	var seed := species_seed.strip_edges()
	if seed.is_empty() or amount <= 0:
		return get_digi_data(seed)
	_digi_data_by_seed[seed] = get_digi_data(seed) + amount
	return int(_digi_data_by_seed[seed])


func consume_digi_data(species_seed: String, amount: int) -> bool:
	var seed := species_seed.strip_edges()
	var cost := maxi(0, amount)
	if seed.is_empty() or get_digi_data(seed) < cost:
		return false
	var remaining := get_digi_data(seed) - cost
	if remaining <= 0:
		_digi_data_by_seed.erase(seed)
	else:
		_digi_data_by_seed[seed] = remaining
	return true


func get_digi_data(species_seed: String) -> int:
	return maxi(0, int(_digi_data_by_seed.get(species_seed.strip_edges(), 0)))


func get_all_digi_data() -> Dictionary:
	return _digi_data_by_seed.duplicate(true)


func to_dict() -> Dictionary:
	var entries: Array[Dictionary] = []
	for instance: DigimonInstance in get_instances():
		entries.append({
			"rosterKey": get_key_for_instance(instance.id),
			"instance": instance.to_dict(),
		})
	return {
		"instances": entries,
		"activePartyIds": get_active_party_ids(),
		"bits": bits,
		"digiData": get_all_digi_data(),
		"progressionFlags": progression_flags.duplicate(true),
		"questStates": quest_states.duplicate(true),
	}


func load_dict(data: Dictionary) -> void:
	_instances_by_id.clear()
	_instance_id_by_key.clear()
	_roster_key_by_id.clear()
	_active_party_ids.clear()
	_digi_data_by_seed.clear()
	bits = maxi(0, int(data.get("bits", 0)))
	progression_flags = _safe_dictionary(data.get("progressionFlags", {}))
	quest_states = _safe_dictionary(data.get("questStates", {}))

	var entries = data.get("instances", [])
	if entries is Array:
		for raw_entry in entries:
			if not raw_entry is Dictionary:
				continue
			var entry := raw_entry as Dictionary
			var raw_instance = entry.get("instance", {})
			if not raw_instance is Dictionary:
				continue
			var instance := DigimonInstance.from_dict(raw_instance as Dictionary)
			if instance.species_seed.is_empty() or _instances_by_id.has(instance.id):
				continue
			add_instance(instance, String(entry.get("rosterKey", "")), "digimon")

	var raw_party = data.get("activePartyIds", [])
	if raw_party is Array:
		for raw_id in raw_party:
			var instance_id := String(raw_id)
			if _instances_by_id.has(instance_id) and not _active_party_ids.has(instance_id):
				_active_party_ids.append(instance_id)

	var raw_data = data.get("digiData", {})
	if raw_data is Dictionary:
		for raw_seed in raw_data.keys():
			var seed := String(raw_seed).strip_edges()
			var amount := maxi(0, int(raw_data[raw_seed]))
			if not seed.is_empty() and amount > 0:
				_digi_data_by_seed[seed] = amount


func _unique_key(base_key: String) -> String:
	var clean := base_key.to_lower().strip_edges()
	if clean.is_empty():
		clean = "digimon"
	if not _instance_id_by_key.has(clean):
		return clean
	var suffix := 2
	while _instance_id_by_key.has("%s_%d" % [clean, suffix]):
		suffix += 1
	return "%s_%d" % [clean, suffix]


func _safe_dictionary(value) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
