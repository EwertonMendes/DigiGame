extends Node2D

const ALLY := Color(0.12, 0.88, 1.0, 1.0)
const ALLY_SOFT := Color(0.18, 0.68, 1.0, 1.0)
const ENEMY := Color(1.0, 0.28, 0.22, 1.0)
const SELECTED := Color(1.0, 0.82, 0.20, 1.0)

var active := false
var selected := false
var player_team := true
var _time := 0.0


func _ready() -> void:
	z_index = -2
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

	var base_color := ALLY if player_team else ENEMY
	if selected:
		base_color = SELECTED

	var pulse := (sin(_time * 4.2) + 1.0) * 0.5
	var scale_factor := 1.0 + pulse * 0.055
	var half_w := 31.0 * scale_factor
	var half_h := 15.5 * scale_factor
	var diamond := PackedVector2Array([
		Vector2(0.0, -half_h),
		Vector2(half_w, 0.0),
		Vector2(0.0, half_h),
		Vector2(-half_w, 0.0),
	])

	var glow := base_color
	glow.a = 0.08 + pulse * 0.08
	draw_colored_polygon(diamond, glow)

	var outer := diamond.duplicate()
	outer.append(diamond[0])
	var outer_color := base_color
	outer_color.a = 0.48 + pulse * 0.38
	draw_polyline(outer, outer_color, 2.4, true)

	var inner_w := half_w - 6.0
	var inner_h := half_h - 3.0
	var inner := PackedVector2Array([
		Vector2(0.0, -inner_h), Vector2(inner_w, 0.0),
		Vector2(0.0, inner_h), Vector2(-inner_w, 0.0), Vector2(0.0, -inner_h)
	])
	var inner_color := base_color
	inner_color.a = 0.24 + pulse * 0.22
	draw_polyline(inner, inner_color, 1.0, true)

	# Four short data-like corner ticks make the marker feel less like a generic ring.
	var tick_color := base_color
	tick_color.a = 0.72
	draw_line(Vector2(-half_w - 4.0, -2.0), Vector2(-half_w - 10.0, -5.0), tick_color, 2.0, true)
	draw_line(Vector2(half_w + 4.0, -2.0), Vector2(half_w + 10.0, -5.0), tick_color, 2.0, true)
	draw_line(Vector2(-half_w - 4.0, 2.0), Vector2(-half_w - 10.0, 5.0), tick_color, 2.0, true)
	draw_line(Vector2(half_w + 4.0, 2.0), Vector2(half_w + 10.0, 5.0), tick_color, 2.0, true)

	if active:
		var bob := sin(_time * 3.8) * 2.5
		var marker_y := -68.0 + bob
		var marker := PackedVector2Array([
			Vector2(-7.0, marker_y),
			Vector2(7.0, marker_y),
			Vector2(0.0, marker_y + 9.0),
		])
		var marker_color := base_color
		marker_color.a = 0.95
		draw_colored_polygon(marker, marker_color)
		var halo := base_color
		halo.a = 0.18 + pulse * 0.10
		draw_circle(Vector2(0.0, marker_y + 1.0), 12.0 + pulse * 2.0, halo)
