extends RefCounted
class_name ExternalCityArt

const ROOT := "res://assets/external/central_city/processed"

static var _texture_cache: Dictionary = {}


static func is_available() -> bool:
	return ResourceLoader.exists("%s/future/future_19.png" % ROOT) \
		and ResourceLoader.exists("%s/dystopian/dystopian_road_a.png" % ROOT)


static func texture(asset_name: String) -> Texture2D:
	if _texture_cache.has(asset_name):
		return _texture_cache[asset_name] as Texture2D

	var folder := "future" if asset_name.begins_with("future_") else "dystopian"
	var path := "%s/%s/%s.png" % [ROOT, folder, asset_name]
	if not ResourceLoader.exists(path):
		return null

	var resource = load(path)
	if resource is Texture2D:
		_texture_cache[asset_name] = resource
		return resource as Texture2D
	return null


static func create_ground_sprite(
	asset_name: String,
	ground_anchor: Vector2,
	depth_order: int,
	scale_value: float = 1.0,
	offset: Vector2 = Vector2.ZERO,
	filter_mode: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_NEAREST
) -> Sprite2D:
	var tex := texture(asset_name)
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = asset_name.capitalize().replace("_", "")
	sprite.texture = tex
	sprite.texture_filter = filter_mode
	sprite.scale = Vector2.ONE * scale_value
	sprite.position = ground_anchor - Vector2(0.0, float(tex.get_height()) * scale_value * 0.5) + offset
	sprite.z_index = clampi(depth_order, -4000, 4000)
	return sprite


static func create_centered_sprite(
	asset_name: String,
	center: Vector2,
	depth_order: int,
	scale_value: float = 1.0,
	tint: Color = Color.WHITE
) -> Sprite2D:
	var tex := texture(asset_name)
	if tex == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = asset_name.capitalize().replace("_", "")
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * scale_value
	sprite.position = center
	sprite.z_index = clampi(depth_order, -4000, 4000)
	sprite.modulate = tint
	return sprite
