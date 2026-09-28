extends RefCounted
class_name WorldWater

# Shared 2D/2.5D water renderer. Areas own only their basin geometry; this
# module owns the reusable surface/shore mesh formats and shader profiles.
const SURFACE_SHADER = preload("res://shaders/world_water_surface.gdshader")
const SHORE_SHADER = preload("res://shaders/world_water_shore.gdshader")

const DEFAULT_SURFACE_PROFILE := {
	"deep_color": Color(0.010, 0.330, 0.540, 1.0),
	"body_color": Color(0.020, 0.640, 0.800, 1.0),
	"shallow_color": Color(0.090, 0.805, 0.900, 1.0),
	"caustic_color": Color(0.420, 0.955, 1.000, 1.0),
	"crest_color": Color(0.800, 1.000, 1.000, 1.0),
	"underwater_tint": Color(0.44, 0.88, 0.96, 1.0),
	"use_basin_depth": false,
	"flow_direction": Vector2(0.70710678, 0.70710678),
	"flow_speed": 0.18,
	"cross_flow_speed": 0.07,
	"wave_scale": 1.15,
	"wave_strength": 0.34,
	"caustic_scale": 1.55,
	"caustic_strength": 0.34,
	"caustic_speed": 0.42,
	"crest_strength": 0.20,
	"depth_strength": 0.58,
	"refraction_pixels": 1.10,
	"refraction_visibility": 0.20,
	"opacity": 0.98,
}

const DEFAULT_SHORE_PROFILE := {
	"foam_color": Color(0.700, 0.985, 1.000, 0.88),
	"secondary_color": Color(0.120, 0.740, 0.900, 0.54),
	"shore_speed": 0.34,
	"shore_strength": 0.72,
	"secondary_strength": 0.30,
	"world_scale": 0.022,
	"crest_width": 0.050,
}


static func create_surface_material(profile: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	_apply_profile(material, DEFAULT_SURFACE_PROFILE, profile)
	return material


static func create_shore_material(profile: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHORE_SHADER
	_apply_profile(material, DEFAULT_SHORE_PROFILE, profile)
	return material


static func create_surface_batch(
	regions: Array[Dictionary],
	depth_order: int,
	node_name: String = "WaterSurface",
	profile: Dictionary = {}
) -> MeshInstance2D:
	var surface := MeshInstance2D.new()
	surface.name = node_name
	surface.mesh = _build_surface_mesh(regions)
	var basin_profile := profile.duplicate(true)
	basin_profile["use_basin_depth"] = true
	surface.material = create_surface_material(basin_profile)
	surface.texture = null
	surface.z_index = clampi(depth_order, -4000, 4000)
	return surface


static func create_shoreline_batch(
	edge_strips: Array[Dictionary],
	depth_order: int,
	node_name: String = "WaterShoreline",
	profile: Dictionary = {}
) -> MeshInstance2D:
	var shoreline := MeshInstance2D.new()
	shoreline.name = node_name
	shoreline.mesh = _build_shoreline_mesh(edge_strips)
	shoreline.material = create_shore_material(profile)
	shoreline.texture = null
	shoreline.z_index = clampi(depth_order, -4000, 4000)
	return shoreline


static func _apply_profile(
	material: ShaderMaterial,
	defaults: Dictionary,
	overrides: Dictionary
) -> void:
	var parameters := defaults.duplicate(true)
	for raw_key in overrides:
		parameters[raw_key] = overrides[raw_key]
	for raw_key in parameters:
		material.set_shader_parameter(StringName(String(raw_key)), parameters[raw_key])


static func _build_surface_mesh(regions: Array[Dictionary]) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for region: Dictionary in regions:
		var points_value = region.get("points", PackedVector2Array())
		if not points_value is PackedVector2Array:
			continue
		var points := points_value as PackedVector2Array
		if points.size() < 3:
			continue

		var grid_value = region.get("grid_points", points)
		var grid_points := (
			grid_value as PackedVector2Array
			if grid_value is PackedVector2Array
			else points
		)
		if grid_points.size() != points.size():
			grid_points = points

		var triangulated := Geometry2D.triangulate_polygon(points)
		if triangulated.is_empty():
			continue

		var min_grid := Vector2(INF, INF)
		var max_grid := Vector2(-INF, -INF)
		for grid_point: Vector2 in grid_points:
			min_grid.x = minf(min_grid.x, grid_point.x)
			min_grid.y = minf(min_grid.y, grid_point.y)
			max_grid.x = maxf(max_grid.x, grid_point.x)
			max_grid.y = maxf(max_grid.y, grid_point.y)
		var grid_size := Vector2(
			maxf(max_grid.x - min_grid.x, 0.0001),
			maxf(max_grid.y - min_grid.y, 0.0001)
		)

		var start := vertices.size()
		for point_index in range(points.size()):
			var point := points[point_index]
			var grid_point := grid_points[point_index]
			var local_uv := Vector2(
				(grid_point.x - min_grid.x) / grid_size.x,
				(grid_point.y - min_grid.y) / grid_size.y
			)
			vertices.append(point)
			# COLOR.rg is intentionally a geometry data channel here. The water
			# shader captures it in vertex() and writes its own final colour.
			colors.append(Color(local_uv.x, local_uv.y, 0.0, 1.0))
			uvs.append(grid_point)
		for raw_index in triangulated:
			indices.append(start + int(raw_index))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _build_shoreline_mesh(edge_strips: Array[Dictionary]) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for strip: Dictionary in edge_strips:
		if not (
			strip.get("outer_a") is Vector2
			and strip.get("outer_b") is Vector2
			and strip.get("inner_a") is Vector2
			and strip.get("inner_b") is Vector2
		):
			continue
		var outer_a: Vector2 = strip["outer_a"]
		var outer_b: Vector2 = strip["outer_b"]
		var inner_a: Vector2 = strip["inner_a"]
		var inner_b: Vector2 = strip["inner_b"]
		var start := vertices.size()

		# COLOR.a is normalized bank distance: 0 at the wall, 1 toward open
		# water. UV is continuous world/display position for shoreline phase.
		vertices.append_array(PackedVector2Array([outer_a, outer_b, inner_b, inner_a]))
		colors.append_array(PackedColorArray([
			Color(1.0, 1.0, 1.0, 0.0),
			Color(1.0, 1.0, 1.0, 0.0),
			Color(1.0, 1.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 1.0),
		]))
		uvs.append_array(PackedVector2Array([outer_a, outer_b, inner_b, inner_a]))
		indices.append_array(PackedInt32Array([
			start,
			start + 1,
			start + 2,
			start,
			start + 2,
			start + 3,
		]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
