extends Node
class_name AreaStreamer

signal current_chunk_changed(chunk: Vector2i)
signal chunk_loaded(chunk: Vector2i)
signal chunk_unloaded(chunk: Vector2i)

const CHUNK_SCENE_PATH := "res://scenes/world/world_chunk.tscn"
const CHUNK_SIZE := 14
const ACTIVE_RADIUS := 1
const PRELOAD_RADIUS := 2
const UNLOAD_RADIUS := 2
const UPDATE_INTERVAL := 0.10

var _player: Node2D = null
var _world_controller: Node = null
var _chunks_root: Node2D = null
var _definitions: Dictionary = {}
var _loaded: Dictionary = {}
var _queued_coords: Array[Vector2i] = []
var _chunk_scene: PackedScene = null
var _current_chunk := Vector2i(999999, 999999)
var _elapsed := 0.0
var _suspended := false


func configure(area_definition: Dictionary, player: Node2D, chunks_root: Node2D, world_controller: Node) -> void:
	_player = player
	_chunks_root = chunks_root
	_world_controller = world_controller
	_chunk_scene = load(CHUNK_SCENE_PATH) as PackedScene
	if _chunk_scene == null:
		push_error("World chunk scene could not be loaded")
		return
	_definitions.clear()
	var raw_chunks = area_definition.get("chunks", [])
	if raw_chunks is Array:
		for raw in raw_chunks:
			if not raw is Dictionary:
				continue
			var definition := (raw as Dictionary).duplicate(true)
			var raw_coord = definition.get("coord", [0, 0])
			var coord := Vector2i(int(raw_coord[0]), int(raw_coord[1]))
			_definitions[_coord_key(coord)] = definition
	_current_chunk = world_to_chunk(_player.global_position)
	_prime_active_ring(_current_chunk)
	_queue_preload_ring(_current_chunk)
	current_chunk_changed.emit(_current_chunk)


func _process(delta: float) -> void:
	if _suspended or _player == null or _chunks_root == null or _chunk_scene == null:
		return
	if not _queued_coords.is_empty():
		var coord: Vector2i = _queued_coords.pop_front()
		if _chebyshev(coord, _current_chunk) <= ACTIVE_RADIUS:
			_instantiate_chunk(coord)
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = 0.0
	var next_chunk := world_to_chunk(_player.global_position)
	if next_chunk != _current_chunk:
		_current_chunk = next_chunk
		current_chunk_changed.emit(_current_chunk)
		_queue_preload_ring(_current_chunk)
		_unload_far_chunks()
	else:
		_queue_preload_ring(_current_chunk)


func get_current_chunk() -> Vector2i:
	return _current_chunk


func set_suspended(value: bool) -> void:
	_suspended = value


func is_suspended() -> bool:
	return _suspended


func refresh_around_player() -> void:
	if _player == null or _chunk_scene == null:
		return
	var next_chunk := world_to_chunk(_player.global_position)
	_current_chunk = next_chunk
	_prime_active_ring(_current_chunk)
	_queue_preload_ring(_current_chunk)
	_unload_far_chunks()
	current_chunk_changed.emit(_current_chunk)


func get_loaded_chunk_count() -> int:
	return _loaded.size()


func has_authored_chunk(coord: Vector2i) -> bool:
	return _definitions.has(_coord_key(coord))


func is_walkable_world_position(world_position: Vector2) -> bool:
	var coord := world_to_chunk(world_position)
	if not has_authored_chunk(coord):
		return false
	var loaded = _loaded.get(_coord_key(coord))
	if loaded != null and is_instance_valid(loaded) and loaded.has_method("is_walkable_world_position"):
		return bool(loaded.call("is_walkable_world_position", world_position))
	return true


func world_to_chunk(world_position: Vector2) -> Vector2i:
	var grid := Vector2(
		world_position.x / 64.0 + world_position.y / 32.0,
		-world_position.x / 64.0 + world_position.y / 32.0
	)
	return Vector2i(floori(grid.x / float(CHUNK_SIZE)), floori(grid.y / float(CHUNK_SIZE)))


func _prime_active_ring(center: Vector2i) -> void:
	for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dy in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			_instantiate_chunk(center + Vector2i(dx, dy))


func _queue_preload_ring(center: Vector2i) -> void:
	for dx in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
		for dy in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
			var coord := center + Vector2i(dx, dy)
			var key := _coord_key(coord)
			if not _definitions.has(key) or _loaded.has(key) or _queued_coords.has(coord):
				continue
			_queued_coords.append(coord)
	_queued_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chebyshev(a, center) < _chebyshev(b, center)
	)


func _instantiate_chunk(coord: Vector2i) -> void:
	var key := _coord_key(coord)
	if _loaded.has(key) or not _definitions.has(key) or _chunk_scene == null:
		return
	var instance := _chunk_scene.instantiate()
	if instance == null or not instance.has_method("configure"):
		push_error("World chunk scene must implement the WorldChunk configuration contract")
		if instance != null:
			instance.queue_free()
		return
	instance.call("configure", _definitions[key] as Dictionary, _player, _world_controller)
	_chunks_root.add_child(instance)
	_loaded[key] = instance
	chunk_loaded.emit(coord)


func _unload_far_chunks() -> void:
	for key in _loaded.keys().duplicate():
		var chunk = _loaded[key]
		if chunk == null or not is_instance_valid(chunk):
			_loaded.erase(key)
			continue
		var coord: Vector2i = chunk.get("chunk_coord")
		if _chebyshev(coord, _current_chunk) <= UNLOAD_RADIUS:
			continue
		_loaded.erase(key)
		chunk.queue_free()
		chunk_unloaded.emit(coord)


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _coord_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]
