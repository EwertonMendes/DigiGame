extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")
const DIGILAB_FLOOR_1_PATH := "res://assets/world/tblack/digilab/floor/floor-1.png"
const DIGILAB_WALL_PATHS := {
	"straight_left": "res://assets/world/tblack/digilab/wall/runtime/wall-straight-left.svg",
	"straight_right": "res://assets/world/tblack/digilab/wall/runtime/wall-straight-right.svg",
	"inner_corner": "res://assets/world/tblack/digilab/wall/runtime/inner-corner.svg",
	"outer_corner": "res://assets/world/tblack/digilab/wall/runtime/outer-corner.svg",
	"joint_pillar": "res://assets/world/tblack/digilab/wall/runtime/joint-pillar.svg",
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
		floor_root.get_child_count() == 252,
		"DigiLab 18x14 floor must keep one visual tile per 64x32 gameplay cell"
	)

	for child in floor_root.get_children():
		var detail := child.get_node_or_null("TopFaceDetail") as Polygon2D
		assert(detail != null and detail.texture != null, "Every DigiLab floor tile must keep the authored Floor 1 texture")
		assert(detail.polygon.size() == 4, "DigiLab floor tiles must remain exact isometric diamonds")
		assert(
			is_equal_approx(absf(detail.polygon[0].x), 32.0)
			and is_equal_approx(absf(detail.polygon[1].y), 16.0),
			"DigiLab visual tiles must remain exactly 64x32"
		)
		assert(
			detail.texture.resource_path == DIGILAB_FLOOR_1_PATH,
			"Every DigiLab floor cell must use the complete Floor 1 source; Floor 2 must not be rendered"
		)
		assert(detail.uv.size() == 4, "Every DigiLab tile must keep the complete authored top-face UV mapping")

func _assert_digilab_wall_assets(interior: WorldInterior) -> void:
	var walls := interior.get_node_or_null("Walls")
	assert(walls != null, "DigiLab interior must expose its wall root")
	assert(walls.get_child_count() == 1, "DigiLab must not mix legacy block walls with the runtime vector kit")

	var authored := walls.get_node_or_null("AuthoredWalls")
	assert(authored != null, "DigiLab must compose walls under one authored wall root")
	assert(authored.get_child_count() == 68, "DigiLab wall shell must keep the exact reviewed grid-edge composition")
	assert(
		(authored.get_meta("grid_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(64.0, 32.0)),
		"Runtime DigiLab walls must remain bound to the 64x32 world grid"
	)
	assert(
		String(authored.get_meta("layout_contract", "")) == "grid-native-vector",
		"DigiLab wall placement must use the grid-native vector contract"
	)

	var counts: Dictionary = {}
	var anchors_by_kind: Dictionary = {}
	for child in authored.get_children():
		var sprite := child as Sprite2D
		assert(sprite != null and sprite.texture != null, "Every DigiLab wall piece must be a textured Sprite2D")
		assert(sprite.scale.is_equal_approx(Vector2.ONE), "Grid-native wall assets must render at exact scale 1")
		assert(is_zero_approx(sprite.rotation), "Grid-native wall assets must never be rotated at runtime")
		assert(not sprite.flip_h and not sprite.flip_v, "Grid-native wall assets must never be mirrored at runtime")
		assert(
			String(sprite.get_meta("normalization_contract", "")) == "grid-native-vector",
			"Every wall node must use the deterministic grid-native vector contract"
		)
		assert(
			String(sprite.get_meta("source_kind", "")) == "runtime_svg",
			"Every wall node must render the prebuilt runtime SVG, not the 1254x1254 AI source PNG"
		)

		var kind := String(sprite.get_meta("digilab_wall_piece", ""))
		assert(DIGILAB_WALL_PATHS.has(kind), "Every runtime wall sprite must declare a known wall role")
		assert(
			sprite.texture.resource_path == String(DIGILAB_WALL_PATHS[kind]),
			"Each runtime wall role must use its exact grid-native SVG"
		)
		counts[kind] = int(counts.get(kind, 0)) + 1

		var anchor := sprite.get_meta("grid_anchor_cell", Vector2(-1000.0, -1000.0)) as Vector2
		assert(
			is_equal_approx(anchor.x, round(anchor.x))
			and is_equal_approx(anchor.y, round(anchor.y)),
			"All runtime wall anchors must sit on exact integer grid vertices"
		)
		if not anchors_by_kind.has(kind):
			anchors_by_kind[kind] = []
		(anchors_by_kind[kind] as Array).append(anchor)

		var span := sprite.get_meta("grid_span", Vector2.ZERO) as Vector2
		match kind:
			"straight_right":
				assert(span.is_equal_approx(Vector2(1.0, 0.0)), "Right wall module must own exactly one X-grid edge")
			"straight_left":
				assert(span.is_equal_approx(Vector2(0.0, 1.0)), "Left wall module must own exactly one Y-grid edge")
			"low_divider":
				assert(span.is_equal_approx(Vector2(1.0, 0.0)), "Low divider must own exactly one X-grid edge")
			"door_frame":
				assert(span.is_equal_approx(Vector2(4.0, 0.0)), "Door frame must own exactly four X-grid edges")
			_:
				assert(span.is_zero_approx(), "Joint/corner assets must not extend the wall run")

		var visual_height := float(sprite.get_meta("visual_height", 0.0))
		if kind == "low_divider":
			assert(is_equal_approx(visual_height, 34.0), "Only the front divider may use the intentional low-wall height")
		else:
			assert(is_equal_approx(visual_height, 72.0), "Every full-height DigiLab wall component must share one exact height")

	assert(int(counts.get("straight_right", 0)) == 17, "Back wall must contain exactly 17 one-edge modules")
	assert(int(counts.get("straight_left", 0)) == 26, "Left and right walls must contain exactly 13 one-edge modules each")
	assert(int(counts.get("inner_corner", 0)) == 2, "Back wall must use exactly two inner joint covers")
	assert(int(counts.get("outer_corner", 0)) == 2, "Front boundary must use exactly two outer joint covers")
	assert(int(counts.get("joint_pillar", 0)) == 7, "Long wall runs must keep the seven reviewed structural seam pillars")
	assert(int(counts.get("low_divider", 0)) == 13, "Front boundary must contain thirteen one-edge divider modules")
	assert(int(counts.get("door_frame", 0)) == 1, "Front boundary must contain exactly one four-edge doorway")

	_assert_anchor_present(anchors_by_kind, "inner_corner", Vector2(0.0, 0.0))
	_assert_anchor_present(anchors_by_kind, "inner_corner", Vector2(17.0, 0.0))
	_assert_anchor_present(anchors_by_kind, "outer_corner", Vector2(0.0, 13.0))
	_assert_anchor_present(anchors_by_kind, "outer_corner", Vector2(17.0, 13.0))
	_assert_anchor_present(anchors_by_kind, "door_frame", Vector2(7.0, 13.0))

	# Runtime end-cap is part of the canonical kit for future partial wall runs,
	# even though the current closed shell terminates into corners/door pillars.
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
