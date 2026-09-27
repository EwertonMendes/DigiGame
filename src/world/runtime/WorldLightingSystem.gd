extends Node2D
class_name WorldLightingSystem

const SHADOW_GROUP := "world_shadow_caster"
const LOCAL_LIGHT_GROUP := "world_local_light"
const LIGHTING_GROUP := "world_lighting_system"

const SHADOW_STYLE_PROJECTED := "projected"
const SHADOW_STYLE_CONTACT := "contact"
const SHADOW_STYLE_PROJECTED_SOFT := "projected_soft"

const DEFAULT_PREVIEW_HOUR := 12.0
const SHADOW_COLOR := Color(0.035, 0.055, 0.075, 1.0)
const SHADOW_RENDER_DISTANCE := 920.0
const LOCAL_LIGHT_RENDER_DISTANCE := 760.0
const DISCOVERY_INTERVAL := 0.75
const LIGHT_CULL_INTERVAL := 0.20
const LIGHT_TEXTURE_SIZE := 64
const SOFT_SHADOW_TEXTURE_SIZE := 64
const SHADOW_ROOT_Z := 120

var _player: Node2D = null
var _ambient: CanvasModulate = null
var _sun: DirectionalLight2D = null
var _shadow_root: Node2D = null
var _light_root: Node2D = null
var _light_texture: Texture2D = null
var _soft_shadow_texture: Texture2D = null
var _glow_material: CanvasItemMaterial = null
var _shadow_entries: Dictionary = {}
var _light_entries: Dictionary = {}
var _discovery_elapsed := 0.0
var _light_cull_elapsed := 0.0
var _active_local_lights := 0
var _exterior_active := true
var _debug_capture_active := false

var _preview_hour := DEFAULT_PREVIEW_HOUR
var _time_phase := "DAY"
var _sun_elevation := 1.0
var _shadow_length_scale := 0.45
var _shadow_direction := Vector2(0.12, 0.99).normalized()
var _projected_shadow_strength := 1.0
var _contact_shadow_strength := 1.0
var _local_light_strength := 0.02


func _ready() -> void:
	add_to_group(LIGHTING_GROUP)
	_build_environment()
	_build_runtime_roots()
	_light_texture = _create_radial_light_texture()
	_soft_shadow_texture = _create_soft_shadow_texture()
	_glow_material = CanvasItemMaterial.new()
	_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_apply_time_of_day()


func configure(player: Node2D) -> void:
	_player = player
	_discover_runtime_sources()
	_refresh_all_shadows()
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


func set_preview_time_hours(hours: float) -> void:
	_preview_hour = fposmod(hours, 24.0)
	_apply_time_of_day()
	_refresh_all_shadows()
	_update_local_lights()


func get_preview_time_hours() -> float:
	return _preview_hour


func get_time_phase() -> String:
	return _time_phase


func get_sun_elevation() -> float:
	return _sun_elevation


func get_shadow_length_scale() -> float:
	return _shadow_length_scale


func get_shadow_direction() -> Vector2:
	return _shadow_direction


func get_local_light_strength() -> float:
	return _local_light_strength


func get_time_debug_snapshot() -> Dictionary:
	return {
		"hour": _preview_hour,
		"phase": _time_phase,
		"sun_elevation": _sun_elevation,
		"shadow_length": _shadow_length_scale,
		"shadow_direction": _shadow_direction,
		"local_light_strength": _local_light_strength,
		"active_local_lights": _active_local_lights,
		"total_local_lights": _light_entries.size(),
		"shadow_casters": _shadow_entries.size(),
	}


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
		_apply_time_of_day()
		_refresh_all_shadows()
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


func is_debug_capture_active() -> bool:
	return _debug_capture_active


func set_debug_capture_active(active: bool) -> void:
	_debug_capture_active = active
	if not _exterior_active:
		return
	_update_shadow_visibility()
	_update_local_lights()


func _build_environment() -> void:
	_ambient = CanvasModulate.new()
	_ambient.name = "AmbientModulate"
	add_child(_ambient)

	_sun = DirectionalLight2D.new()
	_sun.name = "SunLight"
	_sun.shadow_enabled = false
	_sun.range_z_min = -2000
	_sun.range_z_max = 4000
	add_child(_sun)


func _build_runtime_roots() -> void:
	_shadow_root = Node2D.new()
	_shadow_root.name = "SunShadows"
	_shadow_root.z_index = SHADOW_ROOT_Z
	add_child(_shadow_root)

	_light_root = Node2D.new()
	_light_root.name = "LocalLights"
	_light_root.z_index = SHADOW_ROOT_Z + 1
	add_child(_light_root)


func _apply_time_of_day() -> void:
	var profile := _time_profile(_preview_hour)
	_time_phase = String(profile.get("phase", "DAY"))
	_sun_elevation = clampf(float(profile.get("sun_elevation", 1.0)), 0.0, 1.0)
	_shadow_length_scale = maxf(0.0, float(profile.get("shadow_length", 0.45)))
	_shadow_direction = profile.get("shadow_direction", Vector2(0.12, 0.99)) as Vector2
	if _shadow_direction.length_squared() <= 0.0001:
		_shadow_direction = Vector2(0.12, 0.99)
	_shadow_direction = _shadow_direction.normalized()
	_projected_shadow_strength = clampf(float(profile.get("projected_shadow_strength", 1.0)), 0.0, 1.4)
	_contact_shadow_strength = clampf(float(profile.get("contact_shadow_strength", 1.0)), 0.0, 1.2)
	_local_light_strength = clampf(float(profile.get("local_light_strength", 0.02)), 0.0, 1.0)

	if _ambient != null:
		_ambient.color = profile.get("ambient", Color.WHITE) as Color
	if _sun != null:
		_sun.color = profile.get("sun_color", Color.WHITE) as Color
		_sun.energy = maxf(0.0, float(profile.get("sun_energy", 0.0)))
		# Point opposite the cast direction. This already matters for 2D normal
		# maps and keeps the global light source consistent with our procedural casts.
		_sun.rotation = _shadow_direction.angle() + PI


func _time_profile(hour: float) -> Dictionary:
	var h := fposmod(hour, 24.0)

	if h < 5.5:
		return _profile_lerp(
			_night_profile(),
			_predawn_profile(),
			_smoothstep_range(h, 3.5, 5.5)
		)
	if h < 8.0:
		return _profile_lerp(
			_predawn_profile(),
			_morning_profile(),
			_smoothstep_range(h, 5.5, 8.0)
		)
	if h < 11.5:
		return _profile_lerp(
			_morning_profile(),
			_midday_profile(),
			_smoothstep_range(h, 8.0, 11.5)
		)
	if h < 15.5:
		return _profile_lerp(
			_midday_profile(),
			_afternoon_profile(),
			_smoothstep_range(h, 11.5, 15.5)
		)
	if h < 18.5:
		return _profile_lerp(
			_afternoon_profile(),
			_sunset_profile(),
			_smoothstep_range(h, 15.5, 18.5)
		)
	if h < 20.5:
		return _profile_lerp(
			_sunset_profile(),
			_night_profile(),
			_smoothstep_range(h, 18.5, 20.5)
		)
	return _night_profile()


func _predawn_profile() -> Dictionary:
	return {
		"phase": "DAWN",
		"ambient": Color(0.40, 0.42, 0.54, 1.0),
		"sun_color": Color(1.0, 0.58, 0.34, 1.0),
		"sun_energy": 0.06,
		"sun_elevation": 0.12,
		"shadow_length": 1.65,
		"shadow_direction": Vector2(-0.90, 0.44),
		"projected_shadow_strength": 0.42,
		"contact_shadow_strength": 0.78,
		"local_light_strength": 0.86,
	}


func _morning_profile() -> Dictionary:
	return {
		"phase": "MORNING",
		"ambient": Color(0.82, 0.84, 0.90, 1.0),
		"sun_color": Color(1.0, 0.80, 0.58, 1.0),
		"sun_energy": 0.18,
		"sun_elevation": 0.48,
		"shadow_length": 1.10,
		"shadow_direction": Vector2(-0.78, 0.48),
		"projected_shadow_strength": 0.90,
		"contact_shadow_strength": 1.0,
		"local_light_strength": 0.18,
	}


func _midday_profile() -> Dictionary:
	return {
		"phase": "DAY",
		"ambient": Color(0.92, 0.94, 0.98, 1.0),
		"sun_color": Color(1.0, 0.96, 0.86, 1.0),
		"sun_energy": 0.24,
		"sun_elevation": 1.0,
		"shadow_length": 0.42,
		"shadow_direction": Vector2(0.10, 0.99),
		"projected_shadow_strength": 0.88,
		"contact_shadow_strength": 1.0,
		"local_light_strength": 0.03,
	}


func _afternoon_profile() -> Dictionary:
	return {
		"phase": "AFTERNOON",
		"ambient": Color(0.90, 0.84, 0.76, 1.0),
		"sun_color": Color(1.0, 0.76, 0.46, 1.0),
		"sun_energy": 0.20,
		"sun_elevation": 0.52,
		"shadow_length": 1.08,
		"shadow_direction": Vector2(0.76, 0.50),
		"projected_shadow_strength": 1.02,
		"contact_shadow_strength": 1.0,
		"local_light_strength": 0.24,
	}


func _sunset_profile() -> Dictionary:
	return {
		"phase": "SUNSET",
		"ambient": Color(0.70, 0.61, 0.62, 1.0),
		"sun_color": Color(1.0, 0.46, 0.22, 1.0),
		"sun_energy": 0.13,
		"sun_elevation": 0.14,
		"shadow_length": 1.78,
		"shadow_direction": Vector2(0.91, 0.42),
		"projected_shadow_strength": 1.08,
		"contact_shadow_strength": 0.92,
		"local_light_strength": 0.72,
	}


func _night_profile() -> Dictionary:
	return {
		"phase": "NIGHT",
		"ambient": Color(0.31, 0.35, 0.47, 1.0),
		"sun_color": Color(0.54, 0.66, 1.0, 1.0),
		"sun_energy": 0.02,
		"sun_elevation": 0.0,
		"shadow_length": 0.72,
		"shadow_direction": Vector2(-0.36, 0.72),
		"projected_shadow_strength": 0.18,
		"contact_shadow_strength": 0.64,
		"local_light_strength": 1.0,
	}


func _profile_lerp(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var t := clampf(weight, 0.0, 1.0)
	var from_direction := from.get("shadow_direction", Vector2.RIGHT) as Vector2
	var to_direction := to.get("shadow_direction", Vector2.RIGHT) as Vector2
	var direction := from_direction.lerp(to_direction, t)
	if direction.length_squared() <= 0.0001:
		direction = to_direction
	return {
		"phase": String(to.get("phase", from.get("phase", "DAY"))) if t >= 0.5 else String(from.get("phase", "DAY")),
		"ambient": (from.get("ambient", Color.WHITE) as Color).lerp(to.get("ambient", Color.WHITE) as Color, t),
		"sun_color": (from.get("sun_color", Color.WHITE) as Color).lerp(to.get("sun_color", Color.WHITE) as Color, t),
		"sun_energy": lerpf(float(from.get("sun_energy", 0.0)), float(to.get("sun_energy", 0.0)), t),
		"sun_elevation": lerpf(float(from.get("sun_elevation", 0.0)), float(to.get("sun_elevation", 0.0)), t),
		"shadow_length": lerpf(float(from.get("shadow_length", 1.0)), float(to.get("shadow_length", 1.0)), t),
		"shadow_direction": direction.normalized(),
		"projected_shadow_strength": lerpf(float(from.get("projected_shadow_strength", 1.0)), float(to.get("projected_shadow_strength", 1.0)), t),
		"contact_shadow_strength": lerpf(float(from.get("contact_shadow_strength", 1.0)), float(to.get("contact_shadow_strength", 1.0)), t),
		"local_light_strength": lerpf(float(from.get("local_light_strength", 0.0)), float(to.get("local_light_strength", 0.0)), t),
	}


func _smoothstep_range(value: float, start: float, end: float) -> float:
	if is_equal_approx(start, end):
		return 1.0
	var t := clampf((value - start) / (end - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


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
		_shadow_root.add_child(polygon)
		render_node = polygon

	if render_node == null:
		return
	if caster.is_in_group("debug_capture_clean_hidden"):
		render_node.add_to_group("debug_capture_clean_hidden")

	var id := caster.get_instance_id()
	_shadow_entries[id] = {
		"caster": caster,
		"render_node": render_node,
		"footprint": footprint,
		"style": style,
		"base_opacity": opacity,
		"dynamic": bool(caster.get_meta("world_shadow_dynamic", false)),
	}
	_apply_shadow_appearance(_shadow_entries[id] as Dictionary)
	_update_shadow_geometry(_shadow_entries[id] as Dictionary)


func _register_local_light(source: Node2D) -> void:
	if _light_texture == null:
		return

	var radius := maxf(24.0, float(source.get_meta("world_light_radius", 120.0)))
	var base_energy := maxf(0.0, float(source.get_meta("world_light_energy", 0.6)))
	var light_color := source.get_meta("world_light_color", Color.WHITE) as Color
	var light := PointLight2D.new()
	light.name = "Light_%s" % source.name
	light.texture = _light_texture
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	light.texture_scale = (radius * 2.0) / float(LIGHT_TEXTURE_SIZE)
	light.color = light_color
	light.shadow_enabled = false
	light.range_z_min = -2000
	light.range_z_max = 4000
	_light_root.add_child(light)

	var glow: Sprite2D = null
	var glow_radius := maxf(0.0, float(source.get_meta("world_light_glow_radius", radius * 0.24)))
	var glow_energy := maxf(0.0, float(source.get_meta("world_light_glow_energy", 0.22)))
	if glow_radius > 0.0 and glow_energy > 0.0 and _glow_material != null:
		glow = Sprite2D.new()
		glow.name = "Glow_%s" % source.name
		glow.texture = _light_texture
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow.scale = Vector2.ONE * ((glow_radius * 2.0) / float(LIGHT_TEXTURE_SIZE))
		glow.material = _glow_material
		glow.modulate = Color(light_color.r, light_color.g, light_color.b, 0.0)
		_light_root.add_child(glow)

	var id := source.get_instance_id()
	_light_entries[id] = {
		"source": source,
		"light": light,
		"glow": glow,
		"offset": source.get_meta("world_light_offset", Vector2.ZERO) as Vector2,
		"base_energy": base_energy,
		"day_factor": clampf(float(source.get_meta("world_light_day_factor", 0.03)), 0.0, 1.0),
		"glow_energy": glow_energy,
		"glow_day_factor": clampf(float(source.get_meta("world_light_glow_day_factor", 0.0)), 0.0, 1.0),
		"color": light_color,
	}
	_update_light_transform(_light_entries[id] as Dictionary)


func _refresh_all_shadows() -> void:
	for entry_value in _shadow_entries.values():
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		_apply_shadow_appearance(entry)
		_update_shadow_geometry(entry)


func _update_dynamic_shadows() -> void:
	for entry_value in _shadow_entries.values():
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		if not bool(entry.get("dynamic", false)):
			continue
		_update_shadow_geometry(entry)


func _apply_shadow_appearance(entry: Dictionary) -> void:
	var style := String(entry.get("style", SHADOW_STYLE_PROJECTED))
	var render_node := entry.get("render_node") as CanvasItem
	if render_node == null or not is_instance_valid(render_node):
		return
	var base_opacity := clampf(float(entry.get("base_opacity", 0.18)), 0.0, 0.55)
	var strength := _contact_shadow_strength if style == SHADOW_STYLE_CONTACT else _projected_shadow_strength
	var alpha := clampf(base_opacity * strength, 0.0, 0.62)
	if render_node is Polygon2D:
		(render_node as Polygon2D).color = Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, alpha)
	elif render_node is Sprite2D:
		(render_node as Sprite2D).modulate = Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, alpha)


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
		var travel := 0.74
		shadow_sprite.position = local_anchor + projection * travel + offset
		if projection.length_squared() > 0.001:
			shadow_sprite.rotation = projection.angle()
		# Canopy shadows stretch in the sun direction, but remain broad enough to
		# read as foliage rather than a line. This is especially important at noon.
		size.x *= 1.0 + _shadow_length_scale * 0.42
		size.y *= 0.92 + minf(_shadow_length_scale, 1.2) * 0.16
	else:
		shadow_sprite.position = local_anchor + offset

	var texture_size := _soft_shadow_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	shadow_sprite.scale = Vector2(size.x / texture_size.x, size.y / texture_size.y)


func _shadow_projection(caster: Node2D) -> Vector2:
	var height := maxf(0.0, float(caster.get_meta("world_shadow_height", 48.0)))
	var multiplier := maxf(0.0, float(caster.get_meta("world_shadow_projection_multiplier", 1.0)))
	return _shadow_direction * height * multiplier * _shadow_length_scale


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
			_debug_capture_active
			or _player == null
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
		var glow := entry.get("glow") as Sprite2D
		if not is_instance_valid(source) or light == null or not is_instance_valid(light):
			continue
		if not source is Node2D:
			light.enabled = false
			if glow != null and is_instance_valid(glow):
				glow.visible = false
			continue

		_update_light_transform(entry)
		var source_2d := source as Node2D
		var close_enough := (
			_debug_capture_active
			or _player == null
			or source_2d.global_position.distance_squared_to(_player.global_position) <= max_distance_sq
		)
		var day_factor := clampf(float(entry.get("day_factor", 0.03)), 0.0, 1.0)
		var time_strength := lerpf(day_factor, 1.0, _local_light_strength)
		var base_energy := maxf(0.0, float(entry.get("base_energy", 0.0)))
		light.energy = base_energy * time_strength
		light.enabled = (
			_exterior_active
			and source_2d.is_visible_in_tree()
			and close_enough
			and light.energy > 0.015
		)

		if glow != null and is_instance_valid(glow):
			var glow_day_factor := clampf(float(entry.get("glow_day_factor", 0.0)), 0.0, 1.0)
			var glow_strength := lerpf(glow_day_factor, 1.0, _local_light_strength)
			var glow_energy := maxf(0.0, float(entry.get("glow_energy", 0.0)))
			var glow_color := entry.get("color", Color.WHITE) as Color
			var glow_alpha := clampf(glow_energy * glow_strength, 0.0, 1.35)
			glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
			glow.visible = (
				_exterior_active
				and source_2d.is_visible_in_tree()
				and close_enough
				and glow_alpha > 0.015
			)

		if light.enabled:
			_active_local_lights += 1


func _update_light_transform(entry: Dictionary) -> void:
	var source = entry.get("source")
	var light := entry.get("light") as PointLight2D
	var glow := entry.get("glow") as Sprite2D
	var offset := entry.get("offset", Vector2.ZERO) as Vector2
	if not is_instance_valid(source) or light == null or not is_instance_valid(light):
		return
	if not source is Node2D:
		return
	var world_position := (source as Node2D).to_global(offset)
	light.global_position = world_position
	if glow != null and is_instance_valid(glow):
		glow.global_position = world_position


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
		var glow := entry.get("glow") as Sprite2D
		if glow != null and is_instance_valid(glow):
			glow.queue_free()
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
			var strength := clampf((1.0 - normalized_distance) / 0.72, 0.0, 1.0)
			strength = strength * strength * (3.0 - 2.0 * strength)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, strength))

	return ImageTexture.create_from_image(image)
