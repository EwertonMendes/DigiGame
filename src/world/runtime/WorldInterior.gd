extends Node2D
class_name WorldInterior

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")
const DIGILAB_ART = preload("res://src/world/runtime/DigiLabInteriorArt.gd")
const NavigationScript = preload("res://src/world/runtime/WorldInteriorNavigation.gd")
const WorldDepthScript = preload("res://src/world/runtime/WorldDepth.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const ROOM_SIZE := Vector2i(18, 14)
const EXIT_CELL := Vector2i(9, 12)
const SPAWN_OFFSET_FROM_EXIT := Vector2i(0, -1)
const SPAWN_CELL := EXIT_CELL + SPAWN_OFFSET_FROM_EXIT
const DEFAULT_ACTOR_CLEARANCE := 8.0
const CLEARANCE_DIRECTIONS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2.RIGHT,
	Vector2.LEFT,
	Vector2.UP,
	Vector2.DOWN,
	Vector2(0.70710678, 0.70710678),
	Vector2(-0.70710678, 0.70710678),
	Vector2(0.70710678, -0.70710678),
	Vector2(-0.70710678, -0.70710678),
]

var definition: Dictionary = {}

var _world_controller: Node = null
var _collision_root: Node2D = null
var _navigation: WorldInteriorNavigation = null
var _accent := Color(0.35, 0.88, 1.0, 1.0)
var _service_id := ""
var _title := "INTERIOR"


func configure(interior_definition: Dictionary, world_controller: Node) -> void:
	definition = interior_definition.duplicate(true)
	_world_controller = world_controller
	_title = String(definition.get("title", "INTERIOR"))
	_service_id = String(definition.get("service", ""))
	_accent = _color_from_array(definition.get("accent", []), Color(0.35, 0.88, 1.0, 1.0))
	name = "Interior_%s" % String(definition.get("interior_id", "space")).validate_node_name()
	_build()


func get_spawn_world_position() -> Vector2:
	if _navigation == null:
		return to_global(grid_to_world(Vector2(SPAWN_CELL)))
	return to_global(grid_to_world(Vector2(_navigation.resolved_spawn_cell())))


func get_spawn_cell() -> Vector2i:
	return _navigation.resolved_spawn_cell() if _navigation != null else SPAWN_CELL


func get_exit_cell() -> Vector2i:
	return EXIT_CELL


func has_safe_spawn_to_exit_path() -> bool:
	return _navigation != null and _navigation.has_spawn_to_exit_path()


func is_grid_cell_walkable(cell: Vector2i) -> bool:
	return _navigation != null and _navigation.is_cell_walkable(cell)


func get_navigation_backend() -> String:
	return "layout-clearance"


func is_walkable_world_position(
	world_position: Vector2,
	clearance_radius: float = DEFAULT_ACTOR_CLEARANCE
) -> bool:
	if _navigation == null:
		return false

	var local_position := to_local(world_position)
	var radius := maxf(0.0, clearance_radius)
	for direction: Vector2 in CLEARANCE_DIRECTIONS:
		var sample := local_position + direction * radius
		if not _navigation.is_grid_position_walkable(world_to_grid(sample)):
			return false
	return true


func grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_HALF_WIDTH,
		(grid.x + grid.y) * TILE_HALF_HEIGHT
	)


func world_to_grid(world: Vector2) -> Vector2:
	return Vector2(
		world.x / CITY.TILE_WIDTH + world.y / CITY.TILE_HEIGHT,
		-world.x / CITY.TILE_WIDTH + world.y / CITY.TILE_HEIGHT
	)


func _build() -> void:
	_navigation = NavigationScript.new(ROOM_SIZE, SPAWN_CELL, EXIT_CELL) as WorldInteriorNavigation

	# Interior movement has exactly one source of truth. Keep a non-physics
	# debug root for tooling/metadata, but never create StaticBody2D wall shapes:
	# those used to disagree with logical walkability and make CharacterBody2D
	# bounce or slide into a different position than the navigation contract.
	_collision_root = Node2D.new()
	_collision_root.name = "InteriorCollision"
	_collision_root.set_meta("movement_backend", "layout-clearance")
	add_child(_collision_root)

	_build_floor()
	_build_walls()
	_build_counter()
	if not _navigation.finalize():
		push_error("Invalid %s interior navigation layout" % _service_id)
	_build_service_zones()
	_build_service_point()
	_build_exit()
	_build_staff()


func _build_floor() -> void:
	var floor_root := Node2D.new()
	floor_root.name = "Floor"
	add_child(floor_root)

	if _service_id == "digilab":
		_build_digilab_floor(floor_root)
		return

	for x in range(ROOM_SIZE.x):
		for y in range(ROOM_SIZE.y):
			var cell := Vector2i(x, y)
			var edge := x == 0 or y == 0 or x == ROOM_SIZE.x - 1 or y == ROOM_SIZE.y - 1
			var surface := _floor_surface(cell, edge)
			var tile := CITY.create_surface_tile(
				surface,
				grid_to_world(Vector2(cell)),
				-900 + x + y,
				0.94
			)
			tile.name = "Floor_%02d_%02d" % [x, y]
			floor_root.add_child(tile)


func _build_digilab_floor(floor_root: Node2D) -> void:
	# DigiLab uses one material across all 252 logical cells, so render those
	# diamonds through one MultiMesh instead of 252 Node2D + 504 Polygon2D
	# objects. The gameplay grid remains unchanged; this only removes render/
	# scene-tree overhead on mobile and Web.
	var texture := CITY.surface_texture(CITY.SURFACE_DIGILAB_FLOOR_1)
	var raw_uvs := CITY.surface_top_face_uvs(CITY.SURFACE_DIGILAB_FLOOR_1)
	var texture_size := texture.get_size()
	var normalized_uvs := PackedVector2Array()
	for uv in raw_uvs:
		normalized_uvs.append(Vector2(
			uv.x / maxf(texture_size.x, 1.0),
			uv.y / maxf(texture_size.y, 1.0)
		))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-TILE_HALF_WIDTH - 0.35, 0.0, 0.0),
		Vector3(0.0, -TILE_HALF_HEIGHT - 0.25, 0.0),
		Vector3(TILE_HALF_WIDTH + 0.35, 0.0, 0.0),
		Vector3(0.0, TILE_HALF_HEIGHT + 0.25, 0.0),
	])
	arrays[Mesh.ARRAY_TEX_UV] = normalized_uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = mesh
	multimesh.instance_count = ROOM_SIZE.x * ROOM_SIZE.y

	var index := 0
	for x in range(ROOM_SIZE.x):
		for y in range(ROOM_SIZE.y):
			multimesh.set_instance_transform_2d(
				index,
				Transform2D(0.0, grid_to_world(Vector2(x, y)))
			)
			index += 1

	var batch := MultiMeshInstance2D.new()
	batch.name = "FloorBatch"
	batch.multimesh = multimesh
	batch.texture = texture
	batch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	batch.z_index = -900
	batch.set_meta("tile_count", ROOM_SIZE.x * ROOM_SIZE.y)
	batch.set_meta("grid_size", Vector2(CITY.TILE_WIDTH, CITY.TILE_HEIGHT))
	batch.set_meta("render_backend", "multimesh")
	floor_root.add_child(batch)


func _floor_surface(cell: Vector2i, edge: bool) -> String:
	var accent_lane := cell.x in [8, 9] or (cell.y == 6 and cell.x >= 5 and cell.x <= 12)
	if accent_lane and not edge:
		return _accent_surface()
	return CITY.SURFACE_DARK if edge else CITY.SURFACE_MAIN


func _build_walls() -> void:
	var walls := Node2D.new()
	walls.name = "Walls"
	add_child(walls)

	if _service_id == "digilab":
		_build_digilab_walls(walls)
		return

	var wall_cells: Array[Vector2i] = []
	for x in range(ROOM_SIZE.x):
		wall_cells.append(Vector2i(x, 0))
	for y in range(1, ROOM_SIZE.y - 1):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(ROOM_SIZE.x - 1, y))

	for cell in wall_cells:
		var layout_anchor := grid_to_world(Vector2(cell))
		for level in range(2):
			var surface := CITY.SURFACE_DARK
			if level == 1 and (cell.x + cell.y) % 4 == 0:
				surface = _accent_surface()
			var block := CITY.create_full_block(
				surface,
				layout_anchor,
				_depth_for_local_ground_y(layout_anchor.y),
				level
			)
			walls.add_child(block)
			if level == 0:
				_register_blocking_visual(block, layout_anchor, "wall")

	for x in range(0, 5):
		_add_low_front_wall(walls, Vector2i(x, ROOM_SIZE.y - 1))
	for x in range(ROOM_SIZE.x - 5, ROOM_SIZE.x):
		_add_low_front_wall(walls, Vector2i(x, ROOM_SIZE.y - 1))


func _build_digilab_walls(walls: Node2D) -> void:
	var authored := Node2D.new()
	authored.name = "AuthoredWalls"
	authored.set_meta("grid_size", Vector2(CITY.TILE_WIDTH, CITY.TILE_HEIGHT))
	authored.set_meta("layout_contract", "grid-native-vector-depth-sorted")
	walls.add_child(authored)

	var last_x := float(ROOM_SIZE.x - 1)
	var front_y := float(ROOM_SIZE.y - 1)

	# Wall pieces need per-anchor depth because actors now use WorldDepth's
	# canonical presentation plane. A MultiMesh has only one z_index for every
	# instance, so batching an entire wall run makes some segments render in
	# front/behind the player at the wrong time. The floor remains batched; the
	# small wall kit is intentionally depth-sorted piece by piece.
	var back_grid: Array[Vector2] = []
	for x in range(ROOM_SIZE.x - 1):
		var anchor := Vector2(float(x), 0.0)
		back_grid.append(anchor)
		_add_digilab_wall_piece(authored, DIGILAB_ART.KIND_STRAIGHT_RIGHT, anchor)

	var side_grid: Array[Vector2] = []
	for y in range(ROOM_SIZE.y - 1):
		for x in [0.0, last_x]:
			var anchor := Vector2(float(x), float(y))
			side_grid.append(anchor)
			_add_digilab_wall_piece(authored, DIGILAB_ART.KIND_STRAIGHT_LEFT, anchor)

	var front_grid: Array[Vector2] = []
	for x in range(0, 7):
		var anchor := Vector2(float(x), front_y)
		front_grid.append(anchor)
		_add_digilab_wall_piece(authored, DIGILAB_ART.KIND_LOW_DIVIDER, anchor)
	for x in range(11, ROOM_SIZE.x - 1):
		var anchor := Vector2(float(x), front_y)
		front_grid.append(anchor)
		_add_digilab_wall_piece(authored, DIGILAB_ART.KIND_LOW_DIVIDER, anchor)

	# Corners are orientation-specific connector sleeves. Each one overlaps a
	# half edge of both adjacent runs, so there is no floating post or visible
	# "sticker" seam at the four room vertices.
	_add_digilab_wall_piece(
		authored,
		DIGILAB_ART.KIND_CORNER_BACK_LEFT,
		Vector2(0.0, 0.0)
	)
	_add_digilab_wall_piece(
		authored,
		DIGILAB_ART.KIND_CORNER_BACK_RIGHT,
		Vector2(last_x, 0.0)
	)
	_add_digilab_wall_piece(
		authored,
		DIGILAB_ART.KIND_CORNER_FRONT_LEFT,
		Vector2(0.0, front_y)
	)
	_add_digilab_wall_piece(
		authored,
		DIGILAB_ART.KIND_CORNER_FRONT_RIGHT,
		Vector2(last_x, front_y)
	)

	# The doorway includes low-wall sleeves on both ends. It owns x=7..11
	# exactly and visually underlaps the neighboring front divider modules.
	_add_digilab_wall_piece(
		authored,
		DIGILAB_ART.KIND_DOOR_FRAME,
		Vector2(7.0, front_y)
	)

	# Register occupancy from the exact same anchor arrays used to render the
	# wall kit. Repositioning or resizing a wall run therefore changes visuals
	# and navigation together instead of requiring a second hand-maintained map.
	_collision_root.set_meta("digilab_wall_collision_backend", "layout-clearance")
	_mark_grid_anchors_blocked(back_grid, "digilab_back_wall")
	_mark_grid_anchors_blocked(side_grid, "digilab_side_wall")
	_mark_grid_anchors_blocked(front_grid, "digilab_front_wall")
	for corner: Vector2 in [
		Vector2(0.0, 0.0),
		Vector2(last_x, 0.0),
		Vector2(0.0, front_y),
		Vector2(last_x, front_y),
	]:
		_mark_blocked(
			Vector2i(roundi(corner.x), roundi(corner.y)),
			"digilab_corner"
		)


func _add_digilab_wall_piece(
	parent: Node2D,
	kind: String,
	grid_anchor: Vector2
) -> void:
	var world_anchor := grid_to_world(grid_anchor)
	var depth_y := world_anchor.y
	for delta: Vector2 in DIGILAB_ART.connector_deltas(kind):
		depth_y = maxf(depth_y, grid_to_world(grid_anchor + delta).y)
	var piece := DIGILAB_ART.create_piece(
		kind,
		world_anchor,
		grid_anchor,
		_depth_for_local_ground_y(depth_y)
	)
	parent.add_child(piece)


func _add_low_front_wall(parent: Node2D, cell: Vector2i) -> void:
	var layout_anchor := grid_to_world(Vector2(cell))
	var block := CITY.create_full_block(
		CITY.SURFACE_DARK,
		layout_anchor,
		_depth_for_local_ground_y(layout_anchor.y)
	)
	parent.add_child(block)
	_register_blocking_visual(block, layout_anchor, "front_wall")


func _build_counter() -> void:
	var counter := Node2D.new()
	counter.name = "ServiceCounter"
	add_child(counter)
	for x in range(6, 12):
		var cell := Vector2i(x, 4)
		var layout_anchor := grid_to_world(Vector2(cell))
		var surface := _accent_surface() if x in [7, 10] else CITY.SURFACE_DARK
		var block := CITY.create_full_block(
			surface,
			layout_anchor,
			_depth_for_local_ground_y(layout_anchor.y) + 2
		)
		counter.add_child(block)
		_register_blocking_visual(block, layout_anchor, "service_counter")


func _build_service_zones() -> void:
	# DigiLab's modularized authored floor already communicates its service
	# layout. Do not stack extra decals over it; keeping one clean visual layer
	# preserves the fine 64x32 tile detail.
	if _service_id == "digilab":
		return

	var cells: Array[Vector2i] = []
	match _service_id:
		"digilab":
			cells = [Vector2i(3, 7), Vector2i(5, 8), Vector2i(13, 7), Vector2i(15, 8)]
		"hospital":
			cells = [Vector2i(3, 7), Vector2i(4, 7), Vector2i(13, 7), Vector2i(14, 7)]
		"training":
			cells = [Vector2i(4, 6), Vector2i(4, 9), Vector2i(14, 6), Vector2i(14, 9)]
		"shop":
			cells = [Vector2i(3, 6), Vector2i(4, 6), Vector2i(13, 6), Vector2i(14, 6)]
		"archive":
			cells = [Vector2i(3, 5), Vector2i(3, 8), Vector2i(14, 5), Vector2i(14, 8)]
	for cell in cells:
		var pad := CITY.create_surface_tile(
			_accent_surface(),
			grid_to_world(Vector2(cell)),
			-350 + cell.x + cell.y,
			1.0
		)
		pad.name = "ServiceZone_%02d_%02d" % [cell.x, cell.y]
		add_child(pad)


func _build_service_point() -> void:
	var service := Node2D.new()
	service.name = "ServicePoint"
	service.position = grid_to_world(Vector2(9, 5))
	service.z_index = _depth_for_local_ground_y(service.position.y) + 2
	add_child(service)

	if _service_id != "digilab":
		var marker := CITY.create_surface_tile(_accent_surface(), Vector2.ZERO, 0, 1.0)
		service.add_child(marker)

	var interactable := InteractableScript.new() as WorldInteractable
	var prompt_text := "USE SERVICE"
	if _service_id == "shop":
		prompt_text = "BROWSE DATA MARKET"
	elif _service_id == "archive":
		prompt_text = "ACCESS ARCHIVE"
	else:
		prompt_text = "OPEN %s" % _title
	interactable.configure(
		_service_id,
		prompt_text,
		{"service": _service_id, "title": _title},
		92.0,
		50
	)
	service.add_child(interactable)


func _build_exit() -> void:
	var exit_root := Area2D.new()
	exit_root.name = "ExitThreshold"
	exit_root.add_to_group("world_interior_exit_threshold")
	exit_root.position = grid_to_world(Vector2(get_exit_cell()))
	exit_root.collision_layer = 0
	exit_root.collision_mask = 1
	exit_root.monitoring = true
	exit_root.monitorable = false
	add_child(exit_root)

	if _service_id != "digilab":
		var marker := CITY.create_surface_tile(CITY.SURFACE_TECH_TEAL, Vector2.ZERO, 0, 0.88)
		exit_root.add_child(marker)

	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 17.0
	shape_node.shape = shape
	shape_node.position = Vector2(0.0, -8.0)
	exit_root.add_child(shape_node)
	exit_root.body_entered.connect(_on_exit_threshold_entered)


func _on_exit_threshold_entered(body: Node2D) -> void:
	if _world_controller == null or not _world_controller.has_method("get_player"):
		return
	if body != _world_controller.call("get_player"):
		return
	if _world_controller.has_method("request_interior_exit"):
		_world_controller.call_deferred("request_interior_exit")


func _build_staff() -> void:
	var actor := ActorScript.new() as HubActor
	actor.name = "Staff"
	actor.configure(NPC_TEXTURE, false, _world_controller, "southwest")
	actor.position = grid_to_world(Vector2(11, 6))
	add_child(actor)

	var label := Label.new()
	label.text = _staff_title()
	label.position = Vector2(-72.0, -84.0)
	label.size = Vector2(144.0, 22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", _accent.lightened(0.20))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	actor.add_child(label)

	var interactable := InteractableScript.new() as WorldInteractable
	interactable.configure(
		"interior_greeting",
		"TALK",
		{"title": _staff_title(), "body": _staff_greeting()},
		76.0,
		25
	)
	actor.add_child(interactable)


func _accent_surface() -> String:
	match _service_id:
		"digilab":
			return CITY.SURFACE_TECH_TEAL
		"hospital":
			return CITY.SURFACE_TECH_BLUE
		"training":
			return CITY.SURFACE_TRAINING
		"shop":
			return CITY.SURFACE_MARKET
		"archive":
			return CITY.SURFACE_TECH_PURPLE
		_:
			return CITY.SURFACE_TECH_TEAL


func _depth_for_local_ground_y(local_y: float) -> int:
	return WorldDepthScript.z_for_ground_y(global_position.y + local_y, 0.0)


func _register_blocking_visual(
	node: Node2D,
	layout_anchor: Vector2,
	source: String
) -> void:
	# The placement anchor is shared by rendering and navigation at the call
	# site. Full-block art intentionally offsets its Sprite2D center below the
	# isometric top face, so reading node.position back as gameplay geometry
	# would couple collision to a render-only implementation detail.
	var grid := world_to_grid(layout_anchor)
	var cell := Vector2i(roundi(grid.x), roundi(grid.y))
	node.set_meta("navigation_blocker", true)
	node.set_meta("navigation_anchor", layout_anchor)
	node.set_meta("navigation_cell", cell)
	node.set_meta("navigation_source", source)
	_mark_blocked(cell, source)


func _mark_grid_anchors_blocked(grid_anchors: Array[Vector2], source: String) -> void:
	for anchor: Vector2 in grid_anchors:
		_mark_blocked(
			Vector2i(roundi(anchor.x), roundi(anchor.y)),
			source
		)


func _mark_blocked(cell: Vector2i, source: String = "") -> void:
	if _navigation == null:
		return
	_navigation.block_cell(cell, source)


func _staff_title() -> String:
	match _service_id:
		"digilab":
			return "LAB TECHNICIAN"
		"hospital":
			return "RECOVERY STAFF"
		"training":
			return "TRAINING COACH"
		"shop":
			return "DATA MERCHANT"
		"archive":
			return "ARCHIVIST"
		_:
			return "CITY STAFF"


func _staff_greeting() -> String:
	match _service_id:
		"digilab":
			return "The DigiLab service floor is online. Use the central console when you are ready."
		"hospital":
			return "The recovery service is ready. The central point handles HP and SP treatment."
		"training":
			return "The training service is online. Use the central point when you are ready."
		"shop":
			return "Welcome to the Data Market. The item economy will expand from this service floor."
		"archive":
			return "The Archive service is online. Research systems can expand here without changing the world runtime."
		_:
			return "Welcome to Central City."


func _color_from_array(raw, fallback: Color) -> Color:
	if raw is Array and raw.size() >= 3:
		return Color(
			float(raw[0]),
			float(raw[1]),
			float(raw[2]),
			float(raw[3]) if raw.size() >= 4 else 1.0
		)
	return fallback
