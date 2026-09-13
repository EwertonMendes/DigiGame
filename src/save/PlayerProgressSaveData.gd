extends RefCounted
class_name PlayerProgressSaveData

const CURRENT_VERSION := 1

var save_version: int = CURRENT_VERSION
var roster: Dictionary = {}


static func from_roster(player_roster: PlayerRoster) -> PlayerProgressSaveData:
	var data := PlayerProgressSaveData.new()
	data.save_version = CURRENT_VERSION
	data.roster = player_roster.to_dict() if player_roster != null else {}
	return data


static func from_dict(data: Dictionary) -> PlayerProgressSaveData:
	var result := PlayerProgressSaveData.new()
	result.save_version = int(data.get("save_version", data.get("saveVersion", CURRENT_VERSION)))
	var raw_roster = data.get("roster", {})
	result.roster = (raw_roster as Dictionary).duplicate(true) if raw_roster is Dictionary else {}
	return result


func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"roster": roster.duplicate(true),
	}
