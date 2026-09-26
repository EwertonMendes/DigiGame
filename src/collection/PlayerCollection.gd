extends RefCounted
class_name PlayerCollection

const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")

const LOCATION_PARTY := "party"
const LOCATION_STORAGE := "storage"
const LOCATION_HOSPITAL := "hospital"

const SQUAD_ROLE_ACTIVE := "active"
const SQUAD_ROLE_RESERVE := "reserve"
const DEFAULT_RESERVE_LIMIT := 3

var bits: int = 0
var progression_flags: Dictionary = {}
var quest_states: Dictionary = {}
var unlocked_technique_records: Array[String] = []
var technique_research: Dictionary = {}
var inventory: Dictionary = {}

var _instances_by_id: Dictionary = {}
var _instance_id_by_key: Dictionary = {}
var _collection_key_by_id: Dictionary = {}
var _active_party_ids: Array[String] = []
var _reserve_party_ids: Array[String] = []
var _hospital_ids: Array[String] = []
# Hospitalized Digimon remember the exact Squad role and index they left from.
# This is durable domain state, not UI state, so discharge can restore intent.
var _hospital_return_slots: Dictionary = {}
var _digi_data_by_seed: Dictionary = {}
var _fusion_data_by_id: Dictionary = {}

func is_empty() -> bool:
	return _instances_by_id.is_empty()

func add_instance(instance: DigimonInstance, preferred_key: String = "", species_name: String = "") -> String:
	if instance == null or instance.id.strip_edges().is_empty():
		return ""
	if _instances_by_id.has(instance.id):
		return String(_collection_key_by_id.get(instance.id, ""))
	var base_key := preferred_key.to_lower().strip_edges()
	if base_key.is_empty():
		base_key = species_name.to_lower().strip_edges().replace(" ", "_")
	if base_key.is_empty():
		base_key = "digimon"
	var key := _unique_key(base_key)
	_instances_by_id[instance.id] = instance
	_instance_id_by_key[key] = instance.id
	_collection_key_by_id[instance.id] = key
	return key

func replace_at_key(instance: DigimonInstance, collection_key: String, species_name: String = "") -> bool:
	if instance == null:
		return false
	var key := collection_key.to_lower().strip_edges()
	if key.is_empty():
		return not add_instance(instance, "", species_name).is_empty()
	var old_id := String(_instance_id_by_key.get(key, ""))
	if old_id.is_empty():
		return not add_instance(instance, key, species_name).is_empty()
	if old_id != instance.id and _instances_by_id.has(instance.id):
		return false
	_instances_by_id.erase(old_id)
	_collection_key_by_id.erase(old_id)
	_instances_by_id[instance.id] = instance
	_instance_id_by_key[key] = instance.id
	_collection_key_by_id[instance.id] = key
	var active_index := _active_party_ids.find(old_id)
	if active_index >= 0:
		_active_party_ids[active_index] = instance.id
	var reserve_index := _reserve_party_ids.find(old_id)
	if reserve_index >= 0:
		_reserve_party_ids[reserve_index] = instance.id
	var hospital_index := _hospital_ids.find(old_id)
	if hospital_index >= 0:
		_hospital_ids[hospital_index] = instance.id
	if _hospital_return_slots.has(old_id):
		var return_slot = _hospital_return_slots.get(old_id, {})
		_hospital_return_slots.erase(old_id)
		_hospital_return_slots[instance.id] = (return_slot as Dictionary).duplicate(true) if return_slot is Dictionary else {}
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

func get_instance_by_key(collection_key: String) -> DigimonInstance:
	var instance_id := String(_instance_id_by_key.get(collection_key.to_lower().strip_edges(), ""))
	return get_instance(instance_id)

func get_key_for_instance(instance_id: String) -> String:
	return String(_collection_key_by_id.get(instance_id, ""))

func has_instance(instance_id: String) -> bool:
	return _instances_by_id.has(instance_id)

func remove_instance(instance_id: String) -> bool:
	var clean_id := instance_id.strip_edges()
	if clean_id.is_empty() or not _instances_by_id.has(clean_id):
		return false
	_active_party_ids.erase(clean_id)
	_reserve_party_ids.erase(clean_id)
	_hospital_ids.erase(clean_id)
	_hospital_return_slots.erase(clean_id)
	return _erase_instance_record(clean_id)


func remove_storage_instance(instance_id: String) -> bool:
	var clean_id := instance_id.strip_edges()
	if clean_id.is_empty() or get_location(clean_id) != LOCATION_STORAGE:
		return false
	return _erase_instance_record(clean_id)


# Compatibility for older call sites while the prototype vocabulary is cleaned up.
# "Reserve" now means the three-member battle bench; this alias still removes only Storage.
func remove_reserve_instance(instance_id: String) -> bool:
	return remove_storage_instance(instance_id)

func _erase_instance_record(instance_id: String) -> bool:
	if not _instances_by_id.has(instance_id):
		return false
	var key := String(_collection_key_by_id.get(instance_id, ""))
	_instances_by_id.erase(instance_id)
	_collection_key_by_id.erase(instance_id)
	if not key.is_empty():
		_instance_id_by_key.erase(key)
	return true

func get_active_party_ids() -> Array[String]:
	return _active_party_ids.duplicate()


func get_reserve_party_ids() -> Array[String]:
	return _reserve_party_ids.duplicate()


func get_squad_ids() -> Array[String]:
	var result := _active_party_ids.duplicate()
	result.append_array(_reserve_party_ids)
	return result


func get_active_instances() -> Array[DigimonInstance]:
	return _instances_for_ids(_active_party_ids)


func get_reserve_party_instances() -> Array[DigimonInstance]:
	return _instances_for_ids(_reserve_party_ids)


func get_squad_instances() -> Array[DigimonInstance]:
	var result := get_active_instances()
	result.append_array(get_reserve_party_instances())
	return result


func get_hospital_ids() -> Array[String]:
	return _hospital_ids.duplicate()


func get_hospital_instances() -> Array[DigimonInstance]:
	return _instances_for_ids(_hospital_ids)


func get_storage_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance: DigimonInstance in get_instances():
		if get_location(instance.id) == LOCATION_STORAGE:
			result.append(instance)
	return result


func _instances_for_ids(instance_ids: Array[String]) -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance_id: String in instance_ids:
		var instance := get_instance(instance_id)
		if instance != null:
			result.append(instance)
	return result


func get_location(instance_id: String) -> String:
	var clean_id := instance_id.strip_edges()
	if not _instances_by_id.has(clean_id):
		return ""
	if _hospital_ids.has(clean_id):
		return LOCATION_HOSPITAL
	if _active_party_ids.has(clean_id) or _reserve_party_ids.has(clean_id):
		return LOCATION_PARTY
	return LOCATION_STORAGE


func get_squad_role(instance_id: String) -> String:
	var clean_id := instance_id.strip_edges()
	if _active_party_ids.has(clean_id):
		return SQUAD_ROLE_ACTIVE
	if _reserve_party_ids.has(clean_id):
		return SQUAD_ROLE_RESERVE
	return ""


func is_hospitalized(instance_id: String) -> bool:
	return get_location(instance_id) == LOCATION_HOSPITAL


func set_squad_ids(
	active_ids: Array[String],
	reserve_ids: Array[String],
	minimum_active_size: int,
	maximum_active_size: int,
	maximum_reserve_size: int
) -> bool:
	if active_ids.size() < maxi(0, minimum_active_size) or active_ids.size() > maxi(0, maximum_active_size):
		return false
	if reserve_ids.size() > maxi(0, maximum_reserve_size):
		return false

	var seen: Dictionary = {}
	var normalized_active: Array[String] = []
	var normalized_reserve: Array[String] = []
	for instance_id: String in active_ids:
		var clean_id := instance_id.strip_edges()
		if not _valid_squad_member(clean_id, seen):
			return false
		seen[clean_id] = true
		normalized_active.append(clean_id)
	for instance_id: String in reserve_ids:
		var clean_id := instance_id.strip_edges()
		if not _valid_squad_member(clean_id, seen):
			return false
		seen[clean_id] = true
		normalized_reserve.append(clean_id)

	_active_party_ids = normalized_active
	_reserve_party_ids = normalized_reserve
	return true


func _valid_squad_member(instance_id: String, seen: Dictionary) -> bool:
	return (
		not instance_id.is_empty()
		and _instances_by_id.has(instance_id)
		and not _hospital_ids.has(instance_id)
		and not seen.has(instance_id)
	)


func set_active_party_ids(instance_ids: Array[String], minimum_size: int, maximum_size: int) -> bool:
	var reserve := _reserve_party_ids.duplicate()
	for instance_id: String in instance_ids:
		reserve.erase(instance_id)
	return set_squad_ids(instance_ids, reserve, minimum_size, maximum_size, maxi(DEFAULT_RESERVE_LIMIT, reserve.size()))


func set_reserve_party_ids(instance_ids: Array[String], maximum_size: int = DEFAULT_RESERVE_LIMIT) -> bool:
	var active := _active_party_ids.duplicate()
	for instance_id: String in instance_ids:
		active.erase(instance_id)
	return set_squad_ids(active, instance_ids, 0, maxi(active.size(), 3), maximum_size)


func admit_to_hospital(instance_id: String) -> bool:
	var clean_id := instance_id.strip_edges()
	var role := get_squad_role(clean_id)
	if clean_id.is_empty() or role.is_empty() or _hospital_ids.has(clean_id) or not _instances_by_id.has(clean_id):
		return false

	var index := _active_party_ids.find(clean_id) if role == SQUAD_ROLE_ACTIVE else _reserve_party_ids.find(clean_id)
	if index < 0:
		return false
	_hospital_return_slots[clean_id] = {"role": role, "index": index}
	if role == SQUAD_ROLE_ACTIVE:
		_active_party_ids.remove_at(index)
	else:
		_reserve_party_ids.remove_at(index)
	_hospital_ids.append(clean_id)
	return true


func cancel_hospital_admission(instance_id: String) -> bool:
	var clean_id := instance_id.strip_edges()
	var hospital_index := _hospital_ids.find(clean_id)
	if hospital_index < 0:
		return false
	var return_slot = _hospital_return_slots.get(clean_id, {})
	var role := String((return_slot as Dictionary).get("role", "")) if return_slot is Dictionary else ""
	var index := int((return_slot as Dictionary).get("index", 0)) if return_slot is Dictionary else 0
	_hospital_ids.remove_at(hospital_index)
	_hospital_return_slots.erase(clean_id)
	if role == SQUAD_ROLE_RESERVE:
		_reserve_party_ids.insert(clampi(index, 0, _reserve_party_ids.size()), clean_id)
	else:
		_active_party_ids.insert(clampi(index, 0, _active_party_ids.size()), clean_id)
	return true


func discharge_from_hospital(instance_id: String, maximum_active_size: int, maximum_reserve_size: int) -> Dictionary:
	var result := {"location": "", "role": ""}
	var clean_id := instance_id.strip_edges()
	var hospital_index := _hospital_ids.find(clean_id)
	if clean_id.is_empty() or hospital_index < 0 or not _instances_by_id.has(clean_id):
		return result

	var return_slot = _hospital_return_slots.get(clean_id, {})
	var preferred_role := String((return_slot as Dictionary).get("role", SQUAD_ROLE_ACTIVE)) if return_slot is Dictionary else SQUAD_ROLE_ACTIVE
	var preferred_index := int((return_slot as Dictionary).get("index", 0)) if return_slot is Dictionary else 0
	_hospital_ids.remove_at(hospital_index)
	_hospital_return_slots.erase(clean_id)

	if preferred_role == SQUAD_ROLE_ACTIVE and _active_party_ids.size() < maxi(0, maximum_active_size):
		_active_party_ids.insert(clampi(preferred_index, 0, _active_party_ids.size()), clean_id)
		return {"location": LOCATION_PARTY, "role": SQUAD_ROLE_ACTIVE}
	if preferred_role == SQUAD_ROLE_RESERVE and _reserve_party_ids.size() < maxi(0, maximum_reserve_size):
		_reserve_party_ids.insert(clampi(preferred_index, 0, _reserve_party_ids.size()), clean_id)
		return {"location": LOCATION_PARTY, "role": SQUAD_ROLE_RESERVE}

	if _active_party_ids.size() < maxi(0, maximum_active_size):
		_active_party_ids.append(clean_id)
		return {"location": LOCATION_PARTY, "role": SQUAD_ROLE_ACTIVE}
	if _reserve_party_ids.size() < maxi(0, maximum_reserve_size):
		_reserve_party_ids.append(clean_id)
		return {"location": LOCATION_PARTY, "role": SQUAD_ROLE_RESERVE}

	return {"location": LOCATION_STORAGE, "role": ""}


func location_invariant_error() -> String:
	var seen: Dictionary = {}
	for instance_id: String in _active_party_ids:
		var error := _record_location(seen, instance_id, SQUAD_ROLE_ACTIVE)
		if not error.is_empty():
			return error
	for instance_id: String in _reserve_party_ids:
		var error := _record_location(seen, instance_id, SQUAD_ROLE_RESERVE)
		if not error.is_empty():
			return error
	for instance_id: String in _hospital_ids:
		var error := _record_location(seen, instance_id, LOCATION_HOSPITAL)
		if not error.is_empty():
			return error
	for raw_id in _hospital_return_slots.keys():
		var instance_id := String(raw_id)
		if not _hospital_ids.has(instance_id):
			return "Hospital return metadata references a Digimon outside the Hospital."
		var raw_slot = _hospital_return_slots[raw_id]
		if not raw_slot is Dictionary:
			return "Hospital return metadata contains an invalid slot."
		var role := String((raw_slot as Dictionary).get("role", ""))
		if role not in [SQUAD_ROLE_ACTIVE, SQUAD_ROLE_RESERVE] or int((raw_slot as Dictionary).get("index", -1)) < 0:
			return "Hospital return metadata contains an invalid Squad slot."
	return ""


func _record_location(seen: Dictionary, instance_id: String, location: String) -> String:
	if not _instances_by_id.has(instance_id):
		return "%s contains an unknown Digimon UUID." % location.capitalize()
	if seen.has(instance_id):
		return "A Digimon UUID occupies more than one collection location."
	seen[instance_id] = location
	return ""


func add_digi_data(species_seed: String, amount: int) -> int:
	if species_seed.strip_edges().is_empty() or amount <= 0:
		return get_digi_data(species_seed)
	var seed := species_seed.strip_edges()
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


func add_fusion_data(fusion_id: String, amount: int) -> int:
	var clean_id := fusion_id.to_lower().strip_edges()
	if clean_id.is_empty():
		return 0
	var before := get_fusion_data(clean_id)
	if amount <= 0 or before >= 100:
		return before
	_fusion_data_by_id[clean_id] = clampi(before + amount, 0, 100)
	return int(_fusion_data_by_id[clean_id])


func get_fusion_data(fusion_id: String) -> int:
	return clampi(int(_fusion_data_by_id.get(fusion_id.to_lower().strip_edges(), 0)), 0, 100)


func set_fusion_data(fusion_id: String, value: int) -> int:
	var clean_id := fusion_id.to_lower().strip_edges()
	if clean_id.is_empty():
		return 0
	var target := clampi(value, 0, 100)
	if target <= 0:
		_fusion_data_by_id.erase(clean_id)
		return 0
	_fusion_data_by_id[clean_id] = target
	return target


func get_all_fusion_data() -> Dictionary:
	return _fusion_data_by_id.duplicate(true)


func commit_fusion(
	material_ids: Array[String],
	result: DigimonInstance,
	item_costs: Dictionary,
	destination_role: String,
	destination_index: int,
	preferred_key: String,
	species_name: String
) -> bool:
	if result == null or result.id.strip_edges().is_empty() or _instances_by_id.has(result.id) or material_ids.size() < 2:
		return false
	var seen: Dictionary = {}
	var normalized: Array[String] = []
	for raw_id: String in material_ids:
		var instance_id := raw_id.strip_edges()
		if instance_id.is_empty() or seen.has(instance_id) or not _instances_by_id.has(instance_id) or _hospital_ids.has(instance_id):
			return false
		var material := get_instance(instance_id)
		if material == null or material.is_fainted() or not material.equipment.is_empty():
			return false
		seen[instance_id] = true
		normalized.append(instance_id)
	for raw_item_id in item_costs.keys():
		var item_id := String(raw_item_id).strip_edges()
		var amount := maxi(0, int(item_costs[raw_item_id]))
		if item_id.is_empty() or amount <= 0 or get_item_count(item_id) < amount:
			return false
	if destination_role not in ["", SQUAD_ROLE_ACTIVE, SQUAD_ROLE_RESERVE]:
		return false

	var rollback_state := to_dict()
	var next_active := _active_party_ids.duplicate()
	var next_reserve := _reserve_party_ids.duplicate()
	for instance_id: String in normalized:
		next_active.erase(instance_id)
		next_reserve.erase(instance_id)

	for instance_id: String in normalized:
		_hospital_return_slots.erase(instance_id)
		if not _erase_instance_record(instance_id):
			load_dict(rollback_state)
			return false

	for raw_item_id in item_costs.keys():
		var item_id := String(raw_item_id).strip_edges()
		var amount := maxi(0, int(item_costs[raw_item_id]))
		var remaining := get_item_count(item_id) - amount
		if remaining > 0:
			inventory[item_id] = remaining
		else:
			inventory.erase(item_id)

	if add_instance(result, preferred_key, species_name).is_empty():
		load_dict(rollback_state)
		return false
	if destination_role == SQUAD_ROLE_ACTIVE:
		next_active.insert(clampi(destination_index, 0, next_active.size()), result.id)
	elif destination_role == SQUAD_ROLE_RESERVE:
		next_reserve.insert(clampi(destination_index, 0, next_reserve.size()), result.id)
	_active_party_ids = next_active
	_reserve_party_ids = next_reserve
	if not location_invariant_error().is_empty():
		load_dict(rollback_state)
		return false
	return true


func get_item_count(item_id: String) -> int:
	return maxi(0, int(inventory.get(item_id.strip_edges(), 0)))

func add_item(item_id: String, amount: int = 1) -> int:
	var clean_id := item_id.strip_edges()
	if clean_id.is_empty() or amount <= 0:
		return get_item_count(clean_id)
	inventory[clean_id] = get_item_count(clean_id) + amount
	return int(inventory[clean_id])

func consume_item(item_id: String, amount: int = 1) -> bool:
	var clean_id := item_id.strip_edges()
	var cost := maxi(0, amount)
	if clean_id.is_empty() or cost <= 0 or get_item_count(clean_id) < cost:
		return false
	var remaining := get_item_count(clean_id) - cost
	if remaining == 0:
		inventory.erase(clean_id)
	else:
		inventory[clean_id] = remaining
	return true

func get_inventory() -> Dictionary:
	return inventory.duplicate(true)


func has_technique_record(skill_id: String) -> bool:
	return unlocked_technique_records.has(skill_id.strip_edges())


func unlock_technique_record(skill_id: String) -> bool:
	var clean_id := skill_id.strip_edges()
	if clean_id.is_empty() or unlocked_technique_records.has(clean_id):
		return false
	unlocked_technique_records.append(clean_id)
	technique_research.erase(clean_id)
	return true


func get_technique_research(skill_id: String) -> int:
	return clampi(int(technique_research.get(skill_id.strip_edges(), 0)), 0, 3)


func add_technique_research(skill_id: String, amount: int = 1) -> Dictionary:
	var clean_id := skill_id.strip_edges()
	var result := {"skill_id": clean_id, "old_points": 0, "new_points": 0, "unlocked": false}
	if clean_id.is_empty() or amount <= 0 or has_technique_record(clean_id):
		return result
	var old_points := get_technique_research(clean_id)
	var new_points := clampi(old_points + amount, 0, 3)
	result["old_points"] = old_points
	result["new_points"] = new_points
	if new_points >= 3:
		unlock_technique_record(clean_id)
		result["unlocked"] = true
	else:
		technique_research[clean_id] = new_points
	return result

func to_dict() -> Dictionary:
	var entries: Array[Dictionary] = []
	for instance: DigimonInstance in get_instances():
		entries.append({"collectionKey": get_key_for_instance(instance.id), "instance": instance.to_dict()})
	return {
		"instances": entries,
		"activeSquadIds": get_active_party_ids(),
		"reserveSquadIds": get_reserve_party_ids(),
		"hospitalIds": get_hospital_ids(),
		"hospitalReturnSlots": _hospital_return_slots.duplicate(true),
		"bits": bits,
		"digiData": get_all_digi_data(),
		"fusionData": get_all_fusion_data(),
		"progressionFlags": progression_flags.duplicate(true),
		"questStates": quest_states.duplicate(true),
		"unlockedTechniqueRecords": unlocked_technique_records.duplicate(),
		"techniqueResearch": technique_research.duplicate(true),
		"inventory": get_inventory(),
	}


func load_dict(data: Dictionary) -> void:
	_instances_by_id.clear()
	_instance_id_by_key.clear()
	_collection_key_by_id.clear()
	_active_party_ids.clear()
	_reserve_party_ids.clear()
	_hospital_ids.clear()
	_hospital_return_slots.clear()
	_digi_data_by_seed.clear()
	_fusion_data_by_id.clear()
	unlocked_technique_records.clear()
	technique_research.clear()
	inventory.clear()
	bits = maxi(0, int(data.get("bits", 0)))
	progression_flags = _safe_dictionary(data.get("progressionFlags", {}))
	quest_states = _safe_dictionary(data.get("questStates", {}))

	var raw_records = data.get("unlockedTechniqueRecords", [])
	if raw_records is Array:
		for raw_record in raw_records:
			var record_id := String(raw_record).strip_edges()
			if not record_id.is_empty() and not unlocked_technique_records.has(record_id):
				unlocked_technique_records.append(record_id)

	var raw_research = data.get("techniqueResearch", {})
	if raw_research is Dictionary:
		for raw_skill_id in raw_research.keys():
			var skill_id := String(raw_skill_id).strip_edges()
			var points := clampi(int(raw_research[raw_skill_id]), 0, 2)
			if not skill_id.is_empty() and points > 0 and not unlocked_technique_records.has(skill_id):
				technique_research[skill_id] = points

	var raw_fusion_data = data.get("fusionData", {})
	if raw_fusion_data is Dictionary:
		for raw_fusion_id in raw_fusion_data.keys():
			var fusion_id := String(raw_fusion_id).to_lower().strip_edges()
			var amount := clampi(int(raw_fusion_data[raw_fusion_id]), 0, 100)
			if not fusion_id.is_empty() and amount > 0:
				_fusion_data_by_id[fusion_id] = amount

	var raw_inventory = data.get("inventory", {})
	if raw_inventory is Dictionary:
		for raw_item_id in raw_inventory.keys():
			var item_id := String(raw_item_id).strip_edges()
			var amount := maxi(0, int(raw_inventory[raw_item_id]))
			if not item_id.is_empty() and amount > 0:
				inventory[item_id] = amount

	var action_database = ActionDatabaseScript.new()
	var action_database_ready := action_database.load_default()
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
			if action_database_ready:
				_migrate_instance_skill_ids(instance, action_database)
			add_instance(instance, String(entry.get("collectionKey", "")), "digimon")

	var raw_hospital = data.get("hospitalIds", [])
	if raw_hospital is Array:
		for raw_id in raw_hospital:
			var instance_id := String(raw_id).strip_edges()
			if _instances_by_id.has(instance_id) and not _hospital_ids.has(instance_id):
				_hospital_ids.append(instance_id)

	var raw_return_slots = data.get("hospitalReturnSlots", {})
	if raw_return_slots is Dictionary:
		for raw_id in (raw_return_slots as Dictionary).keys():
			var instance_id := String(raw_id).strip_edges()
			var raw_slot = (raw_return_slots as Dictionary)[raw_id]
			if not _hospital_ids.has(instance_id) or not raw_slot is Dictionary:
				continue
			var role := String((raw_slot as Dictionary).get("role", ""))
			var index := int((raw_slot as Dictionary).get("index", -1))
			if role in [SQUAD_ROLE_ACTIVE, SQUAD_ROLE_RESERVE] and index >= 0:
				_hospital_return_slots[instance_id] = {"role": role, "index": index}

	var raw_active = data.get("activeSquadIds", [])
	if raw_active is Array:
		for raw_id in raw_active:
			var instance_id := String(raw_id).strip_edges()
			if _instances_by_id.has(instance_id) and not _hospital_ids.has(instance_id) and not _active_party_ids.has(instance_id):
				_active_party_ids.append(instance_id)

	var raw_reserve = data.get("reserveSquadIds", [])
	if raw_reserve is Array:
		for raw_id in raw_reserve:
			var instance_id := String(raw_id).strip_edges()
			if (
				_instances_by_id.has(instance_id)
				and not _hospital_ids.has(instance_id)
				and not _active_party_ids.has(instance_id)
				and not _reserve_party_ids.has(instance_id)
			):
				_reserve_party_ids.append(instance_id)

	var raw_data = data.get("digiData", {})
	if raw_data is Dictionary:
		for raw_seed in raw_data.keys():
			var seed := String(raw_seed).strip_edges()
			var amount := maxi(0, int(raw_data[raw_seed]))
			if not seed.is_empty() and amount > 0:
				_digi_data_by_seed[seed] = amount


func _migrate_instance_skill_ids(instance: DigimonInstance, action_database) -> void:
	if instance == null or action_database == null:
		return
	var species_key := instance.species_seed
	var old_learned := instance.learned_skills.duplicate()
	var old_favorites := instance.favorite_skills.duplicate()
	var old_archived := instance.archived_skills.duplicate()
	var old_mastery := instance.skill_mastery.duplicate(true)
	var migrated_learned: Array[String] = []
	var migrated_mastery: Dictionary = {}

	for raw_skill_id in old_learned:
		var old_id := String(raw_skill_id).strip_edges()
		if old_id.is_empty():
			continue
		var resolved_id := String(action_database.resolve_skill_id(species_key, old_id)).strip_edges()
		if resolved_id.is_empty():
			resolved_id = old_id
		if not migrated_learned.has(resolved_id):
			migrated_learned.append(resolved_id)
		var old_points := clampi(int(old_mastery.get(old_id, old_mastery.get(resolved_id, 0))), 0, DigimonInstance.MAX_SKILL_MASTERY_POINTS)
		migrated_mastery[resolved_id] = maxi(int(migrated_mastery.get(resolved_id, 0)), old_points)

	var migrated_favorites: Array[String] = []
	for raw_skill_id in old_favorites:
		var resolved_id := String(action_database.resolve_skill_id(species_key, String(raw_skill_id))).strip_edges()
		if migrated_learned.has(resolved_id) and not migrated_favorites.has(resolved_id) and migrated_favorites.size() < DigimonInstance.MAX_FAVORITE_SKILLS:
			migrated_favorites.append(resolved_id)

	var migrated_archived: Array[String] = []
	for raw_skill_id in old_archived:
		var resolved_id := String(action_database.resolve_skill_id(species_key, String(raw_skill_id))).strip_edges()
		if migrated_learned.has(resolved_id) and not migrated_archived.has(resolved_id):
			migrated_archived.append(resolved_id)
			migrated_favorites.erase(resolved_id)

	instance.learned_skills = migrated_learned
	instance.favorite_skills = migrated_favorites
	instance.archived_skills = migrated_archived
	instance.skill_mastery = migrated_mastery

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
