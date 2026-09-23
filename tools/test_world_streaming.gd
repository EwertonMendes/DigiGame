extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)
	WorldState.reset_to_defaults()

	var world := WORLD_SCENE.instantiate()
	add_child(world)
	await _frames(8)

	var player = world.call("get_player")
	var streamer = world.call("get_streamer")
	assert(player != null, "Campaign world must create one persistent player actor")
	assert(streamer != null, "Campaign world must own an AreaStreamer")
	assert(streamer.call("get_current_chunk") == Vector2i.ZERO, "Fresh saves must start in Central Plaza chunk 0,0")
	assert(bool(world.call("can_actor_move_to", (player as Node2D).global_position, player)), "Fresh campaign spawn must be walkable")
	assert((player as Node2D).global_position.is_equal_approx(Vector2(-96.0, 272.0)), "Fresh campaign spawn must use the safe south-plaza lane")
	assert(int(streamer.call("get_loaded_chunk_count")) >= 9, "Initial streaming ring must contain the visible 3x3 neighborhood")
	assert(get_tree().get_nodes_in_group("world_interactable").size() >= 1, "Central City must stream reusable NPC/service interactables around the plaza")
	assert(get_tree().get_nodes_in_group("world_interior_threshold").size() >= 3, "Nearby city services must expose physical seamless-entry thresholds")

	var player_node := player as Node2D
	player_node.global_position = _grid_to_world(Vector2(21, 7))
	await _frames(12)
	assert(streamer.call("get_current_chunk") == Vector2i(1, 0), "Walking east must cross a chunk boundary without changing scenes")
	assert(get_tree().current_scene == self, "Chunk streaming must never replace the active test scene")
	assert(int(streamer.call("get_loaded_chunk_count")) <= 15, "Streaming must keep a bounded neighborhood rather than accumulating the whole city")

	player_node.global_position = _grid_to_world(Vector2(35, 7))
	await _frames(12)
	assert(streamer.call("get_current_chunk") == Vector2i(2, 0), "The authored East Gate chunk must be reachable continuously")
	assert(int(streamer.call("get_loaded_chunk_count")) <= 15, "Distant chunks must unload after the hysteresis boundary")

	WorldState.capture_location("central_city", "central_city", Vector2i(2, 0), player_node.global_position, "east")
	var saved := WorldState.to_dict()
	WorldState.reset_to_defaults()
	WorldState.load_dict(saved)
	assert(WorldState.current_chunk == Vector2i(2, 0), "World state round-trip must preserve chunk")
	assert(WorldState.player_position.is_equal_approx(player_node.global_position), "World state round-trip must preserve exact position")
	assert(WorldState.player_facing == "east", "World state round-trip must preserve facing")

	print("seamless world streaming regression passed")
	get_tree().quit()


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * 32.0,
		(grid.x + grid.y) * 16.0
	)
