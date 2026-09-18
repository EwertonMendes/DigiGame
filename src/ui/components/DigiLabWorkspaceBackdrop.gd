extends Control
class_name DigiLabWorkspaceBackdrop

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const BACKGROUND = preload("res://assets/ui/backgrounds/digi_lab.webp")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var image := TextureRect.new()
	image.name = "DigiLabBackgroundImage"
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.texture = BACKGROUND
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.modulate = Color(0.94, 0.98, 1.0, 0.94)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)

	var shade := ColorRect.new()
	shade.name = "DigiLabBackgroundShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.004, 0.018, 0.030, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var cyan_wash := ColorRect.new()
	cyan_wash.name = "DigiLabCyanWash"
	cyan_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cyan_wash.color = Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.018)
	cyan_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cyan_wash)
