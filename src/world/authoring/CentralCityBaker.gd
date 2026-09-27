@tool
extends RefCounted
class_name CentralCityBaker

const AUTHORING_DATA = preload("res://src/world/authoring/CentralCityAuthoringData.gd")
const BAKED_DATA = preload("res://src/world/authoring/CentralCityBakedData.gd")
const BAKED_PATH := "res://assets/resources/world/central_city_baked.tres"


static func bake(root: Node) -> Error:
	if root == null:
		return ERR_INVALID_PARAMETER
	var resource = BAKED_DATA.new()
	resource.snapshot = AUTHORING_DATA.snapshot_from_root(root)
	if resource.snapshot.is_empty():
		return ERR_INVALID_DATA
	return ResourceSaver.save(resource, BAKED_PATH)


static func load_snapshot() -> Dictionary:
	if not ResourceLoader.exists(BAKED_PATH):
		return {}
	var resource = ResourceLoader.load(BAKED_PATH)
	if resource == null:
		return {}
	var value = resource.get("snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
