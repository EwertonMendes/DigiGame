extends Node2D

var DigimonsToInstantiate := ["agumon", "greymon"]

func _ready() -> void:
	for digimon in DigimonsToInstantiate:
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
	var animation_scene := load("res://scenes/animations/%s_animations.tscn" % digimon_name) as PackedScene
	var animation_instance := animation_scene.instantiate() as AnimationPlayer

	digimon_instance.name = digimon_name
	digimon_sprite.texture = digimon_resource.Texture
	digimon_sprite.frame = digimon_resource.InitialFrame
	digimon_sprite.scale = Vector2(0.5, 0.5)
	digimon_instance.add_child(animation_instance)

func set_digimon_initial_position(digimon_resource: Digimon, digimon_instance: CharacterBody2D) -> void:
	digimon_instance.set("PLAYER_POSITION_DEVIATION", digimon_resource.SpriteDeviation)
	digimon_instance.set("PARTICLES_POSITION_DEVIATION", digimon_resource.ParticleDeviation)
	digimon_instance.set("initialTileCoords", digimon_resource.InitialPosition)
