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
		area.get_ground_render_node_count() <= 16,
		"Central City ground must stay globally batched by the curated Devil surface palette"
	)
	assert(area.get_ground_tile_count() == 4341, "Central City octagonal island must omit only the authored corner void")
	assert(
		area.get_node_or_null("CityGround/Surface_main") != null,
		"Central City must render 0072 as its primary high-resolution city surface"
	)
	assert(
		area.get_node_or_null("CityGround/Surface_tech_teal") != null,
		"Central City must render the high-resolution digital promenade surface"
	)
	assert(
		area.get_node_or_null("CityGround/Surface_market") != null,
		"Central City market must render the 0009 replacement surface"
	)
	var edge_blocks := area.get_node_or_null("CityGround/EdgeBlocks")
	assert(
		edge_blocks != null and edge_blocks.get_child_count() > 0,
		"Central City perimeter must expose authored Devil block side faces"
	)
	assert(
		area.get_runtime_node_count() < 1000,
		"Central City runtime node budget must remain below 3000 nodes"
	)
	assert(area.is_exterior_active(), "Central City exterior must start active")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Fresh campaign spawn must be walkable")
	assert(player.global_position.is_equal_approx(Vector2(-96.0, 272.0)), "Fresh campaign spawn must use the 64x32 safe plaza lane")

	var digilab_section := area.get_node_or_null("Section_-1_0") as WorldAreaSection
	assert(digilab_section != null, "DigiLab district must remain in the authored west-central section")
	var digilab_building := digilab_section.get_node_or_null("DigiLabExterior/Building") as Sprite2D
	assert(digilab_building != null, "DigiLab district must render its authored exterior building")
	var digilab_upper := digilab_section.get_node_or_null("DigiLabExterior/UpperOccluder") as Sprite2D
	assert(digilab_upper != null, "DigiLab must split upper occlusion from the foreground facade")
	assert(
		digilab_building.texture != null
		and digilab_building.texture.resource_path == "res://assets/world/tblack/digilab/digilab.png",
		"DigiLab exterior must use the project-supplied Tblack building asset"
	)
	assert(
		ResourceLoader.exists("res://assets/world/tblack/digilab/digilab-door-semi-open.png")
		and ResourceLoader.exists("res://assets/world/tblack/digilab/digilab-door-open.png"),
		"DigiLab door animation must ship both project-supplied opening frames"
	)
	var digilab_entrance := digilab_section.get_node_or_null("DigiLabExterior/DigiLabEntrance") as Area2D
	assert(digilab_entrance != null, "DigiLab exterior must expose a doorway threshold")
	var expected_door := digilab_section.grid_to_world(Vector2(8, 10))
	assert(
		digilab_entrance.position.is_equal_approx(expected_door),
		"DigiLab teleport threshold must be anchored to the authored door position"
	)
	assert(
		digilab_section.is_walkable_world_position(digilab_section.global_position + expected_door),
		"DigiLab doorway must remain walkable"
	)
	assert(
		absf(digilab_building.rotation_degrees - (-2.00295)) < 0.01
		and digilab_building.scale.distance_to(Vector2(0.40, 0.32838876)) < 0.001,
		"DigiLab source perspective must be corrected to the 64x32 city axes"
	)
	assert(
		digilab_building.z_index == 880
		and digilab_upper.z_index == 1800
		and digilab_upper.region_enabled
		and absf(digilab_upper.region_rect.size.y - 700.0) < 0.01,
		"DigiLab must keep the lower facade in front of actors while reserving occlusion for the upper/back art"
	)
	var digilab_floor = digilab_section.call("_ground_presentation", Vector2i(5, 5), "digilab")
	assert(
		digilab_floor is Dictionary
		and String((digilab_floor as Dictionary).get("surface", "")) == "stone_soft",
		"DigiLab lot must use the standard gray 0054 pavement instead of green/teal ground"
	)
	var digilab_collision := digilab_section.get_node_or_null(
		"DigiLabExterior/FootprintCollision/CollisionPolygon2D"
	) as CollisionPolygon2D
	var digilab_left_guard := digilab_section.get_node_or_null(
		"DigiLabExterior/LeftSideGuardCollision/CollisionPolygon2D"
	) as CollisionPolygon2D
	var digilab_right_guard := digilab_section.get_node_or_null(
		"DigiLabExterior/RightSideGuardCollision/CollisionPolygon2D"
	) as CollisionPolygon2D
	var digilab_upper_right_guard := digilab_section.get_node_or_null(
		"DigiLabExterior/UpperRightGuardCollision/CollisionPolygon2D"
	) as CollisionPolygon2D
	assert(
		digilab_collision != null and digilab_collision.polygon.size() == 22,
		"DigiLab must use the detailed measured ground-contact footprint"
	)
	assert(
		digilab_left_guard != null and digilab_left_guard.polygon.size() == 6
		and digilab_right_guard != null and digilab_right_guard.polygon.size() == 6
		and digilab_upper_right_guard != null and digilab_upper_right_guard.polygon.size() == 7,
		"DigiLab side and upper-right utilities must expose dedicated player-clearance guards"
	)
	assert(
		digilab_section.is_walkable_world_position(
			digilab_section.global_position + digilab_section.grid_to_world(Vector2(5, 5))
		),
		"Open pavement behind the DigiLab must not have an invisible collision barrier"
	)
	assert(
		not digilab_section.is_walkable_world_position(
			digilab_section.global_position + digilab_section.grid_to_world(Vector2(5, 8))
		),
		"DigiLab measured footprint must block movement through the center of the structure"
	)
	assert(
		not digilab_section.is_walkable_world_position(
			digilab_section.global_position + digilab_section.grid_to_world(Vector2(2, 11))
		),
		"DigiLab measured footprint must cover the lower-left wall that was previously penetrable"
	)
	# Regression points are expressed in source-image coordinates so they track
	# the exact visible corners reviewed in-game instead of relying on coarse
	# grid cells.
	var digilab_door_local := digilab_section.grid_to_world(Vector2(8, 10))
	for source_point: Vector2 in [
		Vector2(80.0, 820.0),   # far-left rear/side corner
		Vector2(250.0, 860.0),  # left lower wing: player must not visually enter facade
		Vector2(410.0, 930.0),  # left inner corner reviewed in screenshot
		Vector2(980.0, 820.0),  # right utility cluster inner edge
		Vector2(1090.0, 700.0), # upper-right cyan antenna platform reviewed in screenshot
		Vector2(1180.0, 760.0), # upper-right outer utility corner
		Vector2(1160.0, 900.0), # right protruding wing reviewed in screenshot
		Vector2(330.0, 1020.0), # lower-left utility wing
		Vector2(1020.0, 760.0), # right cylinder / utility cluster
		Vector2(1140.0, 930.0), # far-right side wall
		Vector2(970.0, 1080.0), # lower-right facade corner
	]:
		var local_corner = digilab_section.call("_digilab_source_to_local", source_point, digilab_door_local)
		assert(
			local_corner is Vector2
			and not digilab_section.is_walkable_world_position(
				digilab_section.global_position + (local_corner as Vector2)
			),
			"DigiLab visible corner %s must be covered by the measured footprint" % str(source_point)
		)
	for source_point: Vector2 in [
		Vector2(15.0, 875.0),    # pavement just outside expanded left guard
		Vector2(1252.0, 1000.0), # pavement just outside expanded right guard
	]:
		var local_clear = digilab_section.call("_digilab_source_to_local", source_point, digilab_door_local)
		assert(
			local_clear is Vector2
			and digilab_section.is_walkable_world_position(
				digilab_section.global_position + (local_clear as Vector2)
			),
			"DigiLab pavement just outside %s must stay walkable" % str(source_point)
		)
	var digilab_payload = digilab_entrance.get_meta("interior_payload", {})
	assert(digilab_payload is Dictionary, "DigiLab doorway must preserve the seamless interior payload")
	var digilab_return = (digilab_payload as Dictionary).get("return_position", [])
	var expected_return := digilab_section.global_position + digilab_section.grid_to_world(Vector2(10, 12))
	assert(
		digilab_return is Array
		and digilab_return.size() >= 2
		and Vector2(float(digilab_return[0]), float(digilab_return[1])).is_equal_approx(expected_return),
		"DigiLab interior exit must return directly in front of the authored door"
	)

	var training_section := area.get_node_or_null("Section_0_-1") as WorldAreaSection
	assert(training_section != null, "Training Center must remain in the authored north-central section")
	var training_building := training_section.get_node_or_null("TrainingCenterExterior/Building") as Sprite2D
	var training_upper := training_section.get_node_or_null("TrainingCenterExterior/UpperOccluder") as Sprite2D
	assert(training_building != null, "Training district must render the authored Training Center exterior")
	assert(training_upper != null, "Training Center must split upper occlusion from its foreground facade")
	assert(
		training_building.texture != null
		and training_building.texture.resource_path == "res://assets/world/tblack/training-center/training-center.png",
		"Training Center exterior must use the supplied project asset"
	)
	assert(
		training_building.scale.distance_to(Vector2(0.36, 0.28231)) < 0.001
		and absf(training_building.rotation_degrees - (-2.20613)) < 0.01,
		"Training Center source projection must be corrected to the 64x32 city axes"
	)
	assert(
		training_building.z_index == 880
		and training_upper.z_index == 1800
		and training_upper.region_enabled
		and absf(training_upper.region_rect.size.y - 720.0) < 0.01,
		"Training Center depth split must keep the facade readable while allowing rear occlusion"
	)
	var training_entrance := training_section.get_node_or_null(
		"TrainingCenterExterior/TrainingCenterEntrance"
	) as Area2D
	assert(training_entrance != null, "Training Center must expose its static doorway threshold")
	var expected_training_door := training_section.grid_to_world(Vector2(7, 11))
	assert(
		training_entrance.position.is_equal_approx(expected_training_door),
		"Training Center threshold must align to the authored down-left-facing door"
	)
	assert(
		training_section.is_walkable_world_position(training_section.global_position + expected_training_door),
		"Training Center stairs and doorway must remain walkable"
	)
	var training_forecourt = training_section.call("_ground_presentation", Vector2i(7, 12), "training")
	var training_lot = training_section.call("_ground_presentation", Vector2i(2, 2), "training")
	assert(
		training_forecourt is Dictionary
		and String((training_forecourt as Dictionary).get("surface", "")) == "stone_soft",
		"Training Center entrance must meet the standard 0054 city pavement"
	)
	assert(
		training_lot is Dictionary
		and String((training_lot as Dictionary).get("surface", "")) == "stone_soft",
		"Training Center district must use the same neutral 0054 pavement as the DigiLab surroundings"
	)
	var training_collision := training_section.get_node_or_null(
		"TrainingCenterExterior/FootprintCollision/CollisionPolygon2D"
	) as CollisionPolygon2D
	assert(
		training_collision != null and training_collision.polygon.size() == 21,
		"Training Center must use the measured source-space ground-contact footprint"
	)
	assert(
		not training_section.is_walkable_world_position(
			training_section.global_position + training_section.grid_to_world(Vector2(7, 7))
		),
		"Training Center structure footprint must block movement through the building"
	)
	var training_door_local := training_section.grid_to_world(Vector2(7, 11))
	for source_point: Vector2 in [
		Vector2(100.0, 820.0),
		Vector2(610.0, 850.0),
		Vector2(1120.0, 800.0),
		Vector2(650.0, 1120.0),
	]:
		var local_corner = training_section.call("_training_center_source_to_local", source_point, training_door_local)
		assert(
			local_corner is Vector2
			and not training_section.is_walkable_world_position(
				training_section.global_position + (local_corner as Vector2)
			),
			"Training Center visible structure point %s must be collision-covered" % str(source_point)
		)
	var training_payload = training_entrance.get_meta("interior_payload", {})
	assert(training_payload is Dictionary, "Training Center doorway must preserve the service payload")
	var training_return = (training_payload as Dictionary).get("return_position", [])
	var expected_training_return := training_section.global_position + training_section.grid_to_world(Vector2(7, 13))
	assert(
		training_return is Array
		and training_return.size() >= 2
		and Vector2(float(training_return[0]), float(training_return[1])).is_equal_approx(expected_training_return),
		"Training Center interior exit must return to the paved approach in front of the door"
	)

	assert(
		not area.is_walkable_world_position(_grid_to_world(Vector2(-28, -28))),
		"Clipped northwest corner must be digital void rather than invisible walkable floor"
	)
	assert(
		(_grid_to_world(Vector2(1, 0)) - _grid_to_world(Vector2.ZERO)).is_equal_approx(Vector2(32.0, 16.0)),
		"Central City exterior grid must be 64x32"
	)

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
