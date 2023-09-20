extends CharacterBody2D

const SPEED = 300.0

func _ready():
	global_position = Vector2(0,0)
	
func _physics_process(delta):
	move(delta)
	MoveMouse()
	move_and_slide()
	
func move(delta):
	velocity = Vector2.ZERO
	
func MoveMouse():
	if Input.is_action_just_pressed("LeftClick"):
		global_position = Vector2($"../Blocks".selectedTile)
