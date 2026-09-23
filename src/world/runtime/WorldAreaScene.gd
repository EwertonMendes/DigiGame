extends Node2D
class_name WorldAreaScene

signal load_started(total: int)
signal load_progress(completed: int, total: int)
signal load_finished

const SECTION_SCENE := preload("res://scenes/world/world_area_section.tscn")
const CITY = preload("res://src/world/runtime/CityAtlasArt.gd")
const CentralCityCustomArtScript = preload("res://src/world/runtime/CentralCityCustomArt.gd")
const SECTION_SIZE := 14
const BUILD_SECTIONS_PER_FRAME := 5
const AMBIENT_VFX_UPDATE_SECONDS := 0.35
const AMBIENT_VFX_SECTION_RADIUS := 1

var _player: Node2D = null
var _world_controller: Node = null
var _definitions: Dictionary = {}
var _sections: Dictionary = {}
var _section_list: Array[WorldAreaSection] = []
var _exterior_active := true
var _ambient_elapsed := 0.0
var _last_ambient_section := Vector2i(999999, 999999)


func configure(area_definition: Dictionary, player: Node2D, world_controller: Node) -> bool:
	_player = player
	_world_controller = world_controller
	_definitions.clear()
	_sections.clear()
	_section_list.clear()
	_exterior_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

	var raw_sections_value = area_definition.get("sections", [])
	if not raw_sections_value is Array or raw_sections_value.is_empty():
		push_error("World area requires a non-empty authored sections array")
		return false
	var raw_sections := raw_sections_value as Array

	var total: int = raw_sections.size() + 1
	var completed: int = 0
	var ground_tiles: Array[Dictionary] = []
	load_started.emit(total)

	await get_tree().process_frame

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

	var ground := CITY.create_floor_batch(ground_tiles, -1200, "CityGround")
	ground.add_to_group("world_batched_ground")
	add_child(ground)
	completed += 1
	load_progress.emit(completed, total)

	_exterior_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_update_ambient_vfx(true)
	load_finished.emit()
	print("[CentralCityCustom] READY available=%s" % str(CentralCityCustomArtScript.is_available()))
	print("[WorldArea] READY sections=%d nodes=%d ground_render_nodes=%d" % [
		_sections.size(),
		get_runtime_node_count(),
		get_ground_render_node_count(),
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
		world_position.x / 64.0 + world_position.y / 32.0,
		-world_position.x / 64.0 + world_position.y / 32.0
	)
	return Vector2i(
		floori((grid.x + 0.5) / float(SECTION_SIZE)),
		floori((grid.y + 0.5) / float(SECTION_SIZE))
	)


func has_section(coord: Vector2i) -> bool:
	return _sections.has(coord)


func get_section_count() -> int:
	return _section_list.size()


func get_runtime_node_count() -> int:
	return _count_nodes(self) - 1


func get_ground_render_node_count() -> int:
	var ground := get_node_or_null("CityGround")
	return 0 if ground == null else 1 + ground.get_child_count()


func get_ground_tile_count() -> int:
	return SECTION_SIZE * SECTION_SIZE * _section_list.size()


func get_section_definition(coord: Vector2i) -> Dictionary:
	var raw = _definitions.get(coord, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func set_exterior_active(active: bool) -> void:
	_exterior_active = active
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func is_exterior_active() -> bool:
	return _exterior_active


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
