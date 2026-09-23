extends Node2D
class_name WorldChunk

const ART = preload("res://src/world/DevilsWorkshopArt.gd")
const TreeAmbientFXScript = preload("res://src/vfx/TreeAmbientFX.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const OAK_TREE_SOURCE = preload("res://assets/terrain/Oak_Tree.png")
const ROCK_TEXTURE = preload("res://assets/world/hawkbirdtree/rock.png")
const CRATE_TEXTURE = preload("res://assets/world/hawkbirdtree/crate.png")
const GRASS_TEXTURE = preload("res://assets/world/hawkbirdtree/grass.png")
const PATH_TEXTURE = preload("res://assets/world/hawkbirdtree/path.png")
const FLOWER_RED_TEXTURE = preload("res://assets/world/hawkbirdtree/flowers_red.png")
const FLOWER_PURPLE_TEXTURE = preload("res://assets/world/hawkbirdtree/flowers_purple.png")
const FLOWER_YELLOW_TEXTURE = preload("res://assets/world/hawkbirdtree/flowers_yellow.png")
const WATER_TEXTURE = preload("res://assets/world/hawkbirdtree/water.png")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

const CHUNK_SIZE := 14
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const LARGE_OAK_REGION := Rect2(11.0, 9.0, 41.0, 63.0)
const LARGE_OAK_FOOT := Vector2(20.5, 62.0)

var definition: Dictionary = {}
var chunk_coord := Vector2i.ZERO

var _player: Node2D = null
var _world_controller: Node = null
var _physics_root: StaticBody2D = null
var _blocked_cells: Dictionary = {}
var _trees: Array[Sprite2D] = []
var _roofs: Array[Dictionary] = []
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
	_update_roofs(delta)


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
	_build_edge_detail()
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
			var sprite := Sprite2D.new()
			sprite.texture = presentation.get("texture") as Texture2D
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var foot := grid_to_world(Vector2(cell))
			sprite.position = foot + Vector2(0.0, 16.0)
			sprite.z_index = -1200 + int(round(global_position.y + foot.y))
			ground.add_child(sprite)
			if not bool(presentation.get("walkable", true)):
				_mark_blocked(cell)
				_add_diamond_collision(cell)


func _ground_presentation(cell: Vector2i, theme: String, center: int) -> Dictionary:
	var road := absi(cell.x - center) <= 1 or absi(cell.y - center) <= 1
	if theme == "plaza" and absi(cell.x - center) <= 3 and absi(cell.y - center) <= 3:
		return {"texture": PATH_TEXTURE, "walkable": true}
	if theme == "canal" and cell.y in [2, 3] and absi(cell.x - center) > 1:
		return {"texture": WATER_TEXTURE, "walkable": false}
	if road:
		return {"texture": PATH_TEXTURE, "walkable": true}
	var world_x := cell.x + chunk_coord.x * CHUNK_SIZE
	var world_y := cell.y + chunk_coord.y * CHUNK_SIZE
	var variation := posmod(world_x * 11 + world_y * 7, 23)
	if theme == "garden":
		if variation in [2, 13]:
			return {"texture": FLOWER_PURPLE_TEXTURE, "walkable": true}
		if variation in [5, 17]:
			return {"texture": FLOWER_YELLOW_TEXTURE, "walkable": true}
		if variation == 9:
			return {"texture": FLOWER_RED_TEXTURE, "walkable": true}
	return {"texture": GRASS_TEXTURE, "walkable": true}


func _build_edge_detail() -> void:
	var props := Node2D.new()
	props.name = "EdgeDetail"
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
		"canal":
			tree_cells = [Vector2i(2, 10), Vector2i(11, 10)]
		_:
			tree_cells = [Vector2i(2, 2), Vector2i(11, 11)]
	for index in range(tree_cells.size()):
		_add_tree(props, tree_cells[index], index)
	if theme in ["residential", "market", "gate"]:
		_add_prop(props, ROCK_TEXTURE, Vector2i(11, 3), Vector2(0.0, -15.0), "Rock")


func _build_theme_content() -> void:
	var theme := String(definition.get("theme", "residential"))
	match theme:
		"plaza":
			_build_plaza()
		"digilab":
			_build_service_building(Vector2i(1, 1), Color(0.36, 0.88, 1.0), "DIGILAB", "digilab")
		"hospital":
			_build_service_building(Vector2i(1, 1), Color(0.42, 1.0, 0.86), "DIGI HOSPITAL", "hospital")
		"training":
			_build_service_building(Vector2i(1, 1), Color(0.50, 0.96, 0.55), "TRAINING CENTER", "training")
		"market":
			_build_service_building(Vector2i(1, 1), Color(1.0, 0.78, 0.34), "DATA MARKET", "shop")
		"archive":
			_build_service_building(Vector2i(1, 1), Color(0.65, 0.58, 1.0), "DIGITAL ARCHIVE", "archive")
		"gate":
			_build_gate()
		"residential":
			_build_residential_houses()


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
				Color(0.82, 0.88, 0.88, 1.0),
				level
			)
			props.add_child(block)
		_mark_blocked(cell)
		_add_block_collision(cell, 24.0)


func _build_residential_houses() -> void:
	_build_shell(Vector2i(1, 1), Vector2i(4, 4), Color(0.56, 0.76, 0.72, 1.0), "ResidenceA", "")
	_build_shell(Vector2i(9, 8), Vector2i(4, 4), Color(0.66, 0.66, 0.82, 1.0), "ResidenceB", "")


func _build_service_building(origin: Vector2i, accent: Color, title: String, action_id: String) -> void:
	var shell := _build_shell(origin, Vector2i(6, 6), accent, title.capitalize().replace(" ", ""), title)
	var building := shell.get("node") as Node2D
	if building == null:
		return
	var interior_center: Vector2i = shell.get("interior_center", origin + Vector2i(3, 3))
	var terminal := Node2D.new()
	terminal.name = "ServiceTerminal"
	terminal.position = grid_to_world(Vector2(interior_center))
	terminal.z_index = 1100 + int(round(global_position.y + terminal.position.y))
	building.add_child(terminal)
	var base := Sprite2D.new()
	base.texture = CRATE_TEXTURE
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base.position = Vector2(0.0, -28.0)
	base.modulate = accent
	terminal.add_child(base)
	var label := Label.new()
	label.text = title
	label.position = Vector2(-82.0, -82.0)
	label.size = Vector2(164.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", accent)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	terminal.add_child(label)
	var interactable := InteractableScript.new() as WorldInteractable
	interactable.configure(action_id, "OPEN %s" % title, {"service": action_id, "title": title}, 76.0, 30)
	terminal.add_child(interactable)


func _build_shell(
	origin: Vector2i,
	size: Vector2i,
	accent: Color,
	node_name: String,
	title: String
) -> Dictionary:
	var building := Node2D.new()
	building.name = node_name
	add_child(building)
	var doorway := Vector2i(origin.x + size.x - 1, origin.y + int(size.y / 2))
	for x in range(size.x):
		for y in range(size.y):
			var boundary := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			if not boundary:
				continue
			var cell := origin + Vector2i(x, y)
			if cell == doorway:
				continue
			var block := ART.create_full_block(
				ART.DATA_BLOCK if accent.b > accent.r + 0.12 else ART.WARM_BLOCK,
				grid_to_world(Vector2(cell)),
				720 + int(round(global_position.y + grid_to_world(Vector2(cell)).y)),
				accent,
				0
			)
			building.add_child(block)
			_mark_blocked(cell)
			_add_block_collision(cell, 22.0)

	var roof := Polygon2D.new()
	roof.name = "Roof"
	roof.polygon = PackedVector2Array([
		grid_to_world(Vector2(origin.x - 0.35, origin.y - 0.35)),
		grid_to_world(Vector2(origin.x + size.x - 0.65, origin.y - 0.35)),
		grid_to_world(Vector2(origin.x + size.x - 0.65, origin.y + size.y - 0.65)),
		grid_to_world(Vector2(origin.x - 0.35, origin.y + size.y - 0.65)),
	])
	roof.color = Color(accent.r * 0.42, accent.g * 0.42, accent.b * 0.48, 0.92)
	roof.position.y -= 46.0
	var roof_center := grid_to_world(Vector2(origin + Vector2i(int(size.x / 2), int(size.y / 2))))
	roof.z_index = 1700 + int(round(global_position.y + roof_center.y))
	building.add_child(roof)
	_roofs.append({
		"node": roof,
		"rect": Rect2(Vector2(origin.x + 1, origin.y + 1), Vector2(size.x - 2, size.y - 2)),
		"alpha": 0.92,
	})

	if not title.is_empty():
		var sign := Label.new()
		sign.text = title
		sign.position = grid_to_world(Vector2(origin + Vector2i(size.x - 1, int(size.y / 2)))) + Vector2(-72.0, -74.0)
		sign.size = Vector2(144.0, 22.0)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign.add_theme_font_size_override("font_size", 10)
		sign.add_theme_color_override("font_color", accent)
		sign.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		sign.add_theme_constant_override("outline_size", 4)
		sign.z_index = 1750 + int(round(global_position.y + sign.position.y))
		building.add_child(sign)

	return {
		"node": building,
		"interior_center": origin + Vector2i(int(size.x / 2), int(size.y / 2)),
	}


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


func _add_prop(parent: Node2D, texture: Texture2D, cell: Vector2i, offset: Vector2, label: String) -> void:
	var foot := grid_to_world(Vector2(cell))
	var sprite := Sprite2D.new()
	sprite.name = label
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = foot + offset
	sprite.z_index = 1000 + int(round(global_position.y + foot.y))
	parent.add_child(sprite)
	_mark_blocked(cell)
	_add_circle_collision(foot, 16.0)


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


func _update_roofs(delta: float) -> void:
	if _player == null:
		return
	var local_grid := world_to_grid(_player.global_position - global_position)
	for entry: Dictionary in _roofs:
		var roof := entry.get("node") as CanvasItem
		if roof == null:
			continue
		var rect: Rect2 = entry.get("rect", Rect2())
		var target := 0.10 if rect.has_point(local_grid) else 0.92
		var alpha := move_toward(float(entry.get("alpha", 0.92)), target, delta * 3.6)
		entry["alpha"] = alpha
		var color := roof.modulate
		color.a = alpha
		roof.modulate = color
