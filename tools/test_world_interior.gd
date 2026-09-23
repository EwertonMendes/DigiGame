extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)
	WorldState.reset_to_defaults()

	var world := WORLD_SCENE.instantiate()
	add_child(world)
	await _frames(8)

	var player := world.call("get_player") as Node2D
	var streamer = world.call("get_streamer")
	var manager = world.call("get_interior_manager")
	assert(player != null and manager != null, "World must expose player and interior manager")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Player must spawn on walkable Central City ground")

	var entry_thresholds := get_tree().get_nodes_in_group("world_interior_threshold")
	assert(not entry_thresholds.is_empty(), "Streamed service buildings must expose physical entry thresholds")
	var entry := entry_thresholds[0] as Area2D
	var payload = entry.get_meta("interior_payload", {})
	assert(payload is Dictionary, "Interior threshold must carry its destination payload")
	var raw_return = (payload as Dictionary).get("return_position", [])
	assert(raw_return is Array and raw_return.size() >= 2, "Interior threshold must define an exterior return point")
	var expected_return := Vector2(float(raw_return[0]), float(raw_return[1]))

	entry.emit_signal("body_entered", player)
	await get_tree().create_timer(1.0).timeout
	assert(bool(manager.call("is_active")), "Crossing a service doorway must enter its dedicated interior")
	assert(bool(streamer.call("is_suspended")), "Exterior chunk streaming must pause while the player is inside")
	assert(get_tree().current_scene == self, "Interior entry must not change the active scene")
	assert(player.global_position.distance_to(expected_return) > 1000.0, "Interior must live in its own streamed world space")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Interior spawn must be walkable")

	var exit_thresholds := get_tree().get_nodes_in_group("world_interior_exit_threshold")
	assert(not exit_thresholds.is_empty(), "Interior must expose a physical exit threshold")
	(exit_thresholds[0] as Area2D).emit_signal("body_entered", player)
	await get_tree().create_timer(1.0).timeout
	assert(not bool(manager.call("is_active")), "Crossing the interior doorway must return to the city")
	assert(not bool(streamer.call("is_suspended")), "Exterior streaming must resume after exit")
	assert(player.global_position.is_equal_approx(expected_return), "Exit must restore the authored exterior doorway position")
	assert(get_tree().current_scene == self, "Interior exit must remain in the same SceneTree")

	print("seamless world interior regression passed")
	get_tree().quit()


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
