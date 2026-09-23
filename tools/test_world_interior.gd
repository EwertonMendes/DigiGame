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

	var payload := {
		"interior_id": "regression_digilab",
		"service": "digilab",
		"title": "DIGILAB",
		"accent": [0.36, 0.88, 1.0, 1.0],
		"return_position": [player.global_position.x, player.global_position.y],
	}
	var exterior_position := player.global_position
	assert(await manager.call("enter_interior", payload), "Interior manager must enter a dedicated scene without changing SceneTree")
	assert(bool(manager.call("is_active")), "Interior must become active after the focus transition")
	assert(bool(streamer.call("is_suspended")), "Exterior chunk streaming must pause while the player is inside")
	assert(get_tree().current_scene == self, "Interior entry must not change the active scene")
	assert(player.global_position.distance_to(exterior_position) > 1000.0, "Interior must live in its own streamed world space")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Interior spawn must be walkable")

	assert(await manager.call("exit_interior"), "Interior manager must return to the exterior")
	assert(not bool(manager.call("is_active")), "Interior must unload after exit")
	assert(not bool(streamer.call("is_suspended")), "Exterior streaming must resume after exit")
	assert(player.global_position.is_equal_approx(exterior_position), "Exit must restore the exact exterior doorway position")
	assert(get_tree().current_scene == self, "Interior exit must remain in the same SceneTree")

	print("seamless world interior regression passed")
	get_tree().quit()


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
