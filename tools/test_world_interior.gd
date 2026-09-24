extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)
	WorldState.reset_to_defaults()

	var world := WORLD_SCENE.instantiate()
	add_child(world)
	await _wait_for_world_ready(world)
	await _frames(2)
	var initial_banner_count := int(world.call("get_area_banner_presentation_count"))

	var player := world.call("get_player") as Node2D
	var area = world.call("get_area_scene") as WorldAreaScene
	var manager = world.call("get_interior_manager")
	assert(player != null and area != null and manager != null, "World must expose player, area and interior manager")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Player must spawn on walkable Central City ground")

	var entry_thresholds := get_tree().get_nodes_in_group("world_interior_threshold")
	assert(not entry_thresholds.is_empty(), "Loaded area service entrances must expose physical entry thresholds")
	var entry: Area2D = null
	for candidate in entry_thresholds:
		var candidate_area := candidate as Area2D
		if candidate_area == null:
			continue
		var candidate_payload = candidate_area.get_meta("interior_payload", {})
		if candidate_payload is Dictionary and String((candidate_payload as Dictionary).get("service", "")) == "digilab":
			entry = candidate_area
			break
	assert(entry != null, "DigiLab exterior must expose its authored doorway threshold")
	var payload = entry.get_meta("interior_payload", {})
	assert(payload is Dictionary, "Interior threshold must carry its destination payload")
	var digilab_section := area.get_node_or_null("Section_-1_0") as WorldAreaSection
	assert(digilab_section != null, "DigiLab section must be loaded for interior regression")
	var digilab_building := digilab_section.get_node_or_null("DigiLabExterior/Building") as Sprite2D
	assert(digilab_building != null, "DigiLab exterior building must be present before entry")
	assert(
		digilab_building.texture != null
		and digilab_building.texture.resource_path == "res://assets/world/tblack/digilab/digilab.png",
		"DigiLab must start with the closed-door base frame"
	)
	var raw_return = (payload as Dictionary).get("return_position", [])
	assert(raw_return is Array and raw_return.size() >= 2, "Interior threshold must define an exterior return point")
	var expected_return := Vector2(float(raw_return[0]), float(raw_return[1]))

	player.global_position = entry.global_position
	assert(
		await _wait_for_texture_path(
			digilab_building,
			"res://assets/world/tblack/digilab/digilab-door-semi-open.png",
			30
		),
		"DigiLab doorway must advance to the supplied semi-open frame before teleporting"
	)
	assert(
		await _wait_for_texture_path(
			digilab_building,
			"res://assets/world/tblack/digilab/digilab-door-open.png",
			30
		),
		"DigiLab doorway must show the supplied open frame before interior handoff"
	)
	assert(not bool(manager.call("is_active")), "DigiLab must finish the door-opening animation before teleport")
	for _index in range(45):
		if bool(manager.call("is_active")):
			break
		await get_tree().process_frame
	assert(bool(manager.call("is_active")), "Crossing the DigiLab doorway must enter its dedicated interior")
	assert(not area.is_exterior_active(), "Loaded exterior area must be hidden and paused while the player is inside")
	assert(get_tree().current_scene == self, "Interior entry must not change the active scene")
	assert(player.global_position.distance_to(expected_return) > 1000.0, "Interior must live in its own streamed world space")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Interior spawn must be walkable")
	assert(
		int(world.call("get_area_banner_presentation_count")) == initial_banner_count,
		"Entering a local interior must not display an area-title banner"
	)

	var exit_thresholds := get_tree().get_nodes_in_group("world_interior_exit_threshold")
	assert(not exit_thresholds.is_empty(), "Interior must expose a physical exit threshold")
	var exit_threshold := exit_thresholds[0] as Area2D
	player.global_position = exit_threshold.global_position
	await _physics_frames(3)
	await get_tree().create_timer(1.0).timeout
	assert(not bool(manager.call("is_active")), "Crossing the interior doorway must return to the city")
	assert(area.is_exterior_active(), "Loaded exterior area must reactivate after exit")
	assert(
		digilab_building.texture != null
		and digilab_building.texture.resource_path == "res://assets/world/tblack/digilab/digilab.png",
		"DigiLab door must reset to the closed base frame before the exterior is shown again"
	)
	assert(player.global_position.is_equal_approx(expected_return), "Exit must restore the authored exterior return position")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "DigiLab return point must be walkable after exit")
	var before_escape := player.global_position
	player.call("_try_move", Vector2(0.0, 12.0))
	assert(
		player.global_position.distance_to(before_escape) > 6.0,
		"Player must be able to walk away immediately after leaving DigiLab"
	)
	assert(get_tree().current_scene == self, "Interior exit must remain in the same SceneTree")
	assert(
		int(world.call("get_area_banner_presentation_count")) == initial_banner_count,
		"Returning from a local interior must not display an area-title banner"
	)

	print("seamless world interior regression passed")
	get_tree().quit()


func _wait_for_world_ready(world: Node, max_frames: int = 120) -> void:
	for _index in range(max_frames):
		if bool(world.call("is_world_ready")):
			return
		await get_tree().process_frame
	assert(false, "World must finish staged area loading before interior regression")


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _wait_for_texture_path(sprite: Sprite2D, resource_path: String, max_frames: int) -> bool:
	for _index in range(max_frames):
		if (
			sprite != null
			and sprite.texture != null
			and sprite.texture.resource_path == resource_path
		):
			return true
		await get_tree().process_frame
	return false


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().physics_frame
