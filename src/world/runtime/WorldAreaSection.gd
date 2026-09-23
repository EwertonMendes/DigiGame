extends Node2D
class_name WorldAreaSection

const CITY = preload("res://src/world/runtime/CityAtlasArt.gd")
const TreeAmbientFXScript = preload("res://src/vfx/TreeAmbientFX.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const OAK_TREE_SOURCE = preload("res://assets/terrain/Oak_Tree.png")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

const SECTION_SIZE := 14
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const LARGE_OAK_REGION := Rect2(11.0, 9.0, 41.0, 63.0)
const LARGE_OAK_FOOT := Vector2(20.5, 62.0)

# Authored MCBlocks atlas cells. Row 16 provides flat isometric surfaces.
const FLOOR_ROAD := Vector2i(12, 16)
const FLOOR_PAVEMENT := Vector2i(13, 16)
const FLOOR_PLAZA := Vector2i(14, 16)
const FLOOR_CYAN := Vector2i(8, 16)
const FLOOR_YELLOW := Vector2i(9, 16)
const FLOOR_GREEN := Vector2i(10, 16)
const FLOOR_PURPLE := Vector2i(15, 16)
const FLOOR_BLUE := Vector2i(16, 16)

# Normalized cells from the project-owner supplied Central City ground sheet.
# These are intentionally separate from the MCBlocks floor constants above:
# MCBlocks continues to own buildings, roofs, interior thresholds and props.
const GROUND_ROAD_PLAIN := Vector2i(0, 0)
const GROUND_ROAD_LANE := Vector2i(1, 0)
const GROUND_ROAD_EDGE := Vector2i(2, 0)
const GROUND_ROAD_ALT := Vector2i(3, 0)
const GROUND_CROSSWALK_A := Vector2i(4, 0)
const GROUND_CROSSWALK_B := Vector2i(0, 1)
const GROUND_ROAD_ARROW := Vector2i(1, 1)
const GROUND_ROAD_TECH := Vector2i(2, 1)
const GROUND_PAVEMENT := Vector2i(3, 1)
const GROUND_PAVEMENT_TAN := Vector2i(4, 1)
const GROUND_PAVEMENT_STONE := Vector2i(0, 2)
const GROUND_TECH_PAVER := Vector2i(1, 2)
const GROUND_GRASS := Vector2i(2, 2)
const GROUND_GRASS_ALT := Vector2i(3, 2)
const GROUND_SAND := Vector2i(4, 2)
const GROUND_DIRT := Vector2i(0, 3)
const GROUND_WATER := Vector2i(1, 3)

const BLOCK_WALL := Vector2i(3, 13)
const BLOCK_WALL_DARK := Vector2i(2, 13)
const BLOCK_WHITE := Vector2i(11, 13)
const BLOCK_GLASS := Vector2i(11, 3)
const BLOCK_TEAL := Vector2i(14, 13)
const BLOCK_YELLOW := Vector2i(15, 13)
const BLOCK_LIME := Vector2i(16, 13)
const BLOCK_PURPLE := Vector2i(5, 13)
const BLOCK_BLUE := Vector2i(6, 13)
const DOOR_DARK := Vector2i(15, 47)
const WINDOW_CYAN := Vector2i(10, 15)
const WINDOW_WHITE := Vector2i(15, 15)
const WINDOW_GREEN := Vector2i(12, 15)
const WINDOW_YELLOW := Vector2i(11, 15)
const WINDOW_PURPLE := Vector2i(17, 15)
const STREET_LAMP := Vector2i(6, 53)
const BENCH := Vector2i(5, 18)
const CITY_CORE := Vector2i(3, 20)

const ROAD_BASE := Color(0.11, 0.14, 0.16, 1.0)
const PAVEMENT_BASE := Color(0.31, 0.34, 0.36, 1.0)
const PLAZA_BASE := Color(0.11, 0.29, 0.31, 1.0)
const PARK_BASE := Color(0.20, 0.38, 0.22, 1.0)
const WATER_BASE := Color(0.035, 0.20, 0.32, 1.0)

var definition: Dictionary = {}
var section_coord := Vector2i.ZERO

var _player: Node2D = null
var _world_controller: Node = null
var _blocked_cells := PackedByteArray()
var _ground_tiles: Array[Dictionary] = []
var _leaf_particles: Array[CPUParticles2D] = []


func configure(section_definition: Dictionary, player: Node2D, world_controller: Node) -> void:
	definition = section_definition.duplicate(true)
	var raw_coord = definition.get("coord", [0, 0])
	section_coord = Vector2i(int(raw_coord[0]), int(raw_coord[1]))
	_player = player
	_world_controller = world_controller
	_blocked_cells.resize(SECTION_SIZE * SECTION_SIZE)
	_blocked_cells.fill(0)
	position = grid_to_world(Vector2(section_coord.x * SECTION_SIZE, section_coord.y * SECTION_SIZE))
	name = "Section_%d_%d" % [section_coord.x, section_coord.y]
	_build_section()


func is_walkable_world_position(world_position: Vector2) -> bool:
	var local_grid := world_to_grid(world_position - global_position)
	var cell := Vector2i(floori(local_grid.x + 0.5), floori(local_grid.y + 0.5))
	if cell.x < 0 or cell.y < 0 or cell.x >= SECTION_SIZE or cell.y >= SECTION_SIZE:
		return false
	return _blocked_cells[cell.y * SECTION_SIZE + cell.x] == 0


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


func _build_section() -> void:
	_prepare_ground_data()
	_build_street_detail()
	_build_theme_content()


func _prepare_ground_data() -> void:
	_ground_tiles.clear()
	var theme := String(definition.get("theme", "residential"))
	var center := int(SECTION_SIZE / 2)
	for x in range(SECTION_SIZE):
		for y in range(SECTION_SIZE):
			var cell := Vector2i(x, y)
			var presentation := _ground_presentation(cell, theme, center)
			_ground_tiles.append({
				"cell": presentation.get("cell", GROUND_PAVEMENT),
				"position": position + grid_to_world(Vector2(cell)),
				"base_color": presentation.get("base_color", PAVEMENT_BASE),
				"detail_tint": Color.WHITE,
				"detail_alpha": 1.0,
				"ground_tint": presentation.get("ground_tint", Color.WHITE),
			})
			if not bool(presentation.get("walkable", true)):
				_mark_blocked(cell)


func append_ground_tiles(target: Array[Dictionary]) -> void:
	target.append_array(_ground_tiles)


func _ground_presentation(cell: Vector2i, theme: String, center: int) -> Dictionary:
	var global_x := section_coord.x * SECTION_SIZE + cell.x
	var global_y := section_coord.y * SECTION_SIZE + cell.y
	var horizontal_road := (
		section_coord.y == 0
		and cell.y >= center - 1
		and cell.y <= center + 1
	)
	var vertical_road := (
		section_coord.x == 0
		and cell.x >= center - 1
		and cell.x <= center + 1
	)

	# The canal remains a physical water strip from the authored city layout.
	# The central bridge stays open so the north-south avenue is never broken.
	if theme == "canal" and cell.y in [2, 3] and absi(cell.x - center) > 1:
		return {
			"cell": GROUND_WATER,
			"base_color": WATER_BASE,
			"walkable": false,
		}

	# Central Plaza deliberately interrupts the avenue asphalt and reads as one
	# civic surface. Crosswalks frame the four road approaches.
	if theme == "plaza":
		var dx := absi(cell.x - center)
		var dy := absi(cell.y - center)
		if dx <= 3 and dy <= 3:
			var plaza_cell := GROUND_TECH_PAVER if posmod(global_x + global_y, 4) == 0 else GROUND_PAVEMENT_STONE
			return {
				"cell": plaza_cell,
				"base_color": PLAZA_BASE,
				"walkable": true,
			}
		if horizontal_road and cell.x in [2, 3, 11, 12]:
			return {
				"cell": GROUND_CROSSWALK_A if cell.x < center else GROUND_CROSSWALK_B,
				"base_color": ROAD_BASE,
				"walkable": true,
			}
		if vertical_road and cell.y in [2, 3, 11, 12]:
			return {
				"cell": GROUND_CROSSWALK_B if cell.y < center else GROUND_CROSSWALK_A,
				"base_color": ROAD_BASE,
				"walkable": true,
			}

	if horizontal_road and vertical_road:
		return {
			"cell": GROUND_ROAD_TECH,
			"base_color": ROAD_BASE,
			"walkable": true,
		}
	if horizontal_road:
		var horizontal_cell := GROUND_ROAD_LANE if cell.y == center else GROUND_ROAD_PLAIN
		if posmod(global_x, 11) == 0 and cell.y == center:
			horizontal_cell = GROUND_ROAD_ARROW
		return {
			"cell": horizontal_cell,
			"base_color": ROAD_BASE,
			"walkable": true,
		}
	if vertical_road:
		var vertical_cell := GROUND_ROAD_ALT if cell.x == center else GROUND_ROAD_EDGE
		if posmod(global_y, 13) == 0 and cell.x == center:
			vertical_cell = GROUND_ROAD_TECH
		return {
			"cell": vertical_cell,
			"base_color": ROAD_BASE,
			"walkable": true,
		}

	# District surfaces are still deterministic authored choices rather than
	# random terrain. This keeps section borders invisible while giving the
	# supplied sheet enough variety to judge how it works as a city kit.
	var pattern := posmod(global_x * 7 + global_y * 11, 17)
	match theme:
		"garden":
			var planted_plot := (
				(cell.x <= 4 or cell.x >= 10)
				and (cell.y <= 4 or cell.y >= 10)
			)
			if planted_plot:
				return {
					"cell": GROUND_GRASS_ALT if pattern in [0, 5, 10] else GROUND_GRASS,
					"base_color": PARK_BASE,
					"walkable": true,
				}
			return {
				"cell": GROUND_PAVEMENT_STONE if pattern % 4 == 0 else GROUND_PAVEMENT,
				"base_color": PAVEMENT_BASE,
				"walkable": true,
			}
		"digilab":
			return {
				"cell": GROUND_TECH_PAVER if pattern in [0, 1, 8] else GROUND_PAVEMENT,
				"base_color": PAVEMENT_BASE,
				"walkable": true,
			}
		"hospital":
			return {
				"cell": GROUND_PAVEMENT_STONE if pattern % 5 == 0 else GROUND_PAVEMENT,
				"base_color": PAVEMENT_BASE,
				"walkable": true,
			}
		"training":
			return {
				"cell": GROUND_TECH_PAVER if pattern % 4 == 0 else GROUND_PAVEMENT_STONE,
				"base_color": PAVEMENT_BASE,
				"walkable": true,
			}
		"market":
			return {
				"cell": GROUND_PAVEMENT_TAN if pattern < 7 else GROUND_PAVEMENT_STONE,
				"base_color": PAVEMENT_BASE,
				"walkable": true,
			}
		"archive":
			return {
				"cell": GROUND_PAVEMENT_STONE if pattern < 10 else GROUND_TECH_PAVER,
				"base_color": PAVEMENT_BASE,
				"walkable": true,
			}
		"gate":
			return {
				"cell": GROUND_SAND if pattern in [0, 8, 16] else GROUND_PAVEMENT_STONE,
				"base_color": PAVEMENT_BASE,
				"walkable": true,
			}
		"canal":
			return {
				"cell": GROUND_PAVEMENT_STONE if pattern % 3 == 0 else GROUND_PAVEMENT,
				"base_color": PAVEMENT_BASE,
				"walkable": true,
			}
		_:
			return {
				"cell": GROUND_PAVEMENT_STONE if pattern in [0, 9] else GROUND_PAVEMENT,
				"base_color": PAVEMENT_BASE,
				"walkable": true,
			}


func _build_street_detail() -> void:
	var props := Node2D.new()
	props.name = "StreetFurniture"
	add_child(props)
	var theme := String(definition.get("theme", "residential"))

	var tree_cells: Array[Vector2i] = []
	match theme:
		"garden":
			tree_cells = [
				Vector2i(2, 2), Vector2i(11, 2),
				Vector2i(2, 11), Vector2i(11, 11),
			]
		"plaza":
			tree_cells = [Vector2i(2, 11), Vector2i(11, 2)]
		"canal":
			tree_cells = [Vector2i(2, 10), Vector2i(11, 10)]
		"residential":
			tree_cells = [Vector2i(2, 11)]
		_:
			tree_cells = []
	for index in range(tree_cells.size()):
		_add_tree(props, tree_cells[index], index)

	if theme != "garden" and theme != "canal":
		for cell in [Vector2i(11, 5), Vector2i(11, 9)]:
			_add_atlas_prop(props, STREET_LAMP, cell, Vector2(1.65, 1.65))

	if theme in ["plaza", "garden"]:
		for cell in [Vector2i(4, 10), Vector2i(10, 4)]:
			_add_atlas_prop(props, BENCH, cell, Vector2(1.75, 1.75), false)


func _build_theme_content() -> void:
	var theme := String(definition.get("theme", "residential"))
	match theme:
		"plaza":
			_build_plaza()
		"digilab":
			_build_service_exterior(Color(0.28, 0.88, 1.0), "DIGILAB", "digilab")
		"hospital":
			_build_service_exterior(Color(0.66, 0.96, 1.0), "DIGI HOSPITAL", "hospital")
		"training":
			_build_service_exterior(Color(0.56, 0.95, 0.43), "TRAINING CENTER", "training")
		"market":
			_build_service_exterior(Color(1.0, 0.78, 0.28), "DATA MARKET", "shop")
		"archive":
			_build_service_exterior(Color(0.72, 0.52, 1.0), "DIGITAL ARCHIVE", "archive")
		"gate":
			_build_gate()
		"residential":
			_build_residential_block()


func _build_plaza() -> void:
	var props := Node2D.new()
	props.name = "CentralPlaza"
	add_child(props)
	var center := Vector2i(int(SECTION_SIZE / 2), int(SECTION_SIZE / 2))
	var foot := grid_to_world(Vector2(center))
	var core := CITY.create_prop(
		CITY_CORE,
		foot,
		980 + int(round(global_position.y + foot.y)),
		Vector2(2.25, 2.25)
	)
	props.add_child(core)
	_mark_blocked(center)
	_spawn_npc(Vector2i(5, 9), "CITY GUIDE", "guide", "TALK", 20)


func _build_gate() -> void:
	var props := Node2D.new()
	props.name = "CityGate"
	add_child(props)
	for cell in [Vector2i(4, 5), Vector2i(4, 6), Vector2i(9, 5), Vector2i(9, 6)]:
		for level in range(2):
			var block := CITY.create_block(
				BLOCK_WALL_DARK,
				grid_to_world(Vector2(cell)),
				850 + int(round(global_position.y + grid_to_world(Vector2(cell)).y)),
				level
			)
			props.add_child(block)
		_mark_blocked(cell)


func _build_residential_block() -> void:
	# Compact residential masses read as buildings instead of perimeter walls.
	# The two volumes share a small courtyard gap but remain close enough to form
	# a coherent block along the city street.
	_build_exterior_shell(Vector2i(2, 2), Vector2i(5, 4), Color(0.42, 0.72, 0.74), "ResidenceA", "", false, "residential", "south")
	_build_exterior_shell(Vector2i(7, 2), Vector2i(5, 4), Color(0.58, 0.60, 0.78), "ResidenceB", "", false, "residential", "south")


func _build_service_exterior(accent: Color, title: String, service_id: String) -> void:
	var origin := Vector2i(2, 1)
	var size := Vector2i(8, 5)
	var door_side := "south"
	if service_id in ["training", "shop"]:
		origin = Vector2i(1, 2)
		size = Vector2i(5, 8)
		door_side = "east"
	elif service_id == "archive":
		origin = Vector2i(2, 2)
		size = Vector2i(8, 5)

	var interior_id := "%s_%d_%d" % [service_id, section_coord.x, section_coord.y]
	var exterior := _build_exterior_shell(
		origin,
		size,
		accent,
		title.capitalize().replace(" ", ""),
		title,
		true,
		service_id,
		door_side
	)
	var door_cell: Vector2i = exterior.get("door_cell", origin)
	var approach_cell := door_cell + (Vector2i(0, 1) if door_side == "south" else Vector2i(1, 0))

	var entrance := Area2D.new()
	entrance.name = "InteriorThreshold"
	entrance.add_to_group("world_interior_threshold")
	entrance.position = grid_to_world(Vector2(door_cell))
	entrance.collision_layer = 0
	entrance.collision_mask = 1
	entrance.monitoring = true
	entrance.monitorable = false
	add_child(entrance)

	var pad := CITY.create_floor_tile(
		_service_floor_cell(service_id),
		Vector2.ZERO,
		0,
		Color(0.10, 0.15, 0.17, 1.0),
		Color.WHITE,
		0.62
	)
	entrance.add_child(pad)

	var threshold_shape := CollisionShape2D.new()
	var threshold_circle := CircleShape2D.new()
	threshold_circle.radius = 17.0
	threshold_shape.shape = threshold_circle
	threshold_shape.position = Vector2(0.0, -8.0)
	entrance.add_child(threshold_shape)

	var return_world := global_position + grid_to_world(Vector2(approach_cell))
	entrance.set_meta("interior_payload", {
		"interior_id": interior_id,
		"service": service_id,
		"title": title,
		"accent": [accent.r, accent.g, accent.b, accent.a],
		"return_position": [return_world.x, return_world.y],
	})
	entrance.body_entered.connect(_on_interior_threshold_entered.bind(entrance))


func _on_interior_threshold_entered(body: Node2D, entrance: Area2D) -> void:
	if body != _player or _world_controller == null:
		return
	if not _world_controller.has_method("request_interior_entry"):
		return
	var payload = entrance.get_meta("interior_payload", {})
	if payload is Dictionary:
		_world_controller.call_deferred("request_interior_entry", (payload as Dictionary).duplicate(true))


func _build_exterior_shell(
	origin: Vector2i,
	size: Vector2i,
	accent: Color,
	node_name: String,
	title: String,
	with_door: bool,
	service_id: String,
	door_side: String = "east"
) -> Dictionary:
	var building := Node2D.new()
	building.name = node_name
	add_child(building)

	var door_cell := (
		origin + Vector2i(int(size.x / 2), size.y - 1)
		if door_side == "south"
		else origin + Vector2i(size.x - 1, int(size.y / 2))
	)
	var accent_block := _service_block_cell(service_id)
	var wall_levels := 2 if with_door else 1
	for x in range(size.x):
		for y in range(size.y):
			var cell := origin + Vector2i(x, y)
			var doorway := with_door and cell == door_cell
			if not doorway:
				_mark_blocked(cell)

			# In an isometric exterior the roof already defines the complete
			# footprint. Drawing four rings of cube blocks made buildings look
			# like open fortresses. Render only the two camera-facing facades.
			var visible_facade := x == size.x - 1 or y == size.y - 1
			if not visible_facade:
				continue
			if doorway:
				var lintel := CITY.create_block(
					accent_block,
					grid_to_world(Vector2(cell)),
					800 + int(round(global_position.y + grid_to_world(Vector2(cell)).y)),
					wall_levels - 1
				)
				building.add_child(lintel)
				continue

			for level in range(wall_levels):
				var block_cell := BLOCK_WALL
				if with_door and level > 0 and (x + y + level) % 4 == 0:
					block_cell = accent_block
				var block := CITY.create_block(
					block_cell,
					grid_to_world(Vector2(cell)),
					720 + int(round(global_position.y + grid_to_world(Vector2(cell)).y)),
					level
				)
				building.add_child(block)

	if with_door:
		_add_service_windows(building, origin, size, service_id, door_side)
		var door := CITY.create_prop(
			DOOR_DARK,
			grid_to_world(Vector2(door_cell)),
			1500 + int(round(global_position.y + grid_to_world(Vector2(door_cell)).y)),
			Vector2(1.75, 1.75)
		)
		door.modulate = accent.lightened(0.12)
		building.add_child(door)

	# Roofs are static and never need one CanvasItem per tile. Batch the whole
	# footprint into two meshes while retaining the authored atlas detail.
	var roof_tiles: Array[Dictionary] = []
	for x in range(size.x):
		for y in range(size.y):
			var roof_cell := origin + Vector2i(x, y)
			var trim := with_door and (
				(y == size.y - 1 and door_side == "south" and absi(x - int(size.x / 2)) <= 1)
				or (x == size.x - 1 and door_side == "east" and absi(y - int(size.y / 2)) <= 1)
			)
			var roof_cell_asset := _service_floor_cell(service_id) if trim else FLOOR_PLAZA
			var roof_color := (
				Color(0.22, 0.29, 0.32, 1.0)
				if with_door
				else Color(0.25, 0.30, 0.33, 1.0)
			)
			roof_tiles.append({
				"cell": roof_cell_asset,
				"position": grid_to_world(Vector2(roof_cell)) - Vector2(0.0, CITY.BLOCK_LEVEL_HEIGHT * float(wall_levels)),
				"base_color": roof_color,
				"detail_tint": Color(0.92, 0.98, 1.0, 1.0),
				"detail_alpha": 0.60,
			})
	var roof_depth := 1700 + int(round(global_position.y + grid_to_world(Vector2(door_cell)).y))
	building.add_child(CITY.create_floor_batch(roof_tiles, roof_depth, "Roof"))

	if not title.is_empty():
		var sign := Label.new()
		sign.text = title
		sign.position = grid_to_world(Vector2(door_cell)) + Vector2(-96.0, -158.0)
		sign.size = Vector2(192.0, 28.0)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.add_theme_font_size_override("font_size", 12)
		sign.add_theme_color_override("font_color", accent.lightened(0.20))
		sign.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
		sign.add_theme_constant_override("outline_size", 5)
		sign.z_index = 1950 + int(round(global_position.y + sign.position.y))
		building.add_child(sign)

	return {"node": building, "door_cell": door_cell}


func _add_service_windows(
	parent: Node2D,
	origin: Vector2i,
	size: Vector2i,
	service_id: String,
	door_side: String
) -> void:
	var pane_cell := _service_window_cell(service_id)
	var facade_cells: Array[Vector2i] = []
	var door_cell := Vector2i.ZERO
	if door_side == "south":
		var door_x := int(size.x / 2)
		door_cell = origin + Vector2i(door_x, size.y - 1)
		for local_x in range(1, size.x - 1):
			if local_x != door_x:
				facade_cells.append(origin + Vector2i(local_x, size.y - 1))
	else:
		var door_y := int(size.y / 2)
		door_cell = origin + Vector2i(size.x - 1, door_y)
		for local_y in range(1, size.y - 1):
			if local_y != door_y:
				facade_cells.append(origin + Vector2i(size.x - 1, local_y))

	for cell: Vector2i in facade_cells:
		var foot := grid_to_world(Vector2(cell))
		var pane := CITY.create_prop(
			pane_cell,
			foot,
			1480 + int(round(global_position.y + foot.y)),
			Vector2(1.48, 1.48),
			Color.WHITE,
			Vector2(0.0, -38.0)
		)
		parent.add_child(pane)

	# A short accent canopy marks the doorway as an actual public entrance.
	var canopy_offsets: Array[Vector2i] = [Vector2i.ZERO]
	canopy_offsets.append(Vector2i(1, 0) if door_side == "south" else Vector2i(0, 1))
	for canopy_offset: Vector2i in canopy_offsets:
		var canopy_cell: Vector2i = door_cell + canopy_offset
		var canopy := CITY.create_floor_tile(
			_service_floor_cell(service_id),
			grid_to_world(Vector2(canopy_cell)) - Vector2(0.0, 82.0),
			1650 + int(round(global_position.y + grid_to_world(Vector2(canopy_cell)).y)),
			Color(0.16, 0.18, 0.20, 1.0),
			Color.WHITE,
			0.86
		)
		parent.add_child(canopy)


func _service_window_cell(service_id: String) -> Vector2i:
	match service_id:
		"digilab":
			return WINDOW_CYAN
		"hospital":
			return WINDOW_WHITE
		"training":
			return WINDOW_GREEN
		"shop":
			return WINDOW_YELLOW
		"archive":
			return WINDOW_PURPLE
		_:
			return WINDOW_CYAN


func _is_window_cell(x: int, y: int, size: Vector2i) -> bool:
	if y == 0 and x in [1, size.x - 2]:
		return true
	if x == 0 and y in [1, size.y - 2]:
		return true
	return false


func _service_block_cell(service_id: String) -> Vector2i:
	match service_id:
		"digilab":
			return BLOCK_TEAL
		"hospital":
			return BLOCK_WHITE
		"training":
			return BLOCK_LIME
		"shop":
			return BLOCK_YELLOW
		"archive":
			return BLOCK_PURPLE
		_:
			return BLOCK_BLUE


func _service_floor_cell(service_id: String) -> Vector2i:
	match service_id:
		"digilab", "hospital":
			return FLOOR_CYAN
		"training":
			return FLOOR_GREEN
		"shop":
			return FLOOR_YELLOW
		"archive":
			return FLOOR_PURPLE
		_:
			return FLOOR_PLAZA


func _spawn_npc(cell: Vector2i, title: String, action_id: String, prompt_text: String, interaction_priority: int) -> void:
	var actor := ActorScript.new() as HubActor
	actor.name = title.capitalize().replace(" ", "")
	actor.configure(NPC_TEXTURE, false, _world_controller, "southwest")
	actor.position = grid_to_world(Vector2(cell))
	add_child(actor)
	var label := Label.new()
	label.text = title
	label.position = Vector2(-78.0, -84.0)
	label.size = Vector2(156.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.74, 0.96, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	actor.add_child(label)
	var interactable := InteractableScript.new() as WorldInteractable
	interactable.configure(action_id, prompt_text, {"speaker": title}, 82.0, interaction_priority)
	actor.add_child(interactable)
	_mark_blocked(cell)


func _add_tree(parent: Node2D, cell: Vector2i, index: int) -> void:
	var foot := grid_to_world(Vector2(cell))
	var texture := AtlasTexture.new()
	texture.atlas = OAK_TREE_SOURCE
	texture.region = LARGE_OAK_REGION
	var tree := Sprite2D.new()
	tree.name = "Oak_%d_%d" % [cell.x, cell.y]
	tree.texture = texture
	tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var center_to_foot := LARGE_OAK_FOOT - texture.get_size() * 0.5
	tree.position = foot + Vector2(0.0, 10.0) - center_to_foot
	tree.z_index = 1000 + int(round(global_position.y + foot.y))
	parent.add_child(tree)
	TreeAmbientFXScript.apply(
		tree,
		float(index) * 1.37 + float(section_coord.x * 3 + section_coord.y),
		2.8,
		4,
		Color(0.62, 0.91, 0.39, 0.72)
	)
	var leaves := tree.get_node_or_null("AmbientLeaves") as CPUParticles2D
	if leaves != null:
		_leaf_particles.append(leaves)
	_mark_blocked(cell)


func _add_atlas_prop(
	parent: Node2D,
	atlas_cell: Vector2i,
	cell: Vector2i,
	scale: Vector2,
	blocking: bool = true
) -> void:
	var foot := grid_to_world(Vector2(cell))
	var prop := CITY.create_prop(
		atlas_cell,
		foot,
		1000 + int(round(global_position.y + foot.y)),
		scale
	)
	parent.add_child(prop)
	if blocking:
		_mark_blocked(cell)


func set_ambient_vfx_active(active: bool) -> void:
	for leaves: CPUParticles2D in _leaf_particles:
		if leaves == null or not is_instance_valid(leaves):
			continue
		leaves.visible = active
		leaves.emitting = active


func _mark_blocked(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= SECTION_SIZE or cell.y >= SECTION_SIZE:
		return
	_blocked_cells[cell.y * SECTION_SIZE + cell.x] = 1
