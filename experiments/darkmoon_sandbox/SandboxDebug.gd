extends Node2D

var sandbox: Node2D


func _draw() -> void:
	if sandbox == null:
		return
	for region: Polygon2D in sandbox.get_node("Walkable").get_children():
		var points := PackedVector2Array()
		for point: Vector2 in region.polygon:
			points.append(region.position + point)
		draw_colored_polygon(points, Color(0.2, 0.9, 0.65, 0.16))
		points.append(points[0])
		draw_polyline(points, Color(0.3, 1.0, 0.7, 0.8), 2.0)
	for entity: Node2D in sandbox.get_node("Depth").get_children():
		var base := entity.get_node_or_null("Footprint") as Polygon2D
		if base == null:
			continue
		var points := PackedVector2Array()
		for point: Vector2 in base.polygon:
			points.append(entity.position + base.position + point)
		draw_colored_polygon(points, Color(1.0, 0.35, 0.4, 0.45))
		points.append(points[0])
		draw_polyline(points, Color(1.0, 0.5, 0.5), 2.0)
	if sandbox.player != null:
		var center: Vector2 = sandbox.player.position + Vector2(0, -11)
		draw_circle(center, 11.0, Color(1.0, 0.9, 0.4, 0.9), false, 2.0)
