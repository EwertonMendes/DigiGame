extends Node2D
class_name WorldAreaSection

const CITY = preload("res://src/world/runtime/CityAtlasArt.gd")
const ExternalCityArtScript = preload("res://src/world/runtime/ExternalCityArt.gd")
const CentralCityCustomArtScript = preload("res://src/world/runtime/CentralCityCustomArt.gd")
const TreeAmbientFXScript = preload("res://src/vfx/TreeAmbientFX.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

const SECTION_SIZE := 14
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0

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
var _tree_occluders: Array[Sprite2D] = []
var _ambient_vfx_active := false


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
				"detail_tint": Color.WHITE,
				"detail_alpha": 0.0,
			})
			if not bool(presentation.get("walkable", true)):
				_mark_blocked(cell)

func append_ground_tiles(target: Array[Dictionary]) -> void:
	target.append_array(_ground_tiles)




func _ground_presentation(cell: Vector2i, theme: String, center: int) -> Dictionary:
	var road := (
		(section_coord.y == 0 and absi(cell.y - center) <= 2)
		or (section_coord.x == 0 and absi(cell.x - center) <= 2)
	)
	if theme == "canal" and cell.y in [2, 3] and absi(cell.x - center) > 1:
		return {
			"cell": FLOOR_BLUE,
			"base_color": Color(0.035, 0.12, 0.18, 1.0),
			"walkable": false,
		}
	if road:
		return {
			"cell": FLOOR_ROAD,
			"base_color": Color(0.075, 0.09, 0.11, 1.0),
			"walkable": true,
		}
	if theme == "garden":
		return {
			"cell": FLOOR_GREEN,
			"base_color": Color(0.12, 0.23, 0.16, 1.0),
			"walkable": true,
		}
	if theme == "plaza":
		return {
			"cell": FLOOR_PLAZA,
			"base_color": Color(0.21, 0.23, 0.25, 1.0),
			"walkable": true,
		}
	return {
		"cell": FLOOR_PAVEMENT,
		"base_color": Color(0.18, 0.20, 0.22, 1.0),
		"walkable": true,
	}


func _build_street_detail() -> void:
	var props := Node2D.new()
	props.name = "StreetFurniture"
	add_child(props)
	var theme := String(definition.get("theme", "residential"))

	_build_custom_ground_patches(props, theme)

	var tree_cells: Array[Vector2i] = []
	match theme:
		"garden":
			tree_cells = [
				Vector2i(3, 3), Vector2i(10, 3),
				Vector2i(3, 10), Vector2i(10, 10),
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
		_add_tree(props, tree_cells[index], index, theme)

	# Keep the current street lamps: this is the one element from the temporary
	# external kit that already matches the desired Central City language.
	if theme not in ["garden", "canal"]:
		_add_external_prop(props, "dystopian_street_lamp_a", Vector2i(11, 5), 0.92)
		_add_external_prop(props, "dystopian_street_lamp_b", Vector2i(11, 9), 0.92)

	match theme:
		"plaza":
			_add_custom_prop(props, "digital-terminal", Vector2i(3, 10), 82.0, true)
			_add_custom_prop(props, "public-bench", Vector2i(10, 10), 142.0, true)
			_add_custom_prop(props, "planter", Vector2i(3, 3), 120.0, true)
		"garden":
			_add_custom_prop(props, "public-bench", Vector2i(7, 11), 142.0, true)
			_add_custom_prop(props, "trash-bin", Vector2i(11, 7), 62.0, true)
			_add_custom_prop(props, "planter", Vector2i(7, 3), 126.0, true)
		"residential":
			_add_custom_prop(props, "public-bench", Vector2i(10, 10), 136.0, true)
			_add_custom_prop(props, "trash-bin", Vector2i(11, 11), 60.0, true)
			_add_custom_prop(props, "planter", Vector2i(3, 10), 118.0, true)
		"digilab", "hospital", "training", "market", "archive":
			_add_custom_prop(props, "digital-terminal", Vector2i(11, 11), 78.0, true)
			_add_custom_prop(props, "planter", Vector2i(10, 10), 112.0, true)

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
	var landmark_name := String(definition.get("landmark_asset", "future_37"))
	var landmark_scale := float(definition.get("landmark_scale", 0.50))
	var landmark := ExternalCityArtScript.create_ground_sprite(
		landmark_name,
		foot,
		1050 + int(round(global_position.y + foot.y)),
		landmark_scale
	)
	if landmark != null:
		props.add_child(landmark)
	_mark_blocked(center)
	_spawn_npc(Vector2i(5, 9), "CITY GUIDE", "guide", "TALK", 20)


func _build_gate() -> void:
	var root := Node2D.new()
	root.name = "CityGate"
	add_child(root)
	var assets = definition.get("building_assets", ["future_13", "future_24"])
	if not assets is Array or assets.size() < 2:
		assets = ["future_13", "future_24"]

	var left_origin := Vector2i(2, 3)
	var right_origin := Vector2i(9, 3)
	_place_external_building(root, String(assets[0]), left_origin, Vector2i(3, 5), 0.68)
	_place_external_building(root, String(assets[1]), right_origin, Vector2i(3, 5), 0.68)
	_block_footprint(left_origin, Vector2i(3, 5))
	_block_footprint(right_origin, Vector2i(3, 5))
	_add_custom_prop(root, "digital-terminal", Vector2i(5, 7), 76.0, false)
	_add_custom_prop(root, "digital-terminal", Vector2i(8, 7), 76.0, false)


func _build_residential_block() -> void:
	var root := Node2D.new()
	root.name = "ResidentialBlock"
	add_child(root)

	var assets = definition.get("building_assets", ["future_20", "future_34"])
	if not assets is Array or assets.is_empty():
		assets = ["future_20", "future_34"]

	var origin_a := Vector2i(2, 2)
	var size_a := Vector2i(5, 5)
	_place_external_building(root, String(assets[0]), origin_a, size_a, 0.72)
	_block_footprint(origin_a, size_a)

	if assets.size() >= 2:
		var origin_b := Vector2i(7, 2)
		var size_b := Vector2i(5, 5)
		_place_external_building(root, String(assets[1]), origin_b, size_b, 0.68)
		_block_footprint(origin_b, size_b)


func _build_service_exterior(accent: Color, title: String, service_id: String) -> void:
	var root := Node2D.new()
	root.name = title.capitalize().replace(" ", "")
	add_child(root)

	var origin := Vector2i(2, 1)
	var size := Vector2i(9, 6)
	var door_side := "south"
	if service_id in ["training", "shop"]:
		origin = Vector2i(1, 2)
		size = Vector2i(6, 9)
		door_side = "east"
	elif service_id == "archive":
		origin = Vector2i(2, 2)
		size = Vector2i(9, 7)

	var default_assets := {
		"digilab": "future_27",
		"hospital": "future_19",
		"training": "future_33",
		"shop": "future_32",
		"archive": "future_06",
	}
	var asset_name := String(definition.get("building_asset", default_assets.get(service_id, "future_27")))
	var visual_scale := float(definition.get("building_scale", 0.88))
	_place_external_building(root, asset_name, origin, size, visual_scale)
	_block_footprint(origin, size)

	var door_cell := (
		origin + Vector2i(int(size.x / 2), size.y)
		if door_side == "south"
		else origin + Vector2i(size.x, int(size.y / 2))
	)
	var approach_cell := door_cell
	_add_entry_marker(root, door_cell, accent)

	var interior_id := "%s_%d_%d" % [service_id, section_coord.x, section_coord.y]
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
	threshold_circle.radius = 20.0
	threshold_shape.shape = threshold_circle
	threshold_shape.position = Vector2(0.0, -6.0)
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


func _build_external_roads(parent: Node2D) -> void:
	var center := int(SECTION_SIZE / 2)
	if section_coord.y == 0:
		for x in range(1, SECTION_SIZE, 2):
			var foot := grid_to_world(Vector2(x, center))
			var road := ExternalCityArtScript.create_centered_sprite(
				"dystopian_road_a",
				foot,
				-1110,
				0.98,
				Color(0.78, 0.88, 0.94, 1.0)
			)
			if road != null:
				parent.add_child(road)
	if section_coord.x == 0:
		for y in range(1, SECTION_SIZE, 2):
			var foot := grid_to_world(Vector2(center, y))
			var road := ExternalCityArtScript.create_centered_sprite(
				"dystopian_road_b",
				foot,
				-1109,
				0.98,
				Color(0.78, 0.88, 0.94, 1.0)
			)
			if road != null:
				parent.add_child(road)


func _place_external_building(
	parent: Node2D,
	asset_name: String,
	origin: Vector2i,
	size: Vector2i,
	visual_scale: float
) -> void:
	var front_cell := origin + Vector2i(size.x - 1, size.y - 1)
	var foot := grid_to_world(Vector2(front_cell))
	var sprite := ExternalCityArtScript.create_ground_sprite(
		asset_name,
		foot,
		1200 + int(round(global_position.y + foot.y)),
		visual_scale
	)
	if sprite != null:
		parent.add_child(sprite)


func _block_footprint(origin: Vector2i, size: Vector2i) -> void:
	for x in range(size.x):
		for y in range(size.y):
			_mark_blocked(origin + Vector2i(x, y))


func _add_entry_marker(parent: Node2D, cell: Vector2i, accent: Color) -> void:
	var marker := Polygon2D.new()
	marker.name = "EntryMarker"
	marker.polygon = PackedVector2Array([
		Vector2(-22.0, 0.0),
		Vector2(0.0, -11.0),
		Vector2(22.0, 0.0),
		Vector2(0.0, 11.0),
	])
	marker.color = Color(accent.r, accent.g, accent.b, 0.48)
	marker.position = grid_to_world(Vector2(cell))
	marker.z_index = -1000
	parent.add_child(marker)

	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(-12.0, 0.0),
		Vector2(0.0, -6.0),
		Vector2(12.0, 0.0),
		Vector2(0.0, 6.0),
	])
	inner.color = Color(accent.r, accent.g, accent.b, 0.88)
	inner.z_index = 1
	marker.add_child(inner)


func _add_external_prop(
	parent: Node2D,
	asset_name: String,
	cell: Vector2i,
	scale_value: float = 1.0,
	blocking: bool = true
) -> void:
	var foot := grid_to_world(Vector2(cell))
	var sprite := ExternalCityArtScript.create_ground_sprite(
		asset_name,
		foot,
		1000 + int(round(global_position.y + foot.y)),
		scale_value
	)
	if sprite != null:
		parent.add_child(sprite)
	if blocking:
		_mark_blocked(cell)


func _build_custom_ground_patches(parent: Node2D, theme: String) -> void:
	var center := Vector2i(int(SECTION_SIZE / 2), int(SECTION_SIZE / 2))
	var center_world := grid_to_world(Vector2(center))

	if theme == "plaza":
		_add_custom_patch(parent, "plaza-floor", center_world, -1175, 430.0)
	elif theme == "garden":
		_add_custom_patch(parent, "grass-ground", center_world, -1175, 430.0)
	elif theme != "canal":
		_add_custom_patch(parent, "sidewalk", center_world, -1178, 430.0)

	if section_coord == Vector2i.ZERO:
		return

	if section_coord.y == 0:
		_add_custom_patch(parent, "road", grid_to_world(Vector2(3, center.y)), -1165, 285.0)
		_add_custom_patch(parent, "road", grid_to_world(Vector2(10, center.y)), -1165, 285.0)
		if absi(section_coord.x) == 1:
			var cross_x := 11 if section_coord.x < 0 else 2
			_add_custom_patch(parent, "crosswalk", grid_to_world(Vector2(cross_x, center.y)), -1155, 176.0)
	elif section_coord.x == 0:
		_add_custom_patch(parent, "road", grid_to_world(Vector2(center.x, 3)), -1165, 285.0, true)
		_add_custom_patch(parent, "road", grid_to_world(Vector2(center.x, 10)), -1165, 285.0, true)
		if absi(section_coord.y) == 1:
			var cross_y := 11 if section_coord.y < 0 else 2
			_add_custom_patch(parent, "crosswalk", grid_to_world(Vector2(center.x, cross_y)), -1155, 176.0, true)

	if theme == "garden":
		_add_custom_curb(parent, 0, Vector2i(2, 7), 118.0)
		_add_custom_curb(parent, 5, Vector2i(11, 7), 118.0, true)


func _add_custom_patch(
	parent: Node2D,
	asset_name: String,
	local_center: Vector2,
	depth_order: int,
	target_width: float,
	flip_h: bool = false
) -> void:
	var sprite := CentralCityCustomArtScript.create_ground_patch(
		asset_name,
		local_center,
		depth_order,
		target_width,
		flip_h
	)
	if sprite != null:
		parent.add_child(sprite)


func _add_custom_prop(
	parent: Node2D,
	asset_name: String,
	cell: Vector2i,
	target_width: float,
	blocking: bool = true,
	offset: Vector2 = Vector2.ZERO
) -> Sprite2D:
	var foot := grid_to_world(Vector2(cell))
	var sprite := CentralCityCustomArtScript.create_ground_prop(
		asset_name,
		foot,
		1000 + int(round(global_position.y + foot.y)),
		target_width,
		offset
	)
	if sprite != null:
		parent.add_child(sprite)
	if blocking:
		_mark_blocked(cell)
	return sprite


func _add_custom_curb(
	parent: Node2D,
	index: int,
	cell: Vector2i,
	target_width: float,
	flip_h: bool = false
) -> void:
	var asset_name := "curb_%02d" % index
	var foot := grid_to_world(Vector2(cell))
	var sprite := CentralCityCustomArtScript.create_ground_prop(
		asset_name,
		foot,
		-1145,
		target_width,
		Vector2.ZERO,
		flip_h
	)
	if sprite != null:
		parent.add_child(sprite)


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



func _add_tree(parent: Node2D, cell: Vector2i, index: int, theme: String) -> void:
	var use_medium := theme in ["garden", "plaza"] and index % 2 == 0
	var asset_name := "medium-tree" if use_medium else "small-tree"
	var target_width := 205.0 if use_medium else 164.0
	var tree := _add_custom_prop(parent, asset_name, cell, target_width, true)
	if tree == null:
		return

	tree.name = "%s_%d_%d" % [asset_name.capitalize().replace("-", ""), cell.x, cell.y]
	tree.add_to_group("central_city_tree_occluder")
	var foot := grid_to_world(Vector2(cell))
	tree.set_meta("occlusion_foot_local", foot)
	tree.set_meta("occlusion_half_width", 78.0 if use_medium else 62.0)
	tree.set_meta("occlusion_depth", 150.0 if use_medium else 116.0)
	_tree_occluders.append(tree)

	TreeAmbientFXScript.apply(
		tree,
		float(index) * 1.37 + float(section_coord.x * 3 + section_coord.y),
		2.5 if use_medium else 2.0,
		5 if use_medium else 3,
		Color(0.62, 0.91, 0.39, 0.72)
	)
	var leaves := tree.get_node_or_null("AmbientLeaves") as CPUParticles2D
	if leaves != null:
		_leaf_particles.append(leaves)

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
	_ambient_vfx_active = active
	set_process(active)
	for leaves: CPUParticles2D in _leaf_particles:
		if leaves == null or not is_instance_valid(leaves):
			continue
		leaves.visible = active
		leaves.emitting = active
	if not active:
		for tree: Sprite2D in _tree_occluders:
			if tree == null or not is_instance_valid(tree):
				continue
			var modulate_color := tree.modulate
			modulate_color.a = 1.0
			tree.modulate = modulate_color


func _process(delta: float) -> void:
	if not _ambient_vfx_active or _player == null:
		return
	for tree: Sprite2D in _tree_occluders:
		if tree == null or not is_instance_valid(tree):
			continue
		var target_alpha := 0.42 if _should_fade_tree_for_player(tree) else 1.0
		var modulate_color := tree.modulate
		modulate_color.a = move_toward(modulate_color.a, target_alpha, 7.5 * delta)
		tree.modulate = modulate_color


func _should_fade_tree_for_player(tree: Sprite2D) -> bool:
	var foot_variant = tree.get_meta("occlusion_foot_local", null)
	if not foot_variant is Vector2:
		return false
	var foot_global := to_global(foot_variant as Vector2)
	var relative := _player.global_position - foot_global
	var half_width := float(tree.get_meta("occlusion_half_width", 64.0))
	var depth := float(tree.get_meta("occlusion_depth", 120.0))
	return (
		relative.y <= 8.0
		and relative.y >= -depth
		and absf(relative.x) <= half_width
	)

func _mark_blocked(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= SECTION_SIZE or cell.y >= SECTION_SIZE:
		return
	_blocked_cells[cell.y * SECTION_SIZE + cell.x] = 1
