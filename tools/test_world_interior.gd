extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")
const INTERIOR_SCENE := preload("res://scenes/world/world_interior.tscn")
const DIGILAB_FLOOR_1_PATH := "res://assets/world/tblack/digilab/floor/floor-1.png"
const DIGILAB_WALL_PATHS := {
	"straight_left": "res://assets/world/tblack/digilab/wall/runtime/wall-straight-left.svg",
	"straight_right": "res://assets/world/tblack/digilab/wall/runtime/wall-straight-right.svg",
	"corner_back_left": "res://assets/world/tblack/digilab/wall/runtime/corner-back-left.svg",
	"corner_back_right": "res://assets/world/tblack/digilab/wall/runtime/corner-back-right.svg",
	"corner_front_left": "res://assets/world/tblack/digilab/wall/runtime/corner-front-left.svg",
	"corner_front_right": "res://assets/world/tblack/digilab/wall/runtime/corner-front-right.svg",
	"door_frame": "res://assets/world/tblack/digilab/wall/runtime/door-frame.svg",
	"low_divider": "res://assets/world/tblack/digilab/wall/runtime/low-divider.svg",
	"wall_end_cap": "res://assets/world/tblack/digilab/wall/runtime/wall-end-cap.svg",
}


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
	var digilab_exterior := entry.get_parent() as Node2D
	assert(
		digilab_exterior != null and digilab_exterior.name == "DigiLabExterior",
		"DigiLab threshold must belong to its authored exterior"
	)
	var digilab_section := digilab_exterior.get_parent() as WorldAreaSection
	assert(
		digilab_section != null,
		"DigiLab exterior must live in the section selected by its current authoring anchor"
	)
	var digilab_building := digilab_exterior.get_node_or_null("VisualRoot/Building") as Sprite2D
	assert(digilab_building != null, "DigiLab exterior building must be present before entry")
	assert(
		digilab_building.texture != null
		and digilab_building.texture.resource_path == "res://assets/world/tblack/digilab/digilab.png",
		"DigiLab must start with the closed-door base frame"
	)
	var raw_return = (payload as Dictionary).get("return_position", [])
	assert(raw_return is Array and raw_return.size() >= 2, "Interior threshold must define an exterior return point")
	var expected_return := Vector2(float(raw_return[0]), float(raw_return[1]))

	# Reproduce entry from a raised exterior foundation. The transition must
	# switch to the flat interior presentation plane while fully covered, never
	# exposing one frame with stale exterior elevation.
	player.call("set_world_elevation", 48.0)
	player.global_position = entry.global_position
	assert(
		await _wait_for_texture_path(
			digilab_building,
			"res://assets/world/tblack/digilab/digilab-door-semi-open.png",
			1200
		),
		"DigiLab doorway must advance to the supplied semi-open frame before teleporting"
	)
	assert(
		await _wait_for_texture_path(
			digilab_building,
			"res://assets/world/tblack/digilab/digilab-door-open.png",
			1200
		),
		"DigiLab doorway must show the supplied open frame before interior handoff"
	)
	assert(not bool(manager.call("is_active")), "DigiLab must finish the door-opening animation before teleport")
	for _index in range(45):
		if bool(manager.call("is_active")):
			break
		await get_tree().process_frame
	assert(bool(manager.call("is_active")), "Crossing the DigiLab doorway must enter its dedicated interior")
	assert(
		await _wait_for_exterior_state(area, false, 1800),
		"Loaded exterior area must be hidden and paused while the player is inside"
	)
	assert(
		digilab_building.texture != null
		and digilab_building.texture.resource_path == "res://assets/world/tblack/digilab/digilab-door-open.png",
		"DigiLab door must remain fully open while the player is inside"
	)
	assert(
		await _wait_for_transition_state(manager, false, 1800),
		"DigiLab entry transition must finish before testing interior exit"
	)
	var interiors_root := world.get_node_or_null("Interiors") as Node2D
	assert(interiors_root != null and interiors_root.get_child_count() == 1, "DigiLab must create exactly one streamed interior")
	var active_interior := interiors_root.get_child(0) as WorldInterior
	assert(active_interior != null, "Streamed DigiLab interior must use WorldInterior")
	_assert_digilab_floor_assets(active_interior)
	_assert_digilab_wall_assets(active_interior)
	assert(get_tree().current_scene == self, "Interior entry must not change the active scene")
	assert(player.global_position.distance_to(expected_return) > 1000.0, "Interior must live in its own streamed world space")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Interior spawn must be walkable")
	assert(
		is_zero_approx(float(player.call("get_world_elevation"))),
		"Interior entry must reset exterior elevation before the reveal transition"
	)
	assert(
		active_interior.has_safe_spawn_to_exit_path(),
		"DigiLab spawn must remain connected to its exit after layout changes"
	)
	_assert_all_service_navigation_contracts()
	assert(
		int(world.call("get_area_banner_presentation_count")) == initial_banner_count,
		"Entering a local interior must not display an area-title banner"
	)

	var exit_thresholds := get_tree().get_nodes_in_group("world_interior_exit_threshold")
	assert(not exit_thresholds.is_empty(), "Interior must expose a physical exit threshold")
	var exit_threshold := exit_thresholds[0] as Area2D
	player.global_position = exit_threshold.global_position
	await _physics_frames(2)
	assert(
		await _wait_for_exterior_state(area, true, 1800),
		"Loaded exterior area must reactivate after exit"
	)
	assert(
		digilab_building.texture != null
		and digilab_building.texture.resource_path == "res://assets/world/tblack/digilab/digilab-door-open.png",
		"DigiLab must return to the city on the fully-open frame"
	)
	assert(
		await _wait_for_texture_path(
			digilab_building,
			"res://assets/world/tblack/digilab/digilab-door-semi-open.png",
			1800
		),
		"DigiLab return must play the semi-open frame while closing"
	)
	assert(
		await _wait_for_texture_path(
			digilab_building,
			"res://assets/world/tblack/digilab/digilab.png",
			1800
		),
		"DigiLab return must finish on the closed base frame"
	)
	assert(not bool(manager.call("is_active")), "Crossing the interior doorway must return to the city")
	assert(
		await _wait_for_transition_state(manager, false, 1800),
		"DigiLab reverse door animation must finish before movement unlocks"
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


func _assert_digilab_floor_assets(interior: WorldInterior) -> void:
	var floor_root := interior.get_node_or_null("Floor")
	assert(floor_root != null, "DigiLab interior must expose its floor root")
	assert(
		floor_root.get_child_count() == 1,
		"DigiLab floor must batch all 252 logical cells into one render node"
	)

	var batch := floor_root.get_child(0) as MultiMeshInstance2D
	assert(batch != null and batch.multimesh != null, "DigiLab floor must use MultiMeshInstance2D")
	assert(
		batch.multimesh.instance_count == 252,
		"DigiLab 18x14 floor batch must preserve exactly 252 logical grid cells"
	)
	assert(
		batch.texture != null and batch.texture.resource_path == DIGILAB_FLOOR_1_PATH,
		"DigiLab floor batch must render only the authored Floor 1 source"
	)
	assert(
		String(batch.get_meta("render_backend", "")) == "multimesh",
		"DigiLab floor must keep the batched render backend"
	)
	assert(
		(batch.get_meta("grid_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(64.0, 32.0)),
		"DigiLab floor batch must preserve the canonical 64x32 grid"
	)


func _assert_digilab_wall_assets(interior: WorldInterior) -> void:
	var walls := interior.get_node_or_null("Walls")
	assert(walls != null, "DigiLab interior must expose its wall root")
	assert(walls.get_child_count() == 1, "DigiLab must not mix legacy block walls with the runtime vector kit")

	var authored := walls.get_node_or_null("AuthoredWalls")
	assert(authored != null, "DigiLab must compose walls under one authored wall root")
	assert(
		authored.get_child_count() == 61,
		"DigiLab wall renderer must keep 61 individually depth-sorted authored wall pieces"
	)
	assert(
		(authored.get_meta("grid_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(64.0, 32.0)),
		"Runtime DigiLab walls must remain bound to the 64x32 world grid"
	)
	assert(
		String(authored.get_meta("layout_contract", "")) == "grid-native-vector-depth-sorted",
		"DigiLab walls must use per-anchor depth sorting instead of one z-index per MultiMesh run"
	)

	var logical_counts: Dictionary = {}
	var anchors_by_kind: Dictionary = {}
	for child in authored.get_children():
		var sprite := child as Sprite2D
		assert(sprite != null and sprite.texture != null, "Every DigiLab wall module must be an authored Sprite2D")
		assert(sprite.scale.is_equal_approx(Vector2.ONE), "Grid-native wall assets must render at scale 1")
		assert(is_zero_approx(sprite.rotation), "Grid-native wall assets must never rotate at runtime")
		assert(not sprite.flip_h and not sprite.flip_v, "Grid-native wall assets must never mirror at runtime")
		assert(
			String(sprite.get_meta("normalization_contract", "")) == "grid-native-vector",
			"Every DigiLab wall piece must use the deterministic grid-native vector contract"
		)

		var kind := String(sprite.get_meta("digilab_wall_piece", ""))
		assert(DIGILAB_WALL_PATHS.has(kind), "Wall piece must declare a known authored role")
		assert(
			sprite.texture.resource_path == String(DIGILAB_WALL_PATHS[kind]),
			"Wall piece must use the exact grid-native SVG for its role"
		)
		logical_counts[kind] = int(logical_counts.get(kind, 0)) + 1
		var anchor := sprite.get_meta("grid_anchor_cell", Vector2(-1000.0, -1000.0)) as Vector2
		assert(
			is_equal_approx(anchor.x, round(anchor.x))
			and is_equal_approx(anchor.y, round(anchor.y)),
			"Wall anchors must sit on exact integer grid vertices"
		)
		if not anchors_by_kind.has(kind):
			anchors_by_kind[kind] = []
		(anchors_by_kind[kind] as Array).append(anchor)

	assert(int(logical_counts.get("straight_right", 0)) == 17, "Back wall must keep seventeen one-edge modules")
	assert(int(logical_counts.get("straight_left", 0)) == 26, "Side walls must keep twenty-six one-edge modules")
	assert(int(logical_counts.get("low_divider", 0)) == 13, "Front boundary must keep thirteen one-edge low dividers")
	assert(int(logical_counts.get("door_frame", 0)) == 1, "Front boundary must keep exactly one four-edge doorway")
	for corner_kind in ["corner_back_left", "corner_back_right", "corner_front_left", "corner_front_right"]:
		assert(int(logical_counts.get(corner_kind, 0)) == 1, "Each orientation-specific corner must appear exactly once: %s" % corner_kind)

	_assert_anchor_present(anchors_by_kind, "corner_back_left", Vector2(0.0, 0.0))
	_assert_anchor_present(anchors_by_kind, "corner_back_right", Vector2(17.0, 0.0))
	_assert_anchor_present(anchors_by_kind, "corner_front_left", Vector2(0.0, 13.0))
	_assert_anchor_present(anchors_by_kind, "corner_front_right", Vector2(17.0, 13.0))
	_assert_anchor_present(anchors_by_kind, "door_frame", Vector2(7.0, 13.0))

	var physics_root := interior.get_node_or_null("InteriorCollision")
	assert(physics_root != null, "DigiLab interior must expose its collision root")
	assert(
		String(physics_root.get_meta("digilab_wall_collision_backend", "")) == "layout-clearance",
		"DigiLab walls must use the shared clearance-aware layout navigation backend"
	)
	assert(
		String(physics_root.get_meta("movement_backend", "")) == "layout-clearance",
		"Interior collision root must expose the single logical movement backend"
	)
	assert(
		physics_root.get_child_count() == 0,
		"Interior walls/counters must not create redundant PhysicsServer shapes that can push the player"
	)

	assert(ResourceLoader.exists(DIGILAB_WALL_PATHS["wall_end_cap"]), "Canonical DigiLab end-cap SVG must remain available")


func _assert_all_service_navigation_contracts() -> void:
	for service_id: String in ["digilab", "hospital", "training"]:
		var interior := INTERIOR_SCENE.instantiate() as WorldInterior
		assert(interior != null, "%s test interior must instantiate" % service_id)
		interior.configure({
			"interior_id": "navigation_test_%s" % service_id,
			"service": service_id,
			"title": service_id.to_upper(),
			"accent": [0.35, 0.88, 1.0, 1.0],
		}, null)

		assert(
			interior.get_navigation_backend() == "layout-clearance",
			"%s must use the shared interior navigation backend" % service_id
		)
		assert(
			interior.has_safe_spawn_to_exit_path(),
			"%s spawn must always have a connected path to the exit" % service_id
		)
		assert(
			interior.is_grid_cell_walkable(interior.get_spawn_cell())
			and interior.is_grid_cell_walkable(interior.get_exit_cell()),
			"%s spawn and exit cells must remain walkable after layout edits" % service_id
		)

		var collision_root := interior.get_node_or_null("InteriorCollision")
		assert(collision_root != null, "%s must expose its navigation debug root" % service_id)
		assert(
			collision_root.get_child_count() == 0,
			"%s must not mix logical navigation with physical wall/counter colliders" % service_id
		)

		# The center is still in logical row 1 here, but the player's footprint
		# reaches into the back-wall row. Zero-clearance point navigation would
		# incorrectly accept it; actor-aware clearance must reject it.
		var near_back_wall := interior.to_global(
			interior.grid_to_world(Vector2(9.0, 0.8))
		)
		assert(
			interior.is_walkable_world_position(near_back_wall, 0.0),
			"%s near-wall probe must demonstrate why point-only collision is insufficient" % service_id
		)
		assert(
			not interior.is_walkable_world_position(near_back_wall),
			"%s player footprint must stop before entering the upper/back wall" % service_id
		)

		var exit_world := interior.to_global(
			interior.grid_to_world(Vector2(interior.get_exit_cell()))
		)
		assert(
			interior.is_walkable_world_position(exit_world),
			"%s player must be able to reach the lower exit lane" % service_id
		)

		# The lower/front row is not globally forbidden. Its authored wall cells
		# are blocked, while the doorway cells stay physically reachable. The old
		# room-bounds shortcut rejected this whole row and created the large gap
		# reported at the bottom of every interior.
		var doorway_world := interior.to_global(
			interior.grid_to_world(Vector2(9.0, 13.0))
		)
		assert(
			interior.is_walkable_world_position(doorway_world),
			"%s front doorway row must remain reachable instead of being rejected by room bounds" % service_id
		)
		var front_wall_world := interior.to_global(
			interior.grid_to_world(Vector2(2.0, 13.0))
		)
		assert(
			not interior.is_walkable_world_position(front_wall_world, 0.0),
			"%s authored lower wall cell must still block movement" % service_id
		)

		# Continuous boundary around the upper wall: immediately inside the
		# shared edge is floor, immediately beyond it is the actual wall cell.
		var upper_inside := interior.to_global(
			interior.grid_to_world(Vector2(9.0, 0.51))
		)
		var upper_wall := interior.to_global(
			interior.grid_to_world(Vector2(9.0, 0.49))
		)
		assert(
			interior.is_walkable_world_position(upper_inside, 0.0),
			"%s upper floor must stay reachable right up to the wall edge" % service_id
		)
		assert(
			not interior.is_walkable_world_position(upper_wall, 0.0),
			"%s player origin must never cross onto the upper wall top face" % service_id
		)

		var counter_world := interior.to_global(
			interior.grid_to_world(Vector2(9, 4))
		)
		assert(
			not interior.is_walkable_world_position(counter_world, 0.0),
			"%s service counter visual must register its own blocked layout cell" % service_id
		)

		interior.free()


func _assert_anchor_present(anchors_by_kind: Dictionary, kind: String, expected: Vector2) -> void:
	assert(anchors_by_kind.has(kind), "Missing wall role while validating grid anchors: %s" % kind)
	for value in anchors_by_kind[kind]:
		var anchor := value as Vector2
		if anchor.is_equal_approx(expected):
			return
	assert(false, "Missing %s wall anchor at %s" % [kind, expected])


func _wait_for_world_ready(world: Node, max_frames: int = 120) -> void:
	for _index in range(max_frames):
		if bool(world.call("is_world_ready")):
			return
		await get_tree().process_frame
	assert(false, "World must finish staged area loading before interior regression")


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _wait_for_texture_path(sprite: Sprite2D, resource_path: String, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline:
		if (
			sprite != null
			and sprite.texture != null
			and sprite.texture.resource_path == resource_path
		):
			return true
		await get_tree().process_frame
	return false


func _wait_for_exterior_state(area: WorldAreaScene, expected: bool, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline:
		if area != null and area.is_exterior_active() == expected:
			return true
		await get_tree().process_frame
	return false


func _wait_for_transition_state(manager, expected: bool, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline:
		if manager != null and bool(manager.call("is_transitioning")) == expected:
			return true
		await get_tree().process_frame
	return false


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().physics_frame
