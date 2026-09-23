extends "res://src/world/HubController.gd"

const ART = preload("res://src/world/DevilsWorkshopArt.gd")
const AreaTitleOverlayScript = preload("res://src/ui/AreaTitleOverlay.gd")
const TreeAmbientFXScript = preload("res://src/vfx/TreeAmbientFX.gd")
const OAK_TREE_SOURCE = preload("res://assets/terrain/Oak_Tree.png")

const LARGE_OAK_REGION := Rect2(11.0, 9.0, 41.0, 63.0)
const LARGE_OAK_FOOT := Vector2(20.5, 62.0)

const PLATFORM_MIN := -6
const PLATFORM_MAX := 6
const WATER_MIN := -8
const WATER_MAX := 8
const LOWER_LEVEL_OFFSET := 24.0
const PLATFORM_SKIRT_DEPTH := 24.0
const AREA_TITLE := "Terminal Commons"
const AREA_SUBTITLE := "Testing Lab"

# The surface palette is intentionally calmer than the source cubes. Characters
# and interaction VFX stay readable while the pack still provides pixel detail.
const GRASS_BASE := Color(0.30, 0.52, 0.29, 1.0)
const GRASS_EDGE_BASE := Color(0.23, 0.41, 0.24, 1.0)
const GRASS_DETAIL := Color(0.92, 1.0, 0.88, 1.0)
const ROUTE_BASE := Color(0.35, 0.38, 0.35, 1.0)
const ROUTE_DETAIL := Color(0.86, 0.90, 0.82, 1.0)
const PLAZA_BASE := Color(0.17, 0.34, 0.39, 1.0)
const PLAZA_DETAIL := Color(0.78, 0.94, 1.0, 1.0)
const DATA_BASE := Color(0.18, 0.34, 0.43, 1.0)
const DATA_DETAIL := Color(0.74, 0.82, 1.0, 1.0)
const WATER_BASE := Color(0.055, 0.29, 0.37, 1.0)
const WATER_DETAIL := Color(0.72, 0.94, 1.0, 1.0)
const SKIRT_LEFT := Color(0.14, 0.27, 0.18, 1.0)
const SKIRT_RIGHT := Color(0.10, 0.22, 0.16, 1.0)

var _area_title_overlay: AreaTitleOverlay = null


func _build_actors() -> void:
	super._build_actors()

	# The old animated test portal sat directly behind the Battle Operator and
	# read visually like a ring attached to the NPC. Keep the technical node for
	# compatibility/debug tooling, but make the operator the only visible battle
	# interaction anchor in the Hub.
	var portal := get_node_or_null("Actors/TestBattlePortal") as Node2D
	if portal != null:
		portal.visible = false
		portal.process_mode = Node.PROCESS_MODE_DISABLED

	if _operator != null:
		var previous_operator_position := _operator.position
		_operator.position = _grid_to_world(Vector2.ZERO)
		_operator.z_index = 1000 + int(round(_operator.position.y))
		for index in range(_blockers.size()):
			var blocker_position := Vector2(_blockers[index].get("position", Vector2.ZERO))
			var blocker_radius := float(_blockers[index].get("radius", 0.0))
			if blocker_position.is_equal_approx(previous_operator_position) and is_equal_approx(blocker_radius, 30.0):
				_blockers[index]["position"] = _operator.position
				break

	# Keep the initial interaction immediately reachable after moving the Battle
	# Operator to the visual center of the commons.
	if _player != null:
		_player.position = _grid_to_world(Vector2(2, 2))
		_player.z_index = 1000 + int(round(_player.position.y))


func _build_ui() -> void:
	super._build_ui()

	# Retire the persistent prototype panel without disturbing the interaction
	# systems that still update its old objective label internally.
	if _location_panel != null:
		_location_panel.visible = false

	if _ui_root == null:
		return
	_area_title_overlay = AreaTitleOverlayScript.new() as AreaTitleOverlay
	_area_title_overlay.name = "AreaTitleOverlay"
	_ui_root.add_child(_area_title_overlay)
	call_deferred("_announce_current_area")


func _announce_current_area() -> void:
	if _area_title_overlay != null:
		_area_title_overlay.present(AREA_TITLE, AREA_SUBTITLE, 1.75)


# Keep every terrain surface exactly as authored. Only the two oak trees use
# ambient presentation motion.
func _process(delta: float) -> void:
	_elapsed += delta
	for tree: Sprite2D in _trees:
		TreeAmbientFXScript.animate(tree, _elapsed)
	_refresh_interaction()


func _build_world() -> void:
	_blockers.clear()
	_trees.clear()
	_build_lower_water_terrace()
	_build_platform_foundation()
	_build_recovery_platform()
	_build_oak_trees()


func _build_ambient_particles() -> void:
	pass


func _build_lower_water_terrace() -> void:
	var water_layer := Node2D.new()
	water_layer.name = "LowerWaterTerrace"
	add_child(water_layer)

	for grid_x in range(WATER_MIN, WATER_MAX + 1):
		for grid_y in range(WATER_MIN, WATER_MAX + 1):
			if grid_x >= PLATFORM_MIN and grid_x <= PLATFORM_MAX and grid_y >= PLATFORM_MIN and grid_y <= PLATFORM_MAX:
				continue
			if maxi(absi(grid_x), absi(grid_y)) > WATER_MAX:
				continue

			var grid := Vector2i(grid_x, grid_y)
			var top_center := _grid_to_world(Vector2(grid)) + Vector2(0.0, LOWER_LEVEL_OFFSET)
			var tile := ART.create_surface_tile(
				ART.WATER_BLOCK,
				top_center,
				-420 + grid_x + grid_y,
				WATER_BASE,
				WATER_DETAIL,
				0.64
			)
			tile.name = "Water_%02d_%02d" % [grid_x, grid_y]
			water_layer.add_child(tile)


func _build_platform_foundation() -> void:
	var outline := _platform_outline()
	var drop := Vector2(0.0, PLATFORM_SKIRT_DEPTH)

	var shadow := Polygon2D.new()
	shadow.name = "PlatformShadow"
	shadow.polygon = _offset_points(outline, Vector2(0.0, PLATFORM_SKIRT_DEPTH + 10.0))
	shadow.color = Color(0.0, 0.025, 0.035, 0.55)
	shadow.z_index = -310
	add_child(shadow)

	# Only the two front faces are visible in this projection. One continuous
	# skirt gives the platform depth without drawing a cube side under every tile.
	var left_face := Polygon2D.new()
	left_face.name = "PlatformLeftSkirt"
	left_face.polygon = PackedVector2Array([
		outline[3], outline[2], outline[2] + drop, outline[3] + drop,
	])
	left_face.color = SKIRT_LEFT
	left_face.z_index = -225
	add_child(left_face)

	var right_face := Polygon2D.new()
	right_face.name = "PlatformRightSkirt"
	right_face.polygon = PackedVector2Array([
		outline[1], outline[2], outline[2] + drop, outline[1] + drop,
	])
	right_face.color = SKIRT_RIGHT
	right_face.z_index = -224
	add_child(right_face)

	# This sits directly below all top tiles so camera scaling can never expose
	# the background through a shared edge.
	var underlay := Polygon2D.new()
	underlay.name = "PlatformUnderlay"
	underlay.polygon = outline
	underlay.color = GRASS_EDGE_BASE
	underlay.z_index = -190
	add_child(underlay)

	var rim := Line2D.new()
	rim.name = "PlatformRim"
	rim.points = PackedVector2Array([
		outline[0], outline[1], outline[2], outline[3], outline[0],
	])
	rim.width = 1.25
	rim.default_color = Color(0.45, 0.76, 0.60, 0.38)
	rim.z_index = -70
	add_child(rim)


func _build_recovery_platform() -> void:
	var ground_layer := Node2D.new()
	ground_layer.name = "RecoveryPlatform"
	add_child(ground_layer)

	for grid_x in range(PLATFORM_MIN, PLATFORM_MAX + 1):
		for grid_y in range(PLATFORM_MIN, PLATFORM_MAX + 1):
			var grid := Vector2i(grid_x, grid_y)
			var presentation := _surface_presentation(grid)
			var tile := ART.create_surface_tile(
				presentation["texture"],
				_grid_to_world(Vector2(grid)),
				-150 + grid_x + grid_y,
				presentation["base_color"],
				presentation["detail_tint"],
				float(presentation["detail_alpha"])
			)
			tile.name = "%s_%02d_%02d" % [String(presentation["name"]), grid_x, grid_y]
			ground_layer.add_child(tile)


func _surface_presentation(grid: Vector2i) -> Dictionary:
	# Four low digital plates replace the previous two-block pylons. They frame
	# the hub without creating visual towers or hiding characters.
	var corner_plates: Array[Vector2i] = [
		Vector2i(-5, -5), Vector2i(5, -5),
		Vector2i(-5, 5), Vector2i(5, 5),
	]
	if grid == Vector2i(-1, -1) or grid in corner_plates:
		return {
			"name": "DataPlate",
			"texture": ART.DATA_BLOCK,
			"base_color": DATA_BASE,
			"detail_tint": DATA_DETAIL,
			"detail_alpha": 0.28,
		}

	var central_plaza := absi(grid.x) <= 2 and absi(grid.y) <= 2
	if central_plaza:
		# The water-pattern source face becomes a dry digital mosaic here. Using a
		# more detailed source tile gives the hub a real focal point without adding
		# collision props or visual clutter.
		return {
			"name": "CommonsPlaza",
			"texture": ART.WATER_BLOCK,
			"base_color": PLAZA_BASE,
			"detail_tint": PLAZA_DETAIL,
			"detail_alpha": 0.54,
		}

	var main_route := (
		absi(grid.x - grid.y) <= 1
		and grid.x >= -4 and grid.x <= 5
		and grid.y >= -4 and grid.y <= 5
	)
	if main_route:
		return {
			"name": "CommonsRoute",
			"texture": ART.WARM_BLOCK,
			"base_color": ROUTE_BASE,
			"detail_tint": ROUTE_DETAIL,
			"detail_alpha": 0.30,
		}

	if absi(grid.x) == PLATFORM_MAX or absi(grid.y) == PLATFORM_MAX:
		return {
			"name": "EdgeGrass",
			"texture": ART.GRASS_BLOCK,
			"base_color": GRASS_EDGE_BASE,
			"detail_tint": GRASS_DETAIL,
			"detail_alpha": 0.38,
		}

	return {
		"name": "Grass",
		"texture": ART.GRASS_BLOCK,
		"base_color": GRASS_BASE,
		"detail_tint": GRASS_DETAIL,
		"detail_alpha": 0.42,
	}


func _build_oak_trees() -> void:
	var props := Node2D.new()
	props.name = "OakTrees"
	add_child(props)

	# Two trees only, framing the commons while keeping every service lane clear.
	var tree_grids: Array[Vector2i] = [
		Vector2i(-5, 4),
		Vector2i(4, -5),
	]

	for index in range(tree_grids.size()):
		var grid := tree_grids[index]
		var foot_position := _grid_to_world(Vector2(grid))
		var texture := _large_oak_texture()
		var tree := Sprite2D.new()
		tree.name = "OakTree%02d" % index
		tree.texture = texture
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tree.position = _oak_position_for_foot(grid, texture)
		tree.z_index = 1000 + int(round(foot_position.y))
		props.add_child(tree)

		TreeAmbientFXScript.apply(
			tree,
			float(index) * 1.73,
			3.25,
			9,
			Color(0.68, 0.94, 0.42, 0.78) if index == 0 else Color(0.44, 0.86, 0.35, 0.72)
		)
		_trees.append(tree)
		_blockers.append({"position": foot_position, "radius": 27.0})


func _large_oak_texture() -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = OAK_TREE_SOURCE
	texture.region = LARGE_OAK_REGION
	return texture


func _oak_position_for_foot(grid: Vector2i, texture: Texture2D) -> Vector2:
	var tile_center := _grid_to_world(Vector2(grid))
	var center_to_near_edge := ART.TILE_HALF_HEIGHT
	var tile_depth := maxf(1.0, center_to_near_edge * 2.0)
	var rendered_height := texture.get_height()
	var extra_height_tiles := maxf(0.0, (rendered_height - tile_depth) / tile_depth)
	var visual_depth_ratio := clampf(
		0.35 + extra_height_tiles * 0.50,
		0.35,
		0.90
	)
	var ground_anchor := tile_center + Vector2(0.0, center_to_near_edge * visual_depth_ratio)
	var texture_center := texture.get_size() * 0.5
	var center_to_foot := LARGE_OAK_FOOT - texture_center
	return ground_anchor - center_to_foot


func _platform_outline() -> PackedVector2Array:
	var top_center := _grid_to_world(Vector2(PLATFORM_MIN, PLATFORM_MIN))
	var right_center := _grid_to_world(Vector2(PLATFORM_MAX, PLATFORM_MIN))
	var bottom_center := _grid_to_world(Vector2(PLATFORM_MAX, PLATFORM_MAX))
	var left_center := _grid_to_world(Vector2(PLATFORM_MIN, PLATFORM_MAX))
	return PackedVector2Array([
		top_center + Vector2(0.0, -ART.TILE_HALF_HEIGHT),
		right_center + Vector2(ART.TILE_HALF_WIDTH, 0.0),
		bottom_center + Vector2(0.0, ART.TILE_HALF_HEIGHT),
		left_center + Vector2(-ART.TILE_HALF_WIDTH, 0.0),
	])


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + offset)
	return result
