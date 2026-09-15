extends Control
class_name DigiProceduralIcon

var _kind := "info"
var _accent := Color.WHITE
var _line_width := 2.4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.x <= 0.0 and custom_minimum_size.y <= 0.0:
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
		"brand":
			_draw_brand(center, side)
		"digimon":
			_draw_digimon(center, side, width)
		"book":
			_draw_book(center, side, width)
		"gear":
			_draw_gear(center, side, width)
		"items":
			_draw_items(center, side, width)
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
	var top_y := center.y - side * 0.17
	for layer in range(3):
		var y := top_y + float(layer) * side * 0.14
		draw_arc(Vector2(center.x, y), rx, 0.0, TAU, 28, _accent, width, true)
		if layer < 2:
			draw_line(Vector2(center.x - rx, y), Vector2(center.x - rx, y + side * 0.14), _accent, width, true)
			draw_line(Vector2(center.x + rx, y), Vector2(center.x + rx, y + side * 0.14), _accent, width, true)
	draw_arc(Vector2(center.x, top_y), maxf(1.0, rx * 0.42), 0.0, TAU, 20, _accent, width * 0.75, true)


func _draw_brand(center: Vector2, side: float) -> void:
	var block := side * 0.19
	var gap := side * 0.02
	var step := block + gap
	for offset: Vector2 in [Vector2.ZERO, Vector2(-step, 0.0), Vector2(step, 0.0), Vector2(0.0, -step), Vector2(0.0, step)]:
		var rect := Rect2(center + offset - Vector2.ONE * block * 0.5, Vector2.ONE * block)
		draw_rect(rect, _accent, true)


func _draw_digimon(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.28
	draw_circle(center + Vector2(0.0, s * 0.12), s * 0.62, _accent, false, width, true)
	draw_circle(center + Vector2(-s * 0.60, -s * 0.62), s * 0.25, _accent, true, -1.0, true)
	draw_circle(center + Vector2(0.0, -s * 0.82), s * 0.25, _accent, true, -1.0, true)
	draw_circle(center + Vector2(s * 0.60, -s * 0.62), s * 0.25, _accent, true, -1.0, true)


func _draw_book(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.28
	var left := PackedVector2Array([
		center + Vector2(-s * 0.95, -s * 0.75),
		center + Vector2(-s * 0.12, -s * 0.52),
		center + Vector2(-s * 0.12, s * 0.78),
		center + Vector2(-s * 0.95, s * 0.55),
		center + Vector2(-s * 0.95, -s * 0.75),
	])
	var right := PackedVector2Array([
		center + Vector2(s * 0.95, -s * 0.75),
		center + Vector2(s * 0.12, -s * 0.52),
		center + Vector2(s * 0.12, s * 0.78),
		center + Vector2(s * 0.95, s * 0.55),
		center + Vector2(s * 0.95, -s * 0.75),
	])
	draw_polyline(left, _accent, width, true)
	draw_polyline(right, _accent, width, true)
	draw_line(center + Vector2(0.0, -s * 0.55), center + Vector2(0.0, s * 0.78), _accent, width, true)


func _draw_gear(center: Vector2, side: float, width: float) -> void:
	var outer := side * 0.28
	draw_circle(center, outer * 0.68, _accent, false, width, true)
	draw_circle(center, outer * 0.22, _accent, false, width, true)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * outer * 0.64, center + direction * outer, _accent, width * 1.35, true)


func _draw_items(center: Vector2, side: float, width: float) -> void:
	var s := side * 0.28
	var body := Rect2(center + Vector2(-s * 0.75, -s * 0.20), Vector2(s * 1.50, s * 1.15))
	draw_rect(body, _accent, false, width, true)
	draw_arc(center + Vector2(0.0, -s * 0.18), s * 0.45, PI, TAU, 18, _accent, width, true)
