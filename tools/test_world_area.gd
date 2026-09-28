extends Node

const WORLD_SCENE := preload("res://scenes/world/world_root.tscn")
const MAP_CAPTURE := preload("res://src/debug/DebugWorldMapCapture.gd")
const CITY_AUTHORING := preload("res://src/world/authoring/CentralCityAuthoringData.gd")
const CITY_EDITOR_MATH := preload("res://src/world/authoring/CentralCityEditorMath.gd")
const CITY_LAYOUT := preload("res://src/world/runtime/CentralCityUrbanLayout.gd")
const CITY_TOPOLOGY := preload("res://src/world/runtime/CentralCityTopology.gd")
const CITY_BAKER := preload("res://src/world/authoring/CentralCityBaker.gd")
const CITY_DECOR := preload("res://src/world/runtime/CentralCityDecor.gd")


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
	assert(InputMap.has_action("player_run"), "Player run action must be registered when the overworld actor initializes")
	var run_button := world.get_node_or_null("WorldUI/Root/MobileControls/RunToggle") as Button
	assert(run_button != null and run_button.text == "RUN", "Touch HUD must expose RUN as the default walk-mode action")
	assert(not bool(player.call("is_touch_run_enabled")), "Touch running must default to walking")
	world.call("_toggle_touch_run")
	assert(bool(player.call("is_touch_run_enabled")), "Touch RUN must enable the player run state")
	assert(run_button.text == "WALK", "Touch run button must offer WALK while running is active")
	world.call("_toggle_touch_run")
	assert(not bool(player.call("is_touch_run_enabled")), "Touch WALK must restore normal movement")
	assert(run_button.text == "RUN", "Touch run button must return to RUN after walking is restored")
	assert(player != null and area != null, "Campaign world must expose its player and loaded area scene")
	assert(
		CITY_AUTHORING.has_authoring_scene()
		and CITY_AUTHORING.authored_section_count() == 25
		and CITY_AUTHORING.authored_road_count() > 0,
		"Central City runtime must be derived from the visual Godot authoring scene and its painted road cells"
	)

	# Regression: moving the last visually-authored prop out of a section must
	# leave that section empty. Legacy JSON must never resurrect a ghost lamp
	# that has no selectable authoring node.
	var authoring_scene := load("res://scenes/world/central_city_authoring.tscn") as PackedScene
	var authoring_root := authoring_scene.instantiate()
	var authoring_snapshot := CITY_AUTHORING.snapshot_from_root(authoring_root)
	var prop_snapshot := authoring_snapshot.duplicate(true)
	authoring_root.free()
	var props_by_section := (prop_snapshot.get("props_by_section", {}) as Dictionary).duplicate(true)
	props_by_section["-1,0"] = []
	prop_snapshot["props_by_section"] = props_by_section
	CITY_AUTHORING.set_preview_snapshot(prop_snapshot)
	var empty_authored_decor := CITY_DECOR.build_for_section(
		Vector2i(-1, 0),
		"service",
		Vector2.ZERO,
		func(_cell: Vector2, _clearance: Vector2) -> bool:
			return true,
		func(_polygon: PackedVector2Array, _asset_id: String) -> void:
			pass,
		func(_cell: Vector2) -> float:
			return 48.0
	)
	CITY_AUTHORING.clear_preview_snapshot()
	var empty_authored_decor_root := empty_authored_decor.get("root") as Node
	assert(
		int(empty_authored_decor.get("count", -1)) == 0,
		"An empty visually-authored section must stay empty instead of reviving a legacy JSON prop"
	)
	if empty_authored_decor_root != null:
		empty_authored_decor_root.free()
	var road_network_value = CITY_AUTHORING.topology_config().get("road_network", {})
	assert(
		road_network_value is Dictionary
		and String((road_network_value as Dictionary).get("mode", "")) == "painted_tiles",
		"Roads must be authored as independent painted cells instead of linked Line2D graph geometry"
	)
	var road_sample := CITY_AUTHORING.ground_override_at(Vector2(7, 10))
	assert(
		String(road_sample.get("surface", "")) == "road"
		and CITY_TOPOLOGY.is_route_reserved(Vector2(7, 10)),
		"Painted road cells must render as road surface and remain reserved from automatic landscaping"
	)
	var baked_snapshot := CITY_BAKER.load_snapshot()
	if not baked_snapshot.is_empty():
		if not _snapshots_equivalent(baked_snapshot, authoring_snapshot):
			for difference: String in _snapshot_diff_paths(baked_snapshot, authoring_snapshot):
				push_error("Central City bake mismatch: %s" % difference)
		assert(
			_snapshots_equivalent(baked_snapshot, authoring_snapshot),
			"Committed Central City baked data must match the editable authoring scene"
		)

	# Service buildings are intentionally movable in the visual authoring scene.
	# Regressions should validate presence/identity, not freeze designer-chosen
	# coordinates that are expected to change in Godot.
	var service_anchors := {}
	for service_id: String in ["digilab", "training", "hospital", "market", "archive"]:
		var anchor := CITY_AUTHORING.building_anchor_grid(service_id, Vector2(INF, INF))
		assert(
			is_finite(anchor.x) and is_finite(anchor.y),
			"Service building %s must keep a valid visual authoring anchor" % service_id
		)
		service_anchors[service_id] = anchor
	assert(
		service_anchors.values().duplicate().size() == 5,
		"Central City must preserve all five authored service building anchors"
	)
	assert(
		area.get_node_or_null("Authoring") == null,
		"Editor-only Central City authoring nodes must be removed from the runtime scene tree"
	)
	var lighting := world.call("get_lighting_system") as Node
	assert(lighting != null, "Campaign world must own one centralized dynamic lighting runtime")
	assert(
		lighting.get_node_or_null("AmbientModulate") is CanvasModulate
		and lighting.get_node_or_null("SunLight") is DirectionalLight2D,
		"World lighting must combine ambient modulation with one global sun light"
	)
	assert(
		int(lighting.call("get_shadow_caster_count")) >= 8,
		"Central City must register its authored geometry and actors as procedural shadow casters"
	)
	assert(
		int(lighting.call("get_local_light_count")) >= 12,
		"Street lamps and authored service buildings must register as data-driven local lights"
	)
	var midday_snapshot = lighting.call("get_time_debug_snapshot")
	assert(midday_snapshot is Dictionary, "World lighting must expose a deterministic debug time snapshot")
	assert(
		String((midday_snapshot as Dictionary).get("phase", "")) == "DAY"
		and absf(float((midday_snapshot as Dictionary).get("hour", 0.0)) - 12.0) < 0.01,
		"Campaign lighting preview must default to midday without advancing automatically"
	)
	var midday_direction := (midday_snapshot as Dictionary).get("shadow_direction", Vector2.ZERO) as Vector2
	var midday_length := float((midday_snapshot as Dictionary).get("shadow_length", 0.0))
	var midday_lights := float((midday_snapshot as Dictionary).get("local_light_strength", 0.0))
	lighting.call("set_preview_time_hours", 18.0)
	var sunset_snapshot := lighting.call("get_time_debug_snapshot") as Dictionary
	assert(
		String(sunset_snapshot.get("phase", "")) == "SUNSET"
		and float(sunset_snapshot.get("shadow_length", 0.0)) > midday_length
		and float(sunset_snapshot.get("local_light_strength", 0.0)) > midday_lights
		and ((sunset_snapshot.get("shadow_direction", Vector2.ZERO) as Vector2).distance_to(midday_direction) > 0.25),
		"Sunset preview must rotate and lengthen shadows while bringing local lights up"
	)
	lighting.call("set_preview_time_hours", 21.0)
	var night_snapshot := lighting.call("get_time_debug_snapshot") as Dictionary
	assert(
		String(night_snapshot.get("phase", "")) == "NIGHT"
		and float(night_snapshot.get("local_light_strength", 0.0)) >= 0.95,
		"Night preview must fully activate authored local illumination"
	)
	var local_light_root := lighting.get_node_or_null("LocalLights") as Node2D
	var max_night_energy := 0.0
	var visible_emissive_glow := false
	if local_light_root != null:
		for child in local_light_root.get_children():
			if child is PointLight2D:
				max_night_energy = maxf(max_night_energy, (child as PointLight2D).energy)
			elif child is Sprite2D and String(child.name).begins_with("Glow_"):
				visible_emissive_glow = visible_emissive_glow or (child as Sprite2D).visible
	assert(
		local_light_root != null and max_night_energy > 1.0 and visible_emissive_glow,
		"Night lighting must combine strong physical PointLight2D output with visible emissive halos"
	)
	lighting.call("set_preview_time_hours", 12.0)
	assert(
		String(player.get_meta("world_shadow_style", "")) == "contact"
		and player.get_meta("world_shadow_size", Vector2.ZERO) is Vector2
		and (player.get_meta("world_shadow_size", Vector2.ZERO) as Vector2).x >= 24.0,
		"Player shadow must be a fitted soft contact shadow instead of an extruded footprint"
	)
	assert(area.get_section_count() == 25, "Central City must be fully built before gameplay starts")
	var capture_bounds := area.get_debug_capture_bounds()
	assert(
		capture_bounds.size.x >= 5000.0 and capture_bounds.size.y >= 3000.0,
		"Full-map capture bounds must include the complete 5x5 city plus tall-asset/shadow headroom"
	)
	var capture_plan_1x := MAP_CAPTURE.build_capture_plan(capture_bounds, 1)
	var capture_plan_2x := MAP_CAPTURE.build_capture_plan(capture_bounds, 2)
	assert(
		capture_plan_1x.size() > 1 and capture_plan_2x.size() > capture_plan_1x.size(),
		"Full-map capture must tile the area instead of allocating one giant GPU viewport"
	)
	for tile_value in capture_plan_2x:
		var tile := tile_value as Dictionary
		var pixel_size := tile.get("pixel_size", Vector2i.ZERO) as Vector2i
		assert(
			pixel_size.x > 0 and pixel_size.y > 0
			and pixel_size.x <= MAP_CAPTURE.DEFAULT_TILE_SIZE.x
			and pixel_size.y <= MAP_CAPTURE.DEFAULT_TILE_SIZE.y,
			"Every map-capture render tile must stay inside the fixed GPU-safe viewport size"
		)
	var output_2x := Vector2i(
		ceili(capture_bounds.size.x * 2.0),
		ceili(capture_bounds.size.y * 2.0)
	)
	var last_capture_tile := capture_plan_2x.back() as Dictionary
	assert(
		(last_capture_tile.get("destination", Vector2i.ZERO) as Vector2i)
		+ (last_capture_tile.get("pixel_size", Vector2i.ZERO) as Vector2i)
		== output_2x,
		"Capture plan must cover the final image exactly without gaps or oversized edge tiles"
	)
	assert(player.is_in_group("debug_capture_clean_hidden"), "Clean-map captures must exclude the player through an explicit runtime contract")
	assert(
		get_tree().get_nodes_in_group("debug_capture_clean_vfx").size() > 0,
		"Ambient world particles must expose a clean-map visibility contract"
	)
	assert(not bool(lighting.call("is_debug_capture_active")), "Lighting capture override must be disabled during normal play")
	lighting.call("set_debug_capture_active", true)
	assert(
		int(lighting.call("get_active_local_light_count")) == int(lighting.call("get_local_light_count")),
		"Full-map capture must temporarily render authored lights outside the player's normal culling radius"
	)
	lighting.call("set_debug_capture_active", false)
	assert(
		area.get_ground_render_node_count() <= 16,
		"Central City ground must stay globally batched by its curated surface palette"
	)
	assert(
		area.get_ground_tile_count() == 4134,
		"Central City ground batch must omit the full-width terrace break, stair transition cells, and both future-water void pockets"
	)

	var main_paving := area.get_node_or_null("CityGround/Surface_main") as MeshInstance2D
	var road_paving := area.get_node_or_null("CityGround/Surface_road") as MeshInstance2D
	var civic_paving := area.get_node_or_null("CityGround/Surface_stone_soft") as MeshInstance2D
	assert(
		main_paving != null and road_paving != null and civic_paving != null,
		"Central City must batch base pavement, painted road cells and civic accent paving"
	)
	assert(
		main_paving.texture == null and road_paving.texture == null and civic_paving.texture == null,
		"Central City hardscape tops must be procedural rather than one texture per gameplay tile"
	)
	var paver_material := main_paving.material as ShaderMaterial
	assert(
		paver_material != null
		and paver_material.shader != null
		and paver_material.shader.resource_path == "res://shaders/city_paver_floor.gdshader",
		"Central City hardscape must use the dedicated continuous micro-paver shader"
	)
	assert(
		not paver_material.shader.code.contains("render_mode unshaded"),
		"Central City paving must stay inside the CanvasItem lighting pipeline so night and local lights affect the ground"
	)
	assert(
		is_equal_approx(float(paver_material.get_shader_parameter("pavers_per_cell")), 4.0),
		"One 64x32 gameplay cell must visually contain four paving subdivisions per ground axis"
	)
	var urban_layout := area.get_node_or_null("CityUrbanLayout") as Node2D
	assert(
		urban_layout != null
		and area.get_urban_layout_layer_count() >= 3
		and area.get_urban_layout_polygon_count() >= 15
		and area.is_road_graph_connected(),
		"Central City must batch authored civic overlays while roads stay in the editable ground-paint layer"
	)
	assert(
		area.get_urban_layout_render_node_count() <= 15,
		"Urban paths, plazas and district courts must stay batched into a small fixed render-node budget"
	)
	assert(
		urban_layout.get_node_or_null("Edges_road_network") == null
		and urban_layout.get_node_or_null("Surface_road_network") == null
		and urban_layout.get_node_or_null("PaintedRoadEdging") is MeshInstance2D,
		"Painted roads need one batched edge finish without duplicating their ground surface"
	)
	for required_urban_node: String in [
		"Surface_central_plaza",
		"Surface_service_forecourts",
		"Surface_district_courts",
	]:
		var urban_surface := urban_layout.get_node_or_null(required_urban_node) as MeshInstance2D
		assert(
			urban_surface != null
			and urban_surface.texture == null
			and urban_surface.material is ShaderMaterial
			and (urban_surface.material as ShaderMaterial).shader.resource_path == "res://shaders/city_paver_floor.gdshader",
			"Urban layout node %s must reuse the lit continuous micro-paver shader instead of tile-sized textures" % required_urban_node
		)
	var south_terrace := area.get_node_or_null("SouthTerraceStructure") as Node2D
	assert(
		south_terrace != null
		and area.get_south_terrace_render_node_count() <= 16
		and south_terrace.get_node_or_null("RetainingWallCaps") is MeshInstance2D
		and south_terrace.get_node_or_null("RetainingWallFaces") is MeshInstance2D
		and south_terrace.get_node_or_null("StairLandings") is MeshInstance2D
		and south_terrace.get_node_or_null("StairTreads") is MeshInstance2D
		and south_terrace.get_node_or_null("StairRisers") is MeshInstance2D
		and south_terrace.get_node_or_null("StairSideCaps") is MeshInstance2D
		and south_terrace.get_node_or_null("StairNosingAndParapets") is MeshInstance2D
		and south_terrace.get_node_or_null("WaterBasinFloor") is MeshInstance2D
		and south_terrace.get_node_or_null("TrenchSubmergedWalls") is MeshInstance2D
		and south_terrace.get_node_or_null("CanalWater") is MeshInstance2D
		and south_terrace.get_node_or_null("CanalShoreline") is MeshInstance2D
		and south_terrace.get_node_or_null("TrenchFrontWalls") is MeshInstance2D
		and south_terrace.get_node_or_null("TrenchBankCaps") is MeshInstance2D
		and south_terrace.get_node_or_null("BridgeBodies") is MeshInstance2D
		and south_terrace.get_node_or_null("BridgeDecks") is MeshInstance2D
		and south_terrace.get_node_or_null("BridgeRails") is MeshInstance2D,
		"South Terrace must batch its architectural stairs, canal banks, water, and bridges"
	)
	assert(
		int(south_terrace.get_meta("visual_level_count", 0)) == 2
		and int(south_terrace.get_meta("stair_count", 0)) == 2
		and int(south_terrace.get_meta("trench_count", 0)) == 2
		and int(south_terrace.get_meta("bridge_count", 0)) == 2
		and is_equal_approx(float(south_terrace.get_meta("water_surface_drop_px", 0.0)), 8.0)
		and is_equal_approx(float(south_terrace.get_meta("basin_depth_px", 0.0)), 22.0)
		and is_equal_approx(float(south_terrace.get_meta("upper_elevation_px", 0.0)), 48.0)
		and is_zero_approx(float(south_terrace.get_meta("lower_elevation_px", -1.0))),
		"South Terrace must keep two presentation levels and a physically recessed 22px canal basin with the water surface 8px below pavement"
	)
	var basin_floor := south_terrace.get_node_or_null("WaterBasinFloor") as MeshInstance2D
	var submerged_walls := south_terrace.get_node_or_null("TrenchSubmergedWalls") as MeshInstance2D
	var canal_water := south_terrace.get_node_or_null("CanalWater") as MeshInstance2D
	var canal_shoreline := south_terrace.get_node_or_null("CanalShoreline") as MeshInstance2D
	var front_walls := south_terrace.get_node_or_null("TrenchFrontWalls") as MeshInstance2D
	var bank_caps := south_terrace.get_node_or_null("TrenchBankCaps") as MeshInstance2D
	assert(
		canal_water != null
		and canal_water.texture == null
		and canal_water.material is ShaderMaterial
		and (canal_water.material as ShaderMaterial).shader.resource_path == "res://shaders/world_water_surface.gdshader",
		"The authored canal must use reusable procedural water without water texture assets"
	)
	var canal_water_material := canal_water.material as ShaderMaterial
	var canal_flow: Vector2 = canal_water_material.get_shader_parameter("flow_direction")
	var canal_body_color: Color = canal_water_material.get_shader_parameter("body_color")
	var basin_depth_enabled: bool = canal_water_material.get_shader_parameter("use_basin_depth")
	var caustic_strength := float(canal_water_material.get_shader_parameter("caustic_strength"))
	var refraction_visibility := float(canal_water_material.get_shader_parameter("refraction_visibility"))
	assert(
		canal_flow.is_equal_approx(Vector2(1.0, 1.0).normalized()),
		"Central City canal flow must travel visually downward along the isometric +X/+Y axis"
	)
	assert(
		canal_body_color.g >= 0.60 and canal_body_color.b >= 0.75,
		"Central City canal must keep the bright cyan-blue prototype palette instead of regressing to dark navy water"
	)
	assert(
		basin_depth_enabled
		and caustic_strength > 0.20
		and refraction_visibility > 0.10,
		"Central City water must combine geometry-driven depth, organic caustics, and subtle screen refraction instead of a flat scrolling pattern"
	)
	assert(
		basin_floor != null
		and submerged_walls != null
		and front_walls != null
		and bank_caps != null
		and basin_floor.z_index < canal_water.z_index
		and submerged_walls.z_index < canal_water.z_index
		and canal_water.z_index < front_walls.z_index
		and front_walls.z_index < bank_caps.z_index,
		"Canal basin draw order must place real submerged geometry behind water and the near wall/rim in front so the water reads below pavement"
	)
	assert(
		canal_shoreline != null
		and canal_shoreline.texture == null
		and canal_shoreline.material is ShaderMaterial
		and (canal_shoreline.material as ShaderMaterial).shader.resource_path == "res://shaders/world_water_shore.gdshader",
		"The authored canal must render its animated shoreline from reusable procedural geometry"
	)
	assert(
		not area.is_walkable_world_position(_grid_to_world(Vector2(0, 19)))
		and area.is_walkable_world_position(_grid_to_world(Vector2(7, 19)))
		and area.is_walkable_world_position(_grid_to_world(Vector2(-5, 19))),
		"The upper civic deck must stop at a real retaining boundary with only the two authored stair openings"
	)
	assert(
		not area.is_walkable_world_position(_grid_to_world(Vector2(-24, 19)))
		and not area.is_walkable_world_position(_grid_to_world(Vector2(38, 19))),
		"The retaining boundary must span the complete playable width instead of leaving flank shortcuts between levels"
	)
	assert(
		not area.can_traverse_world_segment(
			_grid_to_world(Vector2(-20.0, 19.35)),
			_grid_to_world(Vector2(-20.0, 19.65))
		)
		and area.can_traverse_world_segment(
			_grid_to_world(Vector2(7.0, 19.35)),
			_grid_to_world(Vector2(7.0, 19.65))
		),
		"Cross-level movement must be rejected outside a staircase and accepted through an authored stair corridor"
	)
	assert(
		not area.can_traverse_world_segment(
			_grid_to_world(Vector2(4.75, 20.0)),
			_grid_to_world(Vector2(5.15, 20.0))
		),
		"A staircase must reject lateral entry through its side wall instead of allowing a mid-flight level shortcut"
	)
	assert(
		not area.is_walkable_world_position(_grid_to_world(Vector2(-10, 23)))
		and area.is_walkable_world_position(_grid_to_world(Vector2(-5, 23)))
		and area.is_walkable_world_position(_grid_to_world(Vector2(21, 23)))
		and area.is_walkable_world_position(_grid_to_world(Vector2(7, 23))),
		"South Terrace voids must block movement while bridge decks and the central solid corridor remain walkable"
	)


	assert(
		is_equal_approx(area.get_elevation_at_world_position(_grid_to_world(Vector2(7, 10))), 48.0)
		and is_zero_approx(area.get_elevation_at_world_position(_grid_to_world(Vector2(7, 26)))),
		"Upper Civic and South Terrace must resolve to distinct 48px and 0px presentation elevations"
	)
	var stair_mid_elevation := area.get_elevation_at_world_position(_grid_to_world(Vector2(7, 19.875)))
	assert(
		stair_mid_elevation > 1.0 and stair_mid_elevation < 47.0,
		"Stair traversal must interpolate elevation continuously instead of teleporting between levels"
	)


	var edge_blocks := area.get_node_or_null("CityGround/EdgeBlocks")
	assert(
		edge_blocks != null and edge_blocks.get_child_count() > 0,
		"Central City perimeter must expose authored Devil block side faces"
	)
	assert(
		area.get_runtime_node_count() < 1000,
		"Central City runtime node budget must remain below 1000 nodes"
	)
	assert(
		area.get_decoration_count() >= 12 and area.get_decoration_count() <= 18,
		"Central City furniture must stay sparse and limited to authored urban anchors"
	)
	var plaza_section := area.get_node_or_null("Section_0_0") as WorldAreaSection
	assert(plaza_section != null, "Central Plaza section must remain available for decoration regression coverage")
	assert(
		plaza_section.get_node_or_null("CityDecor") != null
		and plaza_section.get_decoration_count() >= 4,
		"Central Plaza must keep sparse lighting and seating composed around its urban edges"
	)
	assert(
		plaza_section.get_node_or_null("CivicPoolFrame") != null,
		"Central Plaza must frame its digital pool with a raised civic structure"
	)
	var plaza_assets := plaza_section.get_decoration_asset_ids()
	assert(
		plaza_assets.has("lamp_blue")
		and plaza_assets.has("bench_ne")
		and plaza_assets.has("bench_nw"),
		"Central Plaza must use the approved lamp and both approved isometric bench orientations"
	)
	assert(
		plaza_section.get_decoration_count() >= 2,
		"Central Plaza lamps must stay on the outer civic/landscape edge rather than crowding the guide or pool"
	)
	var plaza_natural := plaza_section.get_node_or_null("NaturalDetails")
	var plaza_tree: Sprite2D = null
	var plaza_planter: Node2D = null
	if plaza_natural != null:
		for child in plaza_natural.get_children():
			if child is Sprite2D and String(child.name).begins_with("Oak_") and plaza_tree == null:
				plaza_tree = child as Sprite2D
			elif child is Node2D and String(child.name).begins_with("LandscapeIsland_") and plaza_planter == null:
				plaza_planter = child as Node2D
	assert(
		plaza_natural != null
		and plaza_tree != null
		and plaza_tree.is_in_group("world_shadow_caster")
		and String(plaza_tree.get_meta("world_shadow_style", "")) == "projected_soft"
		and float(plaza_tree.get_meta("world_shadow_height", 0.0)) >= 100.0
		and (plaza_tree.get_meta("world_shadow_size", Vector2.ZERO) as Vector2).x >= 90.0,
		"Central City trees must cast a visible broad projected canopy shadow from their ground anchor"
	)
	var shadow_root := lighting.get_node_or_null("SunShadows") as Node2D
	assert(
		shadow_root != null and shadow_root.z_index > 40,
		"World shadows must render above raised landscape tops so tree canopy casts remain visible"
	)
	assert(
		plaza_planter != null
		and plaza_planter.is_in_group("world_shadow_caster")
		and String(plaza_planter.get_meta("world_shadow_style", "")) == "projected",
		"Raised landscape islands must cast a low structural shadow onto the city pavement"
	)
	var plaza_decor := plaza_section.get_node_or_null("CityDecor")
	assert(
		plaza_decor != null
		and plaza_section.get_node_or_null("CityDecor/LampSurround_01/PaverPad") != null
		and plaza_section.get_node_or_null("CityDecor/LampSurround_01/LandscapeBed") != null,
		"Plaza lamps must keep their approved paver/canteiro integration"
	)
	assert(
		plaza_section.get_node_or_null("CityDecor/LampSurround_01/MountingSocket") == null
		and plaza_section.get_node_or_null("CityDecor/LampSurround_01/MountingCollar") == null
		and plaza_section.get_node_or_null("CityDecor/LampSurround_01/MountingInset") == null,
		"Lamp surrounds must never add a dark pedestal, socket or floating square under the sprite"
	)
	var first_plaza_lamp: Sprite2D = null
	for child in plaza_decor.get_children():
		if child is Sprite2D:
			first_plaza_lamp = child as Sprite2D
			break
	var first_plaza_lamp_local := plaza_section.grid_to_world(Vector2(2.2, 5.2))
	assert(
		first_plaza_lamp != null
		and first_plaza_lamp.position.is_equal_approx(first_plaza_lamp_local - Vector2(0.0, 96.0))
		and is_equal_approx(float(first_plaza_lamp.get_meta("world_elevation_px", 0.0)), 48.0),
		"Lamp sprite must preserve its authored foot offset while following the 48px upper-city elevation"
	)
	assert(
		first_plaza_lamp.is_in_group("world_shadow_caster")
		and first_plaza_lamp.is_in_group("world_local_light")
		and first_plaza_lamp.has_meta("world_light_color")
		and first_plaza_lamp.has_meta("world_shadow_height"),
		"City lamps must expose one shared runtime contract for light and procedural shadow generation"
	)
	assert(
		float(first_plaza_lamp.get_meta("world_light_energy", 0.0)) > 1.0
		and float(first_plaza_lamp.get_meta("world_light_radius", 0.0)) >= 190.0
		and float(first_plaza_lamp.get_meta("world_light_glow_radius", 0.0)) >= 36.0
		and float(first_plaza_lamp.get_meta("world_light_glow_energy", 0.0)) >= 0.75,
		"Street lamps must expose enough physical light and emissive halo energy to read as night-time light sources"
	)
	assert(
		String(first_plaza_lamp.get_meta("world_shadow_style", "")) == "projected"
		and float(first_plaza_lamp.get_meta("world_shadow_height", 0.0)) >= 100.0
		and float(first_plaza_lamp.get_meta("world_shadow_projection_multiplier", 0.0)) > 1.0,
		"Street lamps must cast a tall narrow shadow proportional to the authored pole height"
	)
	var first_plaza_lamp_world := plaza_section.global_position + first_plaza_lamp_local
	assert(
		not plaza_section.is_walkable_world_position(first_plaza_lamp_world),
		"Lamp pedestal center must block movement"
	)
	assert(
		plaza_section.is_walkable_world_position(first_plaza_lamp_world + Vector2(11.0, 0.0)),
		"Lamp collision must hug the pedestal rather than exposing a large invisible square"
	)
	assert(
		not bool(world.call("can_actor_move_to", first_plaza_lamp_world + Vector2(12.0, 0.0), player))
		and bool(world.call("can_actor_move_to", first_plaza_lamp_world + Vector2(18.0, 0.0), player)),
		"Player clearance must prevent sprite overlap while releasing movement immediately outside the pedestal envelope"
	)

	var first_plaza_bench_local := plaza_section.grid_to_world(Vector2(4.2, 11.6))
	var expected_ground_center := first_plaza_bench_local + Vector2(-15.0, -8.0)
	var expected_ground_world := plaza_section.global_position + expected_ground_center
	assert(
		not plaza_section.is_walkable_world_position(expected_ground_world),
		"Bench ground footprint must block movement through the visible seat contact area"
	)
	assert(
		plaza_section.is_walkable_world_position(expected_ground_world + Vector2(34.0, 0.0)),
		"Bench collision must stay fitted to the seat instead of creating a broad invisible wall"
	)

	var first_plaza_bench: Sprite2D = null
	var bench_surround_count := 0
	for child in plaza_decor.get_children():
		if child is Sprite2D and String(child.name).begins_with("Bench") and first_plaza_bench == null:
			first_plaza_bench = child as Sprite2D
		elif child is Node2D and String(child.name).begins_with("BenchSurround"):
			bench_surround_count += 1
	assert(first_plaza_bench != null, "Central Plaza must instantiate the approved bench art")
	var bench_atlas := first_plaza_bench.texture as AtlasTexture
	assert(
		bench_atlas != null
		and bench_atlas.atlas != null
		and bench_atlas.atlas.resource_path == "res://assets/world/tblack/city/props_v2/bench.png"
		and first_plaza_bench.scale.is_equal_approx(Vector2(0.10, 0.10)),
		"Approved bench must render from the user-supplied bench.png sheet at gameplay scale"
	)
	assert(
		bench_surround_count == 0,
		"Benches must sit directly on the normal city pavement without an exclusive floor or seating bay"
	)
	assert(
		(first_plaza_bench.get_meta("ground_center", Vector2.INF) as Vector2).is_equal_approx(expected_ground_center),
		"Bench collision must stay aligned to the visible four-foot ground centroid"
	)

	var bench_collision_body := plaza_section.get_node_or_null("BenchCollisions") as StaticBody2D
	assert(
		bench_collision_body != null and bench_collision_body.get_child_count() == 2,
		"Central Plaza benches must expose fitted physics collision in addition to walkability blockers"
	)
	for child in bench_collision_body.get_children():
		assert(
			child is CollisionPolygon2D and (child as CollisionPolygon2D).polygon.size() >= 4,
			"Each bench must use its fitted isometric collision polygon for swept CharacterBody2D collision"
		)

	var southwest_tree_center := plaza_section.grid_to_world(Vector2(2.0, 11.0))
	assert(
		(first_plaza_bench_local - southwest_tree_center).is_equal_approx(Vector2(51.2, 44.8)),
		"Plaza bench anchor must sit at the exact midpoint between the two planter-face corner-biased placements"
	)
	assert(
		(expected_ground_center - southwest_tree_center).is_equal_approx(Vector2(36.2, 36.8)),
		"Plaza bench collision must remain centered with the visible seat at the planter-face midpoint"
	)

	# Exercise the same incremental movement contract used by the runtime rather
	# than teleporting across the prop in one synthetic 90px step. Repeated
	# frame-sized advances must stop before entering the fitted bench footprint.
	var original_player_position := player.global_position
	player.global_position = expected_ground_world + Vector2(0.0, -45.0)
	player.set("velocity", Vector2.ZERO)
	for _step in range(24):
		player.call("_try_move", Vector2(0.0, 4.0))
	assert(
		player.global_position.y < expected_ground_world.y - 8.0,
		"Incremental player movement must stop before entering the bench footprint"
	)
	assert(
		not bool(world.call("can_actor_move_to", expected_ground_world, player)),
		"Bench ground center must remain forbidden to the player clearance model"
	)
	player.global_position = original_player_position
	player.set("velocity", Vector2.ZERO)

	var digilab_lighting := area.get_node_or_null("Section_-1_0") as WorldAreaSection
	var training_lighting := area.get_node_or_null("Section_0_-1") as WorldAreaSection
	var hospital_lighting := _service_section(area, "hospital")
	var canal_lighting := area.get_node_or_null("Section_0_-2") as WorldAreaSection
	var market_lighting := area.get_node_or_null("Section_0_1") as WorldAreaSection
	var market_pad: Area2D = null
	if market_lighting != null:
		market_pad = market_lighting.get_node_or_null("DataMarketPad") as Area2D
	assert(
		market_pad != null
		and market_pad.position.is_equal_approx(market_lighting.grid_to_world(Vector2(7, 12))),
		"Data Market must move onto the lower South Terrace instead of remaining on the upper flat"
	)
	assert(
		digilab_lighting != null and digilab_lighting.get_decoration_count() <= 1,
		"DigiLab may use at most one safe outer-sidewalk lamp until more surrounding streets exist"
	)
	assert(
		training_lighting != null and training_lighting.get_decoration_count() <= 1,
		"Training Center may use at most one safe outer-sidewalk lamp instead of posts covering its facade"
	)
	assert(
		hospital_lighting != null and hospital_lighting.get_decoration_count() <= 1,
		"Hospital may use at most one safe outer-sidewalk lamp instead of posts covering its entrance"
	)
	var canal_assets := canal_lighting.get_decoration_asset_ids() if canal_lighting != null else PackedStringArray()
	assert(
		canal_lighting != null
		and canal_lighting.get_decoration_count() >= 4
		and canal_assets.has("bench_nw")
		and not canal_assets.has("bench_ne"),
		"North Canal benches must use the orientation matching their centered planter faces, including the seat nearest Digital Archive"
	)
	assert(
		market_lighting != null
		and market_lighting.get_decoration_asset_ids().has("lamp_yellow"),
		"Data Market must reserve the approved warm lamp for its service node"
	)
	var annotation_labels: Dictionary = {}
	for raw_annotation in get_tree().get_nodes_in_group("world_annotation_unlit"):
		if raw_annotation is Label:
			var annotation := raw_annotation as Label
			annotation_labels[annotation.text] = annotation
	for required_text: String in ["CITY GUIDE", "DATA MARKET"]:
		var annotation := annotation_labels.get(required_text) as Label
		assert(annotation != null, "World gameplay annotation %s must remain present" % required_text)
		var annotation_material := annotation.material as CanvasItemMaterial
		assert(
			annotation_material != null
			and annotation_material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED,
			"NPC and service labels must remain unlit and readable regardless of time-of-day darkness"
		)

	# Empty authoring sections must remain empty, but designer-authored props
	# are allowed in any district now that the visual scene is the source of truth.
	for quiet_coord: Vector2i in [
		Vector2i(-2, -2),
		Vector2i(-1, -2),
		Vector2i(2, 0),
		Vector2i(0, 2),
	]:
		var quiet_section := area.get_node_or_null(
			"Section_%d_%d" % [quiet_coord.x, quiet_coord.y]
		) as WorldAreaSection
		assert(quiet_section != null, "Authored city section %s must exist" % str(quiet_coord))
		var authored_decor := CITY_AUTHORING.decoration_placements(quiet_coord)
		if authored_decor.is_empty():
			assert(
				quiet_section.get_decoration_count() == 0,
				"Section %s has no authored props and must not receive legacy/profile fallback decor" % str(quiet_coord)
			)
	for prop_path: String in [
		"res://assets/world/tblack/city/props_v2/lamp_blue.png",
		"res://assets/world/tblack/city/props_v2/lamp_yellow.png",
		"res://assets/world/tblack/city/props_v2/bench.png",
	]:
		assert(ResourceLoader.exists(prop_path), "Approved Central City prop asset must be vendored: %s" % prop_path)
	for rejected_prop_path: String in [
		"res://assets/world/tblack/city/props_v2/bench_ne.png",
		"res://assets/world/tblack/city/props_v2/bench_nw.png",
		"res://assets/world/tblack/city/props_v2/planter_long_ne.png",
		"res://assets/world/tblack/city/props_v2/planter_long_nw.png",
		"res://assets/world/tblack/city/props_v2/terminal.png",
		"res://assets/world/tblack/city/props_v2/holo_sign.png",
		"res://assets/world/tblack/city/props_v2/railing_ne.png",
		"res://assets/world/tblack/city/props_v2/railing_nw.png",
	]:
		assert(
			not ResourceLoader.exists(rejected_prop_path),
			"Rejected prototype decoration must stay removed: %s" % rejected_prop_path
		)
	assert(area.is_exterior_active(), "Central City exterior must start active")
	assert(bool(world.call("can_actor_move_to", player.global_position, player)), "Fresh campaign spawn must be walkable")
	assert(player.global_position.is_equal_approx(Vector2(-96.0, 272.0)), "Fresh campaign spawn must use the 64x32 safe plaza lane")
	assert(
		is_equal_approx(float(player.call("get_world_elevation")), 48.0),
		"Fresh Central City spawn must render on the elevated Upper Civic deck"
	)
	var world_camera := player.get_node_or_null("WorldCamera") as Camera2D
	assert(
		world_camera != null and world_camera.position.is_equal_approx(Vector2(0.0, -48.0)),
		"World camera must follow the player's presentation elevation"
	)

	var digilab_section := area.get_node_or_null("Section_-1_0") as WorldAreaSection
	assert(digilab_section != null, "DigiLab district must remain in the authored west-central section")
	var digilab_building := digilab_section.get_node_or_null("DigiLabExterior/VisualRoot/Building") as Sprite2D
	assert(digilab_building != null, "DigiLab district must render its authored exterior building")
	var digilab_door_light := digilab_section.get_node_or_null("DigiLabExterior/VisualRoot/DigiLabDoorLight") as Node2D
	var digilab_core_light := digilab_section.get_node_or_null("DigiLabExterior/VisualRoot/DigiLabCoreLight") as Node2D
	assert(
		digilab_door_light != null
		and digilab_core_light != null
		and digilab_door_light.is_in_group("world_local_light")
		and digilab_core_light.is_in_group("world_local_light"),
		"DigiLab exterior must expose authored door and core illumination sources"
	)
	var digilab_upper := digilab_section.get_node_or_null("DigiLabExterior/VisualRoot/UpperOccluder") as Sprite2D
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
		absf(digilab_building.rotation_degrees - (-2.48231)) < 0.01
		and digilab_building.scale.distance_to(Vector2(0.40, 0.31635585)) < 0.001,
		"DigiLab source projection must be corrected to the exact 64x32 city axes"
	)
	assert(
		digilab_building.z_index == 880
		and digilab_upper.z_index == 1800
		and digilab_upper.region_enabled
		and absf(digilab_upper.region_rect.size.y - 700.0) < 0.01,
		"DigiLab must keep the lower facade in front of actors while reserving occlusion for the upper/back art"
	)
	var digilab_floor = digilab_section.call("_ground_presentation", Vector2i(5, 4), "digilab")
	var digilab_approach = digilab_section.call("_ground_presentation", Vector2i(8, 10), "digilab")
	assert(
		digilab_floor is Dictionary
		and digilab_approach is Dictionary
		and String((digilab_floor as Dictionary).get("surface", "")) == "main"
		and String((digilab_approach as Dictionary).get("surface", "")) == "road",
		"DigiLab lot must stay on base paving while its street approach is independently painted as road"
	)
	assert(
		digilab_section.get_node_or_null("DigiLabExterior/VisualRoot/DigiLabFoundation/Top") != null,
		"DigiLab must sit on an authored raised foundation derived from its measured footprint"
	)
	var digilab_visual_root := digilab_section.get_node_or_null("DigiLabExterior/VisualRoot") as Node2D
	var digilab_foundation_shape = digilab_section.call("_digilab_foundation_footprint", expected_door)
	assert(
		digilab_visual_root != null
		and digilab_visual_root.position.is_equal_approx(Vector2(0.0, -48.0))
		and digilab_foundation_shape is PackedVector2Array
		and (digilab_foundation_shape as PackedVector2Array).size() == 10,
		"DigiLab visual lot must use its own full-building footprint on the elevated deck"
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
	var training_building := training_section.get_node_or_null("TrainingCenterExterior/VisualRoot/Building") as Sprite2D
	var training_upper := training_section.get_node_or_null("TrainingCenterExterior/VisualRoot/UpperOccluder") as Sprite2D
	assert(training_building != null, "Training district must render the authored Training Center exterior")
	assert(
		training_section.get_node_or_null("TrainingCenterExterior/VisualRoot/TrainingDoorLight") != null
		and training_section.get_node_or_null("TrainingCenterExterior/VisualRoot/TrainingAccentLight") != null,
		"Training Center exterior must expose two time-of-day local light sources"
	)
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
		and training_lot is Dictionary
		and String((training_forecourt as Dictionary).get("surface", "")) == "road"
		and String((training_lot as Dictionary).get("surface", "")) == "main",
		"Training Center lot must stay on base paving while its street approach is independently painted as road"
	)
	assert(
		training_section.get_node_or_null("TrainingCenterExterior/VisualRoot/TrainingCenterFoundation/Top") != null,
		"Training Center must sit on a raised foundation instead of blending into the street"
	)
	var training_visual_root := training_section.get_node_or_null("TrainingCenterExterior/VisualRoot") as Node2D
	var training_foundation_shape = training_section.call("_training_center_foundation_footprint", expected_training_door)
	assert(
		training_visual_root != null
		and training_visual_root.position.is_equal_approx(Vector2(0.0, -48.0))
		and training_foundation_shape is PackedVector2Array
		and (training_foundation_shape as PackedVector2Array).size() == 9,
		"Training Center visual lot must cover the complete building projection independently from collision"
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

	var hospital_section := _service_section(area, "hospital")
	var hospital_door_cell := _service_local_cell("hospital")
	assert(hospital_section != null, "Digi Hospital must render in the section selected by its authoring marker")
	var hospital_building := hospital_section.get_node_or_null("HospitalExterior/VisualRoot/Building") as Sprite2D
	var hospital_upper := hospital_section.get_node_or_null("HospitalExterior/VisualRoot/UpperOccluder") as Sprite2D
	assert(hospital_building != null, "Hospital district must render the authored hospital exterior")
	assert(
		hospital_section.get_node_or_null("HospitalExterior/VisualRoot/HospitalDoorLight") != null
		and hospital_section.get_node_or_null("HospitalExterior/VisualRoot/HospitalAccentLight") != null,
		"Hospital exterior must expose two time-of-day local light sources"
	)
	assert(hospital_upper != null, "Hospital must split upper occlusion from its foreground facade")
	assert(
		hospital_building.texture != null
		and hospital_building.texture.resource_path == "res://assets/world/tblack/hospital/hospital.png",
		"Hospital exterior must use the project-supplied hospital asset"
	)
	assert(
		hospital_building.scale.distance_to(Vector2(0.35, 0.35)) < 0.001
		and absf(hospital_building.rotation_degrees - (-0.87567)) < 0.01,
		"Hospital must preserve its authored aspect ratio while correcting only its grid heading"
	)
	assert(
		hospital_building.z_index == 880
		and hospital_upper.z_index == 1800
		and hospital_upper.region_enabled
		and absf(hospital_upper.region_rect.size.y - 650.0) < 0.01,
		"Hospital depth split must keep the front facade readable while allowing rear occlusion"
	)
	var hospital_entrance := hospital_section.get_node_or_null(
		"HospitalExterior/HospitalEntrance"
	) as Area2D
	assert(hospital_entrance != null, "Hospital must expose its authored doorway threshold")
	var expected_hospital_door := hospital_section.grid_to_world(Vector2(hospital_door_cell))
	assert(
		hospital_entrance.position.is_equal_approx(expected_hospital_door),
		"Hospital threshold must align to the centered straight-down door"
	)
	assert(
		hospital_section.is_walkable_world_position(hospital_section.global_position + expected_hospital_door),
		"Hospital stairs and doorway must remain walkable"
	)
	var hospital_lot_cell := hospital_door_cell + Vector2i(-2, -6)
	var hospital_lot = hospital_section.call("_ground_presentation", hospital_lot_cell, "hospital")
	var hospital_approach = hospital_section.call("_ground_presentation", hospital_door_cell, "hospital")
	assert(
		hospital_lot is Dictionary
		and hospital_approach is Dictionary
		and bool((hospital_lot as Dictionary).get("walkable", true))
		and bool((hospital_approach as Dictionary).get("walkable", true)),
		"Hospital placement and road paint must stay independent while its lot and approach remain walkable"
	)
	assert(
		hospital_section.get_node_or_null("HospitalExterior/VisualRoot/HospitalFoundation/Top") != null,
		"Hospital must sit on a raised foundation instead of blending into the street"
	)
	var hospital_visual_root := hospital_section.get_node_or_null("HospitalExterior/VisualRoot") as Node2D
	var hospital_foundation_shape = hospital_section.call("_hospital_foundation_footprint", expected_hospital_door)
	assert(
		hospital_visual_root != null
		and hospital_visual_root.position.is_equal_approx(Vector2(0.0, -48.0))
		and hospital_foundation_shape is PackedVector2Array
		and (hospital_foundation_shape as PackedVector2Array).size() == 10,
		"Hospital visual lot must cover the complete building projection independently from collision"
	)
	var hospital_collision := hospital_section.get_node_or_null(
		"HospitalExterior/FootprintCollision/CollisionPolygon2D"
	) as CollisionPolygon2D
	assert(
		hospital_collision != null and hospital_collision.polygon.size() == 25,
		"Hospital must use the measured source-space ground-contact footprint"
	)
	assert(
		not hospital_section.is_walkable_world_position(
			hospital_section.global_position + hospital_section.grid_to_world(
				Vector2(hospital_door_cell + Vector2i(0, -3))
			)
		),
		"Hospital structure footprint must block movement through the building"
	)
	var hospital_door_local := hospital_section.grid_to_world(Vector2(hospital_door_cell))
	for source_point: Vector2 in [
		Vector2(120.0, 820.0),
		Vector2(350.0, 900.0),
		Vector2(930.0, 900.0),
		Vector2(1130.0, 820.0),
	]:
		var hospital_local = hospital_section.call("_hospital_source_to_local", source_point, hospital_door_local)
		assert(
			hospital_local is Vector2
			and not hospital_section.is_walkable_world_position(
				hospital_section.global_position + (hospital_local as Vector2)
			),
			"Hospital visible structure point %s must be collision-covered" % str(source_point)
		)
	var hospital_payload = hospital_entrance.get_meta("interior_payload", {})
	assert(hospital_payload is Dictionary, "Hospital doorway must preserve the service payload")
	assert(String((hospital_payload as Dictionary).get("service", "")) == "hospital", "Hospital doorway must open the hospital service")
	var hospital_return = (hospital_payload as Dictionary).get("return_position", [])
	var expected_hospital_return := hospital_section.global_position + hospital_section.grid_to_world(
		Vector2(hospital_door_cell + Vector2i(2, 2))
	)
	assert(
		hospital_return is Array
		and hospital_return.size() >= 2
		and Vector2(float(hospital_return[0]), float(hospital_return[1])).is_equal_approx(expected_hospital_return),
		"Hospital interior exit must return straight down the centered entrance approach"
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


func _snapshots_equivalent(left, right, epsilon: float = 0.00001) -> bool:
	var left_type := typeof(left)
	var right_type := typeof(right)
	var left_numeric := left_type == TYPE_INT or left_type == TYPE_FLOAT
	var right_numeric := right_type == TYPE_INT or right_type == TYPE_FLOAT
	if left_numeric and right_numeric:
		return absf(float(left) - float(right)) <= epsilon
	if left_type != right_type:
		return false
	if left is Vector2:
		return (left as Vector2).is_equal_approx(right as Vector2)
	if left is Vector2i:
		return left == right
	if left is Color:
		return (left as Color).is_equal_approx(right as Color)
	if left is PackedVector2Array:
		var left_packed := left as PackedVector2Array
		var right_packed := right as PackedVector2Array
		if left_packed.size() != right_packed.size():
			return false
		for index in range(left_packed.size()):
			if not left_packed[index].is_equal_approx(right_packed[index]):
				return false
		return true
	if left is Dictionary:
		var left_dict := left as Dictionary
		var right_dict := right as Dictionary
		if left_dict.size() != right_dict.size():
			return false
		for key in left_dict.keys():
			if not right_dict.has(key):
				return false
			if not _snapshots_equivalent(left_dict[key], right_dict[key], epsilon):
				return false
		return true
	if left is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			return false
		for index in range(left_array.size()):
			if not _snapshots_equivalent(left_array[index], right_array[index], epsilon):
				return false
		return true
	return left == right


func _snapshot_diff_paths(left, right, path: String = "snapshot", limit: int = 12) -> Array[String]:
	var result: Array[String] = []
	if _snapshots_equivalent(left, right):
		return result
	var left_type := typeof(left)
	var right_type := typeof(right)
	var left_numeric := left_type == TYPE_INT or left_type == TYPE_FLOAT
	var right_numeric := right_type == TYPE_INT or right_type == TYPE_FLOAT
	if left_numeric and right_numeric:
		result.append("%s %s != %s" % [path, str(left), str(right)])
		return result
	if left_type != right_type:
		result.append("%s type %s != %s" % [path, type_string(typeof(left)), type_string(typeof(right))])
		return result
	if left is Dictionary:
		var left_dict := left as Dictionary
		var right_dict := right as Dictionary
		for key in left_dict.keys():
			if result.size() >= limit:
				break
			if not right_dict.has(key):
				result.append("%s missing right key %s" % [path, str(key)])
				continue
			result.append_array(
				_snapshot_diff_paths(
					left_dict[key],
					right_dict[key],
					"%s.%s" % [path, str(key)],
					limit - result.size()
				)
			)
		for key in right_dict.keys():
			if result.size() >= limit:
				break
			if not left_dict.has(key):
				result.append("%s missing left key %s" % [path, str(key)])
		return result
	if left is Array:
		var left_array := left as Array
		var right_array := right as Array
		if left_array.size() != right_array.size():
			result.append("%s size %d != %d" % [path, left_array.size(), right_array.size()])
			return result
		for index in range(left_array.size()):
			if result.size() >= limit:
				break
			result.append_array(
				_snapshot_diff_paths(
					left_array[index],
					right_array[index],
					"%s[%d]" % [path, index],
					limit - result.size()
				)
			)
		return result
	if left != right:
		result.append("%s %s != %s" % [path, str(left), str(right)])
	return result


func _service_section(area: WorldAreaScene, service_id: String) -> WorldAreaSection:
	var global_grid := CITY_AUTHORING.building_anchor_grid(service_id, Vector2(INF, INF))
	if not is_finite(global_grid.x) or not is_finite(global_grid.y):
		return null
	var section_size := int(CITY_AUTHORING.area_definition().get("section_size", 14))
	var coord := Vector2i(
		floori((global_grid.x + 0.5) / float(section_size)),
		floori((global_grid.y + 0.5) / float(section_size))
	)
	return area.get_node_or_null("Section_%d_%d" % [coord.x, coord.y]) as WorldAreaSection


func _service_local_cell(service_id: String) -> Vector2i:
	var global_grid := CITY_AUTHORING.building_anchor_grid(service_id, Vector2(INF, INF))
	var section_size := int(CITY_AUTHORING.area_definition().get("section_size", 14))
	var coord := Vector2i(
		floori((global_grid.x + 0.5) / float(section_size)),
		floori((global_grid.y + 0.5) / float(section_size))
	)
	var local_grid := global_grid - Vector2(coord * section_size)
	return Vector2i(roundi(local_grid.x), roundi(local_grid.y))


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
