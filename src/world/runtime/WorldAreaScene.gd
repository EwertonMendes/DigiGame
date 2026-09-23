extends Node2D
class_name WorldAreaScene

const SECTION_SCENE := preload("res://scenes/world/world_area_section.tscn")
const SECTION_SIZE := 14

var _player: Node2D = null
var _world_controller: Node = null
var _definitions: Dictionary = {}
var _sections: Dictionary = {}
var _exterior_active := true


func configure(area_definition: Dictionary, player: Node2D, world_controller: Node) -> void:
	_player = player
	_world_controller = world_controller
	_definitions.clear()
	_sections.clear()

	var raw_sections = area_definition.get("sections", [])
	if not raw_sections is Array:
		push_error("World area requires an authored sections array")
		return

	# Build the complete area before gameplay starts. Sections are authoring
	# units only: there is no runtime queue, radius, pop-in or unload lifecycle.
	for raw in raw_sections:
		if not raw is Dictionary:
			continue
		var definition := (raw as Dictionary).duplicate(true)
		var raw_coord = definition.get("coord", [0, 0])
		var coord := Vector2i(int(raw_coord[0]), int(raw_coord[1]))
		var instance := SECTION_SCENE.instantiate() as WorldAreaSection
		if instance == null:
			push_error("World area section scene must use WorldAreaSection.gd")
			continue
		instance.configure(definition, _player, _world_controller)
		add_child(instance)
		var key := _coord_key(coord)
		_definitions[key] = definition
		_sections[key] = instance

	print("[WorldArea] READY sections=%d" % _sections.size())


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
