extends RefCounted
class_name CentralCityRoadGeometry

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const EPSILON := 0.001


static func corridor_grid_polygon(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var half := maxf(0.0, width) * 0.5
	if absf(a.x - b.x) <= EPSILON:
		var y0 := minf(a.y, b.y) - half
		var y1 := maxf(a.y, b.y) + half
		return PackedVector2Array([
			Vector2(a.x - half, y0),
			Vector2(a.x + half, y0),
			Vector2(a.x + half, y1),
			Vector2(a.x - half, y1),
		])
	if absf(a.y - b.y) <= EPSILON:
		var x0 := minf(a.x, b.x) - half
		var x1 := maxf(a.x, b.x) + half
		return PackedVector2Array([
			Vector2(x0, a.y - half),
			Vector2(x1, a.y - half),
			Vector2(x1, a.y + half),
			Vector2(x0, a.y + half),
		])

	var world_a := grid_to_world(a)
	var world_b := grid_to_world(b)
	var direction := world_b - world_a
	if direction.length_squared() <= EPSILON:
		return PackedVector2Array()
	var projected_width := width * sqrt(TILE_HALF_WIDTH * TILE_HALF_WIDTH + TILE_HALF_HEIGHT * TILE_HALF_HEIGHT)
	var normal := direction.normalized().orthogonal() * projected_width * 0.5
	return PackedVector2Array([
		world_to_grid(world_a + normal),
		world_to_grid(world_b + normal),
		world_to_grid(world_b - normal),
		world_to_grid(world_a - normal),
	])


static func width_handle_grid(a: Vector2, b: Vector2, width: float) -> Vector2:
	var midpoint := (a + b) * 0.5
	var half := maxf(0.0, width) * 0.5
	if absf(a.x - b.x) <= EPSILON:
		return midpoint + Vector2(half, 0.0)
	if absf(a.y - b.y) <= EPSILON:
		return midpoint + Vector2(0.0, half)
	var corridor := corridor_grid_polygon(a, b, width)
	if corridor.size() < 2:
		return midpoint
	return (corridor[0] + corridor[1]) * 0.5


static func width_from_grid_point(a: Vector2, b: Vector2, point: Vector2) -> float:
	var midpoint := (a + b) * 0.5
	if absf(a.x - b.x) <= EPSILON:
		return absf(point.x - midpoint.x) * 2.0
	if absf(a.y - b.y) <= EPSILON:
		return absf(point.y - midpoint.y) * 2.0

	var world_a := grid_to_world(a)
	var world_b := grid_to_world(b)
	var world_point := grid_to_world(point)
	var direction := (world_b - world_a).normalized()
	if direction.length_squared() <= EPSILON:
		return 0.0
	var normal := direction.orthogonal()
	var half_world := absf((world_point - (world_a + world_b) * 0.5).dot(normal))
	var world_per_grid_width := sqrt(TILE_HALF_WIDTH * TILE_HALF_WIDTH + TILE_HALF_HEIGHT * TILE_HALF_HEIGHT)
	return half_world * 2.0 / world_per_grid_width


static func grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_HALF_WIDTH,
		(grid.x + grid.y) * TILE_HALF_HEIGHT
	)


static func world_to_grid(world: Vector2) -> Vector2:
	return Vector2(
		world.x / TILE_WIDTH + world.y / TILE_HEIGHT,
		-world.x / TILE_WIDTH + world.y / TILE_HEIGHT
	)
