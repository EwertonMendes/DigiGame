extends Control
class_name DigiProceduralIcon

var _kind := "info"
var _accent := Color.WHITE
var _line_width := 2.4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32.0, 32.0)
	queue_redraw()


func configure(kind: String, accent: Color, line_width: float = 2.4) -> DigiProceduralIcon:
	_kind = kind
	_accent = accent
	_line_width = line_width
	queue_redraw()
	return self


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 1.0:
		return
	var center := size * 0.5
	var scale := side / 32.0
	var width := maxf(1.4, _line_width * scale)
	match _kind:
		"heart":
			_draw_heart(center, side, width)
		"bolt":
			_draw_bolt(center, side, width)
		"sword":
			_draw_sword(center, side, width)
		"shield":
			_draw_shield(center, side, width)
		"spark":
			_draw_spark(center, side, width)
		"speed":
			_draw_speed(center, side, width)
		"move":
			_draw_move(center, side, width)
		"techniques":
			_draw_techniques(center, side, width)
		"evolution":
			_draw_evolution(center, side, width)
		"training":
			_draw_training(center, side, width)
		"link":
			_draw_link(center, side, width)
		"bits":
			_draw_bits(center, side, width)
		_:
			draw_circle(center, side * 0.18, _accent, false, width, true)
			draw_line(center + Vector2(0.0, side * 0.03), center + Vector2(0.0, side * 0.20), _accent, width, true)


func _draw_heart(center: Vector2, side: float, _width: float) -> void:
	var r := side * 0.14
	var left := center + Vector2(-r * 0.78, -r * 0.42)
	var right := center + Vector2(r * 0.78, -r * 0.42)
	draw_circle(left, r, _accent, true, -1.0, true)
	draw_circle(right, r, _accent, true, -1.0, true)
	var points := PackedVector2Array([
		center + Vector2(-r * 1.62, -r * 0.28),
		center + Vector2(r * 1.62, -r * 0.28),
		center + Vector2(0.0, r * 2.15),
	])
	draw_colored_polygon(points, _accent)


func _draw_bolt(center: Vector2, side: float, _width: float) -> void:
	var s := side * 0.34
	var points := PackedVector2Array([
		center + Vector2(s * 0.10, -s),
		center + Vector2(-s * 0.58, s * 0.05),
		center + Vector2(-s * 0.08, s * 0.03),
		center + Vector2(-s * 0.24, s),
		center + Vector2(s * 0.62, -s * 0.12),
		center + Vector2(s * 0.12, -s * 0.10),
	])
	draw_colored_polygon(points, _accent)


func _draw_sword(center: Vector2, side: float, width: float) -> void:
	var d := side * 0.27
	draw_line(center + Vector2(-d, d), center + Vector2(d, -d), _accent, width * 1.18, true)
	draw_line(center + Vector2(-d * 0.45, d * 0.10), center + Vector2(-d * 0.05, d * 0.50), _accent, width, true)
	draw_line(center + Vector2(-d * 0.95, d * 0.95), center + Vector2(-d * 0.55, d * 0.55), _accent, width * 1.35, true)
	var tip := PackedVector2Array([
		center + Vector2(d, -d),
		center + Vector2(d * 0.56, -d * 0.88),
		center + Vector2(d * 0.88, -d * 0.56),
	])
	draw_colored_polygon(tip, _accent)


func _draw_shield(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.30
	var points := PackedVector2Array([
		center + Vector2(0.0, -s),
		center + Vector2(s * 0.78, -s * 0.58),
		center + Vector2(s * 0.64, s * 0.42),
		center + Vector2(0.0, s),
		center + Vector2(-s * 0.64, s * 0.42),
		center + Vector2(-s * 0.78, -s * 0.58),
		center + Vector2(0.0, -s),
	])
	draw_polyline(points, _accent, width, true)


func _draw_spark(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.31
	draw_line(center + Vector2(0.0, -s), center + Vector2(0.0, s), _accent, width, true)
	draw_line(center + Vector2(-s, 0.0), center + Vector2(s, 0.0), _accent, width, true)
	draw_line(center + Vector2(-s * 0.60, -s * 0.60), center + Vector2(s * 0.60, s * 0.60), _accent, width * 0.72, true)
	draw_line(center + Vector2(s * 0.60, -s * 0.60), center + Vector2(-s * 0.60, s * 0.60), _accent, width * 0.72, true)


func _draw_speed(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.32
	draw_arc(center + Vector2(s * 0.10, 0.0), s * 0.64, -2.1, 2.1, 22, _accent, width, true)
	draw_line(center + Vector2(-s, -s * 0.55), center + Vector2(-s * 0.28, -s * 0.55), _accent, width, true)
	draw_line(center + Vector2(-s * 1.08, 0.0), center + Vector2(-s * 0.38, 0.0), _accent, width, true)
	draw_line(center + Vector2(-s, s * 0.55), center + Vector2(-s * 0.28, s * 0.55), _accent, width, true)


func _draw_move(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.30
	draw_line(center + Vector2(-s, 0.0), center + Vector2(s, 0.0), _accent, width, true)
	draw_line(center + Vector2(0.0, -s), center + Vector2(0.0, s), _accent, width, true)
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for direction: Vector2 in directions:
		var tip: Vector2 = center + direction * s
		var tangent: Vector2 = Vector2(-direction.y, direction.x)
		draw_line(tip, tip - direction * s * 0.34 + tangent * s * 0.22, _accent, width, true)
		draw_line(tip, tip - direction * s * 0.34 - tangent * s * 0.22, _accent, width, true)


func _draw_techniques(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.29
	draw_arc(center, s, -0.35, 4.25, 30, _accent, width, true)
	draw_arc(center, s * 0.56, 2.3, 6.35, 24, _accent, width, true)
	draw_circle(center + Vector2(s * 0.10, -s * 0.04), s * 0.10, _accent, true, -1.0, true)


func _draw_evolution(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.26
	var top := center + Vector2(0.0, -s * 0.86)
	var left := center + Vector2(-s, s * 0.76)
	var right := center + Vector2(s, s * 0.76)
	draw_line(top, left, _accent, width, true)
	draw_line(top, right, _accent, width, true)
	draw_circle(top, s * 0.30, _accent, false, width, true)
	draw_circle(left, s * 0.30, _accent, false, width, true)
	draw_circle(right, s * 0.30, _accent, false, width, true)


func _draw_training(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.30
	draw_line(center + Vector2(-s * 0.62, 0.0), center + Vector2(s * 0.62, 0.0), _accent, width, true)
	var marker_offsets: Array[float] = [-s, -s * 0.72, s * 0.72, s]
	for x: float in marker_offsets:
		draw_line(center + Vector2(x, -s * 0.52), center + Vector2(x, s * 0.52), _accent, width * 1.18, true)


func _draw_link(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.24
	draw_arc(center + Vector2(-s * 0.52, 0.0), s * 0.62, -0.9, 0.9, 18, _accent, width, true)
	draw_arc(center + Vector2(s * 0.52, 0.0), s * 0.62, 2.25, 4.03, 18, _accent, width, true)
	draw_line(center + Vector2(-s * 0.20, -s * 0.16), center + Vector2(s * 0.20, s * 0.16), _accent, width, true)


func _draw_bits(center: Vector2, side: float, width: float) -> void:
	var rx := side * 0.27
	var ry := side * 0.095
	var top_y := center.y - side * 0.17
	for layer in range(3):
		var y := top_y + float(layer) * side * 0.14
		draw_arc(Vector2(center.x, y), rx, 0.0, TAU, 28, _accent, width, true)
		if layer < 2:
			draw_line(Vector2(center.x - rx, y), Vector2(center.x - rx, y + side * 0.14), _accent, width, true)
			draw_line(Vector2(center.x + rx, y), Vector2(center.x + rx, y + side * 0.14), _accent, width, true)
	# Small inner mark keeps the icon readable even at compact header sizes.
	draw_arc(Vector2(center.x, top_y), maxf(1.0, rx * 0.42), 0.0, TAU, 20, _accent, width * 0.75, true)
