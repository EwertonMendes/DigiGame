extends Node2D
class_name WorldAreaSection

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")
const TreeAmbientFXScript = preload("res://src/vfx/TreeAmbientFX.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const OAK_TREE_SOURCE = preload("res://assets/terrain/Oak_Tree.png")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")
const DIGILAB_TEXTURE = preload("res://assets/world/tblack/digilab.png")

const SECTION_SIZE := 14
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const CITY_CENTER_GLOBAL := Vector2i(7, 7)
const CITY_SHAPE_MANHATTAN_RADIUS := 54
const LARGE_OAK_REGION := Rect2(11.0, 9.0, 41.0, 63.0)
const LARGE_OAK_FOOT := Vector2(20.5, 62.0)
const DIGILAB_SCALE := Vector2(0.40, 0.40)
const DIGILAB_DOOR_PIXEL := Vector2(754.0, 1054.0)
const DIGILAB_DOOR_CELL := Vector2i(8, 10)
const DIGILAB_RETURN_CELL := Vector2i(9, 11)
const DIGILAB_FOOTPRINT_MIN := Vector2i(1, 1)
const DIGILAB_FOOTPRINT_MAX := Vector2i(11, 9)

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
		world.x / CITY.TILE_WIDTH + world.y / CITY.TILE_HEIGHT,
		-world.x / CITY.TILE_WIDTH + world.y / CITY.TILE_HEIGHT
	)


func _build_section() -> void:
	_prepare_ground_data()
	_build_natural_details()
	_build_theme_content()


func _prepare_ground_data() -> void:
	_ground_tiles.clear()
	var theme := String(definition.get("theme", "residential"))
	for x in range(SECTION_SIZE):
		for y in range(SECTION_SIZE):
			var cell := Vector2i(x, y)
			var presentation := _ground_presentation(cell, theme)
			if not bool(presentation.get("render", true)):
				_mark_blocked(cell)
				continue
			var surface := String(presentation.get("surface", CITY.SURFACE_MAIN))
			var global_grid := _global_grid(cell)
			_ground_tiles.append({
				"surface": surface,
				"position": position + grid_to_world(Vector2(cell)),
				"base_color": presentation.get("base_color", CITY.surface_base_color(surface)),
				"detail_tint": presentation.get("detail_tint", Color.WHITE),
				"detail_alpha": float(presentation.get("detail_alpha", 1.0)),
				"edge": _is_global_city_edge(global_grid),
			})
			if not bool(presentation.get("walkable", true)):
				_mark_blocked(cell)


func append_ground_tiles(target: Array[Dictionary]) -> void:
	target.append_array(_ground_tiles)


func _ground_presentation(cell: Vector2i, theme: String) -> Dictionary:
	var global_grid := _global_grid(cell)
	if not _is_global_city_land(global_grid):
		return {"render": false, "walkable": false}

	var delta := global_grid - CITY_CENTER_GLOBAL
	var ax := absi(delta.x)
	var ay := absi(delta.y)
	var city_ring := maxi(ax, ay)

	# Central Plaza is one authored civic space instead of a patchwork of
	# district materials: 0064 pool, a single teal rim, then 0054 pavement.
	if ax <= 1 and ay <= 1:
		return {"surface": CITY.SURFACE_WATER, "walkable": false}
	if city_ring == 2:
		return {"surface": CITY.SURFACE_TECH_TEAL, "walkable": true}
	if city_ring <= 6:
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}

	# City structure is defined before district styling. A wide north/south and
	# east/west promenade crosses the whole island, while every 14x14 authoring
	# section contributes a one-cell 0054 sidewalk around its lot. Neighbouring
	# sections therefore form coherent two-cell streets between city blocks.
	if ax <= 1 or ay <= 1:
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
	if _is_block_sidewalk(cell):
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}

	# DigiLab now has a real exterior. Keep its structure on the teal lot and
	# reserve a paved 0054 forecourt directly in front of the authored door.
	if theme == "digilab" and _is_digilab_pavement(cell):
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}

	# The remaining service districts still use the temporary paved cross until
	# their dedicated exterior art is authored.
	if theme != "digilab" and _is_service_district(theme) and _is_service_walkway(cell):
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}

	match theme:
		"garden":
			# Parks are bounded rectangles: mint edging, green interior and one
			# consistent checker cross. No coordinate hash/random alternation.
			var garden_border := cell.x in [2, 11] or cell.y in [2, 11]
			var garden_cross := cell.x in [6, 7] or cell.y in [6, 7]
			if garden_border:
				return {"surface": CITY.SURFACE_MINT, "walkable": true}
			if garden_cross:
				return {"surface": CITY.SURFACE_GRASS_CHECKER, "walkable": true}
			return {"surface": CITY.SURFACE_GRASS, "walkable": true}
		"digilab":
			return {"surface": CITY.SURFACE_TECH_TEAL, "walkable": true}
		"hospital":
			return {"surface": CITY.SURFACE_TECH_BLUE, "walkable": true}
		"training":
			return {"surface": CITY.SURFACE_TRAINING, "walkable": true}
		"market":
			return {"surface": CITY.SURFACE_MARKET, "walkable": true}
		"archive":
			return {"surface": CITY.SURFACE_TECH_PURPLE, "walkable": true}
		"gate":
			# Gate wards stay sober and directional: dark buildable lots with a
			# 0054 central outbound lane.
			if cell.x in [6, 7] or cell.y in [6, 7]:
				return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
			return {"surface": CITY.SURFACE_DARK, "walkable": true}
		"canal":
			# A rectangular canal crosses the block. The center two columns form
			# the permanent 0054 bridge, keeping the route legible.
			if cell.y >= 5 and cell.y <= 8 and cell.x >= 2 and cell.x <= 11:
				if cell.x in [6, 7]:
					return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
				return {"surface": CITY.SURFACE_WATER, "walkable": false}
			return {"surface": CITY.SURFACE_MAIN, "walkable": true}
		"plaza":
			return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
		_:
			# 0072 is the neutral city-lot material. Residential and future
			# establishment blocks stay as large contiguous pads rather than
			# being sprinkled with unrelated surfaces.
			return {"surface": CITY.SURFACE_MAIN, "walkable": true}


func _is_block_sidewalk(cell: Vector2i) -> bool:
	return cell.x in [0, SECTION_SIZE - 1] or cell.y in [0, SECTION_SIZE - 1]


func _is_digilab_pavement(cell: Vector2i) -> bool:
	if cell.y in [10, 11] and cell.x >= 5 and cell.x <= 11:
		return true
	return cell in [Vector2i(9, 11), Vector2i(10, 12), Vector2i(11, 13)]


func _is_service_district(theme: String) -> bool:
	return theme in ["digilab", "hospital", "training", "market", "archive"]


func _is_service_walkway(cell: Vector2i) -> bool:
	return cell.x in [6, 7] or cell.y in [6, 7]


func _global_grid(cell: Vector2i) -> Vector2i:
	return section_coord * SECTION_SIZE + cell


func _is_global_city_land(global_grid: Vector2i) -> bool:
	var delta := global_grid - CITY_CENTER_GLOBAL
	var ax := absi(delta.x)
	var ay := absi(delta.y)
	return ax <= 34 and ay <= 34 and ax + ay <= CITY_SHAPE_MANHATTAN_RADIUS


func _is_global_city_edge(global_grid: Vector2i) -> bool:
	if not _is_global_city_land(global_grid):
		return false
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not _is_global_city_land(global_grid + step):
			return true
	return false


func _is_city_land(cell: Vector2i) -> bool:
	return _is_global_city_land(_global_grid(cell))


func _build_natural_details() -> void:
	var props := Node2D.new()
	props.name = "NaturalDetails"
	add_child(props)
	var theme := String(definition.get("theme", "residential"))
	var tree_cells: Array[Vector2i] = []
	match theme:
		"garden":
			tree_cells = [Vector2i(2, 2), Vector2i(11, 2), Vector2i(2, 11), Vector2i(11, 11)]
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


func _build_theme_content() -> void:
	var theme := String(definition.get("theme", "residential"))
	match theme:
		"plaza":
			_spawn_npc(Vector2i(5, 9), "CITY GUIDE", "guide", "TALK", 20)
		"digilab":
			_build_digilab_exterior()
		"hospital":
			_build_service_pad(Color(0.66, 0.96, 1.0), "DIGI HOSPITAL", "hospital", CITY.SURFACE_TECH_BLUE)
		"training":
			_build_service_pad(Color(0.56, 0.95, 0.43), "TRAINING CENTER", "training", CITY.SURFACE_TRAINING)
		"market":
			_build_service_pad(Color(0.42, 1.0, 0.52), "DATA MARKET", "shop", CITY.SURFACE_MARKET)
		"archive":
			_build_service_pad(Color(0.72, 0.52, 1.0), "DIGITAL ARCHIVE", "archive", CITY.SURFACE_TECH_PURPLE)


func _build_digilab_exterior() -> void:
	if not _is_city_land(DIGILAB_DOOR_CELL):
		return

	var exterior := Node2D.new()
	exterior.name = "DigiLabExterior"
	add_child(exterior)

	var door_world := grid_to_world(Vector2(DIGILAB_DOOR_CELL))
	var sprite := Sprite2D.new()
	sprite.name = "Building"
	sprite.texture = DIGILAB_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = DIGILAB_SCALE
	var texture_center := DIGILAB_TEXTURE.get_size() * 0.5
	var authored_door_offset := (DIGILAB_DOOR_PIXEL - texture_center) * DIGILAB_SCALE
	sprite.position = door_world - authored_door_offset
	# Match the actor depth convention to preserve natural occlusion. At the
	# doorway itself the player stays one layer in front of the facade.
	sprite.z_index = 999 + int(round(global_position.y + door_world.y))
	exterior.add_child(sprite)

	var door_marker := Marker2D.new()
	door_marker.name = "DoorAnchor"
	door_marker.position = door_world
	exterior.add_child(door_marker)

	# The visible structure occupies the lot above the 0054 forecourt. Logical
	# cell blocking keeps actors from walking through the building while the
	# door and its approach remain open.
	for x in range(DIGILAB_FOOTPRINT_MIN.x, DIGILAB_FOOTPRINT_MAX.x + 1):
		for y in range(DIGILAB_FOOTPRINT_MIN.y, DIGILAB_FOOTPRINT_MAX.y + 1):
			_mark_blocked(Vector2i(x, y))

	var entrance := _create_service_threshold(
		"DigiLabEntrance",
		"digilab",
		"DIGILAB",
		Color(0.28, 0.88, 1.0),
		DIGILAB_DOOR_CELL,
		DIGILAB_RETURN_CELL,
		14.0
	)
	exterior.add_child(entrance)


func _build_service_pad(accent: Color, title: String, service_id: String, surface: String) -> void:
	var pad_cell := Vector2i(7, 7)
	if not _is_city_land(pad_cell):
		return
	var approach_cell := pad_cell + Vector2i(1, 0)

	var entrance := _create_service_threshold(
		"%sPad" % title.capitalize().replace(" ", ""),
		service_id,
		title,
		accent,
		pad_cell,
		approach_cell,
		17.0
	)
	add_child(entrance)

	var pad := CITY.create_surface_tile(surface, Vector2.ZERO, 0, 1.0)
	pad.name = "ServicePadSurface"
	entrance.add_child(pad)

	var label := Label.new()
	label.text = title
	label.position = Vector2(-76.0, -52.0)
	label.size = Vector2(152.0, 22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", accent.lightened(0.15))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 4
	entrance.add_child(label)


func _create_service_threshold(
	node_name: String,
	service_id: String,
	title: String,
	accent: Color,
	cell: Vector2i,
	return_cell: Vector2i,
	radius: float
) -> Area2D:
	var entrance := Area2D.new()
	entrance.name = node_name
	entrance.add_to_group("world_interior_threshold")
	entrance.position = grid_to_world(Vector2(cell))
	entrance.collision_layer = 0
	entrance.collision_mask = 1
	entrance.monitoring = true
	entrance.monitorable = false

	var threshold_shape := CollisionShape2D.new()
	var threshold_circle := CircleShape2D.new()
	threshold_circle.radius = radius
	threshold_shape.shape = threshold_circle
	threshold_shape.position = Vector2(0.0, -6.0)
	entrance.add_child(threshold_shape)

	var return_world := global_position + grid_to_world(Vector2(return_cell))
	var interior_id := "%s_%d_%d" % [service_id, section_coord.x, section_coord.y]
	entrance.set_meta("interior_payload", {
		"interior_id": interior_id,
		"service": service_id,
		"title": title,
		"accent": [accent.r, accent.g, accent.b, accent.a],
		"return_position": [return_world.x, return_world.y],
	})
	entrance.body_entered.connect(_on_interior_threshold_entered.bind(entrance))
	return entrance


func _on_interior_threshold_entered(body: Node2D, entrance: Area2D) -> void:
	if body != _player or _world_controller == null:
		return
	if not _world_controller.has_method("request_interior_entry"):
		return
	var payload = entrance.get_meta("interior_payload", {})
	if payload is Dictionary:
		_world_controller.call_deferred("request_interior_entry", (payload as Dictionary).duplicate(true))


func _spawn_npc(cell: Vector2i, title: String, action_id: String, prompt_text: String, interaction_priority: int) -> void:
	if not _is_city_land(cell):
		return
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
	if not _is_city_land(cell):
		return
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
