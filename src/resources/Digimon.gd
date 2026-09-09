extends Resource
class_name Digimon

@export var texture: Texture2D
@export var initial_frame: int
@export var initial_facing: String = "up_right"
@export var sprite_hframes: int = 12
@export var sprite_vframes: int = 1
@export var sprite_layout: String = "directional_12"
@export var sprite_deviation: Vector2
@export var particle_deviation: Vector2
@export var initial_position: Vector2i
@export var type: String
@export var display_name: String
@export var level: int
@export var hp: int
@export var mp: int
@export var attack: int
@export var defense: int
@export var age: int
@export var battles: int
@export var victories: int
@export var defeats: int
