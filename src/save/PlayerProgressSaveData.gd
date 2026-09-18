extends RefCounted
class_name PlayerProgressSaveData

const CURRENT_VERSION := 1
const SAVE_FORMAT := "squad-v1"

var save_version: int = CURRENT_VERSION
var save_format: String = SAVE_FORMAT
var collection: Dictionary = {}


static func from_collection(player_collection) -> PlayerProgressSaveData:
	var data := PlayerProgressSaveData.new()
	data.collection = player_collection.to_dict() if player_collection != null else {}
	return data


static func from_dict(data: Dictionary) -> PlayerProgressSaveData:
	var result := PlayerProgressSaveData.new()
	result.save_version = int(data.get("save_version", CURRENT_VERSION))
	result.save_format = String(data.get("save_format", SAVE_FORMAT))
	var raw_collection = data.get("collection", {})
	result.collection = (raw_collection as Dictionary).duplicate(true) if raw_collection is Dictionary else {}
	return result


func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"save_format": save_format,
		"collection": collection.duplicate(true),
	}
