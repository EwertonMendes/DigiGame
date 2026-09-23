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
const CITY_WALL_LEVELS := 3
const CITY_WALL_LEVEL_HEIGHT := 32.0
const CITY_WALL_HEIGHT := CITY_WALL_LEVEL_HEIGHT * CITY_WALL_LEVELS
const CITY_DOOR_HEIGHT := 64.0
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

# Match the approved Test Hub surface treatment: an opaque calm base plus a
# low-opacity authored top-face texture. This preserves material detail without
# turning every 64x32 gameplay diamond into a high-contrast outlined tile.
const ROAD_BASE := Color(0.18, 0.21, 0.22, 1.0)
const PAVEMENT_BASE := Color(0.31, 0.34, 0.35, 1.0)
const PLAZA_BASE := Color(0.17, 0.34, 0.39, 1.0)
const PARK_BASE := Color(0.30, 0.52, 0.29, 1.0)
const WATER_BASE := Color(0.055, 0.29, 0.37, 1.0)

const CYAN_ACCENT_BASE := Color(0.18, 0.34, 0.43, 1.0)
const YELLOW_ACCENT_BASE := Color(0.38, 0.33, 0.22, 1.0)
const GREEN_ACCENT_BASE := Color(0.26, 0.46, 0.28, 1.0)
const PURPLE_ACCENT_BASE := Color(0.30, 0.27, 0.38, 1.0)

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
				"cell": presentation.get("cell", FLOOR_PAVEMENT),
				"position": position + grid_to_world(Vector2(cell)),
				"base_color": presentation.get("base_color", PAVEMENT_BASE),
				"detail_tint": presentation.get("detail_tint", Color.WHITE),
				"detail_alpha": float(presentation.get("detail_alpha", 0.42)),
				"surface": String(presentation.get("surface", "warm")),
			})
			if not bool(presentation.get("walkable", true)):
				_mark_blocked(cell)


func append_ground_tiles(target: Array[Dictionary]) -> void:
	target.append_array(_ground_tiles)


func _ground_presentation(cell: Vector2i, theme: String, center: int) -> Dictionary:
	# Central City now uses the exact same top-face source family and blending
	# strategy as Terminal Commons (the Test Hub). The surface texture stays
	# subtle over an opaque base, so seams exist only as gentle material changes.
	var road := (
		(section_coord.y == 0 and cell.y >= center - 1 and cell.y <= center + 1)
		or (section_coord.x == 0 and cell.x >= center - 1 and cell.x <= center + 1)
	)
	if road:
		return {
			"cell": FLOOR_ROAD,
			"surface": "warm",
			"base_color": ROAD_BASE,
			"detail_tint": Color(0.82, 0.87, 0.84, 1.0),
			"detail_alpha": 0.26,
			"walkable": true,
		}

	if theme == "canal" and cell.y in [2, 3] and absi(cell.x - center) > 1:
		return {
			"cell": FLOOR_BLUE,
			"surface": "water",
			"base_color": WATER_BASE,
			"detail_tint": Color(0.72, 0.94, 1.0, 1.0),
			"detail_alpha": 0.62,
			"walkable": false,
		}

	if theme == "plaza" and absi(cell.x - center) <= 3 and absi(cell.y - center) <= 3:
		return {
			"cell": FLOOR_PLAZA,
			"surface": "water",
			"base_color": PLAZA_BASE,
			"detail_tint": Color(0.78, 0.94, 1.0, 1.0),
			"detail_alpha": 0.46,
			"walkable": true,
		}

	if theme == "garden":
		var corner_plot := (
			(cell.x <= 4 or cell.x >= 10)
			and (cell.y <= 4 or cell.y >= 10)
		)
		if corner_plot:
			return {
				"cell": FLOOR_GREEN,
				"surface": "grass",
				"base_color": PARK_BASE,
				"detail_tint": Color(0.92, 1.0, 0.88, 1.0),
				"detail_alpha": 0.38,
				"walkable": true,
			}

	var service_accent := _service_ground_accent(theme)
	if not service_accent.is_empty() and _is_service_forecourt(cell, theme):
		return {
			"cell": service_accent.get("cell", FLOOR_PAVEMENT),
			"surface": String(service_accent.get("surface", "data")),
			"base_color": service_accent.get("base_color", PAVEMENT_BASE),
			"detail_tint": service_accent.get("detail_tint", Color.WHITE),
			"detail_alpha": float(service_accent.get("detail_alpha", 0.30)),
			"walkable": true,
		}

	return {
		"cell": FLOOR_PAVEMENT,
		"surface": "warm",
		"base_color": PAVEMENT_BASE,
		"detail_tint": Color(0.86, 0.90, 0.82, 1.0),
		"detail_alpha": 0.24,
		"walkable": true,
	}


func _service_ground_accent(theme: String) -> Dictionary:
	match theme:
		"digilab", "hospital":
			return {
				"cell": FLOOR_CYAN,
				"surface": "data",
				"base_color": CYAN_ACCENT_BASE,
				"detail_tint": Color(0.74, 0.82, 1.0, 1.0),
				"detail_alpha": 0.32,
			}
		"training":
			return {
				"cell": FLOOR_GREEN,
				"surface": "grass",
				"base_color": GREEN_ACCENT_BASE,
				"detail_tint": Color(0.90, 1.0, 0.86, 1.0),
				"detail_alpha": 0.34,
			}
		"market":
			return {
				"cell": FLOOR_YELLOW,
				"surface": "warm",
				"base_color": YELLOW_ACCENT_BASE,
				"detail_tint": Color(1.0, 0.93, 0.72, 1.0),
				"detail_alpha": 0.28,
			}
		"archive":
			return {
				"cell": FLOOR_PURPLE,
				"surface": "data",
				"base_color": PURPLE_ACCENT_BASE,
				"detail_tint": Color(0.92, 0.82, 1.0, 1.0),
				"detail_alpha": 0.28,
			}
		_:
			return {}


func _is_service_forecourt(cell: Vector2i, theme: String) -> bool:
	# Accent paving is a narrow sidewalk/entry zone beside the road. It never
	# paints over the three-cell-wide road itself.
	match theme:
		"digilab", "hospital":
			return cell.y == 5 and cell.x >= 3 and cell.x <= 9
		"training", "market":
			return cell.x == 5 and cell.y >= 3 and cell.y <= 9
		"archive":
			return cell.y == 6 and cell.x >= 3 and cell.x <= 9
		_:
			return false


func _build_street_detail() -> void:
	# Keep this pass intentionally clean: only trees remain as environmental
	# decoration. Lamps, benches, fires and other small props can return after the
	# ground/building language is stable.
	var trees := Node2D.new()
	trees.name = "Trees"
	add_child(trees)
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
		_add_tree(trees, tree_cells[index], index)


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
	# The plaza stays structurally clean for this pass. The guide is gameplay
	# content, while the previous decorative core prop is intentionally removed.
	_spawn_npc(Vector2i(5, 9), "CITY GUIDE", "guide", "TALK", 20)


func _build_gate() -> void:
	# Gate structures follow the same continuous vector-wall language as the
	# establishments. MC Blocks are intentionally not used for exterior walls.
	var props := Node2D.new()
	props.name = "CityGate"
	add_child(props)
	for origin in [Vector2i(4, 5), Vector2i(9, 5)]:
		var size := Vector2i(1, 2)
		for x in range(size.x):
			for y in range(size.y):
				_mark_blocked(origin + Vector2i(x, y))
		_build_continuous_facade(
			props,
			origin,
			size,
			"east",
			false,
			Vector2i.ZERO,
			Color(0.20, 0.25, 0.28, 1.0),
			Color(0.38, 0.82, 1.0, 1.0),
			"GateEast"
		)
		_build_continuous_facade(
			props,
			origin,
			size,
			"south",
			false,
			Vector2i.ZERO,
			Color(0.24, 0.29, 0.31, 1.0),
			Color(0.38, 0.82, 1.0, 1.0),
			"GateSouth"
		)


func _build_residential_block() -> void:
	# Compact residential masses read as buildings instead of perimeter walls.
	# The two volumes share a small courtyard gap but remain close enough to form
	# a coherent block along the city street.
	_build_exterior_shell(Vector2i(2, 2), Vector2i(5, 4), Color(0.42, 0.72, 0.74), "ResidenceA", "", false, "residential", "south")
	_build_exterior_shell(Vector2i(7, 2), Vector2i(5, 4), Color(0.58, 0.60, 0.78), "ResidenceB", "", false, "residential", "south")


func _build_service_exterior(accent: Color, title: String, service_id: String) -> void:
	# Establishments sit beside the avenue with one clear pedestrian tile
	# between the doorway and the three-cell road. No facade is allowed to claim
	# a road cell.
	var origin := Vector2i(2, 0)
	var size := Vector2i(8, 5)
	var door_side := "south"
	if service_id in ["training", "shop"]:
		origin = Vector2i(0, 2)
		size = Vector2i(5, 8)
		door_side = "east"
	elif service_id == "archive":
		origin = Vector2i(2, 1)
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
	building.add_to_group("central_city_building")
	building.set_meta("grid_origin", origin)
	building.set_meta("grid_size", size)
	building.set_meta("wall_levels", CITY_WALL_LEVELS)
	building.set_meta("service_id", service_id)
	building.set_meta("wall_renderer", "continuous")
	add_child(building)

	var door_cell := (
		origin + Vector2i(int(size.x / 2), size.y - 1)
		if door_side == "south"
		else origin + Vector2i(size.x - 1, int(size.y / 2))
	)

	# Collision still follows the authored footprint, but the visual facade is
	# now one continuous surface per side instead of one sprite per grid cell.
	for x in range(size.x):
		for y in range(size.y):
			var cell := origin + Vector2i(x, y)
			if not (with_door and cell == door_cell):
				_mark_blocked(cell)

	var palette := _wall_palette(service_id, accent, with_door)
	_build_continuous_facade(
		building,
		origin,
		size,
		"south",
		with_door and door_side == "south",
		door_cell,
		palette.get("south", Color(0.34, 0.38, 0.40, 1.0)),
		accent,
		"SouthFacade"
	)
	_build_continuous_facade(
		building,
		origin,
		size,
		"east",
		with_door and door_side == "east",
		door_cell,
		palette.get("east", Color(0.28, 0.32, 0.34, 1.0)),
		accent,
		"EastFacade"
	)

	# No roof layer. The wall height itself provides the architectural mass.
	if not title.is_empty():
		var sign := Label.new()
		sign.text = title
		sign.position = grid_to_world(Vector2(door_cell)) + Vector2(-96.0, -178.0)
		sign.size = Vector2(192.0, 28.0)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.add_theme_font_size_override("font_size", 12)
		sign.add_theme_color_override("font_color", accent.lightened(0.20))
		sign.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
		sign.add_theme_constant_override("outline_size", 5)
		sign.z_index = 1950 + int(round(global_position.y + sign.position.y))
		building.add_child(sign)

	return {"node": building, "door_cell": door_cell}


func _build_continuous_facade(
	parent: Node2D,
	origin: Vector2i,
	size: Vector2i,
	side: String,
	has_door: bool,
	door_cell: Vector2i,
	face_color: Color,
	accent: Color,
	node_name: String
) -> void:
	var edge_start := Vector2.ZERO
	var edge_end := Vector2.ZERO
	var door_start := Vector2.ZERO
	var door_end := Vector2.ZERO

	if side == "south":
		var first_center := grid_to_world(Vector2(origin + Vector2i(0, size.y - 1)))
		var last_center := grid_to_world(Vector2(origin + Vector2i(size.x - 1, size.y - 1)))
		edge_start = first_center + Vector2(-TILE_HALF_WIDTH, 0.0)
		edge_end = last_center + Vector2(0.0, TILE_HALF_HEIGHT)
		if has_door:
			var door_center := grid_to_world(Vector2(door_cell))
			door_start = door_center + Vector2(-TILE_HALF_WIDTH, 0.0)
			door_end = door_center + Vector2(0.0, TILE_HALF_HEIGHT)
	else:
		var first_center := grid_to_world(Vector2(origin + Vector2i(size.x - 1, 0)))
		var last_center := grid_to_world(Vector2(origin + Vector2i(size.x - 1, size.y - 1)))
		edge_start = first_center + Vector2(TILE_HALF_WIDTH, 0.0)
		edge_end = last_center + Vector2(0.0, TILE_HALF_HEIGHT)
		if has_door:
			var door_center := grid_to_world(Vector2(door_cell))
			door_start = door_center + Vector2(TILE_HALF_WIDTH, 0.0)
			door_end = door_center + Vector2(0.0, TILE_HALF_HEIGHT)

	var depth := 760 + int(round(global_position.y + maxf(edge_start.y, edge_end.y)))
	if not has_door:
		parent.add_child(CITY.create_city_wall_segment(
			edge_start,
			edge_end,
			CITY_WALL_HEIGHT,
			face_color,
			accent,
			depth,
			node_name
		))
		return

	if edge_start.distance_to(door_start) > 0.5:
		parent.add_child(CITY.create_city_wall_segment(
			edge_start,
			door_start,
			CITY_WALL_HEIGHT,
			face_color,
			accent,
			depth,
			"%sLeft" % node_name
		))
	if door_end.distance_to(edge_end) > 0.5:
		parent.add_child(CITY.create_city_wall_segment(
			door_end,
			edge_end,
			CITY_WALL_HEIGHT,
			face_color,
			accent,
			depth + 1,
			"%sRight" % node_name
		))

	# The lintel is the same continuous wall material above the opening. Accent
	# bands are suppressed here so the long facade stripe remains visually clean.
	parent.add_child(CITY.create_city_wall_segment(
		door_start - Vector2(0.0, CITY_DOOR_HEIGHT),
		door_end - Vector2(0.0, CITY_DOOR_HEIGHT),
		CITY_WALL_HEIGHT - CITY_DOOR_HEIGHT,
		face_color,
		accent,
		depth + 2,
		"%sLintel" % node_name,
		false,
		true
	))
	parent.add_child(CITY.create_city_door_panel(
		door_start,
		door_end,
		CITY_DOOR_HEIGHT,
		accent,
		depth + 3,
		"%sDoor" % node_name
	))


func _wall_palette(service_id: String, accent: Color, with_door: bool) -> Dictionary:
	var base := Color(0.31, 0.35, 0.37, 1.0)
	match service_id:
		"hospital":
			base = Color(0.62, 0.66, 0.67, 1.0)
		"digilab":
			base = Color(0.25, 0.33, 0.36, 1.0)
		"training":
			base = Color(0.29, 0.35, 0.30, 1.0)
		"shop":
			base = Color(0.36, 0.32, 0.24, 1.0)
		"archive":
			base = Color(0.31, 0.28, 0.36, 1.0)
		"residential":
			base = accent.darkened(0.42)
		_:
			if with_door:
				base = accent.darkened(0.55)

	return {
		"south": base.lightened(0.055),
		"east": base.darkened(0.075),
	}


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
