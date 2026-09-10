extends Node2D
class_name HubPortal

var _time := 0.0
var _base_position := Vector2.ZERO


func _ready() -> void:
	_base_position = position
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	position = _base_position + Vector2(0.0, sin(_time * 1.8) * 2.0)
	queue_redraw()


func _draw() -> void:
	var pulse := (sin(_time * 2.4) + 1.0) * 0.5
	var center := Vector2(0.0, -40.0)
	draw_circle(center, 31.0 + pulse * 2.0, Color(0.05, 0.13, 0.18, 0.92))
	draw_circle(center, 24.0 + pulse * 1.5, Color(0.08, 0.58, 0.64, 0.30))
	draw_arc(center, 34.0 + pulse * 2.0, -PI * 0.82, PI * 0.82, 42, Color(0.35, 0.86, 0.90, 0.82), 3.0)
	draw_arc(center, 27.0, PI * 0.18, PI * 1.82, 34, Color(0.98, 0.76, 0.16, 0.72), 2.0)
	for index in range(6):
		var angle := _time * (0.7 + float(index) * 0.04) + TAU * float(index) / 6.0
		var radius := 23.0 + float(index % 2) * 8.0
		var mote := center + Vector2(cos(angle), sin(angle)) * radius
		draw_rect(Rect2(mote - Vector2.ONE * 1.5, Vector2.ONE * 3.0), Color(0.78, 0.98, 1.0, 0.65 + pulse * 0.25))
	draw_polygon(
		PackedVector2Array([Vector2(-25.0, -5.0), Vector2(0.0, 7.0), Vector2(25.0, -5.0), Vector2(0.0, -16.0)]),
		PackedColorArray([Color(0.08, 0.69, 0.74, 0.34)])
	)
