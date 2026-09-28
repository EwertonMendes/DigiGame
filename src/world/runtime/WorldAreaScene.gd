extends Node2D
class_name WorldAreaScene

signal load_started(total: int)
signal load_progress(completed: int, total: int)
signal load_finished

const SECTION_SCENE := preload("res://scenes/world/world_area_section.tscn")
const CITY = preload("res://src/world/runtime/CentralCityArt.gd")
const CITY_LAYOUT = preload("res://src/world/runtime/CentralCityUrbanLayout.gd")
const CITY_TERRACE = preload("res://src/world/runtime/CentralCityTerrace.gd")
const CITY_TOPOLOGY = preload("res://src/world/runtime/CentralCityTopology.gd")
const SECTION_SIZE := 14
const BUILD_SECTIONS_PER_FRAME := 5
const AMBIENT_VFX_UPDATE_SECONDS := 0.35
const AMBIENT_VFX_SECTION_RADIUS := 1
# Full-map debug captures use the authored section envelope plus deliberate
# visual headroom for tall service buildings, tree canopies and long sunset
# shadows. This remains a world-space contract rather than a screen-size guess.
const DEBUG_CAPTURE_VISUAL_MARGIN := Vector4(420.0, 520.0, 420.0, 360.0)

var _player: Node2D = null
var _world_controller: Node = null
var _definitions: Dictionary = {}
var _sections: Dictionary = {}
var _section_list: Array[WorldAreaSection] = []
var _exterior_active := true
var _ambient_elapsed := 0.0
var _last_ambient_section := Vector2i(999999, 999999)
var _ground_tile_count := 0
var _urban_layout_polygon_count := 0
var _urban_layout_layer_count := 0
var _south_terrace_render_node_count := 0
var _road_graph_connected := false


func configure(area_definition: Dictionary, player: Node2D, world_controller: Node) -> bool:
	_player = player
	_world_controller = world_controller
	_definitions.clear()
	_sections.clear()
	_section_list.clear()
	_ground_tile_count = 0
	_urban_layout_polygon_count = 0
	_urban_layout_layer_count = 0
	_south_terrace_render_node_count = 0
	_road_graph_connected = false
	_exterior_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

	var raw_sections_value = area_definition.get("sections", [])
	if not raw_sections_value is Array or raw_sections_value.is_empty():
		push_error("World area requires a non-empty authored sections array")
		return false
	var raw_sections := raw_sections_value as Array

	var total: int = raw_sections.size() + 3
	var completed: int = 0
	var ground_tiles: Array[Dictionary] = []
	load_started.emit(total)

	# Yield before doing any expensive area construction. On Web/mobile this lets
	# the engine present its first frame and replace the browser's 100% download
	# bar with the in-game area loader instead of appearing frozen.
	await get_tree().process_frame

	# Build one authoring section per frame behind the loading screen. The whole
	# area remains hidden and non-interactive until every section is ready, so
	# there is still zero terrain pop-in while the player explores.
	for raw in raw_sections:
		if not raw is Dictionary:
			continue
		var definition := (raw as Dictionary).duplicate(true)
		var raw_coord = definition.get("coord", [0, 0])
		var coord := Vector2i(int(raw_coord[0]), int(raw_coord[1]))
		var instance := SECTION_SCENE.instantiate() as WorldAreaSection
		if instance == null:
			push_error("World area section scene must use WorldAreaSection.gd")
			return false
		instance.configure(definition, _player, _world_controller)
		add_child(instance)
		_definitions[coord] = definition
		_sections[coord] = instance
		_section_list.append(instance)
		instance.append_ground_tiles(ground_tiles)
		completed += 1
		load_progress.emit(completed, total)
		if completed < total and completed % BUILD_SECTIONS_PER_FRAME == 0:
			await get_tree().process_frame

	_ground_tile_count = ground_tiles.size()
	var ground := CITY.create_ground_batch(ground_tiles, -1200, "CityGround")
	ground.add_to_group("world_batched_ground")
	add_child(ground)
	completed += 1
	load_progress.emit(completed, total)

	# The authored urban network is a separate presentation layer above the
	# continuous micro-paver field. It does not replace gameplay cells or mutate
	# section walkability: broad avenues, plazas, forecourts and district courts
	# are batched as a handful of lit paver meshes across the complete city.
	var urban_result := CITY_LAYOUT.build()
	var urban_root = urban_result.get("root")
	if urban_root is Node2D:
		(urban_root as Node2D).add_to_group("world_urban_layout")
		add_child(urban_root as Node2D)
	_urban_layout_polygon_count = int(urban_result.get("polygon_count", 0))
	_urban_layout_layer_count = int(urban_result.get("layer_count", 0))
	_road_graph_connected = bool(urban_result.get("road_graph_connected", false))
	completed += 1
	load_progress.emit(completed, total)

	var south_terrace := CITY_TERRACE.build()
	south_terrace.add_to_group("world_urban_layout")
	add_child(south_terrace)
	_south_terrace_render_node_count = south_terrace.get_child_count()
	completed += 1
	load_progress.emit(completed, total)

	_exterior_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_update_ambient_vfx(true)
	load_finished.emit()
	print("[WorldArea] READY sections=%d nodes=%d ground_render_nodes=%d urban_layers=%d urban_polygons=%d terrace_nodes=%d decor=%d" % [
		_sections.size(),
		get_runtime_node_count(),
		get_ground_render_node_count(),
		_urban_layout_layer_count,
		_urban_layout_polygon_count,
		_south_terrace_render_node_count,
		get_decoration_count(),
	])
	return completed == total


func _process(delta: float) -> void:
	if not _exterior_active or _player == null:
		return
	_ambient_elapsed += delta
	if _ambient_elapsed < AMBIENT_VFX_UPDATE_SECONDS:
		return
	_ambient_elapsed = 0.0
	_update_ambient_vfx(false)


func is_walkable_world_position(world_position: Vector2) -> bool:
	var coord := world_to_section(world_position)
	var section = _sections.get(coord)
	if section == null or not is_instance_valid(section):
		return false
	return bool((section as WorldAreaSection).is_walkable_world_position(world_position))


func world_to_section(world_position: Vector2) -> Vector2i:
	var grid := Vector2(
		world_position.x / CITY.TILE_WIDTH + world_position.y / CITY.TILE_HEIGHT,
		-world_position.x / CITY.TILE_WIDTH + world_position.y / CITY.TILE_HEIGHT
	)
	return Vector2i(
		floori((grid.x + 0.5) / float(SECTION_SIZE)),
		floori((grid.y + 0.5) / float(SECTION_SIZE))
	)


func has_section(coord: Vector2i) -> bool:
	return _sections.has(coord)


func get_section_count() -> int:
	return _section_list.size()


func get_debug_capture_bounds() -> Rect2:
	if _sections.is_empty():
		return Rect2()

	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for raw_coord in _sections.keys():
		if not raw_coord is Vector2i:
			continue
		var coord := raw_coord as Vector2i
		var grid_min := Vector2(coord * SECTION_SIZE) - Vector2(0.5, 0.5)
		var grid_max := Vector2(coord * SECTION_SIZE + Vector2i(SECTION_SIZE - 1, SECTION_SIZE - 1)) + Vector2(0.5, 0.5)
		for grid_corner: Vector2 in [
			Vector2(grid_min.x, grid_min.y),
			Vector2(grid_max.x, grid_min.y),
			Vector2(grid_min.x, grid_max.y),
			Vector2(grid_max.x, grid_max.y),
		]:
			var world_corner := Vector2(
				(grid_corner.x - grid_corner.y) * CITY.TILE_WIDTH * 0.5,
				(grid_corner.x + grid_corner.y) * CITY.TILE_HEIGHT * 0.5
			)
			min_point.x = minf(min_point.x, world_corner.x)
			min_point.y = minf(min_point.y, world_corner.y)
			max_point.x = maxf(max_point.x, world_corner.x)
			max_point.y = maxf(max_point.y, world_corner.y)

	if not is_finite(min_point.x) or not is_finite(min_point.y):
		return Rect2()

	min_point -= Vector2(DEBUG_CAPTURE_VISUAL_MARGIN.x, DEBUG_CAPTURE_VISUAL_MARGIN.y)
	max_point += Vector2(DEBUG_CAPTURE_VISUAL_MARGIN.z, DEBUG_CAPTURE_VISUAL_MARGIN.w)
	return Rect2(min_point, max_point - min_point)


func get_runtime_node_count() -> int:
	return _count_nodes(self) - 1


func get_ground_render_node_count() -> int:
	var ground := get_node_or_null("CityGround")
	return 0 if ground == null else 1 + ground.get_child_count()


func get_ground_tile_count() -> int:
	return _ground_tile_count


func get_urban_layout_polygon_count() -> int:
	return _urban_layout_polygon_count


func get_urban_layout_layer_count() -> int:
	return _urban_layout_layer_count


func get_urban_layout_render_node_count() -> int:
	var layout := get_node_or_null("CityUrbanLayout")
	return 0 if layout == null else layout.get_child_count()


func get_south_terrace_render_node_count() -> int:
	return _south_terrace_render_node_count


func is_road_graph_connected() -> bool:
	return _road_graph_connected


func get_elevation_at_world_position(world_position: Vector2) -> float:
	return CITY_TOPOLOGY.elevation_at_grid(CITY_TOPOLOGY.world_to_grid(world_position))


func get_level_at_world_position(world_position: Vector2) -> String:
	return CITY_TOPOLOGY.level_at_grid(CITY_TOPOLOGY.world_to_grid(world_position))


func is_void_world_position(world_position: Vector2) -> bool:
	return CITY_TOPOLOGY.is_void_at_grid(CITY_TOPOLOGY.world_to_grid(world_position))


func can_traverse_world_segment(from_world: Vector2, to_world: Vector2) -> bool:
	return CITY_TOPOLOGY.can_traverse_world_segment(from_world, to_world)


func get_decoration_count() -> int:
	var total := 0
	for section: WorldAreaSection in _section_list:
		if section != null and is_instance_valid(section):
			total += section.get_decoration_count()
	return total


func get_section_definition(coord: Vector2i) -> Dictionary:
	var raw = _definitions.get(coord, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func set_exterior_active(active: bool) -> void:
	_exterior_active = active
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func is_exterior_active() -> bool:
	return _exterior_active


func play_service_return_animation(service_id: String) -> void:
	if service_id.is_empty():
		return
	for section: WorldAreaSection in _section_list:
		if section != null and is_instance_valid(section) and section.handles_service(service_id):
			await section.play_service_return_animation(service_id)
			return


func _update_ambient_vfx(force: bool) -> void:
	if _player == null:
		return
	var player_section := world_to_section(_player.global_position)
	if not force and player_section == _last_ambient_section:
		return
	_last_ambient_section = player_section
	for section: WorldAreaSection in _section_list:
		var distance := maxi(
			absi(section.section_coord.x - player_section.x),
			absi(section.section_coord.y - player_section.y)
		)
		section.set_ambient_vfx_active(distance <= AMBIENT_VFX_SECTION_RADIUS)


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total

