extends Node
class_name DebugWorldMapCapture

signal capture_started(total_tiles: int, output_size: Vector2i)
signal capture_progress(completed_tiles: int, total_tiles: int)
signal capture_finished(result: Dictionary)

enum CaptureMode {
	WORLD_SNAPSHOT,
	CLEAN_MAP,
}

const CLEAN_HIDDEN_GROUP := "debug_capture_clean_hidden"
const CLEAN_VFX_GROUP := "debug_capture_clean_vfx"
const ANNOTATION_GROUP := "world_annotation_unlit"
const DEFAULT_TILE_SIZE := Vector2i(1024, 768)
const MAX_OUTPUT_PIXELS := 90000000
const OUTPUT_DIRECTORY := "user://captures"

var _capturing := false
var _viewport: SubViewport = null
var _camera: Camera2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_capturing() -> bool:
	return _capturing


func capture(world_root: Node, mode: int, scale_factor: int = 1) -> Dictionary:
	if _capturing:
		return _failure("A map capture is already running.")
	if world_root == null or not is_instance_valid(world_root):
		return _failure("Campaign world is unavailable.")
	if not world_root.has_method("is_world_ready") or not bool(world_root.call("is_world_ready")):
		return _failure("Wait for the campaign world to finish loading before capturing.")
	if not world_root.has_method("get_area_scene"):
		return _failure("Current scene does not expose a capturable world area.")

	var area = world_root.call("get_area_scene")
	if area == null or not is_instance_valid(area) or not area.has_method("get_debug_capture_bounds"):
		return _failure("Current world area does not expose authored capture bounds.")
	if area.has_method("is_exterior_active") and not bool(area.call("is_exterior_active")):
		return _failure("Full-map capture is only available while the exterior area is active.")

	var scale := clampi(scale_factor, 1, 2)
	var bounds := _normalized_bounds(area.call("get_debug_capture_bounds") as Rect2)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return _failure("Current world area returned invalid capture bounds.")

	var output_size := Vector2i(
		ceili(bounds.size.x * float(scale)),
		ceili(bounds.size.y * float(scale))
	)
	var pixel_count := int(output_size.x) * int(output_size.y)
	if pixel_count <= 0 or pixel_count > MAX_OUTPUT_PIXELS:
		return _failure(
			"Capture would be %d×%d (%d MP), above the debug safety limit."
			% [output_size.x, output_size.y, ceili(float(pixel_count) / 1000000.0)]
		)

	var plan := build_capture_plan(bounds, scale, DEFAULT_TILE_SIZE)
	if plan.is_empty():
		return _failure("No capture tiles were produced for the current area.")

	_capturing = true
	var paused_before := get_tree().paused
	var hidden_state: Array[Dictionary] = []
	var lighting: Node = null
	var lighting_capture_before := false
	if world_root.has_method("get_lighting_system"):
		lighting = world_root.call("get_lighting_system") as Node
		if lighting != null and is_instance_valid(lighting):
			if lighting.has_method("is_debug_capture_active"):
				lighting_capture_before = bool(lighting.call("is_debug_capture_active"))
			if lighting.has_method("set_debug_capture_active"):
				lighting.call("set_debug_capture_active", true)
	get_tree().paused = true

	if mode == CaptureMode.CLEAN_MAP:
		hidden_state = _hide_clean_map_nodes()

	_ensure_capture_viewport()
	_viewport.world_2d = get_viewport().world_2d
	_camera.zoom = Vector2.ONE * float(scale)

	var canvas := Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var total_tiles := plan.size()
	capture_started.emit(total_tiles, output_size)

	var capture_error := ""
	for index in range(total_tiles):
		var tile := plan[index] as Dictionary
		var tile_image: Image = await _render_tile(tile, scale)
		if tile_image == null or tile_image.is_empty():
			capture_error = "Failed to render capture tile %d of %d." % [index + 1, total_tiles]
			break

		var pixel_size := tile.get("pixel_size", Vector2i.ZERO) as Vector2i
		if tile_image.get_size() != pixel_size:
			capture_error = (
				"Rendered tile size mismatch: expected %s, got %s."
				% [str(pixel_size), str(tile_image.get_size())]
			)
			break

		var destination := tile.get("destination", Vector2i.ZERO) as Vector2i
		canvas.blit_rect(
			tile_image,
			Rect2i(Vector2i.ZERO, pixel_size),
			destination
		)
		capture_progress.emit(index + 1, total_tiles)

	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_restore_hidden_state(hidden_state)
	if lighting != null and is_instance_valid(lighting) and lighting.has_method("set_debug_capture_active"):
		lighting.call("set_debug_capture_active", lighting_capture_before)
	get_tree().paused = paused_before
	_capturing = false

	if not capture_error.is_empty():
		var failed := _failure(capture_error)
		capture_finished.emit(failed)
		return failed

	var mode_name := "clean" if mode == CaptureMode.CLEAN_MAP else "snapshot"
	var filename := _build_filename(world_root, mode_name, scale)
	var save_result := _deliver_png(canvas, filename)
	save_result["mode"] = mode_name
	save_result["scale"] = scale
	save_result["size"] = output_size
	save_result["bounds"] = bounds
	save_result["tiles"] = total_tiles
	capture_finished.emit(save_result)
	return save_result


static func build_capture_plan(
	bounds: Rect2,
	scale_factor: int,
	tile_size: Vector2i = DEFAULT_TILE_SIZE
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var scale := clampi(scale_factor, 1, 2)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return result
	if tile_size.x <= 0 or tile_size.y <= 0:
		return result

	var output_size := Vector2i(
		ceili(bounds.size.x * float(scale)),
		ceili(bounds.size.y * float(scale))
	)
	for output_y in range(0, output_size.y, tile_size.y):
		for output_x in range(0, output_size.x, tile_size.x):
			var chunk := Vector2i(
				mini(tile_size.x, output_size.x - output_x),
				mini(tile_size.y, output_size.y - output_y)
			)
			var world_top_left := bounds.position + Vector2(
				float(output_x) / float(scale),
				float(output_y) / float(scale)
			)
			var world_size := Vector2(chunk) / float(scale)
			result.append({
				"destination": Vector2i(output_x, output_y),
				"pixel_size": chunk,
				"world_rect": Rect2(world_top_left, world_size),
			})
	return result


func _render_tile(tile: Dictionary, scale: int) -> Image:
	var pixel_size := tile.get("pixel_size", Vector2i.ZERO) as Vector2i
	var world_rect := tile.get("world_rect", Rect2()) as Rect2
	if pixel_size.x <= 0 or pixel_size.y <= 0 or world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return null

	_viewport.size = pixel_size
	_camera.zoom = Vector2.ONE * float(scale)
	_camera.global_position = world_rect.position + world_rect.size * 0.5
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Two completed draw frames guarantee that both the viewport resize and the
	# camera transform have reached RenderingServer before reading pixels.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var image := _viewport.get_texture().get_image()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return image


func _ensure_capture_viewport() -> void:
	if _viewport != null and is_instance_valid(_viewport) and _camera != null and is_instance_valid(_camera):
		return

	_viewport = SubViewport.new()
	_viewport.name = "DebugFullMapCaptureViewport"
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_camera = Camera2D.new()
	_camera.name = "CaptureCamera"
	_camera.enabled = true
	_camera.position_smoothing_enabled = false
	_camera.rotation_smoothing_enabled = false
	_viewport.add_child(_camera)


func _hide_clean_map_nodes() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var seen: Dictionary = {}
	for group_name in [CLEAN_HIDDEN_GROUP, CLEAN_VFX_GROUP, ANNOTATION_GROUP]:
		for raw_node in get_tree().get_nodes_in_group(group_name):
			if not raw_node is CanvasItem:
				continue
			var item := raw_node as CanvasItem
			var id := item.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			states.append({
				"node": item,
				"visible": item.visible,
			})
			item.visible = false
	return states


func _restore_hidden_state(states: Array[Dictionary]) -> void:
	for state in states:
		var item = state.get("node")
		if item is CanvasItem and is_instance_valid(item):
			(item as CanvasItem).visible = bool(state.get("visible", true))


func _deliver_png(image: Image, filename: String) -> Dictionary:
	if OS.has_feature("web"):
		var png := image.save_png_to_buffer()
		if png.is_empty():
			return _failure("PNG encoding failed in the Web build.")
		JavaScriptBridge.download_buffer(png, filename, "image/png")
		return {
			"ok": true,
			"message": "Browser download started: %s" % filename,
			"path": filename,
			"web_download": true,
		}

	var dir := DirAccess.open("user://")
	if dir == null:
		return _failure("Could not open the project user-data directory.")
	var make_error := dir.make_dir_recursive("captures")
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		return _failure("Could not create user://captures (error %d)." % make_error)

	var path := "%s/%s" % [OUTPUT_DIRECTORY, filename]
	var save_error := image.save_png(path)
	if save_error != OK:
		return _failure("Could not save PNG (error %d)." % save_error)
	return {
		"ok": true,
		"message": "Saved full-map capture to %s" % ProjectSettings.globalize_path(path),
		"path": ProjectSettings.globalize_path(path),
		"web_download": false,
	}


func _build_filename(world_root: Node, mode_name: String, scale: int) -> String:
	var area_id := "world"
	if world_root.has_method("get_area_id"):
		area_id = String(world_root.call("get_area_id")).strip_edges().to_lower().replace(" ", "_")
	if area_id.is_empty():
		area_id = "world"

	var timestamp := Time.get_datetime_string_from_system()
	timestamp = timestamp.replace(":", "-").replace("T", "_")
	return "%s_%s_%s_%dx.png" % [area_id, mode_name, timestamp, scale]


func _normalized_bounds(raw: Rect2) -> Rect2:
	var left := floorf(raw.position.x)
	var top := floorf(raw.position.y)
	var right := ceilf(raw.end.x)
	var bottom := ceilf(raw.end.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
		"path": "",
	}
