extends RefCounted
class_name PlayerProgressSaveData

const CURRENT_VERSION := 2

var save_version: int = CURRENT_VERSION
var collection: Dictionary = {}

static func from_collection(player_collection) -> PlayerProgressSaveData:
	var data := PlayerProgressSaveData.new()
	data.save_version = CURRENT_VERSION
	data.collection = player_collection.to_dict() if player_collection != null else {}
	return data

static func from_dict(data: Dictionary) -> PlayerProgressSaveData:
	var result := PlayerProgressSaveData.new()
	result.save_version = int(data.get("save_version", data.get("saveVersion", CURRENT_VERSION)))
	var raw_collection = data.get("collection", {})
	result.collection = (raw_collection as Dictionary).duplicate(true) if raw_collection is Dictionary else {}
	return result

func to_dict() -> Dictionary:
	return {"save_version": save_version, "collection": collection.duplicate(true)}
