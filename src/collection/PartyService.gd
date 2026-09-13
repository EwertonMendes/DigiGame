extends RefCounted
class_name PartyService

const BalanceScript = preload("res://src/digimon/ProgressionBalance.gd")

var _balance = BalanceScript.new()


func minimum_size() -> int:
	return maxi(1, _balance.party_int("minActive", 1))


func maximum_size() -> int:
	return maxi(minimum_size(), _balance.party_int("maxActive", 3))


func set_party(roster: PlayerRoster, instance_ids: Array[String]) -> bool:
	if roster == null:
		return false
	return roster.set_active_party_ids(instance_ids, minimum_size(), maximum_size())


func add_to_party(roster: PlayerRoster, instance_id: String) -> bool:
	if roster == null or not roster.has_instance(instance_id):
		return false
	var party := roster.get_active_party_ids()
	if party.has(instance_id) or party.size() >= maximum_size():
		return false
	party.append(instance_id)
	return set_party(roster, party)


func remove_from_party(roster: PlayerRoster, instance_id: String) -> bool:
	if roster == null:
		return false
	var party := roster.get_active_party_ids()
	var index := party.find(instance_id)
	if index < 0 or party.size() <= minimum_size():
		return false
	party.remove_at(index)
	return set_party(roster, party)


func swap_with_reserve(roster: PlayerRoster, active_instance_id: String, reserve_instance_id: String) -> bool:
	if roster == null or not roster.has_instance(reserve_instance_id):
		return false
	var party := roster.get_active_party_ids()
	var active_index := party.find(active_instance_id)
	if active_index < 0 or party.has(reserve_instance_id):
		return false
	party[active_index] = reserve_instance_id
	return set_party(roster, party)


func move(roster: PlayerRoster, instance_id: String, new_index: int) -> bool:
	if roster == null:
		return false
	var party := roster.get_active_party_ids()
	var current_index := party.find(instance_id)
	if current_index < 0:
		return false
	var target_index := clampi(new_index, 0, party.size() - 1)
	if target_index == current_index:
		return true
	party.remove_at(current_index)
	party.insert(target_index, instance_id)
	return set_party(roster, party)


func validation_error(roster: PlayerRoster, instance_ids: Array[String]) -> String:
	if roster == null:
		return "Roster is unavailable."
	if instance_ids.size() < minimum_size():
		return "Keep at least %d Digimon in the active party." % minimum_size()
	if instance_ids.size() > maximum_size():
		return "The active party can contain at most %d Digimon." % maximum_size()
	var seen: Dictionary = {}
	for instance_id: String in instance_ids:
		if not roster.has_instance(instance_id):
			return "The selected Digimon no longer exists in the roster."
		if seen.has(instance_id):
			return "The same Digimon instance cannot occupy two party slots."
		seen[instance_id] = true
	return ""
