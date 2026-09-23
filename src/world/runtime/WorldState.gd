extends Node

signal location_changed(region_id: String, area_id: String, chunk: Vector2i)
signal world_flags_changed

const DEFAULT_REGION := "central_city"
const DEFAULT_AREA := "central_city"
const DEFAULT_CHUNK := Vector2i.ZERO
const DEFAULT_POSITION := Vector2(-96.0, 272.0)
const DEFAULT_FACING := "south"
const DEFAULT_WORLD_SCENE := "res://scenes/world/world_root.tscn"

var current_region := DEFAULT_REGION
var current_area := DEFAULT_AREA
var current_chunk := DEFAULT_CHUNK
var player_position := DEFAULT_POSITION
var player_facing := DEFAULT_FACING
var story_flags: Dictionary = {}
var world_variants: Dictionary = {}
var opened_objects: Dictionary = {}

var _return_scene_path := ""
var _return_context: Dictionary = {}


func reset_to_defaults() -> void:
	current_region = DEFAULT_REGION
	current_area = DEFAULT_AREA
	current_chunk = DEFAULT_CHUNK
	player_position = DEFAULT_POSITION
	player_facing = DEFAULT_FACING
	story_flags.clear()
	world_variants.clear()
	opened_objects.clear()
	clear_return_scene()


func capture_location(
	region_id: String,
	area_id: String,
	chunk: Vector2i,
	position: Vector2,
	facing: String
) -> void:
	var area_changed := current_region != region_id or current_area != area_id or current_chunk != chunk
	current_region = region_id
	current_area = area_id
	current_chunk = chunk
	player_position = position
	if not facing.is_empty():
		player_facing = facing
	if area_changed:
		location_changed.emit(current_region, current_area, current_chunk)


func set_story_flag(flag_id: String, value: bool) -> void:
	var clean_id := flag_id.strip_edges()
	if clean_id.is_empty() or bool(story_flags.get(clean_id, false)) == value:
		return
	story_flags[clean_id] = value
	world_flags_changed.emit()


func get_story_flag(flag_id: String, fallback: bool = false) -> bool:
	return bool(story_flags.get(flag_id, fallback))


func set_world_variant(variant_id: String, value: String) -> void:
	var clean_id := variant_id.strip_edges()
	if clean_id.is_empty() or String(world_variants.get(clean_id, "")) == value:
		return
	world_variants[clean_id] = value
	world_flags_changed.emit()


func mark_opened(object_id: String) -> void:
	var clean_id := object_id.strip_edges()
	if clean_id.is_empty() or bool(opened_objects.get(clean_id, false)):
		return
	opened_objects[clean_id] = true
	world_flags_changed.emit()


func is_opened(object_id: String) -> bool:
	return bool(opened_objects.get(object_id, false))


func stage_return_scene(scene_path: String, context: Dictionary = {}) -> void:
	_return_scene_path = scene_path
	_return_context = context.duplicate(true)


func clear_return_scene() -> void:
	_return_scene_path = ""
	_return_context.clear()


func get_return_scene_path(default_path: String = DEFAULT_WORLD_SCENE) -> String:
	return _return_scene_path if not _return_scene_path.is_empty() else default_path


func get_return_context() -> Dictionary:
	return _return_context.duplicate(true)


func to_dict() -> Dictionary:
	return {
		"region": current_region,
		"area": current_area,
		"chunk": [current_chunk.x, current_chunk.y],
		"position": [player_position.x, player_position.y],
		"facing": player_facing,
		"story_flags": story_flags.duplicate(true),
		"world_variants": world_variants.duplicate(true),
		"opened_objects": opened_objects.duplicate(true),
	}


func load_dict(data: Dictionary) -> void:
	if data.is_empty():
		reset_to_defaults()
		return
	current_region = String(data.get("region", DEFAULT_REGION))
	current_area = String(data.get("area", DEFAULT_AREA))
	current_chunk = _vector2i_from_array(data.get("chunk", []), DEFAULT_CHUNK)
	player_position = _vector2_from_array(data.get("position", []), DEFAULT_POSITION)
	player_facing = String(data.get("facing", DEFAULT_FACING))
	story_flags = _dictionary_copy(data.get("story_flags", {}))
	world_variants = _dictionary_copy(data.get("world_variants", {}))
	opened_objects = _dictionary_copy(data.get("opened_objects", {}))
	clear_return_scene()


func _vector2_from_array(raw, fallback: Vector2) -> Vector2:
	if raw is Array and raw.size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return fallback


func _vector2i_from_array(raw, fallback: Vector2i) -> Vector2i:
	if raw is Array and raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return fallback


func _dictionary_copy(raw) -> Dictionary:
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
