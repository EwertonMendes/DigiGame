extends RefCounted
class_name TreeAmbientFX

const FOLIAGE_SHADER = preload("res://shaders/foliage_sway.gdshader")

static var _leaf_texture: Texture2D = null


static func apply(
	tree: Sprite2D,
	phase: float,
	sway_strength: float,
	leaf_count: int,
	leaf_color: Color
) -> void:
	if tree == null:
		return

	tree.set_meta("ambient_base_position", tree.position)
	tree.set_meta("ambient_base_rotation", tree.rotation)
	tree.set_meta("ambient_phase", phase)

	var material := ShaderMaterial.new()
	material.shader = FOLIAGE_SHADER
	material.set_shader_parameter("phase", phase)
	material.set_shader_parameter("sway_strength", sway_strength)
	tree.material = material

	var leaves := CPUParticles2D.new()
	leaves.name = "AmbientLeaves"
	leaves.texture = _leaf_particle_texture()
	leaves.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leaves.amount = maxi(1, leaf_count)
	leaves.lifetime = 4.4
	leaves.randomness = 0.74
	leaves.local_coords = false

	var texture_size := tree.texture.get_size() if tree.texture != null else Vector2(32.0, 48.0)
	leaves.position = Vector2(0.0, -texture_size.y * 0.19)
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(
		maxf(8.0, texture_size.x * 0.32),
		maxf(5.0, texture_size.y * 0.13)
	)
	leaves.direction = Vector2(0.70, 1.0)
	leaves.spread = 46.0
	leaves.gravity = Vector2(7.0, 19.0)
	leaves.initial_velocity_min = 4.0
	leaves.initial_velocity_max = 13.0
	leaves.angular_velocity_min = -120.0
	leaves.angular_velocity_max = 120.0
	leaves.scale_amount_min = 0.55
	leaves.scale_amount_max = 1.15
	leaves.color = leaf_color
	leaves.z_index = 1
	leaves.emitting = true
	tree.add_child(leaves)


static func animate(tree: Sprite2D, elapsed: float) -> void:
	if tree == null or not is_instance_valid(tree):
		return

	var phase := float(tree.get_meta("ambient_phase", 0.0))
	var base_position := Vector2(tree.get_meta("ambient_base_position", tree.position))
	var base_rotation := float(tree.get_meta("ambient_base_rotation", tree.rotation))
	var wind := sin(elapsed * 1.02 + phase)
	var gust := sin(elapsed * 0.31 + phase * 1.9)

	tree.position = base_position + Vector2(
		wind * 0.40 + gust * 0.16,
		absf(wind) * 0.14
	)
	tree.rotation = base_rotation + wind * 0.005 + gust * 0.0025


static func _leaf_particle_texture() -> Texture2D:
	if _leaf_texture != null:
		return _leaf_texture
	var image := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_leaf_texture = ImageTexture.create_from_image(image)
	return _leaf_texture
