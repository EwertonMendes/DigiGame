extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)
	WorldState.reset_to_defaults()

	var world := WORLD_SCENE.instantiate()
	add_child(world)
	var saw_partial_area := await _wait_for_world_ready(world)

	var player := world.call("get_player") as Node2D
	var area := world.call("get_area_scene") as WorldAreaScene
	assert(saw_partial_area, "Area construction must yield across frames instead of blocking the first frame")
	assert(player != null and area != null, "Campaign world must expose its player and loaded area scene")
	assert(area.get_section_count() == 25, "Central City must be fully built before gameplay starts")
	assert(
		area.get_ground_render_node_count() <= 6,
		"Central City ground must stay globally batched across the four approved Test Hub surface textures"
	)
	assert(area.get_ground_tile_count() == 4900, "Central City global ground batch must contain all authored cells")
	assert(
		area.get_runtime_node_count() < 1000,
		"Central City runtime node budget must remain below 1000 nodes"
	)
	assert(area.is_exterior_active(), "Central City exterior must start active")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Fresh campaign spawn must be walkable")
	assert(get_tree().get_nodes_in_group("central_city_wall_block").size() > 0, "Central City structures must use joined wall blocks")
	for building_node in get_tree().get_nodes_in_group("central_city_building"):
		var building := building_node as Node2D
		assert(building != null, "Central City building metadata must belong to Node2D structures")
		assert(int(building.get_meta("wall_levels", 0)) >= 3, "Every Central City establishment must be at least three blocks tall")
		assert(building.find_child("Roof", true, false) == null, "Central City buildings must not create floating roof tile layers")
		var origin_variant = building.get_meta("grid_origin", null)
		var size_variant = building.get_meta("grid_size", null)
		if origin_variant is Vector2i and size_variant is Vector2i:
			var building_origin: Vector2i = origin_variant
			var building_size: Vector2i = size_variant
			var definition := area.get_section_definition((building.get_parent() as WorldAreaSection).section_coord)
			var theme := String(definition.get("theme", ""))
			if theme in ["digilab", "hospital"]:
				assert(building_origin.y + building_size.y - 1 <= 4, "Horizontal-road establishments must stay above the road with a sidewalk buffer")
			elif theme in ["training", "market"]:
				assert(building_origin.x + building_size.x - 1 <= 4, "Vertical-road establishments must stay left of the road with a sidewalk buffer")
	assert(player.global_position.is_equal_approx(Vector2(-96.0, 272.0)), "Fresh campaign spawn must use the safe plaza lane")

	await _frames(2)
	var banner_count_before_travel := int(world.call("get_area_banner_presentation_count"))
	assert(banner_count_before_travel == 1, "Central City main-area banner should present once on entry")

	var initial_child_count := area.get_child_count()
	_assert_seam_crossing(player, area, Vector2(13.35, 7.0), Vector2(13.65, 7.0), Vector2i(1, 0), "east")
	_assert_seam_crossing(player, area, Vector2(-0.35, 7.0), Vector2(-0.65, 7.0), Vector2i(-1, 0), "west")
	_assert_seam_crossing(player, area, Vector2(7.0, 13.35), Vector2(7.0, 13.65), Vector2i(0, 1), "south")
	_assert_seam_crossing(player, area, Vector2(7.0, -0.35), Vector2(7.0, -0.65), Vector2i(0, -1), "north")

	player.global_position = _grid_to_world(Vector2(35, 7))
	await _frames(4)
	assert(area.world_to_section(player.global_position) == Vector2i(2, 0), "The authored East Gate section must be reachable in the same scene")
	assert(area.get_section_count() == 25, "Walking must never load or unload parts of Central City")
	assert(area.get_child_count() == initial_child_count, "Area scene tree must remain stable while exploring")
	assert(get_tree().current_scene == self, "Exploring Central City must never replace the active scene")
	await _frames(2)
	assert(
		int(world.call("get_area_banner_presentation_count")) == banner_count_before_travel,
		"Crossing internal authoring sections must never show an area-title banner"
	)

	WorldState.capture_location("central_city", "central_city", Vector2i(2, 0), player.global_position, "east")
	var saved := WorldState.to_dict()
	WorldState.reset_to_defaults()
	WorldState.load_dict(saved)
	assert(WorldState.current_chunk == Vector2i(2, 0), "Legacy spatial cell metadata must remain save-compatible")
	assert(WorldState.player_position.is_equal_approx(player.global_position), "World state round-trip must preserve exact position")
	assert(WorldState.player_facing == "east", "World state round-trip must preserve facing")

	print("single-scene world area regression passed")
	get_tree().quit()


func _assert_seam_crossing(
	player: Node2D,
	area: WorldAreaScene,
	before_grid: Vector2,
	after_grid: Vector2,
	expected_section: Vector2i,
	direction_name: String
) -> void:
	var before := _grid_to_world(before_grid)
	var after := _grid_to_world(after_grid)
	player.global_position = before
	player.call("_try_move", after - before)
	assert(
		player.global_position.distance_to(after) < 2.0,
		"Continuous movement must cross the %s authoring seam without an invisible wall" % direction_name
	)
	assert(
		area.world_to_section(player.global_position) == expected_section,
		"Crossing %s must resolve to section %s" % [direction_name, str(expected_section)]
	)


func _wait_for_world_ready(world: Node, max_frames: int = 120) -> bool:
	var saw_partial := false
	for _index in range(max_frames):
		var area = world.call("get_area_scene") as WorldAreaScene
		if area != null:
			var count := area.get_section_count()
			if count > 0 and count < 25:
				saw_partial = true
		if bool(world.call("is_world_ready")):
			return saw_partial
		await get_tree().process_frame
	assert(false, "World must finish staged area loading within the regression frame budget")
	return false


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * 32.0,
		(grid.x + grid.y) * 16.0
	)
