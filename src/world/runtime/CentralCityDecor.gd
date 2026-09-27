extends RefCounted
class_name CentralCityDecor

const CONFIG_PATH := "res://assets/resources/world/central_city_decor.json"
const CITY_URBAN = preload("res://src/world/runtime/CentralCityUrbanPlan.gd")
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const DECOR_BASE_Z := 1000
const GROUND_DECOR_Z := -1100
const SHADOW_GROUP := "world_shadow_caster"
const LOCAL_LIGHT_GROUP := "world_local_light"

static var _config_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}


static func build_for_section(
	section_coord: Vector2i,
	theme: String,
	global_origin: Vector2,
	can_place: Callable,
	register_blocker: Callable,
	elevation_at_grid: Callable
) -> Dictionary:
	var root := Node2D.new()
	root.name = "CityDecor"
	var config := _load_config()
	if config.is_empty():
		return {"root": root, "count": 0, "assets": PackedStringArray()}

	# Prefer an explicitly authored district composition. Street furniture is
	# urban infrastructure, so important districts need exact placements tied
	# to entrances, foundation edges, plaza borders and bridge heads instead of
	# being scattered by a generic theme template.
	var placements: Array = []
	var sections_value = config.get("sections", {})
	if sections_value is Dictionary:
		var sections := sections_value as Dictionary
		var section_key := "%d,%d" % [section_coord.x, section_coord.y]
		var authored_value = sections.get(section_key, null)
		if authored_value is Array:
			placements = authored_value as Array

	if placements.is_empty():
		var profiles_value = config.get("profiles", {})
		if not profiles_value is Dictionary:
			return {"root": root, "count": 0, "assets": PackedStringArray()}
		var profiles := profiles_value as Dictionary
		var variants_value = profiles.get(theme, profiles.get("residential", []))
		if not variants_value is Array or variants_value.is_empty():
			return {"root": root, "count": 0, "assets": PackedStringArray()}
		var variants := variants_value as Array
		var variant_index := posmod(section_coord.x * 31 + section_coord.y * 17, variants.size())
		var placements_value = variants[variant_index]
		if not placements_value is Array:
			return {"root": root, "count": 0, "assets": PackedStringArray()}
		placements = placements_value as Array

	var assets_value = config.get("assets", {})
	if not assets_value is Dictionary:
		return {"root": root, "count": 0, "assets": PackedStringArray()}
	var assets := assets_value as Dictionary
	var used := {}
	var count := 0

	for raw_placement in placements:
		if not raw_placement is Dictionary:
			continue
		var placement := raw_placement as Dictionary
		var asset_id := String(placement.get("asset", ""))
		var asset_value = assets.get(asset_id, {})
		if asset_id.is_empty() or not asset_value is Dictionary:
			continue
		var asset := asset_value as Dictionary
		var cell := _vec2(placement.get("cell", [0.0, 0.0]))
		var clearance := _vec2(
			placement.get("clearance", asset.get("clearance", asset.get("blocker", [0.0, 0.0])))
		)
		# Validate the authored placement clearance separately from the fitted
		# physical footprint. Benches beside landscape islands deliberately reduce
		# this envelope at placement level, while the anchor itself must still be on
		# open pavement before the fitted blocker is registered.
		if not bool(can_place.call(cell, clearance)):
			continue

		var texture := _texture_for(asset_id, asset)
		if texture == null:
			continue
		var foot := _vec2(asset.get("foot", [texture.get_width() * 0.5, texture.get_height()]))
		var scale_value := float(asset.get("scale", 1.0))
		var world_foot := _grid_to_world(cell)
		var elevation_px := 0.0
		if elevation_at_grid.is_valid():
			elevation_px = maxf(0.0, float(elevation_at_grid.call(cell)))
		var visual_offset := Vector2(0.0, -elevation_px)
		# The sprite depth anchor is intentionally the front-most foot. Collision
		# uses the centroid of the four contact points, which sits slightly behind
		# that sorting anchor on an isometric bench.
		var ground_center := world_foot + _vec2(asset.get("ground_offset", [0.0, 0.0]))

		var surround_style := String(placement.get("surround", ""))
		if not surround_style.is_empty():
			var accent := _color(placement.get("accent", asset.get("accent", [0.24, 0.88, 1.0, 1.0])))
			var surround := CITY_URBAN.create_lamp_surround(
				"LampSurround_%02d" % (count + 1),
				world_foot,
				accent,
				surround_style == "landscape"
			)
			surround.position = visual_offset
			surround.z_index = GROUND_DECOR_Z
			surround.set_meta("world_elevation_px", elevation_px)
			root.add_child(surround)

		var sprite := Sprite2D.new()
		sprite.name = "%s_%02d" % [asset_id.capitalize(), count + 1]
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * scale_value
		var center_to_foot := foot - Vector2(texture.get_width(), texture.get_height()) * 0.5
		sprite.position = world_foot - center_to_foot * scale_value + visual_offset
		sprite.set_meta("world_elevation_px", elevation_px)
		if String(asset.get("layer", "")) == "ground":
			sprite.z_index = GROUND_DECOR_Z
		elif String(placement.get("depth", "world")) == "behind_building":
			# Used only for deliberately rear-side infrastructure. Service exteriors
			# keep their main body at z=880, so 840 reads behind the architecture
			# instead of painting the post over the facade.
			sprite.z_index = 840
		else:
			sprite.z_index = DECOR_BASE_Z + int(round(global_origin.y + world_foot.y - elevation_px))
		root.add_child(sprite)

		var collision_polygon := _collision_polygon(ground_center, asset)
		if collision_polygon.size() >= 3:
			register_blocker.call(collision_polygon, asset_id)
			sprite.set_meta("collision_polygon", collision_polygon)
		sprite.set_meta("ground_center", ground_center)
		var visual_collision_polygon := PackedVector2Array()
		for point: Vector2 in collision_polygon:
			visual_collision_polygon.append(point + visual_offset)
		_configure_lighting_metadata(sprite, asset, visual_collision_polygon)
		used[asset_id] = true
		count += 1

	var asset_ids := PackedStringArray()
	for asset_id in used.keys():
		asset_ids.append(String(asset_id))
	asset_ids.sort()
	return {"root": root, "count": count, "assets": asset_ids}


static func _configure_lighting_metadata(
	sprite: Sprite2D,
	asset: Dictionary,
	collision_polygon: PackedVector2Array
) -> void:
	var shadow_value = asset.get("shadow", {})
	if shadow_value is Dictionary and not (shadow_value as Dictionary).is_empty():
		var shadow := shadow_value as Dictionary
		var style := String(shadow.get("style", "projected"))
		if style != "projected" or collision_polygon.size() >= 3:
			sprite.add_to_group(SHADOW_GROUP)
			sprite.set_meta("world_shadow_style", style)
			if collision_polygon.size() >= 3:
				var inverse_transform := sprite.transform.affine_inverse()
				var local_footprint := PackedVector2Array()
				for point: Vector2 in collision_polygon:
					local_footprint.append(inverse_transform * point)
				sprite.set_meta("world_shadow_footprint", local_footprint)
			sprite.set_meta("world_shadow_height", maxf(0.0, float(shadow.get("height", 24.0))))
			sprite.set_meta(
				"world_shadow_projection_multiplier",
				maxf(0.0, float(shadow.get("projection_multiplier", 1.0)))
			)
			sprite.set_meta("world_shadow_opacity", clampf(float(shadow.get("opacity", 0.18)), 0.0, 0.55))
			sprite.set_meta("world_shadow_dynamic", false)
			var size_value = shadow.get("size", [])
			if size_value is Array and size_value.size() >= 2:
				sprite.set_meta("world_shadow_size", _vec2(size_value))
			var anchor_value = shadow.get("anchor", [])
			if anchor_value is Array and anchor_value.size() >= 2:
				sprite.set_meta("world_shadow_anchor", _vec2(anchor_value))

	var light_value = asset.get("light", {})
	if light_value is Dictionary and not (light_value as Dictionary).is_empty():
		var light := light_value as Dictionary
		sprite.add_to_group(LOCAL_LIGHT_GROUP)
		sprite.set_meta("world_light_offset", _vec2(light.get("offset", [0.0, 0.0])))
		sprite.set_meta("world_light_color", _color(light.get("color", asset.get("accent", [1.0, 1.0, 1.0, 1.0]))))
		sprite.set_meta("world_light_energy", maxf(0.0, float(light.get("energy", 0.6))))
		sprite.set_meta("world_light_radius", maxf(24.0, float(light.get("radius", 120.0))))
		sprite.set_meta("world_light_day_factor", clampf(float(light.get("day_factor", 0.02)), 0.0, 1.0))
		sprite.set_meta("world_light_glow_radius", maxf(0.0, float(light.get("glow_radius", 0.0))))
		sprite.set_meta("world_light_glow_energy", maxf(0.0, float(light.get("glow_energy", 0.0))))
		sprite.set_meta("world_light_glow_day_factor", clampf(float(light.get("glow_day_factor", 0.0)), 0.0, 1.0))


static func _load_config() -> Dictionary:
	if not _config_cache.is_empty():
		return _config_cache
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("CentralCityDecor: missing decoration config %s" % CONFIG_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		push_error("CentralCityDecor: invalid decoration config %s" % CONFIG_PATH)
		return {}
	_config_cache = (parsed as Dictionary).duplicate(true)
	return _config_cache


static func _texture_for(asset_id: String, asset: Dictionary) -> Texture2D:
	if _texture_cache.has(asset_id):
		return _texture_cache[asset_id] as Texture2D

	var path := String(asset.get("path", ""))
	if path.is_empty():
		return null
	var resource = ResourceLoader.load(path)
	if not resource is Texture2D:
		push_warning("CentralCityDecor: could not load prop %s from %s" % [asset_id, path])
		return null

	var source := resource as Texture2D
	var texture: Texture2D = source
	var region_value = asset.get("region", [])
	if region_value is Array and region_value.size() >= 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(
			float(region_value[0]),
			float(region_value[1]),
			float(region_value[2]),
			float(region_value[3])
		)
		atlas.filter_clip = true
		texture = atlas

	_texture_cache[asset_id] = texture
	return texture


static func _collision_polygon(center: Vector2, asset: Dictionary) -> PackedVector2Array:
	var custom_value = asset.get("collision", [])
	if custom_value is Array and custom_value.size() >= 3:
		var custom := PackedVector2Array()
		for raw_point in custom_value:
			if raw_point is Array and raw_point.size() >= 2:
				custom.append(center + Vector2(float(raw_point[0]), float(raw_point[1])))
		if custom.size() >= 3:
			return custom

	var blocker := _vec2(asset.get("blocker", [0.0, 0.0]))
	if blocker.x <= 0.0 or blocker.y <= 0.0:
		return PackedVector2Array()
	return _blocker_polygon(center, blocker)


static func _blocker_polygon(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half_w := size.x * 0.5
	var half_h := size.y * 0.5
	return PackedVector2Array([
		center + Vector2(-half_w, 0.0),
		center + Vector2(0.0, -half_h),
		center + Vector2(half_w, 0.0),
		center + Vector2(0.0, half_h),
	])


static func _grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_WIDTH * 0.5,
		(grid.x + grid.y) * TILE_HEIGHT * 0.5
	)


static func _color(value) -> Color:
	if value is Array and value.size() >= 3:
		var alpha := float(value[3]) if value.size() >= 4 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return Color.WHITE


static func _vec2(value) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

