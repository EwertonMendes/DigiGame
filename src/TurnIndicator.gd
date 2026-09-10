extends Node2D

const ALLY := Color(0.12, 0.88, 1.0, 1.0)
const ENEMY := Color(1.0, 0.28, 0.22, 1.0)
const SELECTED := Color(1.0, 0.82, 0.20, 1.0)

var active := false
var selected := false
var player_team := true
var _time := 0.0


func _ready() -> void:
	# The turn marker is intentionally kept above the unit. Movement/range
	# feedback belongs to the board, so there is no persistent ground marker.
	z_index = 6
	z_as_relative = true
	queue_redraw()


func _process(delta: float) -> void:
	if not active and not selected:
		visible = false
		return
	visible = true
	_time += delta
	queue_redraw()


func set_state(is_active: bool, is_selected: bool, is_player_team: bool) -> void:
	active = is_active
	selected = is_selected
	player_team = is_player_team
	visible = active or selected
	queue_redraw()


func _draw() -> void:
	if not active and not selected:
		return

	var marker_color := ALLY if player_team else ENEMY
	if selected:
		marker_color = SELECTED

	var pulse := (sin(_time * 4.2) + 1.0) * 0.5
	var bob := sin(_time * 3.8) * 2.5
	var marker_y := -68.0 + bob

	# A single floating arrow is enough to communicate the active unit without
	# competing with movement tiles or obscuring small field sprites.
	var glow := marker_color
	glow.a = 0.16 + pulse * 0.08
	var glow_arrow := PackedVector2Array([
		Vector2(-10.0, marker_y - 2.0),
		Vector2(10.0, marker_y - 2.0),
		Vector2(0.0, marker_y + 12.0),
	])
	draw_colored_polygon(glow_arrow, glow)

	var arrow := PackedVector2Array([
		Vector2(-7.0, marker_y),
		Vector2(7.0, marker_y),
		Vector2(0.0, marker_y + 9.0),
	])
	var fill := marker_color
	fill.a = 0.92 + pulse * 0.08
	draw_colored_polygon(arrow, fill)

	var highlight := Color(1.0, 1.0, 1.0, 0.68)
	draw_line(Vector2(-4.5, marker_y + 1.0), Vector2(4.5, marker_y + 1.0), highlight, 1.0, true)
