extends Node2D

const BATTLE_SPRITE_SCALE := Vector2(1.0, 1.0)
const DIRECTIONAL_FRAME_COUNT := 12

var digimons_to_instantiate := ["agumon", "gabumon", "greymon"]

func _ready() -> void:
	for digimon in digimons_to_instantiate:
		instantiate_digimon(digimon)

func instantiate_digimon(digimon_name: String) -> void:
	var digimon_resource := load("res://assets/resources/%s.tres" % digimon_name) as Digimon
	if digimon_resource == null:
		push_error("Could not load Digimon resource: %s" % digimon_name)
		return

	var digimon_instance := create_digimon_instance()
	if digimon_instance == null:
		return

	set_digimon_name_and_graphics(digimon_name, digimon_resource, digimon_instance)
	set_digimon_initial_position(digimon_resource, digimon_instance)
	add_child(digimon_instance)

func create_digimon_instance() -> CharacterBody2D:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if player_scene == null:
		push_error("Could not load player scene")
		return null
	return player_scene.instantiate() as CharacterBody2D

func set_digimon_name_and_graphics(digimon_name: String, digimon_resource: Digimon, digimon_instance: CharacterBody2D) -> void:
	var digimon_sprite := digimon_instance.get_node("Sprite2D") as Sprite2D

	digimon_instance.name = digimon_name
	digimon_sprite.texture = digimon_resource.texture
	digimon_sprite.hframes = DIRECTIONAL_FRAME_COUNT
	digimon_sprite.frame = digimon_resource.initial_frame
	digimon_sprite.flip_h = false
	digimon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	digimon_sprite.scale = BATTLE_SPRITE_SCALE
	digimon_instance.set("initial_facing", digimon_resource.initial_facing)

func set_digimon_initial_position(digimon_resource: Digimon, digimon_instance: CharacterBody2D) -> void:
	digimon_instance.set("PLAYER_POSITION_DEVIATION", digimon_resource.sprite_deviation)
	digimon_instance.set("PARTICLES_POSITION_DEVIATION", digimon_resource.particle_deviation)
	digimon_instance.set("initialTileCoords", digimon_resource.initial_position)
