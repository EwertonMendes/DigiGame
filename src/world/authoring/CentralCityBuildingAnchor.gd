@tool
extends Marker2D
class_name CentralCityBuildingAnchor

const BUILDING_PREVIEW := {
	"digilab": {
		"path": "res://assets/world/tblack/digilab/digilab.png",
		"scale": Vector2(0.40, 0.31635585),
		"rotation_degrees": -2.48231,
		"door_pixel": Vector2(754.0, 1054.0),
		"elevation_px": 48.0,
	},
	"training": {
		"path": "res://assets/world/tblack/training-center/training-center.png",
		"scale": Vector2(0.36, 0.28231),
		"rotation_degrees": -2.20613,
		"door_pixel": Vector2(414.0, 1035.0),
		"elevation_px": 48.0,
	},
	"hospital": {
		"path": "res://assets/world/tblack/hospital/hospital.png",
		"scale": Vector2(0.35, 0.35),
		"rotation_degrees": -0.87567,
		"door_pixel": Vector2(627.0, 1000.0),
		"elevation_px": 48.0,
	},
}

@export_enum("digilab", "training", "hospital", "market", "archive") var building_id := "digilab":
	set(value):
		building_id = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_sync_preview")
			queue_redraw()
@export var editor_color := Color(0.45, 1.0, 0.55, 0.95)


func _ready() -> void:
	if Engine.is_editor_hint():
		_sync_preview()
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if not BUILDING_PREVIEW.has(building_id):
		var c := Color(1.0, 0.78, 0.25, 0.9) if building_id == "market" else Color(0.75, 0.48, 1.0, 0.9)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-28.0, 0.0),
				Vector2(0.0, -14.0),
				Vector2(28.0, 0.0),
				Vector2(0.0, 14.0),
			]),
			c
		)
	draw_circle(Vector2.ZERO, 8.0, editor_color)
	draw_line(Vector2(-14, 0), Vector2(14, 0), editor_color, 2.0)
	draw_line(Vector2(0, -14), Vector2(0, 14), editor_color, 2.0)


func _sync_preview() -> void:
	var old := get_node_or_null("__EditorBuildingPreview")
	if old != null:
		old.free()
	if not Engine.is_editor_hint() or not BUILDING_PREVIEW.has(building_id):
		return

	var data := BUILDING_PREVIEW[building_id] as Dictionary
	var resource = ResourceLoader.load(String(data.get("path", "")))
	if not resource is Texture2D:
		return
	var texture := resource as Texture2D
	var sprite := Sprite2D.new()
	sprite.name = "__EditorBuildingPreview"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = data.get("scale", Vector2.ONE) as Vector2
	sprite.rotation_degrees = float(data.get("rotation_degrees", 0.0))
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.82)
	sprite.z_index = -5

	var door_pixel := data.get("door_pixel", Vector2.ZERO) as Vector2
	var texture_center := texture.get_size() * 0.5
	var authored_door_offset := (
		(door_pixel - texture_center) * sprite.scale
	).rotated(sprite.rotation)
	var elevation_px := float(data.get("elevation_px", 0.0))
	sprite.position = -authored_door_offset + Vector2(0.0, -elevation_px)
	add_child(sprite)
