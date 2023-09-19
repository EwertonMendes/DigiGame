extends CharacterBody2D

const SPEED = 300.0

func _physics_process(delta):
	move(delta)
	MoveMouse()
	move_and_slide()
	
func move(delta):
	velocity = Vector2.ZERO
	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if (dir.x != 0) and (dir.y != 0):
		velocity = (dir*Vector2(2, 1)) * SPEED * delta
	
func MoveMouse():
	if Input.is_action_just_pressed("LeftClick"):
		global_position = Vector2($"../Blocks".selectedTile)
