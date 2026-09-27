extends Node2D
class_name WorldLightingSystem

const SHADOW_GROUP := "world_shadow_caster"
const LOCAL_LIGHT_GROUP := "world_local_light"

const SHADOW_STYLE_PROJECTED := "projected"
const SHADOW_STYLE_CONTACT := "contact"
const SHADOW_STYLE_PROJECTED_SOFT := "projected_soft"

const AMBIENT_COLOR := Color(0.88, 0.91, 0.96, 1.0)
const SUN_COLOR := Color(1.0, 0.93, 0.80, 1.0)
const SUN_ENERGY := 0.18
const SUN_ROTATION_DEGREES := -32.0
const SHADOW_COLOR := Color(0.035, 0.055, 0.075, 1.0)
const SHADOW_PROJECTION_PER_HEIGHT := Vector2(0.42, 0.22)
const SHADOW_RENDER_DISTANCE := 920.0
const LOCAL_LIGHT_RENDER_DISTANCE := 720.0
const DISCOVERY_INTERVAL := 0.75
const LIGHT_CULL_INTERVAL := 0.20
const LIGHT_TEXTURE_SIZE := 64
const SOFT_SHADOW_TEXTURE_SIZE := 64

var _player: Node2D = null
var _ambient: CanvasModulate = null
var _sun: DirectionalLight2D = null
var _shadow_root: Node2D = null
var _light_root: Node2D = null
var _light_texture: Texture2D = null
var _soft_shadow_texture: Texture2D = null
var _shadow_entries: Dictionary = {}
var _light_entries: Dictionary = {}
var _discovery_elapsed := 0.0
var _light_cull_elapsed := 0.0
var _active_local_lights := 0
var _exterior_active := true


func _ready() -> void:
	_build_environment()
	_build_runtime_roots()
	_light_texture = _create_radial_light_texture()
	_soft_shadow_texture = _create_soft_shadow_texture()


func configure(player: Node2D) -> void:
	_player = player
	_discover_runtime_sources()
	_update_shadow_visibility()
	_update_local_lights()


func _process(delta: float) -> void:
	if not _exterior_active:
		return

	_discovery_elapsed += delta
	if _discovery_elapsed >= DISCOVERY_INTERVAL:
		_discovery_elapsed = 0.0
		_discover_runtime_sources()

	_update_dynamic_shadows()

	_light_cull_elapsed += delta
	if _light_cull_elapsed >= LIGHT_CULL_INTERVAL:
		_light_cull_elapsed = 0.0
		_update_shadow_visibility()
		_update_local_lights()


func set_exterior_active(active: bool) -> void:
	_exterior_active = active
	if _ambient != null:
		_ambient.visible = active
	if _sun != null:
		_sun.enabled = active
	if _shadow_root != null:
		_shadow_root.visible = active
	if _light_root != null:
		_light_root.visible = active

	if active:
		_discover_runtime_sources()
		_update_shadow_visibility()
		_update_local_lights()
	else:
		_active_local_lights = 0
		for entry_value in _light_entries.values():
			if not entry_value is Dictionary:
				continue
			var light := (entry_value as Dictionary).get("light") as PointLight2D
			if light != null and is_instance_valid(light):
				light.enabled = false


func get_shadow_caster_count() -> int:
	return _shadow_entries.size()


func get_local_light_count() -> int:
	return _light_entries.size()


func get_active_local_light_count() -> int:
	return _active_local_lights


func _build_environment() -> void:
	_ambient = CanvasModulate.new()
	_ambient.name = "AmbientModulate"
	_ambient.color = AMBIENT_COLOR
	add_child(_ambient)

	_sun = DirectionalLight2D.new()
	_sun.name = "SunLight"
	_sun.color = SUN_COLOR
	_sun.energy = SUN_ENERGY
	_sun.rotation_degrees = SUN_ROTATION_DEGREES
	_sun.shadow_enabled = false
	_sun.range_z_min = -2000
	_sun.range_z_max = 4000
	add_child(_sun)


func _build_runtime_roots() -> void:
	_shadow_root = Node2D.new()
	_shadow_root.name = "SunShadows"
	_shadow_root.z_index = -1000
	add_child(_shadow_root)

	_light_root = Node2D.new()
	_light_root.name = "LocalLights"
	add_child(_light_root)


func _discover_runtime_sources() -> void:
	_prune_invalid_entries()

	for raw_node in get_tree().get_nodes_in_group(SHADOW_GROUP):
		if not raw_node is Node2D:
			continue
		var caster := raw_node as Node2D
		var id := caster.get_instance_id()
		if _shadow_entries.has(id):
			continue
		_register_shadow_caster(caster)

	for raw_node in get_tree().get_nodes_in_group(LOCAL_LIGHT_GROUP):
		if not raw_node is Node2D:
			continue
		var source := raw_node as Node2D
		var id := source.get_instance_id()
		if _light_entries.has(id):
			continue
		_register_local_light(source)


func _register_shadow_caster(caster: Node2D) -> void:
	var style := String(caster.get_meta("world_shadow_style", SHADOW_STYLE_PROJECTED))
	var opacity := clampf(float(caster.get_meta("world_shadow_opacity", 0.18)), 0.0, 0.55)
	var render_node: CanvasItem = null
	var footprint := PackedVector2Array()

	if style == SHADOW_STYLE_CONTACT or style == SHADOW_STYLE_PROJECTED_SOFT:
		if _soft_shadow_texture == null:
			return
		var shadow_sprite := Sprite2D.new()
		shadow_sprite.name = "Shadow_%s" % String(caster.name)
		shadow_sprite.texture = _soft_shadow_texture
		shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		shadow_sprite.modulate = Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, opacity)
		_shadow_root.add_child(shadow_sprite)
		render_node = shadow_sprite
	else:
		var footprint_value = caster.get_meta("world_shadow_footprint", PackedVector2Array())
		if not footprint_value is PackedVector2Array:
			return
		footprint = (footprint_value as PackedVector2Array).duplicate()
		if footprint.size() < 3:
			return
		var polygon := Polygon2D.new()
		polygon.name = "Shadow_%s" % String(caster.name)
		polygon.color = Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, opacity)
		_shadow_root.add_child(polygon)
		render_node = polygon

	if render_node == null:
		return

	var id := caster.get_instance_id()
	_shadow_entries[id] = {
		"caster": caster,
		"render_node": render_node,
		"footprint": footprint,
		"style": style,
		"dynamic": bool(caster.get_meta("world_shadow_dynamic", false)),
	}
	_update_shadow_geometry(_shadow_entries[id] as Dictionary)


func _register_local_light(source: Node2D) -> void:
	if _light_texture == null:
		return

	var radius := maxf(24.0, float(source.get_meta("world_light_radius", 120.0)))
	var light := PointLight2D.new()
	light.name = "Light_%s" % source.name
	light.texture = _light_texture
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	light.texture_scale = (radius * 2.0) / float(LIGHT_TEXTURE_SIZE)
	light.color = source.get_meta("world_light_color", Color.WHITE) as Color
	light.energy = maxf(0.0, float(source.get_meta("world_light_energy", 0.6)))
	light.shadow_enabled = false
	light.range_z_min = -2000
	light.range_z_max = 4000
	_light_root.add_child(light)

	var id := source.get_instance_id()
	_light_entries[id] = {
		"source": source,
		"light": light,
		"offset": source.get_meta("world_light_offset", Vector2.ZERO) as Vector2,
	}
	_update_light_transform(_light_entries[id] as Dictionary)


func _update_dynamic_shadows() -> void:
	for entry_value in _shadow_entries.values():
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		if not bool(entry.get("dynamic", false)):
			continue
		_update_shadow_geometry(entry)


func _update_shadow_geometry(entry: Dictionary) -> void:
	var caster = entry.get("caster")
	if not is_instance_valid(caster) or not caster is Node2D:
		return

	var style := String(entry.get("style", SHADOW_STYLE_PROJECTED))
	if style == SHADOW_STYLE_CONTACT or style == SHADOW_STYLE_PROJECTED_SOFT:
		_update_soft_shadow(entry, caster as Node2D, style)
	else:
		_update_projected_polygon(entry, caster as Node2D)


func _update_projected_polygon(entry: Dictionary, caster: Node2D) -> void:
	var polygon := entry.get("render_node") as Polygon2D
	var footprint_value = entry.get("footprint", PackedVector2Array())
	if polygon == null or not is_instance_valid(polygon) or not footprint_value is PackedVector2Array:
		return

	var footprint := footprint_value as PackedVector2Array
	var projected_points := PackedVector2Array()
	var projection := _shadow_projection(caster)

	for local_point: Vector2 in footprint:
		var world_point := caster.to_global(local_point)
		var shadow_point := _shadow_root.to_local(world_point)
		projected_points.append(shadow_point)
		projected_points.append(shadow_point + projection)

	if projected_points.size() >= 3:
		polygon.polygon = Geometry2D.convex_hull(projected_points)


func _update_soft_shadow(entry: Dictionary, caster: Node2D, style: String) -> void:
	var shadow_sprite := entry.get("render_node") as Sprite2D
	if shadow_sprite == null or not is_instance_valid(shadow_sprite) or _soft_shadow_texture == null:
		return

	var anchor := Vector2.ZERO
	var anchor_value = caster.get_meta("world_shadow_anchor", Vector2.ZERO)
	if anchor_value is Vector2:
		anchor = anchor_value as Vector2

	var offset := Vector2.ZERO
	var offset_value = caster.get_meta("world_shadow_offset", Vector2.ZERO)
	if offset_value is Vector2:
		offset = offset_value as Vector2

	var size := Vector2(30.0, 10.0)
	var size_value = caster.get_meta("world_shadow_size", size)
	if size_value is Vector2:
		size = size_value as Vector2
	size.x = maxf(4.0, size.x)
	size.y = maxf(3.0, size.y)

	var world_anchor := caster.to_global(anchor)
	var local_anchor := _shadow_root.to_local(world_anchor)
	shadow_sprite.rotation = 0.0

	if style == SHADOW_STYLE_PROJECTED_SOFT:
		var projection := _shadow_projection(caster)
		shadow_sprite.position = local_anchor + projection * 0.62 + offset
		if projection.length_squared() > 0.001:
			shadow_sprite.rotation = projection.angle()
	else:
		shadow_sprite.position = local_anchor + offset

	var texture_size := _soft_shadow_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	shadow_sprite.scale = Vector2(size.x / texture_size.x, size.y / texture_size.y)


func _shadow_projection(caster: Node2D) -> Vector2:
	var height := maxf(0.0, float(caster.get_meta("world_shadow_height", 48.0)))
	var multiplier := maxf(0.0, float(caster.get_meta("world_shadow_projection_multiplier", 1.0)))
	return SHADOW_PROJECTION_PER_HEIGHT * height * multiplier


func _update_shadow_visibility() -> void:
	var max_distance_sq := SHADOW_RENDER_DISTANCE * SHADOW_RENDER_DISTANCE
	for entry_value in _shadow_entries.values():
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		var caster = entry.get("caster")
		var render_node := entry.get("render_node") as CanvasItem
		if not is_instance_valid(caster) or render_node == null or not is_instance_valid(render_node):
			continue
		if not caster is Node2D:
			render_node.visible = false
			continue
		var caster_2d := caster as Node2D
		var close_enough := (
			_player == null
			or caster_2d.global_position.distance_squared_to(_player.global_position) <= max_distance_sq
		)
		render_node.visible = caster_2d.is_visible_in_tree() and close_enough


func _update_local_lights() -> void:
	var max_distance_sq := LOCAL_LIGHT_RENDER_DISTANCE * LOCAL_LIGHT_RENDER_DISTANCE
	_active_local_lights = 0

	for entry_value in _light_entries.values():
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		var source = entry.get("source")
		var light := entry.get("light") as PointLight2D
		if not is_instance_valid(source) or light == null or not is_instance_valid(light):
			continue
		if not source is Node2D:
			light.enabled = false
			continue

		_update_light_transform(entry)
		var source_2d := source as Node2D
		var close_enough := (
			_player == null
			or source_2d.global_position.distance_squared_to(_player.global_position) <= max_distance_sq
		)
		light.enabled = _exterior_active and source_2d.is_visible_in_tree() and close_enough
		if light.enabled:
			_active_local_lights += 1


func _update_light_transform(entry: Dictionary) -> void:
	var source = entry.get("source")
	var light := entry.get("light") as PointLight2D
	var offset := entry.get("offset", Vector2.ZERO) as Vector2
	if not is_instance_valid(source) or light == null or not is_instance_valid(light):
		return
	if not source is Node2D:
		return
	light.global_position = (source as Node2D).to_global(offset)


func _prune_invalid_entries() -> void:
	for id in _shadow_entries.keys():
		var entry := _shadow_entries[id] as Dictionary
		var caster = entry.get("caster")
		if is_instance_valid(caster):
			continue
		var render_node := entry.get("render_node") as CanvasItem
		if render_node != null and is_instance_valid(render_node):
			render_node.queue_free()
		_shadow_entries.erase(id)

	for id in _light_entries.keys():
		var entry := _light_entries[id] as Dictionary
		var source = entry.get("source")
		if is_instance_valid(source):
			continue
		var light := entry.get("light") as PointLight2D
		if light != null and is_instance_valid(light):
			light.queue_free()
		_light_entries.erase(id)


func _create_radial_light_texture() -> Texture2D:
	var image := Image.create(
		LIGHT_TEXTURE_SIZE,
		LIGHT_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	var center := Vector2.ONE * (float(LIGHT_TEXTURE_SIZE - 1) * 0.5)
	var radius := float(LIGHT_TEXTURE_SIZE) * 0.5

	for y in range(LIGHT_TEXTURE_SIZE):
		for x in range(LIGHT_TEXTURE_SIZE):
			var normalized_distance := Vector2(float(x), float(y)).distance_to(center) / radius
			var strength := clampf(1.0 - normalized_distance, 0.0, 1.0)
			strength = strength * strength * (3.0 - 2.0 * strength)
			image.set_pixel(x, y, Color(strength, strength, strength, strength))

	return ImageTexture.create_from_image(image)


func _create_soft_shadow_texture() -> Texture2D:
	var image := Image.create(
		SOFT_SHADOW_TEXTURE_SIZE,
		SOFT_SHADOW_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	var center := Vector2.ONE * (float(SOFT_SHADOW_TEXTURE_SIZE - 1) * 0.5)
	var radius := float(SOFT_SHADOW_TEXTURE_SIZE) * 0.5

	for y in range(SOFT_SHADOW_TEXTURE_SIZE):
		for x in range(SOFT_SHADOW_TEXTURE_SIZE):
			var normalized_distance := Vector2(float(x), float(y)).distance_to(center) / radius
			var strength := clampf((1.0 - normalized_distance) / 0.58, 0.0, 1.0)
			strength = strength * strength * (3.0 - 2.0 * strength)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, strength))

	return ImageTexture.create_from_image(image)
