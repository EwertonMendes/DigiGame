extends SceneTree

const SOURCE := "res://assets/terrain/MCBlocksColorOutline.png"
const OUTPUT := "res://build/terrain-atlas-preview.png"


func _initialize() -> void:
	var image := Image.load_from_file(SOURCE)
	if image == null or image.is_empty():
		push_error("[TerrainAtlasProbe] Could not load atlas")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var error := image.save_png(OUTPUT)
	if error != OK:
		push_error("[TerrainAtlasProbe] Could not save preview: %s" % error_string(error))
		quit(1)
		return
	print("[TerrainAtlasProbe] SIZE %dx%d" % [image.get_width(), image.get_height()])
	print("[TerrainAtlasProbe] PASS")
	quit()
