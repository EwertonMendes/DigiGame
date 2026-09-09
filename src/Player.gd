extends CharacterBody2D

var PLAYER_POSITION_DEVIATION := Vector2.ZERO
var PARTICLES_POSITION_DEVIATION := Vector2.ZERO
var initialTileCoords := Vector2.ZERO

var is_selected := false
var selected_tile_coords := Vector2i.ZERO
var animation_player: AnimationPlayer

func _ready() -> void:
	global_position = Vector2(initialTileCoords) + PLAYER_POSITION_DEVIATION
	animation_player = get_node("AnimationPlayer") as AnimationPlayer
	animation_player.play("Idle")

func _physics_process(_delta: float) -> void:
	selected_tile_coords = GlobalVariables.SelectedTileCoords

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not mouse_event.pressed and not is_digimon_position_clicked() and not is_selected:
		is_selected = false
		animation_player.play("Idle")
		emit_particles_when_selected()
		return

	if mouse_event.pressed and is_selected:
		is_selected = false
		animation_player.play("Idle")
		move_digimon_position()
		emit_particles_when_selected()
		return

	if mouse_event.pressed and is_digimon_position_clicked():
		is_selected = true
		emit_particles_when_selected()
		move_camera_to_selected_digimon()
		mouse_event.position = Vector2.ZERO
		animation_player.play("walk_up")

func is_digimon_position_clicked() -> bool:
	return Vector2(selected_tile_coords) == global_position - PLAYER_POSITION_DEVIATION

func move_digimon_position() -> void:
	global_position = Vector2(selected_tile_coords) + PLAYER_POSITION_DEVIATION

func emit_particles_when_selected() -> void:
	var particles := get_node("Sprite2D/CPUParticles2D") as CPUParticles2D
	particles.position = to_local(global_position) + PARTICLES_POSITION_DEVIATION
	particles.emitting = is_selected

func move_camera_to_selected_digimon() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		camera.global_position = global_position
