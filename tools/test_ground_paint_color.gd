extends SceneTree

const DATA = preload("res://src/world/runtime/GroundPaintData.gd")
const PAINT = preload("res://src/world/authoring/CentralCityGroundPaintAuthoring.gd")
const AUTHORING = preload("res://src/world/authoring/CentralCityAuthoringData.gd")
const ART = preload("res://src/world/runtime/CentralCityArt.gd")


func _initialize() -> void:
	assert(ART.surface_base_color("main").is_equal_approx(Color(0.555, 0.575, 0.585)))
	var root := Node2D.new()
	var paint := PAINT.new()
	paint.name = "GroundPaint"
	root.add_child(paint)
	var red := Color(0.8, 0.2, 0.15)
	var blue := Color(0.15, 0.3, 0.8)
	paint.cells = {"0,0": "main", "1,0": DATA.entry("main", red), "2,0": DATA.entry("road", blue)}
	assert(paint.get_surface(Vector2i(2, 0)) == "road")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(AUTHORING._parse_ground_paint(root)))
	AUTHORING.set_preview_snapshot({"ground_paint": saved})
	assert(not AUTHORING.ground_override_at(Vector2.ZERO).has("base_color"))
	assert((AUTHORING.ground_override_at(Vector2(1, 0)).get("base_color") as Color).is_equal_approx(red))
	assert((AUTHORING.ground_override_at(Vector2(2, 0)).get("base_color") as Color).is_equal_approx(blue))
	assert(AUTHORING._parse_roads(root, {}).get("cells") == ["2,0"])
	var tiles: Array[Dictionary] = []
	for index in range(3):
		var spec := AUTHORING.ground_override_at(Vector2(index, 0))
		spec["position"] = Vector2(index * 32, index * 16)
		tiles.append(spec)
	var batch := ART.create_ground_batch(tiles, 0)
	var paving := batch.get_node("Surface_main") as MeshInstance2D
	var colors: PackedColorArray = paving.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	# Godot packs mesh vertex colors into RGBA8; allow one quantization step.
	assert(_mesh_color_matches(colors[0], ART.surface_base_color("main")))
	assert(_mesh_color_matches(colors[4], red), "Custom colors must be vertex colors in the existing material batch")
	assert(batch.get_child_count() == 4, "Adding colors must not add material batches or nodes")
	var undo := UndoRedo.new()
	var before := paint.cells.duplicate(true)
	paint.erase_cell(Vector2i(1, 0))
	var after := paint.cells.duplicate(true)
	paint.cells = before
	undo.create_action("Erase painted cell")
	undo.add_do_property(paint, "cells", after)
	undo.add_undo_property(paint, "cells", before)
	undo.commit_action()
	assert(paint.get_surface(Vector2i(1, 0)).is_empty())
	undo.undo()
	assert(DATA.color(paint.cells["1,0"]).is_equal_approx(red))
	undo.redo()
	assert(paint.get_surface(Vector2i(1, 0)).is_empty())
	undo.clear_history()
	undo.free()
	batch.free()
	root.free()
	AUTHORING.clear_preview_snapshot()
	print("[GroundPaintColor] default gray, custom color persistence, road metadata, batching, and undo/redo passed")
	quit()


func _mesh_color_matches(actual: Color, expected: Color) -> bool:
	return maxf(absf(actual.r - expected.r), maxf(absf(actual.g - expected.g), absf(actual.b - expected.b))) <= 1.0 / 255.0
