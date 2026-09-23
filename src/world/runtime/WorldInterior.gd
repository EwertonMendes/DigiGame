extends Node2D
class_name WorldInterior

const ART = preload("res://src/world/DevilsWorkshopArt.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const ROOM_SIZE := Vector2i(18, 14)
const SPAWN_CELL := Vector2i(9, 11)
const EXIT_CELL := Vector2i(9, 12)

var definition: Dictionary = {}

var _world_controller: Node = null
var _physics_root: StaticBody2D = null
var _blocked_cells: Dictionary = {}
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
	return to_global(grid_to_world(Vector2(SPAWN_CELL)))


func is_walkable_world_position(world_position: Vector2) -> bool:
	var local_grid := world_to_grid(to_local(world_position))
	var cell := Vector2i(floori(local_grid.x + 0.5), floori(local_grid.y + 0.5))
	if cell.x < 1 or cell.y < 1 or cell.x >= ROOM_SIZE.x - 1 or cell.y >= ROOM_SIZE.y - 1:
		return false
	return not _blocked_cells.has(_cell_key(cell))


func grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_HALF_WIDTH,
		(grid.x + grid.y) * TILE_HALF_HEIGHT
	)


func world_to_grid(world: Vector2) -> Vector2:
	return Vector2(
		world.x / 64.0 + world.y / 32.0,
		-world.x / 64.0 + world.y / 32.0
	)


func _build() -> void:
	_physics_root = StaticBody2D.new()
	_physics_root.name = "InteriorCollision"
	add_child(_physics_root)
	_build_floor()
	_build_back_walls()
	_build_counter()
	_build_lounge()
	_build_service_point()
	_build_exit()
	_build_staff()


func _build_floor() -> void:
	var floor_root := Node2D.new()
	floor_root.name = "Floor"
	add_child(floor_root)
	for x in range(ROOM_SIZE.x):
		for y in range(ROOM_SIZE.y):
			var cell := Vector2i(x, y)
			var edge := x == 0 or y == 0 or x == ROOM_SIZE.x - 1 or y == ROOM_SIZE.y - 1
			var texture := ART.WARM_BLOCK
			var base_color := Color(0.30, 0.33, 0.35, 1.0)
			var detail_tint := Color(0.90, 0.94, 0.96, 1.0)
			var detail_alpha := 0.34
			if (x + y) % 7 == 0 and not edge:
				texture = ART.DATA_BLOCK
				base_color = Color(
					0.18 + _accent.r * 0.08,
					0.22 + _accent.g * 0.08,
					0.26 + _accent.b * 0.08,
					1.0
				)
				detail_tint = _accent
				detail_alpha = 0.28
			var tile := ART.create_surface_tile(
				texture,
				grid_to_world(Vector2(cell)),
				-900 + x + y,
				base_color,
				detail_tint,
				detail_alpha
			)
			floor_root.add_child(tile)


func _build_back_walls() -> void:
	var walls := Node2D.new()
	walls.name = "Walls"
	add_child(walls)
	var wall_cells: Array[Vector2i] = []
	for x in range(ROOM_SIZE.x):
		wall_cells.append(Vector2i(x, 0))
	for y in range(1, ROOM_SIZE.y - 1):
		wall_cells.append(Vector2i(0, y))
		wall_cells.append(Vector2i(ROOM_SIZE.x - 1, y))
	for cell in wall_cells:
		_add_wall_stack(walls, cell, 2)
		_mark_blocked(cell)

	# Low front corners frame the room without hiding the playable floor.
	for x in range(0, 5):
		var left_cell := Vector2i(x, ROOM_SIZE.y - 1)
		_add_wall_stack(walls, left_cell, 1)
		_mark_blocked(left_cell)
	for x in range(ROOM_SIZE.x - 5, ROOM_SIZE.x):
		var right_cell := Vector2i(x, ROOM_SIZE.y - 1)
		_add_wall_stack(walls, right_cell, 1)
		_mark_blocked(right_cell)


func _build_counter() -> void:
	var counter := Node2D.new()
	counter.name = "ServiceCounter"
	add_child(counter)
	for x in range(6, 12):
		var cell := Vector2i(x, 4)
		var block := ART.create_full_block(
			ART.DATA_BLOCK,
			grid_to_world(Vector2(cell)),
			1000 + int(round(grid_to_world(Vector2(cell)).y)),
			_accent,
			0
		)
		counter.add_child(block)
		_mark_blocked(cell)
		_add_circle_collision(cell, 22.0)

	# Back console towers make the service point read as an actual establishment.
	for cell in [Vector2i(7, 2), Vector2i(10, 2)]:
		for level in range(2):
			var console := ART.create_full_block(
				ART.DATA_BLOCK,
				grid_to_world(Vector2(cell)),
				1030 + int(round(grid_to_world(Vector2(cell)).y)),
				_accent.lightened(0.10),
				level
			)
			counter.add_child(console)
		_mark_blocked(cell)
		_add_circle_collision(cell, 21.0)


func _build_lounge() -> void:
	var lounge := Node2D.new()
	lounge.name = "Lounge"
	add_child(lounge)
	for cell in [Vector2i(4, 8), Vector2i(5, 8), Vector2i(12, 8), Vector2i(13, 8)]:
		var seat := ART.create_full_block(
			ART.WARM_BLOCK,
			grid_to_world(Vector2(cell)),
			930 + int(round(grid_to_world(Vector2(cell)).y)),
			Color(0.60, 0.67, 0.70, 1.0),
			0
		)
		seat.scale *= Vector2(0.84, 0.72)
		lounge.add_child(seat)
		_mark_blocked(cell)
		_add_circle_collision(cell, 18.0)

	for cell in [Vector2i(3, 5), Vector2i(14, 5)]:
		var kiosk := ART.create_full_block(
			ART.DATA_BLOCK,
			grid_to_world(Vector2(cell)),
			940 + int(round(grid_to_world(Vector2(cell)).y)),
			_accent.darkened(0.12),
			0
		)
		lounge.add_child(kiosk)
		_mark_blocked(cell)
		_add_circle_collision(cell, 18.0)


func _build_service_point() -> void:
	var service := Node2D.new()
	service.name = "ServicePoint"
	service.position = grid_to_world(Vector2(9, 5))
	service.z_index = 1200 + int(round(service.position.y))
	add_child(service)

	var glow := Polygon2D.new()
	glow.name = "ServiceGlow"
	glow.polygon = ART.tile_diamond(Vector2(-8.0, -4.0))
	glow.color = Color(_accent.r, _accent.g, _accent.b, 0.26)
	glow.position = Vector2(0.0, 4.0)
	service.add_child(glow)

	var interactable := InteractableScript.new() as WorldInteractable
	var action_id := _service_id
	var prompt_text := "USE SERVICE"
	if action_id == "shop":
		prompt_text = "BROWSE DATA MARKET"
	elif action_id == "archive":
		prompt_text = "ACCESS ARCHIVE"
	else:
		prompt_text = "OPEN %s" % _title
	interactable.configure(
		action_id,
		prompt_text,
		{"service": action_id, "title": _title},
		92.0,
		50
	)
	service.add_child(interactable)


func _build_exit() -> void:
	var exit_root := Node2D.new()
	exit_root.name = "Exit"
	exit_root.position = grid_to_world(Vector2(EXIT_CELL))
	exit_root.z_index = 1180 + int(round(exit_root.position.y))
	add_child(exit_root)

	var marker := Polygon2D.new()
	marker.name = "ExitMarker"
	marker.polygon = ART.tile_diamond(Vector2(-10.0, -5.0))
	marker.color = Color(0.55, 0.94, 1.0, 0.18)
	exit_root.add_child(marker)

	var interactable := InteractableScript.new() as WorldInteractable
	interactable.configure("exit_interior", "EXIT", {"title": _title}, 70.0, 80)
	exit_root.add_child(interactable)


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
		{
			"title": _staff_title(),
			"body": _staff_greeting(),
		},
		76.0,
		25
	)
	actor.add_child(interactable)


func _add_wall_stack(parent: Node2D, cell: Vector2i, levels: int) -> void:
	for level in range(levels):
		var block := ART.create_full_block(
			ART.WARM_BLOCK if level == 0 else ART.DATA_BLOCK,
			grid_to_world(Vector2(cell)),
			820 + int(round(grid_to_world(Vector2(cell)).y)),
			Color(0.52, 0.58, 0.62, 1.0) if level == 0 else _accent.darkened(0.18),
			level
		)
		parent.add_child(block)
	_add_circle_collision(cell, 23.0)


func _add_circle_collision(cell: Vector2i, radius: float) -> void:
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	shape_node.shape = shape
	shape_node.position = grid_to_world(Vector2(cell)) + Vector2(0.0, -10.0)
	_physics_root.add_child(shape_node)


func _mark_blocked(cell: Vector2i) -> void:
	_blocked_cells[_cell_key(cell)] = true


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


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
			return "The DigiLab floor is open. Use the central service point for evolution, expansion and party management."
		"hospital":
			return "Recovery systems are ready. The central service point handles HP and SP treatment."
		"training":
			return "Use the training service point when you are ready to spend Capacity on permanent growth."
		"shop":
			return "The market floor is ready for the item economy. This space is already built to support multiple vendors."
		"archive":
			return "This archive hall is ready for research, records and future encyclopedia systems."
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
