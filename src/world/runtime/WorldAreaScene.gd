extends Node2D
class_name WorldAreaScene

signal load_started(total: int)
signal load_progress(completed: int, total: int)
signal load_finished

const SECTION_SCENE := preload("res://scenes/world/world_area_section.tscn")
const SECTION_SIZE := 14

var _player: Node2D = null
var _world_controller: Node = null
var _definitions: Dictionary = {}
var _sections: Dictionary = {}
var _exterior_active := true


func configure(area_definition: Dictionary, player: Node2D, world_controller: Node) -> bool:
	_player = player
	_world_controller = world_controller
	_definitions.clear()
	_sections.clear()
	_exterior_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

	var raw_sections_value = area_definition.get("sections", [])
	if not raw_sections_value is Array or raw_sections_value.is_empty():
		push_error("World area requires a non-empty authored sections array")
		return false
	var raw_sections := raw_sections_value as Array

	var total: int = raw_sections.size()
	var completed: int = 0
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
		var key := _coord_key(coord)
		_definitions[key] = definition
		_sections[key] = instance
		completed += 1
		load_progress.emit(completed, total)
		if completed < total:
			await get_tree().process_frame

	_exterior_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	load_finished.emit()
	print("[WorldArea] READY sections=%d" % _sections.size())
	return completed == total


func is_walkable_world_position(world_position: Vector2) -> bool:
	var coord := world_to_section(world_position)
	var section = _sections.get(_coord_key(coord))
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
	return _sections.has(_coord_key(coord))


func get_section_count() -> int:
	return _sections.size()


func get_section_definition(coord: Vector2i) -> Dictionary:
	var raw = _definitions.get(_coord_key(coord), {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func set_exterior_active(active: bool) -> void:
	_exterior_active = active
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func is_exterior_active() -> bool:
	return _exterior_active


func _coord_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]
