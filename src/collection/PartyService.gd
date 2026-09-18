extends RefCounted
class_name PartyService

const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")

const ROLE_ACTIVE := PlayerCollection.SQUAD_ROLE_ACTIVE
const ROLE_RESERVE := PlayerCollection.SQUAD_ROLE_RESERVE

var _balance = BalanceScript.new()


func minimum_size() -> int:
	return minimum_active_size()


func maximum_size() -> int:
	return maximum_active_size()


func minimum_active_size() -> int:
	return maxi(1, _balance.party_int("minActive", 1))


func maximum_active_size() -> int:
	return maxi(minimum_active_size(), _balance.party_int("maxActive", 3))


func maximum_reserve_size() -> int:
	return maxi(0, _balance.party_int("maxReserve", 3))


func maximum_squad_size() -> int:
	return maximum_active_size() + maximum_reserve_size()


func set_party(collection: PlayerCollection, instance_ids: Array[String]) -> bool:
	if collection == null:
		return false
	return collection.set_squad_ids(
		instance_ids,
		collection.get_reserve_party_ids(),
		minimum_active_size(),
		maximum_active_size(),
		maximum_reserve_size()
	)


func set_squad(collection: PlayerCollection, active_ids: Array[String], reserve_ids: Array[String]) -> bool:
	if collection == null:
		return false
	return collection.set_squad_ids(
		active_ids,
		reserve_ids,
		minimum_active_size(),
		maximum_active_size(),
		maximum_reserve_size()
	)


func add_to_party(collection: PlayerCollection, instance_id: String) -> bool:
	return add_to_active(collection, instance_id)


func add_to_active(collection: PlayerCollection, instance_id: String) -> bool:
	if collection == null or not _can_join_squad(collection, instance_id):
		return false
	var active := collection.get_active_party_ids()
	if active.has(instance_id) or active.size() >= maximum_active_size():
		return false
	var reserve := collection.get_reserve_party_ids()
	reserve.erase(instance_id)
	active.append(instance_id)
	return set_squad(collection, active, reserve)


func add_to_reserve(collection: PlayerCollection, instance_id: String) -> bool:
	if collection == null or not _can_join_squad(collection, instance_id):
		return false
	var reserve := collection.get_reserve_party_ids()
	if reserve.has(instance_id) or reserve.size() >= maximum_reserve_size():
		return false
	var active := collection.get_active_party_ids()
	if active.has(instance_id) and active.size() <= minimum_active_size():
		return false
	active.erase(instance_id)
	reserve.append(instance_id)
	return set_squad(collection, active, reserve)


func remove_from_party(collection: PlayerCollection, instance_id: String) -> bool:
	return move_to_storage(collection, instance_id)


func move_to_storage(collection: PlayerCollection, instance_id: String) -> bool:
	if collection == null:
		return false
	var active := collection.get_active_party_ids()
	var reserve := collection.get_reserve_party_ids()
	if active.has(instance_id):
		if active.size() <= minimum_active_size():
			return false
		active.erase(instance_id)
	elif reserve.has(instance_id):
		reserve.erase(instance_id)
	else:
		return false
	return set_squad(collection, active, reserve)


func assign_to_slot(collection: PlayerCollection, instance_id: String, role: String, slot_index: int) -> bool:
	if collection == null or not _can_join_squad(collection, instance_id):
		return false
	var normalized_role := role.to_lower().strip_edges()
	if normalized_role not in [ROLE_ACTIVE, ROLE_RESERVE]:
		return false

	var active := collection.get_active_party_ids()
	var reserve := collection.get_reserve_party_ids()
	var source_role := collection.get_squad_role(instance_id)
	var source_index := active.find(instance_id) if source_role == ROLE_ACTIVE else reserve.find(instance_id)
	var target := active if normalized_role == ROLE_ACTIVE else reserve
	var target_capacity := maximum_active_size() if normalized_role == ROLE_ACTIVE else maximum_reserve_size()
	if slot_index < 0 or slot_index >= target_capacity:
		return false

	var target_id := String(target[slot_index]) if slot_index < target.size() else ""
	if source_role == normalized_role:
		if source_index < 0:
			return false
		if target_id.is_empty():
			target.remove_at(source_index)
			target.insert(mini(slot_index, target.size()), instance_id)
		else:
			target[source_index] = target_id
			target[slot_index] = instance_id
		return set_squad(collection, active, reserve)

	# Moving an Active member into an empty Reserve slot may not violate the
	# explicit out-of-battle minimum. Swapping Active <-> Reserve keeps the count.
	if source_role == ROLE_ACTIVE and target_id.is_empty() and active.size() <= minimum_active_size():
		return false

	if source_role == ROLE_ACTIVE:
		active.remove_at(source_index)
	elif source_role == ROLE_RESERVE:
		reserve.remove_at(source_index)

	# A filled target slot swaps back into the source slot when the source was
	# already in the Squad. A Storage Digimon displaces the target to Storage.
	if not target_id.is_empty():
		target[slot_index] = instance_id
		if source_role == ROLE_ACTIVE:
			active.insert(clampi(source_index, 0, active.size()), target_id)
		elif source_role == ROLE_RESERVE:
			reserve.insert(clampi(source_index, 0, reserve.size()), target_id)
	else:
		target.insert(mini(slot_index, target.size()), instance_id)

	return set_squad(collection, active, reserve)


func swap_with_reserve(collection: PlayerCollection, active_instance_id: String, reserve_instance_id: String) -> bool:
	if collection == null:
		return false
	var active := collection.get_active_party_ids()
	var reserve := collection.get_reserve_party_ids()
	var active_index := active.find(active_instance_id)
	var reserve_index := reserve.find(reserve_instance_id)
	if active_index < 0 or reserve_index < 0:
		return false
	active[active_index] = reserve_instance_id
	reserve[reserve_index] = active_instance_id
	return set_squad(collection, active, reserve)


func move(collection: PlayerCollection, instance_id: String, new_index: int) -> bool:
	if collection == null:
		return false
	var role := collection.get_squad_role(instance_id)
	if role.is_empty():
		return false
	var members := collection.get_active_party_ids() if role == ROLE_ACTIVE else collection.get_reserve_party_ids()
	var current_index := members.find(instance_id)
	if current_index < 0:
		return false
	var target_index := clampi(new_index, 0, members.size() - 1)
	if target_index == current_index:
		return true
	members.remove_at(current_index)
	members.insert(target_index, instance_id)
	if role == ROLE_ACTIVE:
		return set_squad(collection, members, collection.get_reserve_party_ids())
	return set_squad(collection, collection.get_active_party_ids(), members)


func validation_error(collection: PlayerCollection, instance_ids: Array[String]) -> String:
	if collection == null:
		return "Collection is unavailable."
	if instance_ids.is_empty():
		return "You need at least one Active Digimon to start a battle."
	if instance_ids.size() < minimum_active_size():
		return "Keep at least %d Digimon Active." % minimum_active_size()
	if instance_ids.size() > maximum_active_size():
		return "The Active Squad can contain at most %d Digimon." % maximum_active_size()
	var seen: Dictionary = {}
	for instance_id: String in instance_ids:
		if not collection.has_instance(instance_id):
			return "The selected Digimon is no longer in your collection."
		if collection.get_location(instance_id) != PlayerCollection.LOCATION_PARTY:
			return "The Active Squad contains a Digimon that is not currently in the Squad."
		if collection.get_squad_role(instance_id) != ROLE_ACTIVE:
			return "The Active Squad contains a Digimon assigned to Reserve."
		if seen.has(instance_id):
			return "The same Digimon instance cannot occupy two Squad slots."
		seen[instance_id] = true
	return ""


func _can_join_squad(collection: PlayerCollection, instance_id: String) -> bool:
	return (
		not instance_id.strip_edges().is_empty()
		and collection.has_instance(instance_id)
		and not collection.is_hospitalized(instance_id)
	)
