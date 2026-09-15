extends "res://src/battle/EscapeBattleController.gd"

const BattleRewardServiceScript = preload("res://src/digimon/BattleRewardService.gd")
const ExpansionQuestCatalogScript = preload("res://src/quests/ExpansionQuestCatalog.gd")

var _reward_service = null


func _ready() -> void:
	# Diagnostic A/B: keep the current world track on Web so we can prove whether
	# the intermittent WASM trap is caused by the music transition or by battle
	# presentation. This branch-only probe is reverted after the diagnostic run.
	if not OS.has_feature("web"):
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
	var size_badge := "2×2" if footprint == "large_2x2" else "1×1"
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
		if profile in ["boss", "elite", "champion"]:
			return true
		var species_rank := String(actor.get("species_data").get("rank", "")) if actor.get("species_data") is Dictionary else ""
		if species_rank.to_lower() in ["perfect", "ultimate", "mega"]:
			return true
	return false


func _encounter_guaranteed_items() -> Dictionary:
	var encounter = OverworldState.consume_active_battle_encounter()
	if not encounter is Dictionary:
		return {}
	var items = (encounter as Dictionary).get("guaranteed_items", {})
	return items.duplicate(true) if items is Dictionary else {}


func _item_totals(items_value) -> Dictionary:
	var totals: Dictionary = {}
	if not items_value is Array:
		return totals
	for entry in items_value as Array:
		if not entry is Dictionary:
			continue
		var item_id := String((entry as Dictionary).get("id", "")).strip_edges()
		var amount := maxi(0, int((entry as Dictionary).get("amount", 0)))
		if item_id.is_empty() or amount <= 0:
			continue
		totals[item_id] = int(totals.get(item_id, 0)) + amount
	return totals
