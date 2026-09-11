extends "res://src/battle/StableSequencedBattleController.gd"

const BattleStartBannerScript = preload("res://src/battle/BattleStartBanner.gd")
const TEAM_SPAWN_GAP := 0.055

var _opening_running := false


func _start_battle() -> void:
	if _controller == null:
		return

	_turn_order.clear()
	for child in _controller.get_children():
		if child is CharacterBody2D:
			_turn_order.append(child)
	if _turn_order.is_empty():
		return

	_turn_scheduler.reset(_turn_order)
	_event_bus.clear()
	_battle_act_number = 0
	_battle_over = false
	_battle_result.clear()
	_defeated_enemy_ids.clear()
	phase = Phase.TURN_START
	_input_locked = true
	current_actor = null
	_turn_index = -1
	_opening_running = true
	_set_gameplay_ui_visible(false)

	await _play_opening_sequence()

	_opening_running = false
	_input_locked = false
	_set_gameplay_ui_visible(true)
	_start_next_turn()


func _play_opening_sequence() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.has_method("animate_opening_overview"):
		await camera.call("animate_opening_overview")

	var player_team: Array[Node] = []
	var enemy_team: Array[Node] = []
	for actor: Node in _turn_order:
		if actor == null or not is_instance_valid(actor):
			continue
		if bool(actor.get("is_player_controlled")):
			player_team.append(actor)
		else:
			enemy_team.append(actor)

	player_team.sort_custom(_sort_actor_left_to_right)
	enemy_team.sort_custom(_sort_actor_left_to_right)

	await _reveal_team(player_team)
	await get_tree().create_timer(0.10).timeout
	await _reveal_team(enemy_team)
	await get_tree().create_timer(0.12).timeout
	await _play_battle_start_banner()


func _reveal_team(team: Array[Node]) -> void:
	for actor: Node in team:
		if actor == null or not is_instance_valid(actor):
			continue
		if actor.has_method("play_battle_spawn_animation"):
			await actor.call("play_battle_spawn_animation")
		else:
			actor.visible = true
			actor.modulate = Color.WHITE
		await get_tree().create_timer(TEAM_SPAWN_GAP).timeout


func _play_battle_start_banner() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BattleStartLayer"
	layer.layer = 140
	get_tree().current_scene.add_child(layer)

	var banner := BattleStartBannerScript.new()
	banner.name = "BattleStartBanner"
	layer.add_child(banner)
	await get_tree().process_frame
	await banner.call("play")
	layer.queue_free()


func _set_gameplay_ui_visible(value: bool) -> void:
	var root := get_parent()
	if root == null:
		return
	for node_name in ["BattleUI", "DigimonInfoUI", "DebugUI"]:
		var layer := root.get_node_or_null(node_name) as CanvasLayer
		if layer != null:
			layer.visible = value


func _sort_actor_left_to_right(a: Node, b: Node) -> bool:
	var a_node := a as Node2D
	var b_node := b as Node2D
	if a_node == null or b_node == null:
		return str(a.name) < str(b.name)
	if is_equal_approx(a_node.global_position.x, b_node.global_position.x):
		return a_node.global_position.y < b_node.global_position.y
	return a_node.global_position.x < b_node.global_position.x


func is_opening_sequence_active() -> bool:
	return _opening_running
