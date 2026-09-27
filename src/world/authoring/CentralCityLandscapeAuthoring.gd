@tool
extends Marker2D
class_name CentralCityLandscapeAuthoring

const OAK_TREE_SOURCE = preload("res://assets/terrain/Oak_Tree.png")
const LARGE_OAK_REGION := Rect2(11.0, 9.0, 41.0, 63.0)
const LARGE_OAK_FOOT := Vector2(20.5, 62.0)
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0

@export var landscape_id := ""
@export var section_coord := Vector2i.ZERO
@export var preferred_local_cell := Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		_sync_preview()
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var elevation_px := 48.0 if _world_to_grid(position).y < 19.5 else 0.0
	var center := Vector2(0.0, -elevation_px)
	var half_width := 32.0 * 2.45
	var half_height := 16.0 * 2.45
	var island := PackedVector2Array([
		center + Vector2(-half_width, 0.0),
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, half_height),
	])
	draw_colored_polygon(island, Color(0.32, 0.68, 0.22, 0.38))
	var outline := island.duplicate()
	outline.append(island[0])
	draw_polyline(outline, Color(0.18, 0.80, 0.88, 0.75), 2.0, false)


func _sync_preview() -> void:
	var old := get_node_or_null("__EditorTreePreview")
	if old != null:
		old.free()
	if not Engine.is_editor_hint():
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = OAK_TREE_SOURCE
	atlas.region = LARGE_OAK_REGION
	atlas.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.name = "__EditorTreePreview"
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var center_to_foot := LARGE_OAK_FOOT - atlas.get_size() * 0.5
	var elevation_px := 48.0 if _world_to_grid(position).y < 19.5 else 0.0
	sprite.position = Vector2(0.0, 10.0 - elevation_px) - center_to_foot
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.9)
	add_child(sprite)


func _world_to_grid(world: Vector2) -> Vector2:
	return Vector2(
		world.x / TILE_WIDTH + world.y / TILE_HEIGHT,
		-world.x / TILE_WIDTH + world.y / TILE_HEIGHT
	)
