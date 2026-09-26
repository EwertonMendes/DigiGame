extends RefCounted
class_name CentralCityUrbanPlan

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")

const FOUNDATION_HEIGHT := 8.0
const LANDSCAPE_HEIGHT := 7.0
const FOUNDATION_MARGIN := 20.0
const FOUNDATION_TOP := Color(0.68, 0.69, 0.67, 1.0)
const FOUNDATION_SIDE_A := Color(0.34, 0.37, 0.38, 1.0)
const FOUNDATION_SIDE_B := Color(0.25, 0.28, 0.30, 1.0)
const FOUNDATION_BORDER := Color(0.16, 0.19, 0.20, 1.0)
const LANDSCAPE_TOP := Color(0.73, 0.74, 0.71, 1.0)
const LANDSCAPE_ACCENT := Color(0.19, 0.78, 0.86, 1.0)


static func create_service_foundation(
	node_name: String,
	building_footprint: PackedVector2Array,
	accent: Color
) -> Node2D:
	var hull := _convex_hull_without_duplicate(building_footprint)
	var expanded := _expand_polygon(hull, FOUNDATION_MARGIN)
	return _create_raised_platform(
		node_name,
		expanded,
		FOUNDATION_HEIGHT,
		FOUNDATION_TOP,
		accent
	)


static func create_landscape_island(
	node_name: String,
	center: Vector2,
	span: float = 2.45
) -> Dictionary:
	var half_width := CITY.TILE_HALF_WIDTH * span
	var half_height := CITY.TILE_HALF_HEIGHT * span
	var outer := PackedVector2Array([
		center + Vector2(-half_width, 0.0),
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, half_height),
	])
	var root := _create_raised_platform(
		node_name,
		outer,
		LANDSCAPE_HEIGHT,
		LANDSCAPE_TOP,
		LANDSCAPE_ACCENT
	)

	var grass := CITY.create_surface_panel(
		CITY.SURFACE_GRASS,
		center,
		4,
		2,
		1.0,
		Color.WHITE
	)
	grass.name = "GrassBed"
	root.add_child(grass)
	return {
		"root": root,
		"blocker": outer,
	}


static func create_lamp_bay(
	node_name: String,
	center: Vector2,
	accent: Color,
	landscaped: bool = false
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name

	# A lamp should read as installed infrastructure rather than a sprite dropped
	# on the road. Give every post a small flush isometric socket using the same
	# civic materials as building foundations. It stays at ground level so it
	# never competes with the raised building/landscape hierarchy.
	var half_width := 30.0
	var half_height := 15.0
	var outer := PackedVector2Array([
		center + Vector2(-half_width, 0.0),
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, half_height),
	])
	var top_color := Color(0.58, 0.60, 0.59, 1.0)
	var top := CITY.create_paver_polygon(outer, top_color, 0)
	top.name = "PaverSocket"
	root.add_child(top)

	var border := Line2D.new()
	border.name = "SocketBorder"
	var border_points := outer.duplicate()
	border_points.append(outer[0])
	border.points = border_points
	border.width = 2.0
	border.default_color = Color(0.20, 0.23, 0.24, 1.0)
	border.antialiased = false
	border.z_index = 1
	root.add_child(border)

	if landscaped:
		# A narrow planted inset gives civic/plaza lamps the same deliberate
		# landscape integration as the larger tree islands without inventing a
		# flower sprite before its final art is approved.
		var green_half_w := 20.0
		var green_half_h := 9.0
		var green := Polygon2D.new()
		green.name = "LandscapeInset"
		green.polygon = PackedVector2Array([
			center + Vector2(-green_half_w, 0.0),
			center + Vector2(0.0, -green_half_h),
			center + Vector2(green_half_w, 0.0),
			center + Vector2(0.0, green_half_h),
		])
		green.color = Color(0.30, 0.63, 0.20, 1.0)
		green.z_index = 2
		root.add_child(green)

	# The dark mounting socket visually explains where the pole is fixed and
	# prevents the base from looking as though it is hovering over pavement.
	var socket := Polygon2D.new()
	socket.name = "MountingSocket"
	socket.polygon = PackedVector2Array([
		center + Vector2(-9.0, 0.0),
		center + Vector2(0.0, -4.5),
		center + Vector2(9.0, 0.0),
		center + Vector2(0.0, 4.5),
	])
	socket.color = Color(0.12, 0.15, 0.17, 1.0)
	socket.z_index = 3
	root.add_child(socket)

	var accent_line := Line2D.new()
	accent_line.name = "SocketAccent"
	accent_line.points = PackedVector2Array([
		outer[0].lerp(outer[3], 0.25),
		outer[0].lerp(outer[3], 0.78),
	])
	accent_line.width = 2.0
	accent_line.default_color = accent
	accent_line.antialiased = false
	accent_line.z_index = 4
	root.add_child(accent_line)
	return root


static func create_civic_pool_frame(center: Vector2) -> Node2D:
	var root := Node2D.new()
	root.name = "CivicPoolFrame"
	root.z_index = 45

	var outer_half_w := CITY.TILE_HALF_WIDTH * 4.2
	var outer_half_h := CITY.TILE_HALF_HEIGHT * 4.2
	var inner_half_w := CITY.TILE_HALF_WIDTH * 2.2
	var inner_half_h := CITY.TILE_HALF_HEIGHT * 2.2
	var outer := [
		center + Vector2(-outer_half_w, 0.0),
		center + Vector2(0.0, -outer_half_h),
		center + Vector2(outer_half_w, 0.0),
		center + Vector2(0.0, outer_half_h),
	]
	var inner := [
		center + Vector2(-inner_half_w, 0.0),
		center + Vector2(0.0, -inner_half_h),
		center + Vector2(inner_half_w, 0.0),
		center + Vector2(0.0, inner_half_h),
	]
	for index in range(4):
		var next := (index + 1) % 4
		var strip := PackedVector2Array([
			outer[index],
			outer[next],
			inner[next],
			inner[index],
		])
		var platform := _create_raised_platform(
			"Frame_%d" % index,
			strip,
			4.0,
			Color(0.61, 0.63, 0.62, 1.0),
			Color(0.20, 0.78, 0.88, 1.0)
		)
		root.add_child(platform)
	return root


static func _create_raised_platform(
	node_name: String,
	points: PackedVector2Array,
	height: float,
	top_color: Color,
	accent: Color
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = 40
	if points.size() < 3:
		return root

	var centroid := _centroid(points)
	for index in range(points.size()):
		var next := (index + 1) % points.size()
		var a := points[index]
		var b := points[next]
		var midpoint := (a + b) * 0.5
		if midpoint.y < centroid.y - 0.5:
			continue
		var side := Polygon2D.new()
		side.name = "Side_%d" % index
		side.polygon = PackedVector2Array([
			a,
			b,
			b + Vector2(0.0, height),
			a + Vector2(0.0, height),
		])
		side.color = FOUNDATION_SIDE_A if b.x >= a.x else FOUNDATION_SIDE_B
		side.z_index = 0
		root.add_child(side)

	var top := CITY.create_paver_polygon(points, top_color, 1)
	top.name = "Top"
	root.add_child(top)

	var border := Line2D.new()
	border.name = "TopBorder"
	var border_points := points.duplicate()
	border_points.append(points[0])
	border.points = border_points
	border.width = 2.0
	border.default_color = FOUNDATION_BORDER
	border.antialiased = false
	border.z_index = 2
	root.add_child(border)

	for index in range(points.size()):
		var next := (index + 1) % points.size()
		var a := points[index]
		var b := points[next]
		var midpoint := (a + b) * 0.5
		if midpoint.y < centroid.y - 0.5:
			continue
		var accent_line := Line2D.new()
		accent_line.name = "Accent_%d" % index
		accent_line.points = PackedVector2Array([
			a.lerp(b, 0.18),
			a.lerp(b, 0.82),
		])
		accent_line.width = 2.0
		accent_line.default_color = accent
		accent_line.antialiased = false
		accent_line.z_index = 3
		root.add_child(accent_line)
	return root


static func _convex_hull_without_duplicate(points: PackedVector2Array) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 2 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		var trimmed := PackedVector2Array()
		for index in range(hull.size() - 1):
			trimmed.append(hull[index])
		return trimmed
	return hull


static func _expand_polygon(points: PackedVector2Array, margin: float) -> PackedVector2Array:
	var center := _centroid(points)
	var expanded := PackedVector2Array()
	for point: Vector2 in points:
		var direction := point - center
		if direction.length_squared() < 0.001:
			expanded.append(point)
		else:
			expanded.append(point + direction.normalized() * margin)
	return expanded


static func _centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var result := Vector2.ZERO
	for point: Vector2 in points:
		result += point
	return result / float(points.size())
