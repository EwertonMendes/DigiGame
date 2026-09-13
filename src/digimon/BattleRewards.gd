extends RefCounted
class_name BattleRewards

var bits: int = 0
var digi_data: Dictionary = {}
var xp_by_instance: Dictionary = {}
var items: Array[Dictionary] = []
var money: int = 0
var other_rewards: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"bits": bits,
		"digi_data": digi_data.duplicate(true),
		"xp_by_instance": xp_by_instance.duplicate(true),
		"items": items.duplicate(true),
		"money": money,
		"other_rewards": other_rewards.duplicate(true),
	}
