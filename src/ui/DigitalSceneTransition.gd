extends CanvasLayer

signal transition_started(scene_path: String, context: String)
signal transition_midpoint(scene_path: String, context: String)
signal transition_finished(scene_path: String, context: String)

const TRANSITION_SHADER = preload("res://shaders/digital_scene_transition.gdshader")
const HUB_SCENE_PATH := "res://scenes/world/hub.tscn"
const CONTEXT_BATTLE := "battle"
const CONTEXT_HUB := "hub"
const LOAD_TIMEOUT_MS := 10000
const FX_LONG_EDGE := 320
const FX_MIN_EDGE := 112
const FIELD_ITEMS_PER_FRAME := 20
const ACTORS_PER_FRAME := 1

var _root: Control = null
var _screen: TextureRect = null
var _fx_viewport: SubViewport = null
var _fx_rect: ColorRect = null
var _material: ShaderMaterial = null
var _busy := false
var _progress := 0.0

# Resource loading is threaded. Scene construction is then spread over multiple
# rendered frames before the visual transition starts, so preparation never has
# to compete with the animation for one large main-thread frame.
var _resource_cache: Dictionary = {}
var _preload_inflight: Dictionary = {}
var _prepared_instances: Dictionary = {}
var _prepare_inflight: Dictionary = {}

# Terminal Commons stays mounted but dormant while combat is active. Returning
# from battle simply wakes the same scene instead of rebuilding the whole hub.
var _retained_hub: Node = null


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	get_viewport().size_changed.connect(_resize_fx_viewport)
	_resize_fx_viewport()
	set_process_input(true)


func _input(_event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()


func is_transitioning() -> bool:
	return _busy


func is_scene_prepared(scene_path: String) -> bool:
	if scene_path == HUB_SCENE_PATH and _retained_hub != null and is_instance_valid(_retained_hub):
		return true
	return _prepared_instances.has(scene_path)


func preload_scene(scene_path: String) -> void:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return
	if _resource_cache.has(scene_path) or _preload_inflight.has(scene_path):
		return
	_preload_inflight[scene_path] = true
	call_deferred("_preload_scene_worker", scene_path)


func prepare_scene(scene_path: String) -> void:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return
	if _prepared_instances.has(scene_path) or _prepare_inflight.has(scene_path):
		return
	if scene_path == HUB_SCENE_PATH and _retained_hub != null and is_instance_valid(_retained_hub):
		return
	_prepare_inflight[scene_path] = true
	call_deferred("_prepare_scene_worker", scene_path)


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

	# Render the effect at a tiny internal resolution and scale it with nearest
	# filtering. The squares stay intentionally crisp while fragment work drops by
	# more than an order of magnitude on phone/integrated GPUs.
	_fx_viewport = SubViewport.new()
	_fx_viewport.name = "LowResolutionTransitionFX"
	_fx_viewport.transparent_bg = true
	_fx_viewport.disable_3d = true
	_fx_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_fx_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(_fx_viewport)

	_material = ShaderMaterial.new()
	_material.shader = TRANSITION_SHADER
	_material.set_shader_parameter("progress", 0.0)
	_material.set_shader_parameter("flash", 0.0)

	_fx_rect = ColorRect.new()
	_fx_rect.name = "DigitalMosaicLowRes"
	_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_rect.material = _material
	_fx_rect.color = Color.WHITE
	_fx_viewport.add_child(_fx_rect)

	_screen = TextureRect.new()
	_screen.name = "DigitalMosaic"
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.texture = _fx_viewport.get_texture()
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _resize_fx_viewport() -> void:
	if _fx_viewport == null or _fx_rect == null:
		return
	var visible_size := get_viewport().get_visible_rect().size
	if visible_size.x <= 1.0 or visible_size.y <= 1.0:
		return
	var long_edge := maxf(visible_size.x, visible_size.y)
	var scale := float(FX_LONG_EDGE) / long_edge
	var target := Vector2i(
		maxi(FX_MIN_EDGE, int(round(visible_size.x * scale))),
		maxi(FX_MIN_EDGE, int(round(visible_size.y * scale)))
	)
	if _fx_viewport.size == target:
		return
	_fx_viewport.size = target
	_fx_rect.position = Vector2.ZERO
	_fx_rect.size = Vector2(target)
	_material.set_shader_parameter("cell_pixels", 8.0)


func _set_fx_active(active: bool) -> void:
	if _fx_viewport == null:
		return
	_fx_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


func _preload_scene_worker(scene_path: String) -> void:
	var packed_scene := await _load_packed_scene(scene_path)
	if packed_scene != null:
		_resource_cache[scene_path] = packed_scene
	_preload_inflight.erase(scene_path)


func _prepare_scene_worker(scene_path: String) -> void:
	var packed_scene := await _load_packed_scene(scene_path)
	if packed_scene == null:
		_prepare_inflight.erase(scene_path)
		return
	_resource_cache[scene_path] = packed_scene
	if _prepared_instances.has(scene_path):
		_prepare_inflight.erase(scene_path)
		return

	# PackedScene.instantiate() itself cannot run on a worker thread. Give loading
	# a frame to settle, instantiate detached, then frame-budget the expensive
	# generated field and actor bootstrap below.
	await get_tree().process_frame
	var instantiate_started := Time.get_ticks_usec()
	var instance := packed_scene.instantiate()
	var instantiate_ms := float(Time.get_ticks_usec() - instantiate_started) / 1000.0
	if instance == null:
		_prepare_inflight.erase(scene_path)
		return
	_set_scene_active(instance, false)

	var spread_started := Time.get_ticks_msec()
	await _prepare_expensive_offtree_nodes(instance)
	var spread_ms := Time.get_ticks_msec() - spread_started
	_prepared_instances[scene_path] = instance
	_prepare_inflight.erase(scene_path)
	print("[TransitionPerf] PREPARED target=%s instantiate_ms=%.2f spread_ms=%d" % [scene_path, instantiate_ms, spread_ms])


func _prepare_expensive_offtree_nodes(instance: Node) -> void:
	# Field first: actor deployment reads tile_map_data. Both components expose a
	# chunk API so low-end devices create a small, bounded amount of work per frame.
	var field := instance.get_node_or_null("Blocks")
	if field != null and field.has_method("begin_transition_preparation") and field.has_method("prepare_transition_chunk"):
		field.call("begin_transition_preparation")
		while not bool(field.call("prepare_transition_chunk", FIELD_ITEMS_PER_FRAME)):
			await get_tree().process_frame
	elif field != null and field.has_method("prepare_transition_offtree"):
		field.call("prepare_transition_offtree")

	var controller := instance.get_node_or_null("DigimonController")
	if controller != null and controller.has_method("begin_transition_preparation") and controller.has_method("prepare_transition_chunk"):
		controller.call("begin_transition_preparation")
		while not bool(controller.call("prepare_transition_chunk", ACTORS_PER_FRAME)):
			await get_tree().process_frame
	elif controller != null and controller.has_method("prepare_transition_offtree"):
		controller.call("prepare_transition_offtree")


func _load_packed_scene(scene_path: String) -> PackedScene:
	if _resource_cache.has(scene_path):
		var cached = _resource_cache[scene_path]
		if cached is PackedScene:
			return cached as PackedScene

	var status := ResourceLoader.load_threaded_get_status(scene_path)
	if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS and status != ResourceLoader.THREAD_LOAD_LOADED:
		var request_error := ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
		if request_error != OK:
			status = ResourceLoader.load_threaded_get_status(scene_path)
			if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS and status != ResourceLoader.THREAD_LOAD_LOADED:
				return null

	var started_at := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < LOAD_TIMEOUT_MS:
		status = ResourceLoader.load_threaded_get_status(scene_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded := ResourceLoader.load_threaded_get(scene_path)
			if loaded is PackedScene:
				return loaded as PackedScene
			return null
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		await get_tree().process_frame
	return null


func _await_prepared_scene(scene_path: String) -> Node:
	if scene_path == HUB_SCENE_PATH and _retained_hub != null and is_instance_valid(_retained_hub):
		return _retained_hub
	if _prepared_instances.has(scene_path):
		return _take_prepared_scene(scene_path)

	prepare_scene(scene_path)
	var started_at := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < LOAD_TIMEOUT_MS:
		if scene_path == HUB_SCENE_PATH and _retained_hub != null and is_instance_valid(_retained_hub):
			return _retained_hub
		if _prepared_instances.has(scene_path):
			return _take_prepared_scene(scene_path)
		if not _prepare_inflight.has(scene_path):
			return null
		await get_tree().process_frame
	return null


func _take_prepared_scene(scene_path: String) -> Node:
	var instance = _prepared_instances.get(scene_path)
	_prepared_instances.erase(scene_path)
	return instance as Node


func _run_transition(scene_path: String, context: String) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()

	# The visible effect starts only after all expensive scene preparation is done.
	# Hub prewarm normally finishes this long before START is pressed. If a very
	# slow device races it, frames keep rendering while this coroutine waits.
	var prepared_scene := await _await_prepared_scene(scene_path)
	if prepared_scene == null:
		push_error("DigitalSceneTransition: could not prepare scene: %s" % scene_path)
		_busy = false
		return

	transition_started.emit(scene_path, context)
	print("[Transition] START context=%s target=%s" % [context, scene_path])
	_configure_palette(context)
	_material.set_shader_parameter("phase_seed", fmod(float(Time.get_ticks_msec()) * 0.001, 97.0))
	_set_progress(0.0)
	_set_flash(0.0)
	_set_fx_active(true)
	_root.visible = true

	var cover := create_tween()
	cover.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	cover.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	cover.tween_method(_set_progress, 0.0, 0.95, 0.34)
	await cover.finished

	var seal := create_tween().set_parallel(true)
	seal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	seal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	seal.tween_method(_set_progress, 0.95, 1.0, 0.055)
	seal.tween_method(_set_flash, 0.0, 0.34, 0.055)
	await seal.finished

	var swap_started := Time.get_ticks_usec()
	var change_error := _swap_scene(prepared_scene, scene_path, context)
	var swap_ms := float(Time.get_ticks_usec() - swap_started) / 1000.0
	print("[TransitionPerf] SWAP context=%s main_thread_ms=%.2f" % [context, swap_ms])
	if change_error != OK:
		push_error("DigitalSceneTransition: failed to activate scene %s (error %d)" % [scene_path, change_error])
		await _abort_transition()
		return

	transition_midpoint.emit(scene_path, context)
	print("[Transition] MIDPOINT context=%s" % context)
	await get_tree().process_frame

	var reveal := create_tween().set_parallel(true)
	reveal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_method(_set_progress, 1.0, 0.0, 0.36)
	reveal.tween_method(_set_flash, 0.34, 0.0, 0.11)
	await reveal.finished

	_finish_transition(scene_path, context)


func _swap_scene(prepared_scene: Node, scene_path: String, context: String) -> Error:
	var tree := get_tree()
	var current := tree.current_scene
	if current == null:
		return ERR_DOES_NOT_EXIST

	# Returning from battle reuses the exact hub instance that was already alive
	# before combat. No terrain/UI reconstruction, no resource churn and no _ready
	# spike are involved in this path.
	if context == CONTEXT_HUB and _retained_hub != null and is_instance_valid(_retained_hub):
		var hub := _retained_hub
		_set_scene_active(current, false)
		tree.current_scene = hub
		_set_scene_active(hub, true)
		if hub.has_method("resume_after_battle_transition"):
			hub.call("resume_after_battle_transition")
		if current != hub:
			current.queue_free()
		_retained_hub = null
		return OK

	# Keep Terminal Commons mounted but completely dormant during battle. Its root
	# visibility hides the whole world/UI and DISABLED stops all processing.
	if context == CONTEXT_BATTLE and current.scene_file_path == HUB_SCENE_PATH:
		_retained_hub = current
		_set_scene_active(current, false)
	else:
		_set_scene_active(current, false)
		current.queue_free()

	if prepared_scene.get_parent() != null:
		prepared_scene.get_parent().remove_child(prepared_scene)
	_set_scene_active(prepared_scene, false)
	tree.root.add_child(prepared_scene)
	tree.current_scene = prepared_scene
	_set_scene_active(prepared_scene, true)
	return OK


func _set_scene_active(scene: Node, active: bool) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	scene.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if scene is CanvasItem:
		(scene as CanvasItem).visible = active


func _abort_transition() -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_progress, _progress, 0.0, 0.18)
	tween.tween_method(_set_flash, float(_material.get_shader_parameter("flash")), 0.0, 0.12)
	await tween.finished
	_root.visible = false
	_set_fx_active(false)
	_busy = false
	_set_progress(0.0)
	_set_flash(0.0)


func _finish_transition(scene_path: String, context: String) -> void:
	_root.visible = false
	_set_fx_active(false)
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
