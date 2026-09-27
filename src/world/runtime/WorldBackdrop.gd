extends RefCounted
class_name WorldBackdrop

const BACKGROUND_SHADER = preload("res://shaders/hub_background.gdshader")


static func create() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "WorldBackdrop"
	layer.layer = -50

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_SHADER
	backdrop.material = material
	backdrop.color = Color(0.06, 0.12, 0.13, 1.0)
	layer.add_child(backdrop)
	return layer
