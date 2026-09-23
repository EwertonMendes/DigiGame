extends Node2D
class_name WorldInterior

const CITY = preload("res://src/world/runtime/CityAtlasArt.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const ROOM_SIZE := Vector2i(18, 14)
const SPAWN_CELL := Vector2i(9, 11)
const EXIT_CELL := Vector2i(9, 12)

const FLOOR_DARK := Vector2i(12, 16)
const FLOOR_GRAY := Vector2i(13, 16)
const FLOOR_CYAN := Vector2i(8, 16)
const FLOOR_YELLOW := Vector2i(9, 16)
const FLOOR_GREEN := Vector2i(10, 16)
const FLOOR_WHITE := Vector2i(5, 16)
const FLOOR_PURPLE := Vector2i(15, 16)

const WALL_GRAY := Vector2i(3, 13)
const WALL_DARK := Vector2i(2, 13)
const WALL_WHITE := Vector2i(11, 13)
const WALL_TEAL := Vector2i(14, 13)
const WALL_YELLOW := Vector2i(15, 13)
const WALL_LIME := Vector2i(16, 13)
const WALL_PURPLE := Vector2i(5, 13)

const TECH_BEACON := Vector2i(3, 20)
const TECH_MACHINE_A := Vector2i(10, 36)
const TECH_MACHINE_B := Vector2i(12, 36)
const ANVIL := Vector2i(15, 19)
const CHEST := Vector2i(13, 18)
const CHEST_ALT := Vector2i(15, 18)
const BOOKSHELF := Vector2i(12, 3)
const LECTERN := Vector2i(10, 20)
const TABLE := Vector2i(0, 21)
const BENCH := Vector2i(5, 18)
const LANTERN := Vector2i(6, 53)

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
	_build_walls()
	_build_counter()
	_build_service_zones()
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
			var accent_lane := x in [8, 9] or (y == 6 and x >= 5 and x <= 12)
			var floor_cell := FLOOR_DARK if edge else FLOOR_GRAY
			if accent_lane and not edge:
				floor_cell = _accent_floor_cell()
			if _service_id == "hospital" and not edge and (x + y) % 11 == 0:
				floor_cell = FLOOR_WHITE
			var tile := CITY.create_floor_tile(
				floor_cell,
				grid_to_world(Vector2(cell)),
				-900 + x + y,
				Color(0.24, 0.27, 0.29, 1.0) if not edge else Color(0.10, 0.12, 0.14, 1.0),
				Color.WHITE,
				0.96
			)
			floor_root.add_child(tile)


func _build_walls() -> void:
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
		for level in range(2):
			var atlas_cell := WALL_GRAY
			if level == 1 and (cell.x + cell.y) % 4 == 0:
				atlas_cell = _accent_block_cell()
			elif level == 1 and _service_id == "hospital":
				atlas_cell = WALL_WHITE
			var block := CITY.create_block(
				atlas_cell,
				grid_to_world(Vector2(cell)),
				820 + int(round(grid_to_world(Vector2(cell)).y)),
				level
			)
			walls.add_child(block)
		_mark_blocked(cell)
		_add_circle_collision(cell, 22.0)

	# Low front corners define the room silhouette without hiding the floor.
	for x in range(0, 5):
		_add_low_front_wall(walls, Vector2i(x, ROOM_SIZE.y - 1))
	for x in range(ROOM_SIZE.x - 5, ROOM_SIZE.x):
		_add_low_front_wall(walls, Vector2i(x, ROOM_SIZE.y - 1))


func _add_low_front_wall(parent: Node2D, cell: Vector2i) -> void:
	var block := CITY.create_block(
		WALL_DARK,
		grid_to_world(Vector2(cell)),
		820 + int(round(grid_to_world(Vector2(cell)).y)),
		0
	)
	parent.add_child(block)
	_mark_blocked(cell)
	_add_circle_collision(cell, 22.0)


func _build_counter() -> void:
	var counter := Node2D.new()
	counter.name = "ServiceCounter"
	add_child(counter)
	for x in range(6, 12):
		var cell := Vector2i(x, 4)
		var atlas_cell := _accent_block_cell() if x in [7, 10] else WALL_DARK
		var block := CITY.create_block(
			atlas_cell,
			grid_to_world(Vector2(cell)),
			1000 + int(round(grid_to_world(Vector2(cell)).y)),
			0
		)
		counter.add_child(block)
		_mark_blocked(cell)
		_add_circle_collision(cell, 20.0)

	for cell in [Vector2i(7, 3), Vector2i(10, 3)]:
		var lamp := CITY.create_prop(
			LANTERN,
			grid_to_world(Vector2(cell)),
			1080 + int(round(grid_to_world(Vector2(cell)).y)),
			Vector2(1.55, 1.55)
		)
		lamp.modulate = _accent.lightened(0.10)
		counter.add_child(lamp)


func _build_service_zones() -> void:
	match _service_id:
		"digilab":
			_add_station(TECH_BEACON, Vector2i(4, 5), Vector2(2.2, 2.2))
			_add_station(TECH_MACHINE_A, Vector2i(3, 8), Vector2(2.0, 2.0))
			_add_station(TECH_MACHINE_B, Vector2i(14, 8), Vector2(2.0, 2.0))
		"hospital":
			_build_hospital_bays()
		"training":
			for cell in [Vector2i(4, 6), Vector2i(4, 9), Vector2i(14, 6), Vector2i(14, 9)]:
				_add_station(ANVIL, cell, Vector2(1.9, 1.9))
		"shop":
			var market_stations: Array[Dictionary] = [
				{"cell": Vector2i(3, 6), "asset": CHEST},
				{"cell": Vector2i(4, 6), "asset": CHEST_ALT},
				{"cell": Vector2i(13, 6), "asset": CHEST},
				{"cell": Vector2i(14, 6), "asset": CHEST_ALT},
				{"cell": Vector2i(3, 9), "asset": CHEST_ALT},
				{"cell": Vector2i(14, 9), "asset": CHEST},
			]
			for spec: Dictionary in market_stations:
				var station_cell: Vector2i = spec.get("cell", Vector2i.ZERO)
				var station_asset: Vector2i = spec.get("asset", CHEST)
				_add_station(station_asset, station_cell, Vector2(1.8, 1.8))
		"archive":
			for cell in [Vector2i(3, 5), Vector2i(3, 8), Vector2i(14, 5), Vector2i(14, 8)]:
				_add_station(BOOKSHELF, cell, Vector2(1.9, 1.9))
			_add_station(LECTERN, Vector2i(5, 8), Vector2(1.75, 1.75))
			_add_station(LECTERN, Vector2i(12, 8), Vector2(1.75, 1.75))
		_:
			pass


func _build_hospital_bays() -> void:
	var bay_origins: Array[Vector2i] = [Vector2i(3, 7), Vector2i(13, 7)]
	for origin: Vector2i in bay_origins:
		for dx: int in range(2):
			var cell: Vector2i = origin + Vector2i(dx, 0)
			var pad := CITY.create_floor_tile(
				FLOOR_WHITE,
				grid_to_world(Vector2(cell)),
				-400 + cell.x + cell.y,
				Color(0.76, 0.82, 0.84, 1.0),
				Color.WHITE,
				1.0
			)
			add_child(pad)
		_add_station(TECH_MACHINE_A, origin + Vector2i(0, -1), Vector2(1.65, 1.65))


func _build_lounge() -> void:
	var lounge := Node2D.new()
	lounge.name = "Lounge"
	add_child(lounge)
	for cell in [Vector2i(5, 10), Vector2i(12, 10)]:
		var bench := CITY.create_prop(
			BENCH,
			grid_to_world(Vector2(cell)),
			930 + int(round(grid_to_world(Vector2(cell)).y)),
			Vector2(1.8, 1.8)
		)
		lounge.add_child(bench)
		_mark_blocked(cell)
		_add_circle_collision(cell, 16.0)

	var table := CITY.create_prop(
		TABLE,
		grid_to_world(Vector2(3, 10)),
		930 + int(round(grid_to_world(Vector2(3, 10)).y)),
		Vector2(1.75, 1.75)
	)
	lounge.add_child(table)
	_mark_blocked(Vector2i(3, 10))
	_add_circle_collision(Vector2i(3, 10), 15.0)


func _add_station(atlas_cell: Vector2i, cell: Vector2i, scale: Vector2) -> void:
	var prop := CITY.create_prop(
		atlas_cell,
		grid_to_world(Vector2(cell)),
		950 + int(round(grid_to_world(Vector2(cell)).y)),
		scale
	)
	add_child(prop)
	_mark_blocked(cell)
	_add_circle_collision(cell, 16.0)


func _build_service_point() -> void:
	var service := Node2D.new()
	service.name = "ServicePoint"
	service.position = grid_to_world(Vector2(9, 5))
	service.z_index = 1200 + int(round(service.position.y))
	add_child(service)

	var marker := CITY.create_floor_tile(
		_accent_floor_cell(),
		Vector2.ZERO,
		0,
		Color(0.11, 0.17, 0.19, 1.0),
		Color.WHITE,
		1.0
	)
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
	var exit_root := Node2D.new()
	exit_root.name = "Exit"
	exit_root.position = grid_to_world(Vector2(EXIT_CELL))
	exit_root.z_index = 1180 + int(round(exit_root.position.y))
	add_child(exit_root)

	var marker := CITY.create_floor_tile(
		FLOOR_CYAN,
		Vector2.ZERO,
		0,
		Color(0.12, 0.19, 0.21, 1.0),
		Color.WHITE,
		0.92
	)
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


func _accent_floor_cell() -> Vector2i:
	match _service_id:
		"digilab", "hospital":
			return FLOOR_CYAN
		"training":
			return FLOOR_GREEN
		"shop":
			return FLOOR_YELLOW
		"archive":
			return FLOOR_PURPLE
		_:
			return FLOOR_CYAN


func _accent_block_cell() -> Vector2i:
	match _service_id:
		"digilab":
			return WALL_TEAL
		"hospital":
			return WALL_WHITE
		"training":
			return WALL_LIME
		"shop":
			return WALL_YELLOW
		"archive":
			return WALL_PURPLE
		_:
			return WALL_TEAL


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
			return "The DigiLab has dedicated workstations and a full service floor. Use the central console when you are ready."
		"hospital":
			return "The recovery bays are ready. The central service point handles HP and SP treatment."
		"training":
			return "The training floor has dedicated stations and open movement space. Use the central service point when you are ready."
		"shop":
			return "Welcome to the Data Market. Vendor storage and floor space are ready for the item economy."
		"archive":
			return "The reading stations and archive stacks are online. Research systems can expand into this hall without changing the world runtime."
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
