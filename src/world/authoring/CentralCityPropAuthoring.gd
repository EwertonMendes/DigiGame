@tool
extends Marker2D
class_name CentralCityPropAuthoring

const CONFIG_PATH := "res://assets/resources/world/central_city_decor.json"
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0

@export var asset_id := "lamp_blue":
	set(value):
		asset_id = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_sync_preview")
@export var role := ""
@export_enum("none", "civic", "landscape") var surround := "none"
@export_enum("world", "behind_building") var depth := "world"
@export var clearance_override := Vector2(-1.0, -1.0)
@export var accent := Color(0.24, 0.88, 1.0, 1.0)


func _ready() -> void:
	if Engine.is_editor_hint():
		_sync_preview()
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(0.25, 0.85, 1.0, 0.95) if asset_id.begins_with("lamp") else Color(1.0, 0.78, 0.28, 0.95)
	draw_circle(Vector2.ZERO, 5.0, c)


func _sync_preview() -> void:
	var old := get_node_or_null("__EditorPropPreview")
	if old != null:
		old.free()
	if not Engine.is_editor_hint() or not FileAccess.file_exists(CONFIG_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		return
	var assets_value = (parsed as Dictionary).get("assets", {})
	if not assets_value is Dictionary:
		return
	var asset_value = (assets_value as Dictionary).get(asset_id, {})
	if not asset_value is Dictionary:
		return
	var asset := asset_value as Dictionary
	var resource = ResourceLoader.load(String(asset.get("path", "")))
	if not resource is Texture2D:
		return

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

	var sprite := Sprite2D.new()
	sprite.name = "__EditorPropPreview"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_value := float(asset.get("scale", 1.0))
	sprite.scale = Vector2.ONE * scale_value
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.88)
	sprite.z_index = -2

	var foot_value = asset.get("foot", [texture.get_width() * 0.5, texture.get_height()])
	var foot := Vector2(float(foot_value[0]), float(foot_value[1])) if foot_value is Array and foot_value.size() >= 2 else Vector2(texture.get_width() * 0.5, texture.get_height())
	var center_to_foot := foot - Vector2(texture.get_width(), texture.get_height()) * 0.5
	var grid := _world_to_grid(position)
	var elevation_px := 48.0 if grid.y < 19.5 else 0.0
	sprite.position = -center_to_foot * scale_value + Vector2(0.0, -elevation_px)
	add_child(sprite)


func _world_to_grid(world: Vector2) -> Vector2:
	return Vector2(
		world.x / TILE_WIDTH + world.y / TILE_HEIGHT,
		-world.x / TILE_WIDTH + world.y / TILE_HEIGHT
	)
