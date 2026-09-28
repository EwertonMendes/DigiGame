extends RefCounted
class_name WorldWater

# Shared 2D water renderer. Geometry stays owned by each world/area, while the
# visual language is centralized here so canals, ponds and future water bodies
# can share the same texture-free materials without duplicating shader setup.
const SURFACE_SHADER = preload("res://shaders/world_water_surface.gdshader")
const SHORE_SHADER = preload("res://shaders/world_water_shore.gdshader")

const DEFAULT_SURFACE_PROFILE := {
	"deep_color": Color(0.015, 0.300, 0.500, 1.0),
	"body_color": Color(0.015, 0.565, 0.755, 1.0),
	"shallow_color": Color(0.055, 0.735, 0.855, 1.0),
	"line_color": Color(0.220, 0.900, 0.980, 1.0),
	"crest_color": Color(0.660, 0.985, 1.000, 1.0),
	"flow_direction": Vector2(0.70710678, 0.70710678),
	"flow_speed": 0.24,
	"pattern_scale": 2.35,
	"line_width": 0.045,
	"line_strength": 0.42,
	"ripple_scale": 1.15,
	"ripple_strength": 0.26,
	"depth_strength": 0.30,
	"opacity": 0.98,
}

const DEFAULT_SHORE_PROFILE := {
	"foam_color": Color(0.320, 0.930, 1.000, 0.88),
	"secondary_color": Color(0.080, 0.690, 0.860, 0.50),
	"shore_speed": 0.42,
	"shore_strength": 0.72,
	"secondary_strength": 0.22,
	"world_scale": 0.020,
	"crest_width": 0.055,
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
