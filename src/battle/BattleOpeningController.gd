extends "res://src/battle/StableSequencedBattleController.gd"

const BattleStartBannerScript = preload("res://src/battle/BattleStartBanner.gd")
const TEAM_SPAWN_GAP := 0.08
const TEAM_SWITCH_GAP := 0.14

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

	# Re-evaluate facing only after both rosters exist. This makes every actor look
	# toward a real opposing Digimon instead of relying on a generic map-center
	# direction while the encounter is still being instantiated.
	if _controller != null and _controller.has_method("orient_battle_actors_toward_opponents"):
		_controller.call("orient_battle_actors_toward_opponents")

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

	var first_focus := true
	first_focus = await _reveal_team(player_team, camera, first_focus)
	await get_tree().create_timer(TEAM_SWITCH_GAP).timeout
	first_focus = await _reveal_team(enemy_team, camera, first_focus)
	await get_tree().create_timer(0.10).timeout

	# The scheduler can preview turn one without mutating CT. Move from the last
	# roster reveal to the actual first-turn Digimon at the gameplay zoom before
	# showing BATTLE START, so combat begins already framed for play instead of
	# snapping back to a distant whole-board overview.
	var first_turn_actor := _preview_first_turn_actor()
	if first_turn_actor != null and camera != null:
		if camera.has_method("animate_gameplay_focus"):
			await camera.call("animate_gameplay_focus", first_turn_actor.global_position)
		elif camera.has_method("focus_on"):
			camera.call("focus_on", first_turn_actor.global_position)
		print("[BattleIntro] FIRST_TURN_FOCUS actor=%s" % first_turn_actor.name)

	await _play_battle_start_banner()


func _reveal_team(team: Array[Node], camera: Camera2D, first_focus: bool) -> bool:
	var is_first_focus := first_focus
	for actor: Node in team:
		if actor == null or not is_instance_valid(actor):
			continue

		# Keep the logical facing fresh immediately before the close-up. The camera
		# move finishes first, then the Digimon materializes while actually centered
		# on screen. This produces a readable roster introduction instead of six
		# simultaneous effects on a distant board.
		if _controller != null and _controller.has_method("face_actor_toward_nearest_opponent"):
			_controller.call("face_actor_toward_nearest_opponent", actor)
		if camera != null and camera.has_method("animate_intro_focus"):
			await camera.call("animate_intro_focus", actor.global_position, is_first_focus)
		elif camera != null and camera.has_method("focus_on"):
			camera.call("focus_on", actor.global_position)
		print("[BattleIntro] CAMERA actor=%s team=%s" % [actor.name, "player" if bool(actor.get("is_player_controlled")) else "enemy"])

		if actor.has_method("play_battle_spawn_animation"):
			await actor.call("play_battle_spawn_animation")
		else:
			actor.visible = true
			actor.modulate = Color.WHITE

		is_first_focus = false
		await get_tree().create_timer(TEAM_SPAWN_GAP).timeout
	return is_first_focus


func _preview_first_turn_actor() -> Node:
	if _turn_scheduler == null:
		return null
	var preview: Array[Node] = _turn_scheduler.preview_next_actors(_turn_order, null, 1)
	return preview[0] if not preview.is_empty() else null


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
