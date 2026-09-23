extends Node2D
class_name WorldAreaSection

const CITY = preload("res://src/world/runtime/CityAtlasArt.gd")
const CentralCityCustomArtScript = preload("res://src/world/runtime/CentralCityCustomArt.gd")
const CentralCityAssetCatalogScript = preload("res://src/world/runtime/CentralCityAssetCatalog.gd")
const CentralCityLayoutScript = preload("res://src/world/runtime/CentralCityLayout.gd")
const TreeAmbientFXScript = preload("res://src/vfx/TreeAmbientFX.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")

const SECTION_SIZE := 14
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const FLOOR_PAVEMENT := Vector2i(13, 16)
const FOUNDATION_COLOR := Color(0.30, 0.32, 0.34, 1.0)

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
	_build_custom_environment()
	_build_gameplay_anchors()


func _prepare_ground_data() -> void:
	_ground_tiles.clear()
	for x in range(SECTION_SIZE):
		for y in range(SECTION_SIZE):
			var cell := Vector2i(x, y)
			_ground_tiles.append({
				"cell": FLOOR_PAVEMENT,
				"position": position + grid_to_world(Vector2(cell)),
				"base_color": FOUNDATION_COLOR,
				"detail_tint": Color.WHITE,
				"detail_alpha": 0.42,
			})


func append_ground_tiles(target: Array[Dictionary]) -> void:
	target.append_array(_ground_tiles)


func _build_custom_environment() -> void:
	var theme := String(definition.get("theme", "residential"))

	var ground_root := Node2D.new()
	ground_root.name = "GroundModules"
	add_child(ground_root)
	for spec: Dictionary in CentralCityLayoutScript.ground_specs_for_section(section_coord, theme):
		_add_ground_module(ground_root, spec)

	var props_root := Node2D.new()
	props_root.name = "StreetFurniture"
	add_child(props_root)
	for spec: Dictionary in CentralCityLayoutScript.prop_specs_for_section(section_coord, theme):
		_add_prop_spec(props_root, spec, theme)


func _add_ground_module(parent: Node2D, spec: Dictionary) -> void:
	var asset_name := String(spec.get("asset", ""))
	if asset_name.is_empty():
		return
	var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
	var center := grid_to_world(Vector2(cell))
	var sprite := CentralCityCustomArtScript.create_ground_asset(
		asset_name,
		center,
		int(spec.get("depth", -1170)),
		bool(spec.get("flip_h", false))
	)
	if sprite == null:
		return
	sprite.set_meta("grid_cell", cell)
	sprite.set_meta("section_coord", section_coord)
	parent.add_child(sprite)


func _add_prop_spec(parent: Node2D, spec: Dictionary, theme: String) -> void:
	var asset_name := String(spec.get("asset", ""))
	if asset_name.is_empty():
		return
	var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
	var blocking := bool(spec.get("blocking", true))
	var flip_h := bool(spec.get("flip_h", false))
	if bool(spec.get("tree", false)):
		_add_tree(parent, asset_name, cell, theme)
		return
	_add_custom_prop(parent, asset_name, cell, blocking, flip_h)


func _build_gameplay_anchors() -> void:
	var theme := String(definition.get("theme", "residential"))
	if theme == "plaza":
		_spawn_npc(Vector2i(5, 9), "CITY GUIDE", "guide", "TALK", 20)
	if CentralCityLayoutScript.is_service_theme(theme):
		_build_service_access(theme)


func _build_service_access(theme: String) -> void:
	var service_def := CentralCityLayoutScript.service_definition(theme)
	if service_def.is_empty():
		return

	var root := Node2D.new()
	root.name = "ServiceAccess"
	root.add_to_group("central_city_service_access")
	add_child(root)

	var terminal_cell := CentralCityLayoutScript.service_terminal_cell(theme)
	_add_custom_prop(root, "digital-terminal", terminal_cell, true)

	var approach_cell := CentralCityLayoutScript.service_approach_cell(theme)
	var accent: Color = service_def.get("accent", Color(0.28, 0.88, 1.0))
	_add_entry_marker(root, approach_cell, accent)

	var service_id := String(service_def.get("service", theme))
	var title := String(service_def.get("title", theme.to_upper()))
	var interior_id := "%s_%d_%d" % [service_id, section_coord.x, section_coord.y]

	var entrance := Area2D.new()
	entrance.name = "InteriorThreshold"
	entrance.add_to_group("world_interior_threshold")
	entrance.position = grid_to_world(Vector2(approach_cell))
	entrance.collision_layer = 0
	entrance.collision_mask = 1
	entrance.monitoring = true
	entrance.monitorable = false
	root.add_child(entrance)

	var threshold_shape := CollisionShape2D.new()
	var threshold_circle := CircleShape2D.new()
	threshold_circle.radius = 18.0
	threshold_shape.shape = threshold_circle
	threshold_shape.position = Vector2(0.0, -5.0)
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


func _add_entry_marker(parent: Node2D, cell: Vector2i, accent: Color) -> void:
	var marker := Polygon2D.new()
	marker.name = "EntryMarker"
	marker.polygon = PackedVector2Array([
		Vector2(-20.0, 0.0),
		Vector2(0.0, -10.0),
		Vector2(20.0, 0.0),
		Vector2(0.0, 10.0),
	])
	marker.color = Color(accent.r, accent.g, accent.b, 0.34)
	marker.position = grid_to_world(Vector2(cell))
	marker.z_index = -900
	parent.add_child(marker)

	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(-10.0, 0.0),
		Vector2(0.0, -5.0),
		Vector2(10.0, 0.0),
		Vector2(0.0, 5.0),
	])
	inner.color = Color(accent.r, accent.g, accent.b, 0.72)
	inner.z_index = 1
	marker.add_child(inner)


func _spawn_npc(
	cell: Vector2i,
	title: String,
	action_id: String,
	prompt_text: String,
	interaction_priority: int
) -> void:
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


func _add_custom_prop(
	parent: Node2D,
	asset_name: String,
	cell: Vector2i,
	blocking: bool = true,
	flip_h: bool = false
) -> Sprite2D:
	var foot := grid_to_world(Vector2(cell))
	var sprite := CentralCityCustomArtScript.create_prop(
		asset_name,
		foot,
		1000 + int(round(global_position.y + foot.y)),
		flip_h
	)
	if sprite == null:
		return null
	sprite.set_meta("grid_cell", cell)
	sprite.set_meta("section_coord", section_coord)
	parent.add_child(sprite)

	if blocking:
		_mark_collision_footprint(cell, CentralCityAssetCatalogScript.collision_footprint(asset_name))
	return sprite


func _add_tree(
	parent: Node2D,
	asset_name: String,
	cell: Vector2i,
	theme: String
) -> void:
	var tree := _add_custom_prop(parent, asset_name, cell, true)
	if tree == null:
		return

	tree.name = "%s_%d_%d" % [asset_name.capitalize().replace("-", ""), cell.x, cell.y]
	tree.add_to_group("central_city_tree_occluder")
	var foot := grid_to_world(Vector2(cell))
	tree.set_meta("occlusion_foot_local", foot)

	var medium := asset_name == "medium-tree"
	tree.set_meta("occlusion_half_width", 74.0 if medium else 58.0)
	tree.set_meta("occlusion_depth", 142.0 if medium else 108.0)
	_tree_occluders.append(tree)

	TreeAmbientFXScript.apply(
		tree,
		float(cell.x * 7 + cell.y) * 0.31 + float(section_coord.x * 3 + section_coord.y),
		2.4 if medium else 1.9,
		5 if medium else 3,
		Color(0.62, 0.91, 0.39, 0.72)
	)
	var leaves := tree.get_node_or_null("AmbientLeaves") as CPUParticles2D
	if leaves != null:
		_leaf_particles.append(leaves)


func _mark_collision_footprint(cell: Vector2i, footprint: Vector2i) -> void:
	if footprint.x <= 0 or footprint.y <= 0:
		return
	var start := cell - Vector2i(
		int(floor(float(footprint.x - 1) * 0.5)),
		int(floor(float(footprint.y - 1) * 0.5))
	)
	for x in range(footprint.x):
		for y in range(footprint.y):
			_mark_blocked(start + Vector2i(x, y))


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
