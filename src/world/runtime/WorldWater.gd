extends RefCounted
class_name WorldWater

# Shared 2D water renderer. Geometry stays owned by each world/area, while the
# visual language is centralized here so canals, ponds and future water bodies
# can share the same texture-free materials without duplicating shader setup.
const SURFACE_SHADER = preload("res://shaders/world_water_surface.gdshader")
const SHORE_SHADER = preload("res://shaders/world_water_shore.gdshader")

const DEFAULT_SURFACE_PROFILE := {
	"deep_color": Color(0.010, 0.090, 0.155, 1.0),
	"body_color": Color(0.020, 0.285, 0.385, 1.0),
	"shallow_color": Color(0.060, 0.500, 0.555, 1.0),
	"highlight_color": Color(0.620, 0.940, 0.920, 1.0),
	"flow_direction": Vector2(0.88, 0.42),
	"flow_speed": 0.28,
	"wave_scale": 0.48,
	"detail_scale": 1.16,
	"wave_strength": 0.86,
	"highlight_strength": 0.62,
	"sparkle_strength": 0.14,
	"depth_bias": 0.50,
	"opacity": 0.98,
}

const DEFAULT_SHORE_PROFILE := {
	"foam_color": Color(0.72, 0.98, 0.95, 0.90),
	"secondary_color": Color(0.22, 0.70, 0.73, 0.50),
	"shore_speed": 0.68,
	"shore_strength": 0.88,
	"secondary_strength": 0.32,
	"world_scale": 0.018,
	"crest_width": 0.075,
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

		# COLOR.a is a normalized bank-distance channel: 0 at the bank and
		# 1 toward open water. This lets the shader move crests across the
		# shoreline without textures or per-frame geometry updates.
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
