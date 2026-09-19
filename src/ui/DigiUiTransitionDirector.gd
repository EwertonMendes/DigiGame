extends Node

signal transition_started(surface_id: String, opening: bool)
signal transition_finished(surface_id: String, opening: bool)

const OPEN_DURATION := 0.34
const CLOSE_DURATION := 0.28

var _busy := false
var _opening := false
var _surface_id := ""
var _surface_ref: WeakRef


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)


func _input(_event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()


func is_transitioning() -> bool:
	return _busy


func active_surface_id() -> String:
	return _surface_id


func begin_open(surface: Node, surface_id: String) -> bool:
	if not _begin(surface, surface_id, true):
		return false
	surface.call("set_transition_progress", 0.0)
	return true


func reveal_open() -> void:
	if not _busy or not _opening:
		return
	var surface := _active_surface()
	if surface == null:
		_abort()
		return
	await _animate(surface, 0.0, 1.0, OPEN_DURATION, Tween.EASE_OUT)
	_finish(true)


func begin_close(surface: Node, surface_id: String) -> bool:
	if not _begin(surface, surface_id, false):
		return false
	surface.call("set_transition_progress", 1.0)
	return true


func conceal_close() -> void:
	if not _busy or _opening:
		return
	var surface := _active_surface()
	if surface == null:
		_abort()
		return
	await _animate(surface, 1.0, 0.0, CLOSE_DURATION, Tween.EASE_IN)
	# Keep the surface fully concealed until the owner has hidden/finalized its
	# screen. This prevents a one-frame flash between the animation and the world.
	surface.call("set_transition_progress", 0.0)


func complete_close() -> void:
	if not _busy or _opening:
		return
	var surface := _active_surface()
	if surface != null:
		# Reset while the owning screen is hidden so the next open starts from a
		# clean authored state before begin_open() deliberately conceals it.
		surface.call("set_transition_progress", 1.0)
	_finish(false)


func cancel_transition() -> void:
	var surface := _active_surface()
	if surface != null:
		surface.call("set_transition_progress", 1.0)
	_abort()


func _begin(surface: Node, surface_id: String, opening: bool) -> bool:
	if _busy or surface == null or not is_instance_valid(surface):
		return false
	if not surface.has_method("set_transition_progress"):
		push_error("DigiUiTransitionDirector: transition surface is missing the shared surface contract")
		return false

	_busy = true
	_opening = opening
	_surface_id = surface_id
	_surface_ref = weakref(surface)
	_configure_surface(surface, surface_id)
	transition_started.emit(surface_id, opening)
	return true


func _animate(surface: Node, from_value: float, to_value: float, duration: float, ease: int) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(ease)
	tween.tween_method(Callable(surface, "set_transition_progress"), from_value, to_value, duration)
	await tween.finished


func _configure_surface(surface: Node, surface_id: String) -> void:
	var palette := _palette_for(surface_id)
	surface.call(
		"configure_palette",
		palette.get("primary", Color(0.35, 0.86, 1.0, 1.0)),
		palette.get("accent", Color(0.58, 0.52, 1.0, 1.0))
	)
	surface.call("set_phase_seed", fmod(float(Time.get_ticks_msec()) * 0.001, 97.0))


func _palette_for(surface_id: String) -> Dictionary:
	match surface_id:
		"digimon":
			return {
				"primary": Color(0.34, 0.84, 1.0, 1.0),
				"accent": Color(0.48, 0.62, 1.0, 1.0),
			}
		"digilab":
			return {
				"primary": Color(0.32, 0.90, 1.0, 1.0),
				"accent": Color(0.62, 0.50, 1.0, 1.0),
			}
		"battle_operator":
			return {
				"primary": Color(0.36, 0.88, 1.0, 1.0),
				"accent": Color(1.0, 0.72, 0.28, 1.0),
			}
		"hospital":
			return {
				"primary": Color(0.28, 0.92, 0.96, 1.0),
				"accent": Color(0.34, 1.0, 0.72, 1.0),
			}
		"training":
			return {
				"primary": Color(0.30, 0.96, 0.76, 1.0),
				"accent": Color(0.34, 0.78, 1.0, 1.0),
			}
		_:
			return {
				"primary": Color(0.35, 0.86, 1.0, 1.0),
				"accent": Color(0.58, 0.52, 1.0, 1.0),
			}


func _active_surface() -> Node:
	if _surface_ref == null:
		return null
	var candidate: Variant = _surface_ref.get_ref()
	return candidate as Node if candidate is Node and is_instance_valid(candidate) else null


func _finish(opening: bool) -> void:
	var finished_id := _surface_id
	_busy = false
	_opening = false
	_surface_id = ""
	_surface_ref = null
	transition_finished.emit(finished_id, opening)


func _abort() -> void:
	_busy = false
	_opening = false
	_surface_id = ""
	_surface_ref = null
