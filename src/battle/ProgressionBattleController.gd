extends "res://src/battle/EscapeBattleController.gd"

const BattleRewardServiceScript = preload("res://src/digimon/BattleRewardService.gd")

var _reward_service = null


func _ready() -> void:
	_reward_service = BattleRewardServiceScript.new(OverworldState.get_database())
	super._ready()


func _build_battle_result(victory: bool) -> Dictionary:
	var result: Dictionary = super._build_battle_result(victory)
	result["xp_rewards"] = {"total_enemy_xp_value": 0, "digimon": []}
	result["items"] = []
	result["money"] = 0
	result["other_rewards"] = {}
	result["digi_data_progress"] = {}
	if not victory:
		OverworldState.save_progress()
		return result

	var players: Array[Node] = []
	var defeated_enemies: Array[Node] = []
	for actor: Node in _turn_order:
		if actor == null or not is_instance_valid(actor):
			continue
		if bool(actor.get("is_player_controlled")):
			players.append(actor)
		elif _defeated_enemy_ids.has(_instance_id(actor)):
			defeated_enemies.append(actor)

	if _reward_service != null:
		var rewards: Dictionary = _reward_service.apply_victory_rewards(players, defeated_enemies)
		result["bits"] = int(rewards.get("bits", 0))
		result["digi_data"] = (rewards.get("digi_data", {}) as Dictionary).duplicate(true) if rewards.get("digi_data", {}) is Dictionary else {}
		result["xp_rewards"] = (rewards.get("xp_rewards", {}) as Dictionary).duplicate(true) if rewards.get("xp_rewards", {}) is Dictionary else {"total_enemy_xp_value": 0, "digimon": []}
		result["items"] = (rewards.get("items", []) as Array).duplicate(true) if rewards.get("items", []) is Array else []
		result["money"] = int(rewards.get("money", 0))
		result["other_rewards"] = (rewards.get("other_rewards", {}) as Dictionary).duplicate(true) if rewards.get("other_rewards", {}) is Dictionary else {}
	result["digi_data_progress"] = OverworldState.apply_account_rewards(int(result.get("bits", 0)), result.get("digi_data", {}))
	return result
