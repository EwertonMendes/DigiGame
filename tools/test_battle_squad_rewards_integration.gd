extends Node

const BATTLE_SCENE = preload("res://scenes/main.tscn")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests()

	var factory: DigimonFactory = FactoryScript.new(OverworldState.get_database())
	var healthy_reserve := factory.create_player_by_name("agumon", 3, 100)
	var ko_reserve := factory.create_player_by_name("gabumon", 3, 100)
	assert(healthy_reserve != null and ko_reserve != null, "Reserve reward fixtures must be creatable")
	ko_reserve.current_hp = 0
	assert(not OverworldState.add_collection_instance(healthy_reserve).is_empty(), "Healthy Reserve must enter the collection")
	assert(not OverworldState.add_collection_instance(ko_reserve).is_empty(), "KO Reserve must enter the collection")
	assert(OverworldState.add_to_reserve_party(healthy_reserve.id), "Healthy fixture must enter Reserve")
	assert(OverworldState.add_to_reserve_party(ko_reserve.id), "KO fixture must enter Reserve")

	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	await _frames(8)

	var controller := battle.get_node_or_null("BattleController")
	var runtime := battle.get_node_or_null("DigimonController")
	assert(controller != null and runtime != null, "Real battle hierarchy must instantiate")
	var runtime_session = runtime.call("get_battle_squad_session")
	var domain_session = controller.get("_squad_session")
	assert(runtime_session != null and domain_session == runtime_session, "Progression controller must own the persistent Squad session")

	var defeated_id := ""
	for child: Node in runtime.get_children():
		if not child is CharacterBody2D or bool(child.get("is_player_controlled")):
			continue
		if child.has_method("get_digimon_instance_id"):
			defeated_id = String(child.call("get_digimon_instance_id"))
			break
	assert(not defeated_id.is_empty(), "Integration fixture must locate an enemy actor")

	var defeated_ids: Array[String] = [defeated_id]
	controller.set("_defeated_enemy_ids", defeated_ids)
	var before_level := healthy_reserve.level
	var before_exp := healthy_reserve.exp
	var result: Dictionary = controller.call("_build_battle_result", true)

	var xp_rewards = result.get("xp_rewards", {})
	assert(xp_rewards is Dictionary, "Real ProgressionBattleController result must expose XP rewards")
	var rows = (xp_rewards as Dictionary).get("digimon", [])
	assert(rows is Array, "Real result must expose per-Digimon reward rows")
	var by_id: Dictionary = {}
	for raw_row in rows:
		if raw_row is Dictionary:
			var row := raw_row as Dictionary
			by_id[String(row.get("instance_id", ""))] = row

	var healthy_row := by_id.get(healthy_reserve.id, {}) as Dictionary
	var ko_row := by_id.get(ko_reserve.id, {}) as Dictionary
	assert(not healthy_row.is_empty(), "Healthy Reserve must have a real reward row instead of UI fallback")
	assert(int(healthy_row.get("xp_gained", 0)) > 0, "Healthy Reserve must receive positive XP in the real battle result")
	assert(not bool(healthy_row.get("participated", true)), "Unused Reserve must remain marked as non-participant metadata")
	assert(healthy_reserve.level > before_level or healthy_reserve.exp > before_exp, "Healthy Reserve XP must persist on the Digimon instance")
	assert(not ko_row.is_empty() and int(ko_row.get("xp_gained", 0)) == 0 and bool(ko_row.get("knocked_out", false)), "KO Reserve must remain visible with zero XP")

	battle.queue_free()
	await _frames(2)
	print("battle squad rewards integration regression passed")
	get_tree().quit()


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
