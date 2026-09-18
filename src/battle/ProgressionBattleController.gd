extends "res://src/battle/EscapeBattleController.gd"

const BattleRewardServiceScript = preload("res://src/digimon/BattleRewardService.gd")
const ExpansionQuestCatalogScript = preload("res://src/quests/ExpansionQuestCatalog.gd")

var _reward_service = null


func _ready() -> void:
	# The persistent director crossfades the current area theme into Battle 1 and
	# keeps it alive for the encounter. Result themes replace it immediately when
	# the battle ends; returning to the Hub asks the same director for Zone 1.
	MusicDirector.play_battle_1()
	_reward_service = BattleRewardServiceScript.new(OverworldState.get_database())
	super._ready()


func _finish_battle(victory: bool) -> void:
	# Result jingles intentionally cut the looping battle theme instead of
	# crossfading, and are configured as one-shots by MusicDirector.
	if victory:
		MusicDirector.play_victory_theme()
	else:
		MusicDirector.play_game_over()
	super._finish_battle(victory)


func _build_battle_result(victory: bool) -> Dictionary:
	var result: Dictionary = super._build_battle_result(victory)
	result["xp_rewards"] = {"total_enemy_xp_value": 0, "digimon": []}
	result["items"] = []
	result["money"] = 0
	result["other_rewards"] = {}
	result["digi_data_progress"] = {}
	result["expansion_quests"] = {}
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
	var guaranteed_items := _encounter_guaranteed_items()
	for raw_item_id in guaranteed_items.keys():
		(result["items"] as Array).append({"id": String(raw_item_id), "amount": int(guaranteed_items[raw_item_id])})
	result["digi_data_progress"] = OverworldState.apply_account_rewards(
		int(result.get("bits", 0)),
		result.get("digi_data", {}),
		_item_totals(result.get("items", []))
	)

	var collection = OverworldState.get("_collection")
	if collection is PlayerCollection:
		var quest_result: Dictionary = ExpansionQuestCatalogScript.record_victory(
			collection as PlayerCollection,
			_is_advanced_expansion_encounter(defeated_enemies)
		)
		result["expansion_quests"] = quest_result
		(result["other_rewards"] as Dictionary)["expansion_quests"] = quest_result.duplicate(true)
		var quest_items = quest_result.get("rewarded_items", {})
		if quest_items is Dictionary and not (quest_items as Dictionary).is_empty():
			for raw_item_id in (quest_items as Dictionary).keys():
				(result["items"] as Array).append({
					"id": String(raw_item_id),
					"amount": int((quest_items as Dictionary)[raw_item_id]),
					"source": "quest",
				})
			OverworldState.inventory_changed.emit(OverworldState.get_inventory())
			OverworldState.account_rewards_changed.emit(OverworldState.get_bits(), OverworldState.get_digi_data())

	var observed: Array[String] = []
	var raw_observed = result.get("observed_techniques", [])
	if raw_observed is Array:
		for raw_skill_id in raw_observed:
			observed.append(String(raw_skill_id))
	var technique_progress: Dictionary = OverworldState.apply_technique_battle_progress(
		result.get("mastery_uses", {}) if result.get("mastery_uses", {}) is Dictionary else {},
		observed
	)
	result["mastery_progress"] = technique_progress.get("mastery", [])
	result["technique_research"] = technique_progress.get("research", [])
	OverworldState.save_progress()
	return result


func get_hud_state() -> Dictionary:
	var state: Dictionary = super.get_hud_state()
	if current_actor == null or not is_instance_valid(current_actor):
		return state
	var tier := String(current_actor.call("get_tier")) if current_actor.has_method("get_tier") else "E"
	var footprint := String(current_actor.call("get_battle_footprint_id")) if current_actor.has_method("get_battle_footprint_id") else "single"
	var size_badge := FootprintScript.display_label(footprint)
	state["tier"] = tier
	state["footprint"] = footprint
	state["size_badge"] = size_badge
	var actor_name := String(state.get("actor_name", "Digimon"))
	state["actor_name"] = "%s  ·  TIER %s  ·  %s" % [actor_name, tier, size_badge]
	return state


func _is_advanced_expansion_encounter(defeated_enemies: Array[Node]) -> bool:
	for actor: Node in defeated_enemies:
		if actor == null or not is_instance_valid(actor):
			continue
		var profile := String(actor.get_meta("encounter_profile", "wild")).to_lower().strip_edges()
		if ["trainer", "elite", "boss", "advanced"].has(profile):
			return true
		if actor.has_method("get_level") and int(actor.call("get_level")) >= 20:
			return true
	return false


func _encounter_guaranteed_items() -> Dictionary:
	if _controller == null:
		return {}
	var definition = _controller.get("encounter_definition")
	if definition == null:
		return {}
	var raw_items = definition.get("guaranteed_items")
	return (raw_items as Dictionary).duplicate(true) if raw_items is Dictionary else {}


func _item_totals(raw_items) -> Dictionary:
	var result: Dictionary = {}
	if not raw_items is Array:
		return result
	for raw_item in raw_items:
		if not raw_item is Dictionary:
			continue
		var item := raw_item as Dictionary
		var item_id := String(item.get("id", item.get("item_id", ""))).strip_edges()
		var amount := maxi(0, int(item.get("amount", 1)))
		if not item_id.is_empty() and amount > 0:
			result[item_id] = int(result.get(item_id, 0)) + amount
	return result
