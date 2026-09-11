extends "res://src/battle/EscapeBattleController.gd"

const BattleRewardServiceScript = preload("res://src/digimon/BattleRewardService.gd")

var _reward_service = null


func _ready() -> void:
	_reward_service = BattleRewardServiceScript.new(OverworldState.get_database())
	super._ready()


func _build_battle_result(victory: bool) -> Dictionary:
	var result: Dictionary = super._build_battle_result(victory)
	result["xp_rewards"] = {"total_enemy_xp_value": 0, "digimon": []}
	if not victory:
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
		result["xp_rewards"] = _reward_service.apply_victory_rewards(players, defeated_enemies)
	OverworldState.apply_account_rewards(int(result.get("bits", 0)), result.get("digi_data", {}))
	return result
