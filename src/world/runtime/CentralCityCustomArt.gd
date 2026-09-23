extends RefCounted
class_name CentralCityCustomArt

const Catalog = preload("res://src/world/runtime/CentralCityAssetCatalog.gd")
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


static func create_ground_asset(
	asset_name: String,
	center: Vector2,
	depth_order: int,
	flip_h: bool = false
) -> Sprite2D:
	var tex := texture(asset_name)
	if tex == null or not Catalog.has(asset_name):
		return null

	var sprite := Sprite2D.new()
	sprite.name = asset_name.capitalize().replace("-", "")
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var target_width := Catalog.logical_visual_width(asset_name)
	var scale_value := target_width / maxf(1.0, float(tex.get_width()))
	sprite.scale = Vector2.ONE * scale_value
	sprite.position = center
	sprite.flip_h = flip_h
	sprite.z_index = clampi(depth_order, -4000, 4000)
	sprite.add_to_group("central_city_custom_asset")
	sprite.add_to_group("central_city_ground_module")
	if asset_name == "road":
		sprite.add_to_group("central_city_road_module")
	elif asset_name == "crosswalk":
		sprite.add_to_group("central_city_crosswalk_module")
	sprite.set_meta("logical_footprint", Catalog.footprint(asset_name))
	sprite.set_meta("asset_id", asset_name)
	return sprite


static func create_prop(
	asset_name: String,
	foot: Vector2,
	depth_order: int,
	flip_h: bool = false
) -> Sprite2D:
	var tex := texture(asset_name)
	if tex == null or not Catalog.has(asset_name):
		return null

	var sprite := Sprite2D.new()
	sprite.name = asset_name.capitalize().replace("-", "")
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var target_width := Catalog.logical_visual_width(asset_name)
	var scale_value := target_width / maxf(1.0, float(tex.get_width()))
	sprite.scale = Vector2.ONE * scale_value
	sprite.flip_h = flip_h

	var anchor := Catalog.anchor(asset_name)
	var effective_anchor_x := 1.0 - anchor.x if flip_h else anchor.x
	var scaled_size := Vector2(float(tex.get_width()), float(tex.get_height())) * scale_value
	var anchor_from_center := Vector2(
		(effective_anchor_x - 0.5) * scaled_size.x,
		(anchor.y - 0.5) * scaled_size.y
	)
	sprite.position = foot - anchor_from_center
	sprite.z_index = clampi(depth_order, -4000, 4000)
	sprite.add_to_group("central_city_custom_asset")
	sprite.add_to_group("central_city_prop")
	sprite.set_meta("asset_id", asset_name)
	sprite.set_meta("collision_footprint", Catalog.collision_footprint(asset_name))
	return sprite


# Compatibility shims for code outside Central City that may still call the
# previous API. New Central City layout code must use create_ground_asset/create_prop.
static func create_ground_patch(
	asset_name: String,
	center: Vector2,
	depth_order: int,
	_target_width: float,
	flip_h: bool = false
) -> Sprite2D:
	return create_ground_asset(asset_name, center, depth_order, flip_h)


static func create_ground_prop(
	asset_name: String,
	foot: Vector2,
	depth_order: int,
	_target_width: float,
	offset: Vector2 = Vector2.ZERO,
	flip_h: bool = false
) -> Sprite2D:
	var sprite := create_prop(asset_name, foot, depth_order, flip_h)
	if sprite != null:
		sprite.position += offset
	return sprite
