extends CharacterBody2D

const SPEED = 300.0
const PLAYER_POSITION_DEVIATION = Vector2(0,4)

var initialTileCoords = Vector2(48,70)

func _ready():
	global_position = initialTileCoords - PLAYER_POSITION_DEVIATION
	$AnimationPlayer.play("walk_up")
	
func _physics_process(delta):
	move(delta)
	MoveMouse()
	move_and_slide()
	
func move(delta):
	velocity = Vector2.ZERO
	
func MoveMouse():
	if Input.is_action_just_pressed("LeftClick"):
		global_position = Vector2($"../Blocks".selectedTile) - PLAYER_POSITION_DEVIATION
