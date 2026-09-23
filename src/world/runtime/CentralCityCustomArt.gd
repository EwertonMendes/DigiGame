extends RefCounted
class_name CentralCityCustomArt

const ROOT := "res://assets/terrain/tblack-central-city/runtime"

static var _texture_cache: Dictionary = {}


static func is_available() -> bool:
	return (
		ResourceLoader.exists("%s/road.png" % ROOT)
		and ResourceLoader.exists("%s/sidewalk.png" % ROOT)
		and ResourceLoader.exists("%s/plaza-floor.png" % ROOT)
		and ResourceLoader.exists("%s/grass-ground.png" % ROOT)
		and ResourceLoader.exists("%s/crosswalk.png" % ROOT)
		and ResourceLoader.exists("%s/digital-terminal.png" % ROOT)
		and ResourceLoader.exists("%s/public-bench.png" % ROOT)
		and ResourceLoader.exists("%s/trash-bin.png" % ROOT)
		and ResourceLoader.exists("%s/planter.png" % ROOT)
		and ResourceLoader.exists("%s/small-tree.png" % ROOT)
		and ResourceLoader.exists("%s/medium-tree.png" % ROOT)
	)


static func texture(asset_name: String) -> Texture2D:
	if _texture_cache.has(asset_name):
		return _texture_cache[asset_name] as Texture2D
	var path := "%s/%s.png" % [ROOT, asset_name]
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if resource is Texture2D:
		_texture_cache[asset_name] = resource
		return resource as Texture2D
	return null


static func create_ground_patch(
	asset_name: String,
	center: Vector2,
	depth_order: int,
	target_width: float,
	flip_h: bool = false
) -> Sprite2D:
	var tex := texture(asset_name)
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = asset_name.capitalize().replace("-", "")
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var scale_value := target_width / maxf(1.0, float(tex.get_width()))
	sprite.scale = Vector2.ONE * scale_value
	sprite.position = center
	sprite.flip_h = flip_h
	sprite.z_index = clampi(depth_order, -4000, 4000)
	sprite.add_to_group("central_city_custom_asset")
	return sprite


static func create_ground_prop(
	asset_name: String,
	foot: Vector2,
	depth_order: int,
	target_width: float,
	offset: Vector2 = Vector2.ZERO,
	flip_h: bool = false
) -> Sprite2D:
	var tex := texture(asset_name)
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = asset_name.capitalize().replace("-", "")
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var scale_value := target_width / maxf(1.0, float(tex.get_width()))
	sprite.scale = Vector2.ONE * scale_value
	sprite.flip_h = flip_h
	sprite.position = foot - Vector2(0.0, float(tex.get_height()) * scale_value * 0.5) + offset
	sprite.z_index = clampi(depth_order, -4000, 4000)
	sprite.add_to_group("central_city_custom_asset")
	return sprite
