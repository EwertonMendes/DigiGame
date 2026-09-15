extends CanvasLayer

signal transition_started(scene_path: String, context: String)
signal transition_midpoint(scene_path: String, context: String)
signal transition_finished(scene_path: String, context: String)

const TRANSITION_SHADER = preload("res://shaders/digital_scene_transition.gdshader")
const HUB_SCENE_PATH := "res://scenes/world/hub.tscn"
const CONTEXT_BATTLE := "battle"
const CONTEXT_HUB := "hub"
const LOAD_TIMEOUT_MS := 8000

var _root: Control = null
var _screen: ColorRect = null
var _material: ShaderMaterial = null
var _busy := false
var _progress := 0.0


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	set_process_input(true)


func _input(_event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()


func is_transitioning() -> bool:
	return _busy


func request_scene(scene_path: String, context: String = "generic") -> bool:
	if _busy:
		return false
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("DigitalSceneTransition: scene does not exist: %s" % scene_path)
		return false
	_busy = true
	call_deferred("_run_transition", scene_path, context)
	return true


func return_to_hub() -> bool:
	return request_scene(HUB_SCENE_PATH, CONTEXT_HUB)


func enter_battle(scene_path: String) -> bool:
	return request_scene(scene_path, CONTEXT_BATTLE)


func _build_overlay() -> void:
	_root = Control.new()
	_root.name = "DigitalSceneTransitionOverlay"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_material = ShaderMaterial.new()
	_material.shader = TRANSITION_SHADER
	_material.set_shader_parameter("progress", 0.0)
	_material.set_shader_parameter("flash", 0.0)

	_screen = ColorRect.new()
	_screen.name = "DigitalMosaic"
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.material = _material
	_screen.color = Color.WHITE
	_root.add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _run_transition(scene_path: String, context: String) -> void:
	transition_started.emit(scene_path, context)
	print("[Transition] START context=%s target=%s" % [context, scene_path])
	_configure_palette(context)
	_material.set_shader_parameter("phase_seed", fmod(float(Time.get_ticks_msec()) * 0.001, 97.0))
	_set_progress(0.0)
	_set_flash(0.0)

	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()

	# Begin loading before the effect becomes visually dense. The previous
	# implementation loaded synchronously at the midpoint, which could freeze the
	# shader and make a deliberately smooth transition feel like a loading screen.
	var request_error := ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if request_error != OK:
		var existing_status := ResourceLoader.load_threaded_get_status(scene_path)
		if existing_status != ResourceLoader.THREAD_LOAD_IN_PROGRESS and existing_status != ResourceLoader.THREAD_LOAD_LOADED:
			push_error("DigitalSceneTransition: could not start threaded load for %s (error %d)" % [scene_path, request_error])
			_busy = false
			return

	_root.visible = true

	# Most of the cover happens while the destination scene is loading. Even if a
	# slower device needs a little longer, the mosaic keeps moving because all of
	# its life comes from shader TIME rather than CPU-created squares.
	var cover := create_tween()
	cover.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	cover.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	cover.tween_method(_set_progress, 0.0, 0.94, 0.42)
	await cover.finished

	var packed_scene := await _await_threaded_scene(scene_path)
	if packed_scene == null:
		push_error("DigitalSceneTransition: threaded scene load failed or timed out: %s" % scene_path)
		await _abort_transition()
		return

	# Seal only for a few frames. This is the sole fully opaque part of the effect
	# and it exists only to hide the actual scene-tree replacement.
	var seal := create_tween().set_parallel(true)
	seal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	seal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	seal.tween_method(_set_progress, 0.94, 1.0, 0.085)
	seal.tween_method(_set_flash, 0.0, 0.52, 0.085)
	await seal.finished

	var change_error := get_tree().change_scene_to_packed(packed_scene)
	if change_error != OK:
		push_error("DigitalSceneTransition: failed to change scene to %s (error %d)" % [scene_path, change_error])
		await _abort_transition()
		return

	transition_midpoint.emit(scene_path, context)
	print("[Transition] MIDPOINT context=%s" % context)
	await get_tree().process_frame

	# Reveal immediately. There is no status card or artificial hold: the new
	# scene simply reconstructs through the same moving cells in reverse.
	var reveal := create_tween().set_parallel(true)
	reveal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_method(_set_progress, 1.0, 0.0, 0.44)
	reveal.tween_method(_set_flash, 0.52, 0.0, 0.16)
	await reveal.finished

	_finish_transition(scene_path, context)


func _await_threaded_scene(scene_path: String) -> PackedScene:
	var started_at := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < LOAD_TIMEOUT_MS:
		var status := ResourceLoader.load_threaded_get_status(scene_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded := ResourceLoader.load_threaded_get(scene_path)
			if loaded is PackedScene:
				print("[Transition] PRELOAD_READY target=%s wait_ms=%d" % [scene_path, Time.get_ticks_msec() - started_at])
				return loaded as PackedScene
			return null
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		await get_tree().process_frame
	return null


func _abort_transition() -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_progress, _progress, 0.0, 0.24)
	tween.tween_method(_set_flash, float(_material.get_shader_parameter("flash")), 0.0, 0.16)
	await tween.finished
	_root.visible = false
	_busy = false
	_set_progress(0.0)
	_set_flash(0.0)


func _finish_transition(scene_path: String, context: String) -> void:
	_root.visible = false
	_set_progress(0.0)
	_set_flash(0.0)
	_busy = false
	transition_finished.emit(scene_path, context)
	print("[Transition] FINISH context=%s" % context)


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	if _material != null:
		_material.set_shader_parameter("progress", _progress)


func _set_flash(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("flash", clampf(value, 0.0, 1.0))


func _configure_palette(context: String) -> void:
	# Keep the palette luminous and cohesive with the game without falling back to
	# the previous cyan/orange loading-screen look.
	if context == CONTEXT_BATTLE:
		_material.set_shader_parameter("primary_color", Color(0.40, 0.82, 1.0, 1.0))
		_material.set_shader_parameter("accent_color", Color(0.60, 0.48, 1.0, 1.0))
		_material.set_shader_parameter("cover_color", Color(0.035, 0.070, 0.145, 1.0))
	elif context == CONTEXT_HUB:
		_material.set_shader_parameter("primary_color", Color(0.35, 0.93, 0.84, 1.0))
		_material.set_shader_parameter("accent_color", Color(0.38, 0.66, 1.0, 1.0))
		_material.set_shader_parameter("cover_color", Color(0.025, 0.080, 0.115, 1.0))
	else:
		_material.set_shader_parameter("primary_color", Color(0.42, 0.84, 1.0, 1.0))
		_material.set_shader_parameter("accent_color", Color(0.55, 0.55, 1.0, 1.0))
		_material.set_shader_parameter("cover_color", Color(0.03, 0.07, 0.13, 1.0))
