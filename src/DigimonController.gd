extends Node2D

signal hovered_digimon_changed(digimon_key: String)

const BATTLE_SPRITE_SCALE := Vector2(1.0, 1.0)

var player_digimons := ["agumon", "gabumon", "greymon"]
var enemy_digimons := ["koromon", "tanemon", "veemon"]
var _hovered_digimon_key := ""


func _ready() -> void:
	for digimon in player_digimons:
		instantiate_digimon(digimon, true)
	for digimon in enemy_digimons:
		instantiate_digimon(digimon, false)


func _process(_delta: float) -> void:
	_update_pointer_hover()


func instantiate_digimon(digimon_name: String, player_controlled: bool) -> void:
	var digimon_resource := load("res://assets/resources/%s.tres" % digimon_name) as Digimon
	if digimon_resource == null:
		push_error("Could not load Digimon resource: %s" % digimon_name)
		return
	var digimon_instance := create_digimon_instance()
	if digimon_instance == null:
		return
	set_digimon_name_and_graphics(digimon_name, digimon_resource, digimon_instance, player_controlled)
	set_digimon_initial_position(digimon_resource, digimon_instance)
	add_child(digimon_instance)


func create_digimon_instance() -> CharacterBody2D:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if player_scene == null:
		push_error("Could not load player scene")
		return null
	return player_scene.instantiate() as CharacterBody2D


func set_digimon_name_and_graphics(digimon_name: String, digimon_resource: Digimon, digimon_instance: CharacterBody2D, player_controlled: bool) -> void:
	var digimon_sprite := digimon_instance.get_node("Sprite2D") as Sprite2D
	digimon_instance.name = digimon_name if player_controlled else "Enemy_%s" % digimon_name
	digimon_instance.set("digimon_key", digimon_name.to_lower())
	digimon_sprite.texture = digimon_resource.texture
	digimon_sprite.hframes = maxi(1, digimon_resource.sprite_hframes)
	digimon_sprite.vframes = maxi(1, digimon_resource.sprite_vframes)
	digimon_sprite.frame = digimon_resource.initial_frame
	digimon_sprite.flip_h = false
	digimon_sprite.region_enabled = false
	digimon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	digimon_sprite.scale = BATTLE_SPRITE_SCALE
	digimon_instance.set("initial_facing", digimon_resource.initial_facing)
	digimon_instance.set("sprite_layout", digimon_resource.sprite_layout)
	digimon_instance.set("is_player_controlled", player_controlled)


func set_digimon_initial_position(digimon_resource: Digimon, digimon_instance: CharacterBody2D) -> void:
	digimon_instance.set("PLAYER_POSITION_DEVIATION", digimon_resource.sprite_deviation)
	digimon_instance.set("PARTICLES_POSITION_DEVIATION", digimon_resource.particle_deviation)
	digimon_instance.set("initialTileCoords", digimon_resource.initial_position)


func is_tile_occupied(tile_world_position: Vector2, ignored_digimon: Node = null) -> bool:
	for child in get_children():
		if child == ignored_digimon or not child is CharacterBody2D:
			continue
		if not child.has_method("get_tile_world_position"):
			continue
		var occupied_position := Vector2(child.call("get_tile_world_position"))
		if occupied_position.distance_squared_to(tile_world_position) < 0.25:
			return true
	return false


func get_selected_digimon() -> Node:
	for child in get_children():
		if child is CharacterBody2D and bool(child.get("is_selected")):
			return child
	return null


func _update_pointer_hover() -> void:
	if GlobalVariables.TouchInputActive:
		_set_hovered_digimon("")
		return

	var pointer := get_global_mouse_position()
	var hovered: CharacterBody2D = null
	for child in get_children():
		if not child is CharacterBody2D or not child.has_method("is_pointer_over"):
			continue
		if not bool(child.call("is_pointer_over", pointer)):
			continue
		if hovered == null or child.global_position.y >= hovered.global_position.y:
			hovered = child

	var next_key := ""
	if hovered != null:
		next_key = String(hovered.get("digimon_key"))
	_set_hovered_digimon(next_key)


func _set_hovered_digimon(digimon_key: String) -> void:
	if digimon_key == _hovered_digimon_key:
		return
	_hovered_digimon_key = digimon_key
	hovered_digimon_changed.emit(digimon_key)
