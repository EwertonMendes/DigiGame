extends RefCounted
class_name DebugCollectionTools


func delete_instance(instance_id: String) -> Dictionary:
	var clean_id := instance_id.strip_edges()
	var collection := _collection()
	if collection == null:
		return {"success": false, "reason": "collection_unavailable"}
	if clean_id.is_empty() or not collection.has_instance(clean_id):
		return {"success": false, "reason": "instance_not_found"}
	if collection.get_instances().size() <= 1:
		return {"success": false, "reason": "last_owned_digimon"}
	var invariant_error := collection.location_invariant_error()
	if not invariant_error.is_empty():
		return {"success": false, "reason": "invalid_collection_state", "detail": invariant_error}

	var location := collection.get_location(clean_id)
	if not collection.remove_instance(clean_id):
		return {"success": false, "reason": "remove_failed"}

	invariant_error = collection.location_invariant_error()
	if not invariant_error.is_empty():
		push_error("Debug Digimon deletion broke collection invariants: %s" % invariant_error)
		return {"success": false, "reason": "invalid_collection_state", "detail": invariant_error}

	OverworldState.collection_changed.emit()
	OverworldState.active_party_changed.emit(OverworldState.get_active_party())
	OverworldState.save_progress()
	return {"success": true, "instance_id": clean_id, "previous_location": location}


func _collection() -> PlayerCollection:
	var raw = OverworldState.get("_collection")
	return raw as PlayerCollection if raw is PlayerCollection else null
