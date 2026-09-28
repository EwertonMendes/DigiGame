extends SceneTree

const LAYOUT = preload("res://src/world/runtime/CentralCityUrbanLayout.gd")


func _initialize() -> void:
	# A painted cell must cut through region fills and borders; otherwise a
	# perfectly valid paint stroke changes data while remaining invisible.
	var mask := LAYOUT._build_paint_mask({"-2,3": "road", "0,5": "water"})
	var texture := mask.get("texture") as ImageTexture
	assert(texture != null)
	assert(mask.get("origin") == Vector2i(-2, 3))
	var image := texture.get_image()
	assert(image.get_size() == Vector2i(3, 3))
	assert(image.get_pixel(0, 0).r > 0.99)
	assert(image.get_pixel(2, 2).r > 0.99)
	assert(image.get_pixel(1, 1).r < 0.01)
	var root := Node2D.new()
	var layer := {
		"id": "paint_visibility",
		"level": "south_terrace",
		"border_width": 2.0,
		"polygons": [{"grid_polygon": [[-3, 2], [2, 2], [2, 7], [-3, 7]]}],
	}
	LAYOUT._build_area_layer(root, layer, mask)
	assert(root.get_child_count() == 2)
	for child in root.get_children():
		var material := (child as MeshInstance2D).material as ShaderMaterial
		assert(material.get_shader_parameter("use_paint_mask") == true)
		assert(material.get_shader_parameter("paint_mask") == texture)
		assert(material.get_shader_parameter("paint_mask_origin") == Vector2(-2, 3))
	root.free()
	print("[CityPaintVisibility] painted materials override region fills and borders")
	quit()
