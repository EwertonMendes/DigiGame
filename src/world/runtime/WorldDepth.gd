extends RefCounted
class_name WorldDepth

# World actors, props and movable architecture must resolve depth from the same
# presentation-space ground Y. Keeping this contract in one place prevents a
# service building from changing front/back behavior when its authored anchor
# moves to another part of the map or another elevation.
const BASE_Z := 1000


static func z_for_ground_y(world_y: float, elevation_px: float = 0.0) -> int:
	return BASE_Z + int(round(world_y - elevation_px))


static func span_for_local_polygon(
	owner_world_y: float,
	polygon: PackedVector2Array,
	elevation_px: float = 0.0,
	padding: int = 1
) -> Vector2i:
	if polygon.is_empty():
		var anchor_depth := z_for_ground_y(owner_world_y, elevation_px)
		return Vector2i(anchor_depth - padding, anchor_depth + padding)

	var min_world_y := INF
	var max_world_y := -INF
	for point: Vector2 in polygon:
		var world_y := owner_world_y + point.y
		min_world_y = minf(min_world_y, world_y)
		max_world_y = maxf(max_world_y, world_y)

	return Vector2i(
		z_for_ground_y(min_world_y, elevation_px) - padding,
		z_for_ground_y(max_world_y, elevation_px) + padding
	)
