extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")
const WORLD_DEPTH = preload("res://src/world/runtime/WorldDepth.gd")
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
	var manager := world.call("get_interior_manager") as WorldInteriorManager
	assert(player != null and area != null and manager != null, "World must expose player, area and interior manager")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Player must spawn on walkable Central City ground")
	assert(
		float(player.call("get_world_elevation")) > 0.0,
		"Regression setup must start on Central City's raised exterior so the interior handoff proves elevation isolation"
	)

	var entry_thresholds := get_tree().get_nodes_in_group("world_interior_threshold")
	assert(not entry_thresholds.is_empty(), "Loaded area service entrances must expose physical entry thresholds")
	var entry: Area2D = null
	var service_payloads: Dictionary = {}
	for candidate in entry_thresholds:
		var candidate_area := candidate as Area2D
		if candidate_area == null:
			continue
		var candidate_payload = candidate_area.get_meta("interior_payload", {})
		if not candidate_payload is Dictionary:
			continue
		var service_id := String((candidate_payload as Dictionary).get("service", ""))
		if service_id.is_empty():
			continue
		service_payloads[service_id] = (candidate_payload as Dictionary).duplicate(true)
		if service_id == "digilab":
			entry = candidate_area
	assert(entry != null, "DigiLab exterior must expose its authored doorway threshold")
	assert(
		service_payloads.has("hospital") and service_payloads.has("training"),
		"Hospital and Training Center must expose payloads for the shared interior presentation regression"
	)
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
	_assert_active_interior_presentation_is_flat(world, player, "DigiLab")
	var interiors_root := world.get_node_or_null("Interiors") as Node2D
	assert(interiors_root != null and interiors_root.get_child_count() == 1, "DigiLab must create exactly one streamed interior")
	var active_interior := interiors_root.get_child(0) as WorldInterior
	assert(active_interior != null, "Streamed DigiLab interior must use WorldInterior")
	_assert_digilab_floor_assets(active_interior)
	_assert_digilab_wall_assets(active_interior)
	_assert_digilab_navigation_footprint(active_interior)
	_assert_player_wall_runtime_guard(player, active_interior, "DigiLab")
	_assert_follower_navigation_guard(world, active_interior)
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

	await _assert_service_interior_presentation_isolated(
		world,
		player,
		manager,
		service_payloads["hospital"] as Dictionary,
		"Hospital"
	)
	await _assert_service_interior_presentation_isolated(
		world,
		player,
		manager,
		service_payloads["training"] as Dictionary,
		"Training Center"
	)

	print("seamless world interior regression passed")
	get_tree().quit()


func _assert_active_interior_presentation_is_flat(
	world: Node,
	player: Node2D,
	label: String
) -> void:
	var area := world.call("get_area_scene") as WorldAreaScene
	assert(area != null, "%s must expose Central City topology for the isolation regression" % label)
	var projected_exterior_elevation := float(
		area.get_elevation_at_world_position(player.global_position)
	)
	assert(
		projected_exterior_elevation > 0.0,
		"%s regression setup must prove the remote interior stage would be misclassified by Central City topology" % label
	)
	assert(
		is_zero_approx(float(world.call("get_world_elevation_at", player.global_position))),
		"%s public elevation queries must resolve to the flat interior plane for followers and other presentation clients" % label
	)
	assert(
		is_zero_approx(float(player.call("get_world_elevation"))),
		"%s must enter on the flat interior presentation plane" % label
	)

	# Exercise the exact historical failure path. The raw exterior topology is
	# non-zero here, but both direct player sync and public elevation consumers
	# must remain isolated while the interior is active.
	world.call("_sync_player_elevation", player.global_position)
	assert(
		is_zero_approx(float(player.call("get_world_elevation"))),
		"%s must reject exterior elevation while its local interior is active" % label
	)
	var party_followers := world.get_node_or_null("PartyFollowers")
	assert(party_followers != null, "%s must keep the shared follower controller alive" % label)
	assert(
		is_zero_approx(float(party_followers.call("_world_elevation_at", player.global_position))),
		"%s followers must use the same flat interior presentation plane as the player" % label
	)

	var before_move := player.global_position
	player.call("_try_move", Vector2(8.0, 0.0))
	assert(
		player.global_position.distance_to(before_move) > 1.0,
		"%s regression must actually move the actor inside the interior" % label
	)
	assert(
		is_zero_approx(float(player.call("get_world_elevation"))),
		"%s movement must not reapply Central City elevation to the interior stage" % label
	)


func _assert_service_interior_presentation_isolated(
	world: Node,
	player: Node2D,
	manager: WorldInteriorManager,
	payload: Dictionary,
	label: String
) -> void:
	var entered: bool = await manager.enter_interior(payload.duplicate(true))
	assert(entered and manager.is_active(), "%s must enter through the shared interior manager" % label)
	assert(
		await _wait_for_transition_state(manager, false, 1800),
		"%s entry transition must finish before presentation validation" % label
	)
	_assert_active_interior_presentation_is_flat(world, player, label)
	var interiors_root := world.get_node_or_null("Interiors") as Node2D
	assert(
		interiors_root != null and interiors_root.get_child_count() == 1,
		"%s must expose exactly one active streamed interior" % label
	)
	var active_interior := interiors_root.get_child(0) as WorldInterior
	assert(active_interior != null, "%s must use WorldInterior" % label)
	_assert_generic_shell_clearance(active_interior, label)
	_assert_player_wall_runtime_guard(player, active_interior, label)

	var exited: bool = await manager.exit_interior()
	assert(exited and not manager.is_active(), "%s must exit through the shared interior manager" % label)
	assert(
		await _wait_for_transition_state(manager, false, 1800),
		"%s exit transition must restore the exterior before validation" % label
	)
	var expected_exterior_elevation := float(world.call("get_world_elevation_at", player.global_position))
	assert(
		is_equal_approx(float(player.call("get_world_elevation")), expected_exterior_elevation),
		"%s exit must restore the exterior presentation elevation" % label
	)


func _assert_generic_shell_clearance(interior: WorldInterior, label: String) -> void:
	var back_overlap := interior.to_global(interior.grid_to_world(Vector2(9.0, 1.25)))
	var back_clear := interior.to_global(interior.grid_to_world(Vector2(9.0, 1.40)))
	var side_overlap := interior.to_global(interior.grid_to_world(Vector2(1.25, 8.0)))
	var side_clear := interior.to_global(interior.grid_to_world(Vector2(1.40, 8.0)))
	var corner_overlap := interior.to_global(interior.grid_to_world(Vector2(1.25, 1.25)))
	var corner_clear := interior.to_global(interior.grid_to_world(Vector2(1.40, 1.40)))
	var front_doorway := interior.to_global(interior.grid_to_world(Vector2(9.0, 12.42)))

	assert(
		not interior.is_walkable_world_position(back_overlap),
		"%s must keep visible feet off the tall back-wall top face" % label
	)
	assert(
		interior.is_walkable_world_position(back_clear),
		"%s must preserve usable floor immediately after the authored back-wall clearance" % label
	)
	assert(
		not interior.is_walkable_world_position(side_overlap),
		"%s must use the same authored clearance against tall side walls" % label
	)
	assert(
		interior.is_walkable_world_position(side_clear),
		"%s must preserve usable floor after the side-wall clearance" % label
	)
	assert(
		not interior.is_walkable_world_position(corner_overlap),
		"%s must not allow the actor footprint into the tall back/side corner face" % label
	)
	assert(
		interior.is_walkable_world_position(corner_clear),
		"%s must recover walkable floor immediately after the tall corner footprint" % label
	)
	assert(
		interior.is_walkable_world_position(front_doorway),
		"%s front doorway must keep its authored lower-boundary reachability" % label
	)


func _assert_digilab_navigation_footprint(interior: WorldInterior) -> void:
	# DigiLab's vector wall sits on the authored grid edge, unlike the two-level
	# city blocks used by Hospital/Training. Straight wall contact stays close,
	# while the wider connector pillars receive a localized diagonal blocker.
	var side_overlap := interior.to_global(interior.grid_to_world(Vector2(16.25, 4.0)))
	var side_clear := interior.to_global(interior.grid_to_world(Vector2(16.05, 4.0)))
	var back_overlap := interior.to_global(interior.grid_to_world(Vector2(9.0, 0.76)))
	var back_clear := interior.to_global(interior.grid_to_world(Vector2(9.0, 0.90)))
	var left_pillar_overlap := interior.to_global(interior.grid_to_world(Vector2(0.82, 0.82)))
	# The center must leave enough room for the actor's 10 px downward sample as
	# well as the local pillar plane. 1.05 is still visually adjacent to the
	# connector, but is outside the complete actor footprint rather than only the
	# origin point.
	var left_pillar_clear := interior.to_global(interior.grid_to_world(Vector2(1.05, 1.05)))
	var right_pillar_overlap := interior.to_global(interior.grid_to_world(Vector2(16.18, 0.82)))
	var right_pillar_clear := interior.to_global(interior.grid_to_world(Vector2(15.95, 1.05)))
	var doorway := interior.to_global(interior.grid_to_world(Vector2(9.0, 12.42)))

	assert(
		not interior.is_walkable_world_position(side_overlap),
		"DigiLab actor footprint must stop before entering the authored side-wall/pillar strip"
	)
	assert(
		interior.is_walkable_world_position(side_clear),
		"DigiLab player must be able to visually reach the vector side wall without an artificial gap"
	)
	assert(
		not interior.is_walkable_world_position(back_overlap),
		"DigiLab player footprint must not cross the authored back-wall edge"
	)
	assert(
		interior.is_walkable_world_position(back_clear),
		"DigiLab player must be able to visually reach the vector back wall without using the generic block inset"
	)
	assert(
		not interior.is_walkable_world_position(left_pillar_overlap),
		"DigiLab upper-left connector pillar must block the diagonal area behind its visible base"
	)
	assert(
		interior.is_walkable_world_position(left_pillar_clear),
		"DigiLab upper-left pillar blocker must remain local and preserve adjacent floor"
	)
	assert(
		not interior.is_walkable_world_position(right_pillar_overlap),
		"DigiLab upper-right connector pillar must use the same localized collision contract"
	)
	assert(
		interior.is_walkable_world_position(right_pillar_clear),
		"DigiLab upper-right pillar blocker must remain local and preserve adjacent floor"
	)
	assert(
		interior.is_walkable_world_position(doorway),
		"DigiLab doorway must remain reachable after footprint-aware wall collision"
	)


func _assert_player_wall_runtime_guard(
	player: Node2D,
	interior: WorldInterior,
	label: String
) -> void:
	var original_position := player.global_position
	var origin := interior.grid_to_world(Vector2.ZERO)
	var probes: Array[Dictionary] = [
		{
			"name": "left wall",
			"start": Vector2(2.0, 6.0),
			"grid_step": Vector2(-0.12, 0.0),
		},
		{
			"name": "back wall",
			"start": Vector2(8.0, 2.0),
			"grid_step": Vector2(0.0, -0.12),
		},
		{
			"name": "back/left corner",
			"start": Vector2(2.0, 2.0),
			"grid_step": Vector2(-0.10, -0.10),
		},
	]

	for probe: Dictionary in probes:
		var start_grid := probe["start"] as Vector2
		var grid_step := probe["grid_step"] as Vector2
		var world_step := interior.grid_to_world(grid_step) - origin
		player.global_position = interior.to_global(interior.grid_to_world(start_grid))
		player.set("velocity", Vector2.ZERO)

		for _index in range(30):
			player.call("_try_move", world_step)
			assert(
				interior.is_walkable_world_position(player.global_position),
				"%s player runtime must never leave authored navigation while pushing into the %s" % [label, probe["name"]]
			)

		var stopped_grid := interior.world_to_grid(interior.to_local(player.global_position))
		if label == "DigiLab":
			assert(
				stopped_grid.x >= 0.70 and stopped_grid.x <= 16.30 and stopped_grid.y >= 0.70,
				"%s player must reach the authored vector-wall contact plane without entering it at the %s; got grid=%s" % [label, probe["name"], stopped_grid]
			)
			if String(probe["name"]) == "back/left corner":
				assert(
					stopped_grid.x + stopped_grid.y >= 1.75,
					"DigiLab player must stop in front of the localized back-pillar base instead of slipping behind it; got grid=%s" % stopped_grid
				)
		else:
			assert(
				stopped_grid.x >= 1.30 and stopped_grid.x <= 15.70 and stopped_grid.y >= 1.30,
				"%s player must stop before the visible two-level block wall plane at the %s; got grid=%s" % [label, probe["name"], stopped_grid]
			)

	player.global_position = original_position
	player.set("velocity", Vector2.ZERO)


func _assert_follower_navigation_guard(world: Node, interior: WorldInterior) -> void:
	var probe := OverworldDigimonFollower.new()
	probe.name = "FollowerNavigationProbe"
	interior.add_child(probe)
	# Start from unquestionably valid floor. The stricter authored wall footprint
	# now rejects x=16 before any movement, so beginning there would only test an
	# invalid fixture rather than follower locomotion into the wall.
	probe.global_position = interior.to_global(interior.grid_to_world(Vector2(15.0, 3.0)))
	var start := probe.global_position
	var target := interior.to_global(interior.grid_to_world(Vector2(17.6, 3.0)))
	var validator := Callable(world, "can_actor_move_to").bind(probe)
	var separation_points: Array[Vector2] = []

	for _index in range(12):
		probe.call("step_toward", target, 0.10, separation_points, validator)
		assert(
			interior.is_walkable_world_position(probe.global_position),
			"Follower navigation must never tunnel into or through the DigiLab side wall"
		)

	assert(
		probe.global_position.distance_to(target) > 20.0,
		"Follower must stop at authored interior navigation instead of cutting through the wall"
	)
	assert(
		probe.global_position.distance_to(start) > 0.5,
		"Follower regression probe must exercise real locomotion before reaching the wall"
	)
	probe.queue_free()


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
		authored.get_child_count() == 45,
		"DigiLab wall renderer must keep one back-wall batch, thirty-nine depth-sorted repeated modules, four corners and one doorway"
	)
	assert(
		(authored.get_meta("grid_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(64.0, 32.0)),
		"Runtime DigiLab walls must remain bound to the 64x32 world grid"
	)
	assert(
		String(authored.get_meta("layout_contract", "")) == "grid-native-depth-sorted",
		"DigiLab walls must keep the hybrid contract: batched background, depth-sorted side/front shell"
	)

	var logical_counts: Dictionary = {}
	var anchors_by_kind: Dictionary = {}
	var batch_kinds: Dictionary = {}

	for child in authored.get_children():
		if child is MultiMeshInstance2D:
			var batch := child as MultiMeshInstance2D
			assert(batch.multimesh != null and batch.texture != null, "Every wall batch must own a MultiMesh and texture")
			var kind := String(batch.get_meta("digilab_wall_batch", ""))
			assert(kind == "straight_right", "Only the always-background DigiLab back wall may remain batched")
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
			assert(span.is_equal_approx(Vector2(1.0, 0.0)), "Back wall modules must own one X-grid edge")
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
			kind in [
				"straight_left",
				"low_divider",
				"corner_back_left",
				"corner_back_right",
				"corner_front_left",
				"corner_front_right",
				"door_frame",
			],
			"Only depth-sensitive side/front modules and authored connectors may remain individual sprites"
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
		if not anchors_by_kind.has(kind):
			anchors_by_kind[kind] = []
		var kind_anchors: Array = anchors_by_kind[kind]
		kind_anchors.append(anchor)
		anchors_by_kind[kind] = kind_anchors

		assert(
			String(sprite.get_meta("depth_contract", "")) == "world-ground-y",
			"Depth-sensitive DigiLab wall pieces must use the shared world-ground depth contract"
		)
		var depth_anchor := sprite.get_meta("depth_anchor_cell", anchor) as Vector2
		var depth_ground := interior.grid_to_world(depth_anchor)
		var priority := int(sprite.get_meta("depth_priority", 0))
		var expected_depth := WORLD_DEPTH.z_for_ground_y(interior.to_global(depth_ground).y) + priority
		assert(
			sprite.z_index == expected_depth,
			"DigiLab wall depth must be derived from its authored ground-contact span"
		)

	assert(batch_kinds.size() == 1, "DigiLab must batch only the always-background back wall")
	assert(int(logical_counts.get("straight_right", 0)) == 17, "Back wall must keep seventeen one-edge modules")
	assert(int(logical_counts.get("straight_left", 0)) == 26, "Side walls must keep twenty-six one-edge modules")
	assert(int(logical_counts.get("low_divider", 0)) == 13, "Front boundary must keep thirteen one-edge low dividers")
	assert(int(logical_counts.get("door_frame", 0)) == 1, "Front boundary must keep exactly one four-edge doorway")

	var front_divider := _find_digilab_piece(authored, "low_divider", Vector2(3.0, 13.0))
	assert(front_divider != null, "DigiLab front divider probe must exist")
	var actor_depth_behind_front := WORLD_DEPTH.z_for_ground_y(
		interior.to_global(interior.grid_to_world(Vector2(3.0, 12.0))).y
	)
	assert(
		front_divider.z_index > actor_depth_behind_front,
		"DigiLab lower wall must render in front of an actor standing one grid cell behind it"
	)

	var doorway := _find_digilab_piece(authored, "door_frame", Vector2(7.0, 13.0))
	assert(doorway != null, "DigiLab doorway probe must exist")
	assert(
		(doorway.get_meta("depth_anchor_cell", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(9.0, 13.0)),
		"DigiLab doorway depth must sort from the center of its authored four-edge span"
	)
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
		String(physics_root.get_meta("collision_backend", "")) == "authored-navigation-footprint",
		"Interior collision root must declare the authored navigation footprint as the single source of truth"
	)
	assert(
		String(physics_root.get_meta("digilab_wall_collision_backend", "")) == "authored-navigation-footprint",
		"DigiLab walls must use the same continuous footprint contract as the other service interiors"
	)
	assert(
		physics_root.get_child_count() == 0,
		"Interior shell/counter collision must not duplicate authored navigation with PhysicsServer shapes"
	)

	assert(ResourceLoader.exists(DIGILAB_WALL_PATHS["wall_end_cap"]), "Canonical DigiLab end-cap SVG must remain available")


func _find_digilab_piece(
	parent: Node,
	kind: String,
	grid_anchor: Vector2
) -> Sprite2D:
	for child in parent.get_children():
		var sprite := child as Sprite2D
		if sprite == null:
			continue
		if String(sprite.get_meta("digilab_wall_piece", "")) != kind:
			continue
		var anchor := sprite.get_meta("grid_anchor_cell", Vector2(-1000.0, -1000.0)) as Vector2
		if anchor.is_equal_approx(grid_anchor):
			return sprite
	return null


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
