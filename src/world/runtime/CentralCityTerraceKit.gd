extends RefCounted
class_name CentralCityTerraceKit

const BATCH = preload("res://src/world/runtime/IsometricSpriteBatch.gd")
const TOPOLOGY = preload("res://src/world/runtime/CentralCityTopology.gd")
const MANIFEST_PATH := "res://assets/world/central_city/terrace/manifest.json"

static var _catalog: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary:
			_catalog = (parsed as Dictionary).get("assets", {})
	return _catalog


static func build(specs: Array[Dictionary], node_name: String, z: int) -> Node2D:
	return BATCH.build(specs, catalog(), node_name, z)


static func append_stair(specs: Array[Dictionary], quad: PackedVector2Array, from_level: String, to_level: String) -> void:
	var travel := ((quad[3] - quad[0]) + (quad[2] - quad[1])) * 0.5
	var suffix := ("se" if travel.x >= 0.0 else "nw") if absf(travel.x) > absf(travel.y) else ("sw" if travel.y >= 0.0 else "ne")
	var asset_id := "stair_%s" % suffix
	var aligned := _align_cross(quad, asset_id)
	var points := PackedVector2Array([
		TOPOLOGY.grid_to_display(aligned[0], from_level),
		TOPOLOGY.grid_to_display(aligned[1], from_level),
		TOPOLOGY.grid_to_display(aligned[2], to_level),
		TOPOLOGY.grid_to_display(aligned[3], to_level),
	])
	specs.append({"asset": asset_id, "points": points})


static func append_bridge(specs: Array[Dictionary], quad: PackedVector2Array, level: String) -> void:
	var travel := ((quad[3] - quad[0]) + (quad[2] - quad[1])) * 0.5
	var axis := "x" if absf(travel.x) > absf(travel.y) else "y"
	var forward := travel.x >= 0.0 if axis == "x" else travel.y >= 0.0
	var directed := quad if forward else PackedVector2Array([quad[3], quad[2], quad[1], quad[0]])
	var asset_id := "bridge_%s" % axis
	var aligned := _align_cross(directed, asset_id)
	var points := PackedVector2Array()
	for grid: Vector2 in aligned:
		points.append(TOPOLOGY.grid_to_display(grid, level))
	specs.append({"asset": asset_id, "points": points})


static func append_edge(specs: Array[Dictionary], family: String, start: Vector2, end: Vector2, height: float) -> void:
	if start.x > end.x:
		var previous := start
		start = end
		end = previous
	var axis := "x" if end.y >= start.y else "y"
	var count := maxi(1, int(ceil(start.distance_to(end) / 72.0)))
	for index in range(count):
		var a := start.lerp(end, float(index) / float(count))
		var b := start.lerp(end, float(index + 1) / float(count))
		var up := Vector2(0.0, -height)
		specs.append({
			"asset": "%s_%s" % [family, axis],
			"points": PackedVector2Array([a, b, b + up, a + up]),
		})


static func append_post(specs: Array[Dictionary], foot: Vector2, height: float = 22.0) -> void:
	var asset := catalog().get("post", {}) as Dictionary
	var source := asset.get("anchors", []) as Array
	if source.size() != 4:
		return
	var a := Vector2(float(source[0][0]), float(source[0][1]))
	var b := Vector2(float(source[1][0]), float(source[1][1]))
	var d := Vector2(float(source[3][0]), float(source[3][1]))
	var scale_value := height / maxf(1.0, a.y - d.y)
	var half_width := (b.x - a.x) * scale_value * 0.5
	var left := foot - Vector2(half_width, 0.0)
	var right := foot + Vector2(half_width, 0.0)
	var up := Vector2(0.0, -height)
	specs.append({"asset": "post", "points": PackedVector2Array([left, right, right + up, left + up])})


static func _align_cross(quad: PackedVector2Array, asset_id: String) -> PackedVector2Array:
	var asset := catalog().get(asset_id, {}) as Dictionary
	var cross_value: Array = asset.get("cross_grid", [1, 0])
	var cross_direction := Vector2(float(cross_value[0]), float(cross_value[1]))
	if (quad[1] - quad[0]).dot(cross_direction) < 0.0:
		return PackedVector2Array([quad[1], quad[0], quad[3], quad[2]])
	return quad
