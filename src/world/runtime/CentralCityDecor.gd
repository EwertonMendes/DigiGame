extends RefCounted
class_name CentralCityDecor

const CONFIG_PATH := "res://assets/resources/world/central_city_decor.json"
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const DECOR_BASE_Z := 1000
const GROUND_DECOR_Z := -1100

static var _config_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}


static func build_for_section(
	section_coord: Vector2i,
	theme: String,
	global_origin: Vector2,
	can_place: Callable,
	register_blocker: Callable
) -> Dictionary:
	var root := Node2D.new()
	root.name = "CityDecor"
	var config := _load_config()
	if config.is_empty():
		return {"root": root, "count": 0, "assets": PackedStringArray()}

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
	var placements := placements_value as Array

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
		var blocker := _vec2(asset.get("blocker", [0.0, 0.0]))
		if not bool(can_place.call(cell, blocker)):
			continue

		var texture := _texture_for(asset_id, String(asset.get("path", "")))
		if texture == null:
			continue
		var foot := _vec2(asset.get("foot", [texture.get_width() * 0.5, texture.get_height()]))
		var scale_value := float(asset.get("scale", 1.0))
		var world_foot := _grid_to_world(cell)

		var sprite := Sprite2D.new()
		sprite.name = "%s_%02d" % [asset_id.capitalize(), count + 1]
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * scale_value
		var center_to_foot := foot - Vector2(texture.get_width(), texture.get_height()) * 0.5
		sprite.position = world_foot - center_to_foot * scale_value
		if String(asset.get("layer", "")) == "ground":
			sprite.z_index = GROUND_DECOR_Z
		else:
			sprite.z_index = DECOR_BASE_Z + int(round(global_origin.y + world_foot.y))
		root.add_child(sprite)

		if blocker.x > 0.0 and blocker.y > 0.0:
			register_blocker.call(_blocker_polygon(world_foot, blocker))
		used[asset_id] = true
		count += 1

	var asset_ids := PackedStringArray()
	for asset_id in used.keys():
		asset_ids.append(String(asset_id))
	asset_ids.sort()
	return {"root": root, "count": count, "assets": asset_ids}


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


static func _texture_for(asset_id: String, path: String) -> Texture2D:
	if _texture_cache.has(asset_id):
		return _texture_cache[asset_id] as Texture2D
	if path.is_empty():
		return null
	var resource = ResourceLoader.load(path)
	if not resource is Texture2D:
		push_warning("CentralCityDecor: could not load prop %s from %s" % [asset_id, path])
		return null
	var texture := resource as Texture2D
	_texture_cache[asset_id] = texture
	return texture


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


static func _vec2(value) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _color(value) -> Color:
	if value is Array and value.size() >= 3:
		var alpha := float(value[3]) if value.size() >= 4 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return Color.WHITE
