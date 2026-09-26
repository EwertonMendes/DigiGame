extends RefCounted
class_name PlayerProgressSaveData

const CURRENT_VERSION := 3
const SAVE_FORMAT := "fusion-v3"

var save_version: int = CURRENT_VERSION
var save_format: String = SAVE_FORMAT
var collection: Dictionary = {}
var world: Dictionary = {}


static func from_collection(player_collection, world_state: Dictionary = {}) -> PlayerProgressSaveData:
	var data := PlayerProgressSaveData.new()
	data.collection = player_collection.to_dict() if player_collection != null else {}
	data.world = world_state.duplicate(true)
	return data


static func from_dict(data: Dictionary) -> PlayerProgressSaveData:
	var result := PlayerProgressSaveData.new()
	result.save_version = int(data.get("save_version", CURRENT_VERSION))
	result.save_format = String(data.get("save_format", SAVE_FORMAT))
	var raw_collection = data.get("collection", {})
	result.collection = (raw_collection as Dictionary).duplicate(true) if raw_collection is Dictionary else {}
	var raw_world = data.get("world", {})
	result.world = (raw_world as Dictionary).duplicate(true) if raw_world is Dictionary else {}
	return result


func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"save_format": save_format,
		"collection": collection.duplicate(true),
		"world": world.duplicate(true),
	}
