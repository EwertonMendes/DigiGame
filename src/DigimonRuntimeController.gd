extends Node2D

signal hovered_digimon_changed(digimon_key: String)

const DatabaseScript = preload("res://src/digimon/DigimonDatabase.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const BATTLE_SPRITE_SCALE := Vector2(1.0, 1.0)

# Temporary encounter/bootstrap data. These descriptors already use the same
# factory path that the future DigiLab, roster save, and encounter generator use.
const PLAYER_ROSTER := [
	{"species": "agumon", "level": 1, "scan": 100},
	{"species": "gabumon", "level": 1, "scan": 100},
	{"species": "greymon", "level": 1, "scan": 100},
]
const ENEMY_ENCOUNTER := [
	{"species": "koromon", "level_min": 1, "level_max": 2, "profile": "wild"},
	{"species": "tanemon", "level_min": 1, "level_max": 2, "profile": "wild"},
	{"species": "veemon", "level_min": 2, "level_max": 3, "profile": "wild"},
]

var player_digimons := ["agumon", "gabumon", "greymon"]
var enemy_digimons := ["koromon", "tanemon", "veemon"]
var _hovered_digimon_key := ""
var _database = DatabaseScript.new()
var _factory = null
var _encounter_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_encounter_rng.randomize()
	if not _database.load_default():
		push_error("Could not initialize Digimon species database")
		return
	_factory = FactoryScript.new(_database)
	_spawn_demo_rosters()


func _process(_delta: float) -> void:
	_update_pointer_hover()


func _spawn_demo_rosters() -> void:
	for descriptor in PLAYER_ROSTER:
		var species_name := String(descriptor.get("species", ""))
		var level := int(descriptor.get("level", 1))
		var scan := int(descriptor.get("scan", 100))
		instantiate_player_digimon(species_name, level, scan)

	for descriptor in ENEMY_ENCOUNTER:
		var species_name := String(descriptor.get("species", ""))
		var min_level := int(descriptor.get("level_min", 1))
		var max_level := maxi(min_level, int(descriptor.get("level_max", min_level)))
		var level := _encounter_rng.randi_range(min_level, max_level)
		var profile := String(descriptor.get("profile", "wild"))
		instantiate_enemy_digimon(species_name, level, profile)


func instantiate_player_digimon(digimon_name: String, level: int = 1, scan_percent: int = 100) -> CharacterBody2D:
	if _factory == null:
		return null
	var instance: DigimonInstance = _factory.create_player_by_name(digimon_name, level, scan_percent)
	return _instantiate_actor(instance, true)


func instantiate_enemy_digimon(digimon_name: String, level: int, profile: String = "wild") -> CharacterBody2D:
	if _factory == null:
		return null
	var instance: DigimonInstance = _factory.create_enemy_by_name(digimon_name, level, profile)
	return _instantiate_actor(instance, false)


func instantiate_from_instance(instance: DigimonInstance, player_controlled: bool, initial_position_override = null) -> CharacterBody2D:
	return _instantiate_actor(instance, player_controlled, initial_position_override)


func _instantiate_actor(instance: DigimonInstance, player_controlled: bool, initial_position_override = null) -> CharacterBody2D:
	if instance == null:
		return null
	var species: Dictionary = _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		push_error("Unknown Digimon species seed: %s" % instance.species_seed)
		return null
	var digimon_name := String(species.get("name", "")).to_lower()
	var digimon_resource := load("res://assets/resources/%s.tres" % digimon_name) as Digimon
	if digimon_resource == null:
		push_error("Could not load Digimon visual resource: %s" % digimon_name)
		return null

	var actor := create_digimon_actor()
	if actor == null:
		return null
	if actor.has_method("bind_digimon_instance"):
		actor.call("bind_digimon_instance", instance, species, player_controlled)
	_set_actor_graphics(digimon_name, digimon_resource, actor, player_controlled, instance.id)
	_set_actor_initial_position(digimon_resource, actor, initial_position_override)
	add_child(actor)
	return actor


func create_digimon_actor() -> CharacterBody2D:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if player_scene == null:
		push_error("Could not load Digimon battle actor scene")
		return null
	return player_scene.instantiate() as CharacterBody2D


func _set_actor_graphics(digimon_name: String, digimon_resource: Digimon, actor: CharacterBody2D, player_controlled: bool, instance_id: String) -> void:
	var digimon_sprite := actor.get_node("Sprite2D") as Sprite2D
	var short_id := instance_id.substr(0, 8)
	actor.name = "%s_%s" % [digimon_name.capitalize(), short_id] if player_controlled else "Enemy_%s_%s" % [digimon_name, short_id]
	actor.set("digimon_key", digimon_name)
	digimon_sprite.texture = digimon_resource.texture
	digimon_sprite.hframes = maxi(1, digimon_resource.sprite_hframes)
	digimon_sprite.vframes = maxi(1, digimon_resource.sprite_vframes)
	digimon_sprite.frame = digimon_resource.initial_frame
	digimon_sprite.flip_h = false
	digimon_sprite.region_enabled = false
	digimon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	digimon_sprite.scale = BATTLE_SPRITE_SCALE
	actor.set("initial_facing", digimon_resource.initial_facing)
	actor.set("sprite_layout", digimon_resource.sprite_layout)
	actor.set("is_player_controlled", player_controlled)


func _set_actor_initial_position(digimon_resource: Digimon, actor: CharacterBody2D, initial_position_override = null) -> void:
	actor.set("PLAYER_POSITION_DEVIATION", digimon_resource.sprite_deviation)
	actor.set("PARTICLES_POSITION_DEVIATION", digimon_resource.particle_deviation)
	var position_value := digimon_resource.initial_position
	if initial_position_override is Vector2 or initial_position_override is Vector2i:
		position_value = Vector2i(initial_position_override)
	actor.set("initialTileCoords", position_value)


func get_database():
	return _database


func get_factory():
	return _factory


func get_battle_digimons() -> Array[Node]:
	var digimons: Array[Node] = []
	for child in get_children():
		if child is CharacterBody2D:
			digimons.append(child)
	return digimons


func get_player_instances() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for actor in get_battle_digimons():
		if not bool(actor.get("is_player_controlled")):
			continue
		var instance = actor.get("digimon_instance")
		if instance is DigimonInstance:
			result.append(instance)
	return result


func get_digimon_at_tile(tile_world_position: Vector2, ignored_digimon: Node = null) -> Node:
	for child in get_children():
		if child == ignored_digimon or not child is CharacterBody2D:
			continue
		if not child.has_method("get_tile_world_position"):
			continue
		var occupied_position := Vector2(child.call("get_tile_world_position"))
		if occupied_position.distance_squared_to(tile_world_position) < 0.25:
			return child
	return null


func is_tile_occupied(tile_world_position: Vector2, ignored_digimon: Node = null) -> bool:
	return get_digimon_at_tile(tile_world_position, ignored_digimon) != null


func get_selected_digimon() -> Node:
	for child in get_children():
		if child is CharacterBody2D and bool(child.get("is_selected")):
			return child
	return null


func get_digimon_under_pointer(world_position: Vector2) -> Node:
	var hovered: CharacterBody2D = null
	for child in get_children():
		if not child is CharacterBody2D or not child.has_method("is_pointer_over"):
			continue
		if not bool(child.call("is_pointer_over", world_position)):
			continue
		if hovered == null or child.global_position.y >= hovered.global_position.y:
			hovered = child
	return hovered


func _update_pointer_hover() -> void:
	if GlobalVariables.TouchInputActive:
		_set_hovered_digimon("")
		return
	var hovered := get_digimon_under_pointer(get_global_mouse_position())
	var next_key := ""
	if hovered != null:
		next_key = String(hovered.get("digimon_key"))
	_set_hovered_digimon(next_key)


func _set_hovered_digimon(digimon_key: String) -> void:
	if digimon_key == _hovered_digimon_key:
		return
	_hovered_digimon_key = digimon_key
	hovered_digimon_changed.emit(digimon_key)
