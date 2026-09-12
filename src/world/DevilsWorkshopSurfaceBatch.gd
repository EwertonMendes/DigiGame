extends Node2D
class_name DevilsWorkshopSurfaceBatch

const ART = preload("res://src/world/DevilsWorkshopArt.gd")

var _entries: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func set_entries(entries: Array[Dictionary]) -> void:
	_entries = entries.duplicate(false)
	queue_redraw()


func _draw() -> void:
	if _entries.is_empty():
		return

	# Draw every slightly oversized opaque base first. Details are drawn in a
	# second pass so seam-protection geometry can never cover a neighbouring top
	# texture. One CanvasItem records all commands instead of creating three scene
	# nodes per grid tile.
	for entry: Dictionary in _entries:
		var position := Vector2(entry.get("position", Vector2.ZERO))
		var base_color: Color = entry.get("base_color", Color.WHITE)
		draw_set_transform(position)
		draw_colored_polygon(ART.tile_diamond(ART.BASE_OVERSCAN), base_color)

	for entry: Dictionary in _entries:
		var position := Vector2(entry.get("position", Vector2.ZERO))
		var texture := entry.get("texture") as Texture2D
		if texture == null:
			continue
		var detail_tint: Color = entry.get("detail_tint", Color.WHITE)
		var detail_alpha := clampf(float(entry.get("detail_alpha", 0.42)), 0.0, 1.0)
		var detail_color := Color(detail_tint.r, detail_tint.g, detail_tint.b, detail_alpha)
		draw_set_transform(position)
		draw_colored_polygon(ART.tile_diamond(), detail_color, ART.top_face_uv(), texture)

	draw_set_transform(Vector2.ZERO)
