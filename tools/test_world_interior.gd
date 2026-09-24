extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")
const DIGILAB_FLOOR_1_PATH := "res://assets/world/tblack/digilab/floor/floor-1.png"
const DIGILAB_WALL_PATHS := {
	"straight_left": "res://assets/world/tblack/digilab/wall/wall-straight-left.png",
	"straight_right": "res://assets/world/tblack/digilab/wall/wall-straight-right.png",
	"inner_corner": "res://assets/world/tblack/digilab/wall/inner-corner.png",
	"outer_corner": "res://assets/world/tblack/digilab/wall/outer-corner.png",
	"joint_pillar": "res://assets/world/tblack/digilab/wall/joint-pillar.png",
	"door_frame": "res://assets/world/tblack/digilab/wall/door-frame.png",
	"low_divider": "res://assets/world/tblack/digilab/wall/low-divider.png",
	"wall_end_cap": "res://assets/world/tblack/digilab/wall/wall-end-cap.png",
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
	assert(walls.get_child_count() == 1, "DigiLab must not mix legacy block walls with the authored wall kit")

	var authored := walls.get_node_or_null("AuthoredWalls")
	assert(authored != null, "DigiLab must compose walls under one authored wall root")
	assert(authored.get_child_count() == 59, "DigiLab wall composition must keep the reviewed modular piece count")
	assert(
		(authored.get_meta("grid_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(64.0, 32.0)),
		"Authored DigiLab walls must remain bound to the 64x32 world grid"
	)

	var seen_kinds: Dictionary = {}
	var seen_anchors: Dictionary = {}
	for child in authored.get_children():
		var sprite := child as Sprite2D
		assert(sprite != null and sprite.texture != null, "Every authored DigiLab wall piece must be a textured Sprite2D")
		assert(sprite.region_enabled, "Wall normalization must trim transparent source padding at runtime")
		assert(sprite.region_rect.size.x > 0.0 and sprite.region_rect.size.y > 0.0, "Normalized wall region must contain visible source pixels")
		assert(sprite.region_rect.size.x <= 1254.0 and sprite.region_rect.size.y <= 1254.0, "Wall region must stay inside the supplied 1254x1254 source canvas")

		var kind := String(sprite.get_meta("digilab_wall_piece", ""))
		assert(DIGILAB_WALL_PATHS.has(kind), "Every authored wall sprite must declare a known wall-piece role")
		assert(
			sprite.texture.resource_path == String(DIGILAB_WALL_PATHS[kind]),
			"Each wall-piece role must use its matching supplied Tblack texture"
		)
		seen_kinds[kind] = true

		var normalized_scale := float(sprite.get_meta("normalized_scale", 0.0))
		var target_contact_width := float(sprite.get_meta("target_contact_width", 0.0))
		var normalized_contact_width := float(sprite.get_meta("normalized_contact_width", 0.0))
		assert(normalized_scale > 0.0 and normalized_scale <= 0.32, "Wall normalization scale must stay positive and bounded")
		assert(target_contact_width > 0.0, "Every wall role must define a target grid-contact width")
		assert(
			absf(normalized_contact_width - target_contact_width) <= maxf(3.0, target_contact_width * 0.12),
			"Wall normalization must keep each visible base close to its role-specific grid width"
		)

		var grid_anchor = sprite.get_meta("grid_anchor_cell", Vector2(-1000.0, -1000.0))
		assert(grid_anchor is Vector2, "Every wall piece must retain its authored grid anchor")
		var anchor := grid_anchor as Vector2
		assert(
			is_equal_approx(anchor.x * 2.0, round(anchor.x * 2.0))
			and is_equal_approx(anchor.y * 2.0, round(anchor.y * 2.0)),
			"Wall anchors may use only integer or half-cell coordinates"
		)
		var anchor_key := "%s@%.1f,%.1f" % [kind, anchor.x, anchor.y]
		assert(not seen_anchors.has(anchor_key), "Authored wall composition must not duplicate the same piece on the same grid anchor")
		seen_anchors[anchor_key] = true

	for kind in DIGILAB_WALL_PATHS.keys():
		assert(seen_kinds.has(kind), "DigiLab wall composition must exercise every supplied wall asset role: %s" % kind)


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
