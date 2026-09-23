extends Node2D
class_name WorldChunk

const ART = preload("res://src/world/DevilsWorkshopArt.gd")
const TreeAmbientFXScript = preload("res://src/vfx/TreeAmbientFX.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const OAK_TREE_SOURCE = preload("res://assets/terrain/Oak_Tree.png")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

const CHUNK_SIZE := 14
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const LARGE_OAK_REGION := Rect2(11.0, 9.0, 41.0, 63.0)
const LARGE_OAK_FOOT := Vector2(20.5, 62.0)

const CITY_STONE := Color(0.39, 0.42, 0.43, 1.0)
const CITY_STONE_ALT := Color(0.35, 0.38, 0.40, 1.0)
const ROAD_BASE := Color(0.25, 0.31, 0.34, 1.0)
const ROAD_DETAIL := Color(0.90, 0.94, 0.95, 1.0)
const PLAZA_BASE := Color(0.12, 0.29, 0.34, 1.0)
const PLAZA_DETAIL := Color(0.62, 0.93, 1.0, 1.0)
const GARDEN_BASE := Color(0.27, 0.45, 0.29, 1.0)
const GARDEN_ALT := Color(0.23, 0.40, 0.27, 1.0)
const GARDEN_DETAIL := Color(0.90, 1.0, 0.86, 1.0)
const WATER_BASE := Color(0.045, 0.25, 0.34, 1.0)
const WATER_DETAIL := Color(0.62, 0.91, 1.0, 1.0)

var definition: Dictionary = {}
var chunk_coord := Vector2i.ZERO

var _player: Node2D = null
var _world_controller: Node = null
var _physics_root: StaticBody2D = null
var _blocked_cells: Dictionary = {}
var _trees: Array[Sprite2D] = []
var _elapsed := 0.0


func configure(chunk_definition: Dictionary, player: Node2D, world_controller: Node) -> void:
	definition = chunk_definition.duplicate(true)
	var raw_coord = definition.get("coord", [0, 0])
	chunk_coord = Vector2i(int(raw_coord[0]), int(raw_coord[1]))
	_player = player
	_world_controller = world_controller
	position = grid_to_world(Vector2(chunk_coord.x * CHUNK_SIZE, chunk_coord.y * CHUNK_SIZE))
	name = "Chunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	_build_chunk()


func _process(delta: float) -> void:
	_elapsed += delta
	for tree: Sprite2D in _trees:
		TreeAmbientFXScript.animate(tree, _elapsed)


func is_walkable_world_position(world_position: Vector2) -> bool:
	var local_grid := world_to_grid(world_position - global_position)
	var cell := Vector2i(floori(local_grid.x + 0.5), floori(local_grid.y + 0.5))
	if cell.x < 0 or cell.y < 0 or cell.x >= CHUNK_SIZE or cell.y >= CHUNK_SIZE:
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


func _build_chunk() -> void:
	_physics_root = StaticBody2D.new()
	_physics_root.name = "StaticCollision"
	add_child(_physics_root)
	_build_ground()
	_build_street_detail()
	_build_theme_content()


func _build_ground() -> void:
	var ground := Node2D.new()
	ground.name = "Ground"
	add_child(ground)
	var theme := String(definition.get("theme", "residential"))
	var center := int(CHUNK_SIZE / 2)
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var cell := Vector2i(x, y)
			var presentation := _ground_presentation(cell, theme, center)
			var foot := grid_to_world(Vector2(cell))
			var tile := ART.create_surface_tile(
				presentation.get("texture") as Texture2D,
				foot,
				-1200 + int(round(global_position.y + foot.y)),
				presentation.get("base_color", CITY_STONE) as Color,
				presentation.get("detail_tint", Color.WHITE) as Color,
				float(presentation.get("detail_alpha", 0.30))
			)
			ground.add_child(tile)
			if not bool(presentation.get("walkable", true)):
				_mark_blocked(cell)
				_add_diamond_collision(cell)


func _ground_presentation(cell: Vector2i, theme: String, center: int) -> Dictionary:
	var road := absi(cell.x - center) <= 1 or absi(cell.y - center) <= 1
	if theme == "canal" and cell.y in [2, 3] and absi(cell.x - center) > 1:
		return {
			"texture": ART.WATER_BLOCK,
			"base_color": WATER_BASE,
			"detail_tint": WATER_DETAIL,
			"detail_alpha": 0.62,
			"walkable": false,
		}
	if theme == "plaza" and absi(cell.x - center) <= 3 and absi(cell.y - center) <= 3:
		return {
			"texture": ART.DATA_BLOCK,
			"base_color": PLAZA_BASE,
			"detail_tint": PLAZA_DETAIL,
			"detail_alpha": 0.44,
			"walkable": true,
		}
	if road:
		return {
			"texture": ART.WARM_BLOCK,
			"base_color": ROAD_BASE,
			"detail_tint": ROAD_DETAIL,
			"detail_alpha": 0.31,
			"walkable": true,
		}
	var world_x := cell.x + chunk_coord.x * CHUNK_SIZE
	var world_y := cell.y + chunk_coord.y * CHUNK_SIZE
	var alternate := posmod(world_x * 7 + world_y * 11, 9) < 3
	if theme == "garden":
		return {
			"texture": ART.GRASS_BLOCK,
			"base_color": GARDEN_ALT if alternate else GARDEN_BASE,
			"detail_tint": GARDEN_DETAIL,
			"detail_alpha": 0.40,
			"walkable": true,
		}
	var stone := CITY_STONE_ALT if alternate else CITY_STONE
	if theme in ["digilab", "hospital", "training", "market", "archive"]:
		stone = stone.darkened(0.05)
	return {
		"texture": ART.WARM_BLOCK,
		"base_color": stone,
		"detail_tint": Color(0.94, 0.96, 0.96, 1.0),
		"detail_alpha": 0.27,
		"walkable": true,
	}


func _build_street_detail() -> void:
	var props := Node2D.new()
	props.name = "StreetDetail"
	add_child(props)
	var theme := String(definition.get("theme", "residential"))
	var tree_cells: Array[Vector2i] = []
	match theme:
		"garden":
			tree_cells = [
				Vector2i(2, 2), Vector2i(4, 3), Vector2i(10, 3),
				Vector2i(2, 10), Vector2i(10, 10),
			]
		"plaza":
			tree_cells = [Vector2i(2, 11), Vector2i(11, 2)]
		"residential":
			tree_cells = [Vector2i(2, 11)]
		"canal":
			tree_cells = [Vector2i(2, 10), Vector2i(11, 10)]
		_:
			tree_cells = []
	for index in range(tree_cells.size()):
		_add_tree(props, tree_cells[index], index)

	if theme in ["digilab", "hospital", "training", "market", "archive", "residential"]:
		for cell in [Vector2i(11, 4), Vector2i(11, 9)]:
			var bollard := ART.create_full_block(
				ART.DATA_BLOCK,
				grid_to_world(Vector2(cell)),
				880 + int(round(global_position.y + grid_to_world(Vector2(cell)).y)),
				Color(0.46, 0.72, 0.78, 1.0),
				0
			)
			bollard.scale *= Vector2(0.48, 0.48)
			props.add_child(bollard)


func _build_theme_content() -> void:
	var theme := String(definition.get("theme", "residential"))
	match theme:
		"plaza":
			_build_plaza()
		"digilab":
			_build_service_exterior(Vector2i(1, 1), Vector2i(5, 5), Color(0.36, 0.88, 1.0), "DIGILAB", "digilab")
		"hospital":
			_build_service_exterior(Vector2i(1, 1), Vector2i(5, 5), Color(0.42, 1.0, 0.86), "DIGI HOSPITAL", "hospital")
		"training":
			_build_service_exterior(Vector2i(1, 1), Vector2i(5, 5), Color(0.50, 0.96, 0.55), "TRAINING CENTER", "training")
		"market":
			_build_service_exterior(Vector2i(1, 1), Vector2i(5, 5), Color(1.0, 0.78, 0.34), "DATA MARKET", "shop")
		"archive":
			_build_service_exterior(Vector2i(1, 1), Vector2i(5, 5), Color(0.65, 0.58, 1.0), "DIGITAL ARCHIVE", "archive")
		"gate":
			_build_gate()
		"residential":
			_build_residential_block()


func _build_plaza() -> void:
	var props := Node2D.new()
	props.name = "CentralPlaza"
	add_child(props)
	var center := Vector2i(int(CHUNK_SIZE / 2), int(CHUNK_SIZE / 2))
	for level in range(3):
		var block := ART.create_full_block(
			ART.DATA_BLOCK,
			grid_to_world(Vector2(center)),
			900 + int(round(global_position.y + grid_to_world(Vector2(center)).y)),
			Color(0.68, 0.94, 1.0, 1.0),
			level
		)
		props.add_child(block)
	_mark_blocked(center)
	_add_block_collision(center, 22.0)
	_spawn_npc(Vector2i(5, 9), "CITY GUIDE", "guide", "TALK", 20)


func _build_gate() -> void:
	var props := Node2D.new()
	props.name = "CityGate"
	add_child(props)
	for cell in [Vector2i(4, 5), Vector2i(4, 6), Vector2i(9, 5), Vector2i(9, 6)]:
		for level in range(2):
			var block := ART.create_full_block(
				ART.WARM_BLOCK,
				grid_to_world(Vector2(cell)),
				850 + int(round(global_position.y + grid_to_world(Vector2(cell)).y)),
				Color(0.72, 0.78, 0.80, 1.0),
				level
			)
			props.add_child(block)
		_mark_blocked(cell)
		_add_block_collision(cell, 24.0)


func _build_residential_block() -> void:
	_build_exterior_shell(Vector2i(1, 1), Vector2i(4, 4), Color(0.52, 0.69, 0.72), "ResidenceA", "", false)
	_build_exterior_shell(Vector2i(9, 8), Vector2i(4, 4), Color(0.62, 0.62, 0.78), "ResidenceB", "", false)


func _build_service_exterior(origin: Vector2i, size: Vector2i, accent: Color, title: String, service_id: String) -> void:
	var interior_id := "%s_%d_%d" % [service_id, chunk_coord.x, chunk_coord.y]
	var exterior := _build_exterior_shell(origin, size, accent, title.capitalize().replace(" ", ""), title, true)
	var door_cell: Vector2i = exterior.get("door_cell", origin + Vector2i(size.x - 1, int(size.y / 2)))
	var approach_cell := door_cell + Vector2i(1, 0)
	var entrance := Node2D.new()
	entrance.name = "InteriorEntrance"
	entrance.position = grid_to_world(Vector2(approach_cell))
	entrance.z_index = 1250 + int(round(global_position.y + entrance.position.y))
	add_child(entrance)

	var pad := Polygon2D.new()
	pad.name = "EntrancePad"
	pad.polygon = ART.tile_diamond(Vector2(-9.0, -4.0))
	pad.color = Color(accent.r, accent.g, accent.b, 0.22)
	entrance.add_child(pad)

	var return_world := global_position + grid_to_world(Vector2(approach_cell))
	var interactable := InteractableScript.new() as WorldInteractable
	interactable.configure(
		"enter_interior",
		"ENTER %s" % title,
		{
			"interior_id": interior_id,
			"service": service_id,
			"title": title,
			"accent": [accent.r, accent.g, accent.b, accent.a],
			"return_position": [return_world.x, return_world.y],
		},
		76.0,
		60
	)
	entrance.add_child(interactable)


func _build_exterior_shell(
	origin: Vector2i,
	size: Vector2i,
	accent: Color,
	node_name: String,
	title: String,
	with_door: bool
) -> Dictionary:
	var building := Node2D.new()
	building.name = node_name
	add_child(building)
	var door_cell := origin + Vector2i(size.x - 1, int(size.y / 2))

	# Two authored block levels create a real facade. The roof is built from the
	# same isometric tile kit instead of a flat polygon floating over the scene.
	for x in range(size.x):
		for y in range(size.y):
			var boundary := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			var cell := origin + Vector2i(x, y)
			if boundary:
				var doorway := with_door and cell == door_cell
				if not doorway:
					for level in range(2):
						var texture := ART.DATA_BLOCK if level == 1 and (x + y) % 2 == 0 else ART.WARM_BLOCK
						var tint := accent.darkened(0.16) if level == 1 else Color(0.58, 0.62, 0.64, 1.0)
						var block := ART.create_full_block(
							texture,
							grid_to_world(Vector2(cell)),
							720 + int(round(global_position.y + grid_to_world(Vector2(cell)).y)),
							tint,
							level
						)
						building.add_child(block)
					_mark_blocked(cell)
					_add_block_collision(cell, 22.0)
				elif with_door:
					# A raised lintel makes the entrance visibly architectural.
					var lintel := ART.create_full_block(
						ART.DATA_BLOCK,
						grid_to_world(Vector2(cell)),
						760 + int(round(global_position.y + grid_to_world(Vector2(cell)).y)),
						accent,
						1
					)
					building.add_child(lintel)
			elif with_door:
				# Exterior shells are visual buildings; their playable interior is
				# a dedicated scene reached through the entrance transition.
				_mark_blocked(cell)

	for x in range(size.x):
		for y in range(size.y):
			var roof_cell := origin + Vector2i(x, y)
			var roof := ART.create_surface_tile(
				ART.DATA_BLOCK,
				grid_to_world(Vector2(roof_cell)) - Vector2(0.0, ART.BLOCK_LEVEL_HEIGHT * 2.0),
				1580 + int(round(global_position.y + grid_to_world(Vector2(roof_cell)).y)),
				accent.darkened(0.28),
				accent.lightened(0.10),
				0.42
			)
			roof.name = "Roof_%d_%d" % [x, y]
			building.add_child(roof)

	if not title.is_empty():
		var sign := Label.new()
		sign.text = title
		sign.position = grid_to_world(Vector2(door_cell)) + Vector2(-94.0, -114.0)
		sign.size = Vector2(188.0, 26.0)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.add_theme_font_size_override("font_size", 12)
		sign.add_theme_color_override("font_color", accent.lightened(0.22))
		sign.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
		sign.add_theme_constant_override("outline_size", 5)
		sign.z_index = 1900 + int(round(global_position.y + sign.position.y))
		building.add_child(sign)

	return {"node": building, "door_cell": door_cell}


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
		float(index) * 1.37 + float(chunk_coord.x * 3 + chunk_coord.y),
		2.8,
		7,
		Color(0.62, 0.91, 0.39, 0.72)
	)
	_trees.append(tree)
	_mark_blocked(cell)
	_add_circle_collision(foot, 23.0)


func _add_diamond_collision(cell: Vector2i) -> void:
	var polygon := CollisionPolygon2D.new()
	polygon.position = grid_to_world(Vector2(cell))
	polygon.polygon = PackedVector2Array([
		Vector2(-28.0, 0.0),
		Vector2(0.0, -13.0),
		Vector2(28.0, 0.0),
		Vector2(0.0, 13.0),
	])
	_physics_root.add_child(polygon)


func _add_block_collision(cell: Vector2i, radius: float) -> void:
	_add_circle_collision(grid_to_world(Vector2(cell)), radius)


func _add_circle_collision(local_position: Vector2, radius: float) -> void:
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	shape_node.shape = shape
	shape_node.position = local_position + Vector2(0.0, -10.0)
	_physics_root.add_child(shape_node)


func _mark_blocked(cell: Vector2i) -> void:
	_blocked_cells[_cell_key(cell)] = true


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
