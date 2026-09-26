extends RefCounted
class_name FusionProgressService

const DEFAULT_REQUIRED := 100


func add_data(collection: PlayerCollection, fusion_id: String, amount: int, catalog: FusionCatalog = null, source: String = "") -> Dictionary:
	var clean_id := fusion_id.to_lower().strip_edges()
	var result := {
		"fusion_id": clean_id,
		"source": source,
		"before": 0,
		"gained": 0,
		"after": 0,
		"unlocked": false,
		"newly_unlocked": false,
		"success": false,
		"reason": "",
	}
	if collection == null or clean_id.is_empty():
		result["reason"] = "invalid"
		return result
	if catalog != null and not catalog.has_id(clean_id):
		result["reason"] = "unknown_fusion"
		return result
	var before := collection.get_fusion_data(clean_id)
	result["before"] = before
	if before >= DEFAULT_REQUIRED:
		result["after"] = DEFAULT_REQUIRED
		result["unlocked"] = true
		result["success"] = true
		return result
	if amount <= 0:
		result["after"] = before
		result["unlocked"] = before >= DEFAULT_REQUIRED
		result["success"] = true
		return result
	var after := collection.add_fusion_data(clean_id, amount)
	result["gained"] = after - before
	result["after"] = after
	result["unlocked"] = after >= DEFAULT_REQUIRED
	result["newly_unlocked"] = before < DEFAULT_REQUIRED and after >= DEFAULT_REQUIRED
	result["success"] = true
	return result


func get_progress(collection: PlayerCollection, fusion_id: String) -> int:
	return collection.get_fusion_data(fusion_id) if collection != null else 0


func is_unlocked(collection: PlayerCollection, fusion_id: String) -> bool:
	return get_progress(collection, fusion_id) >= DEFAULT_REQUIRED
