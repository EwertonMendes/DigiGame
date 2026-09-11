extends CanvasLayer

signal transition_started(scene_path: String, context: String)
signal transition_midpoint(scene_path: String, context: String)
signal transition_finished(scene_path: String, context: String)

const UI = preload("res://src/ui/TacticalTheme.gd")
const TRANSITION_SHADER = preload("res://shaders/digital_scene_transition.gdshader")
const HUB_SCENE_PATH := "res://scenes/world/hub.tscn"
const CONTEXT_BATTLE := "battle"
const CONTEXT_HUB := "hub"

var _root: Control = null
var _screen: ColorRect = null
var _material: ShaderMaterial = null
var _status_stack: VBoxContainer = null
var _title: Label = null
var _subtitle: Label = null
var _progress_label: Label = null
var _busy := false
var _revealing := false


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
	_material.set_shader_parameter("primary_color", UI.CYAN)
	_material.set_shader_parameter("accent_color", UI.GOLD)

	_screen = ColorRect.new()
	_screen.name = "DigitalGate"
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.material = _material
	_root.add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "StatusCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_status_stack = VBoxContainer.new()
	_status_stack.name = "Status"
	_status_stack.custom_minimum_size = Vector2(420.0, 116.0)
	_status_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_stack.add_theme_constant_override("separation", 5)
	_status_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_status_stack)

	_title = _transition_label("DIGITAL GATE", 34, Color.WHITE, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.08, 0.98))
	_title.add_theme_constant_override("outline_size", 8)
	_status_stack.add_child(_title)

	_subtitle = _transition_label("DATA LINK // STANDBY", 13, UI.CYAN, true)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.08, 0.96))
	_subtitle.add_theme_constant_override("outline_size", 5)
	_status_stack.add_child(_subtitle)

	_progress_label = _transition_label("000%", 12, UI.GOLD, true)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.08, 0.96))
	_progress_label.add_theme_constant_override("outline_size", 4)
	_status_stack.add_child(_progress_label)


func _transition_label(text_value: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label


func _run_transition(scene_path: String, context: String) -> void:
	transition_started.emit(scene_path, context)
	_revealing = false
	_configure_context(context, false)
	_material.set_shader_parameter("phase_seed", fmod(float(Time.get_ticks_msec()) * 0.001, 97.0))
	_set_progress(0.0)
	_root.visible = true
	_status_stack.modulate.a = 0.0

	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()

	var cover := create_tween().set_parallel(true)
	cover.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	cover.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	cover.tween_method(_set_progress, 0.0, 1.0, 0.64)
	cover.tween_property(_status_stack, "modulate:a", 1.0, 0.18)
	await cover.finished

	_subtitle.text = _transfer_text(context)
	await get_tree().create_timer(0.07, true, false, true).timeout

	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error("DigitalSceneTransition: failed to change scene to %s (error %d)" % [scene_path, change_error])
		_subtitle.text = "LINK ERROR // ABORTING"
		await get_tree().create_timer(0.12, true, false, true).timeout
		await _abort_transition()
		return

	transition_midpoint.emit(scene_path, context)
	await get_tree().process_frame
	await get_tree().process_frame

	_revealing = true
	_configure_context(context, true)
	_set_progress(1.0)
	var reveal := create_tween().set_parallel(true)
	reveal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_method(_set_progress, 1.0, 0.0, 0.72)
	reveal.tween_property(_status_stack, "modulate:a", 0.0, 0.30).set_delay(0.28)
	await reveal.finished

	_finish_transition(scene_path, context)


func _abort_transition() -> void:
	_revealing = true
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_progress, 1.0, 0.0, 0.34)
	tween.tween_property(_status_stack, "modulate:a", 0.0, 0.20)
	await tween.finished
	_root.visible = false
	_busy = false
	_revealing = false


func _finish_transition(scene_path: String, context: String) -> void:
	_root.visible = false
	_set_progress(0.0)
	_revealing = false
	_busy = false
	transition_finished.emit(scene_path, context)


func _set_progress(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("progress", clampf(value, 0.0, 1.0))
	if _progress_label != null:
		var display_value := (1.0 - value) if _revealing else value
		_progress_label.text = "%03d%%" % int(round(clampf(display_value, 0.0, 1.0) * 100.0))


func _configure_context(context: String, reveal: bool) -> void:
	if context == CONTEXT_BATTLE:
		_title.text = "DIGITAL GATE"
		_subtitle.text = "BATTLE GRID // MATERIALIZING" if reveal else "BATTLE LINK // DIGITIZING"
		_material.set_shader_parameter("primary_color", UI.CYAN)
		_material.set_shader_parameter("accent_color", UI.GOLD)
	elif context == CONTEXT_HUB:
		_title.text = "DATA RETURN"
		_subtitle.text = "TERMINAL COMMONS // RECONSTRUCTING" if reveal else "TERMINAL COMMONS // RECALLING DATA"
		_material.set_shader_parameter("primary_color", Color(0.16, 0.92, 0.93, 1.0))
		_material.set_shader_parameter("accent_color", UI.GOLD)
	else:
		_title.text = "DATA TRANSFER"
		_subtitle.text = "DESTINATION // MATERIALIZING" if reveal else "DIGITAL LINK // SYNCHRONIZING"
		_material.set_shader_parameter("primary_color", UI.CYAN)
		_material.set_shader_parameter("accent_color", UI.GOLD)


func _transfer_text(context: String) -> String:
	if context == CONTEXT_BATTLE:
		return "BATTLE LINK // TRANSFERRING"
	if context == CONTEXT_HUB:
		return "RETURN LINK // TRANSFERRING"
	return "DIGITAL LINK // TRANSFERRING"
