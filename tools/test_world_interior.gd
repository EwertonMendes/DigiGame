extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")
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
		authored.get_child_count() == 8,
		"DigiLab wall renderer must stay at eight visual nodes: three batches, four corners and one doorway"
	)
	assert(
		(authored.get_meta("grid_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(64.0, 32.0)),
		"Runtime DigiLab walls must remain bound to the 64x32 world grid"
	)
	assert(
		String(authored.get_meta("layout_contract", "")) == "grid-native-vector-batched",
		"DigiLab wall placement must use the batched grid-native vector contract"
	)

	var logical_counts: Dictionary = {}
	var anchors_by_kind: Dictionary = {}
	var batch_kinds: Dictionary = {}

	for child in authored.get_children():
		if child is MultiMeshInstance2D:
			var batch := child as MultiMeshInstance2D
			assert(batch.multimesh != null and batch.texture != null, "Every wall batch must own a MultiMesh and texture")
			var kind := String(batch.get_meta("digilab_wall_batch", ""))
			assert(kind in ["straight_right", "straight_left", "low_divider"], "Only repeated straight/divider modules may be batched")
			assert(
				String(batch.get_meta("normalization_contract", "")) == "grid-native-vector-batch",
				"Wall batches must use the deterministic grid-native batch contract"
			)
			assert(
				String(batch.get_meta("source_kind", "")) == "runtime_svg",
				"Wall batches must render prebuilt runtime SVGs"
			)
			assert(DIGILAB_WALL_PATHS.has(kind), "Wall batch must declare a known wall role")
			assert(
				batch.texture.resource_path == String(DIGILAB_WALL_PATHS[kind]),
				"Wall batch must use the exact grid-native SVG for its role"
			)
			var batch_count := int(batch.get_meta("batch_count", 0))
			assert(batch_count > 0 and batch.multimesh.instance_count == batch_count, "Wall batch metadata must match MultiMesh instance count")
			logical_counts[kind] = batch_count
			batch_kinds[kind] = true
			var grid_anchors := batch.get_meta("grid_anchors", []) as Array
			assert(grid_anchors.size() == batch_count, "Wall batch must retain every logical grid anchor")
			anchors_by_kind[kind] = grid_anchors
			var span := batch.get_meta("grid_span", Vector2.ZERO) as Vector2
			if kind == "straight_right":
				assert(span.is_equal_approx(Vector2(1.0, 0.0)), "Back wall modules must own one X-grid edge")
			elif kind == "straight_left":
				assert(span.is_equal_approx(Vector2(0.0, 1.0)), "Side wall modules must own one Y-grid edge")
			else:
				assert(span.is_equal_approx(Vector2(1.0, 0.0)), "Front dividers must own one X-grid edge")
			continue

		var sprite := child as Sprite2D
		assert(sprite != null and sprite.texture != null, "Non-batched wall nodes must be connector/door Sprite2D assets")
		assert(sprite.scale.is_equal_approx(Vector2.ONE), "Grid-native connector assets must render at scale 1")
		assert(is_zero_approx(sprite.rotation), "Grid-native connector assets must never rotate at runtime")
		assert(not sprite.flip_h and not sprite.flip_v, "Grid-native connector assets must never mirror at runtime")
		assert(
			String(sprite.get_meta("normalization_contract", "")) == "grid-native-vector",
			"Connector assets must use the deterministic grid-native vector contract"
		)
		var kind := String(sprite.get_meta("digilab_wall_piece", ""))
		assert(
			kind in ["corner_back_left", "corner_back_right", "corner_front_left", "corner_front_right", "door_frame"],
			"Only orientation-specific corners and the doorway may remain individual sprites"
		)
		assert(DIGILAB_WALL_PATHS.has(kind), "Connector sprite must declare a known role")
		assert(
			sprite.texture.resource_path == String(DIGILAB_WALL_PATHS[kind]),
			"Connector sprite must use its exact orientation-specific SVG"
		)
		logical_counts[kind] = int(logical_counts.get(kind, 0)) + 1
		var anchor := sprite.get_meta("grid_anchor_cell", Vector2(-1000.0, -1000.0)) as Vector2
		assert(
			is_equal_approx(anchor.x, round(anchor.x))
			and is_equal_approx(anchor.y, round(anchor.y)),
			"Connector anchors must sit on exact integer grid vertices"
		)
		anchors_by_kind[kind] = [anchor]

	assert(batch_kinds.size() == 3, "DigiLab must use exactly three repeated-geometry wall batches")
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
		String(physics_root.get_meta("digilab_wall_collision_backend", "")) == "blocked-cells-only",
		"DigiLab walls must not duplicate blocked-cell movement rules with per-tile PhysicsServer colliders"
	)

	assert(ResourceLoader.exists(DIGILAB_WALL_PATHS["wall_end_cap"]), "Canonical DigiLab end-cap SVG must remain available")


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
