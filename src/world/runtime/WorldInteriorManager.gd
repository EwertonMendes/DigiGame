extends Node
class_name WorldInteriorManager

signal interior_state_changed(active: bool, title: String)

const InteriorScene = preload("res://scenes/world/world_interior.tscn")
const STAGE_ORIGIN := Vector2(12000.0, 8000.0)
const EXTERIOR_ZOOM := 1.18
const INTERIOR_ZOOM := 1.30
const TRANSITION_ZOOM := 1.04

var _world_root: Node = null
var _player: OverworldActor = null
var _camera: Camera2D = null
var _streamer: AreaStreamer = null
var _interiors_root: Node2D = null
var _active_interior: WorldInterior = null
var _return_position := Vector2.ZERO
var _transitioning := false
var _overlay: ColorRect = null


func configure(
	world_root: Node,
	player: OverworldActor,
	camera: Camera2D,
	streamer: AreaStreamer,
	interiors_root: Node2D
) -> void:
	_world_root = world_root
	_player = player
	_camera = camera
	_streamer = streamer
	_interiors_root = interiors_root
	_build_transition_overlay()


func is_active() -> bool:
	return _active_interior != null and is_instance_valid(_active_interior)


func is_transitioning() -> bool:
	return _transitioning


func can_move_to(world_position: Vector2) -> bool:
	if not is_active():
		return false
	return _active_interior.is_walkable_world_position(world_position)


func enter_interior(payload: Dictionary) -> bool:
	if is_active() or _transitioning or _player == null or _camera == null or _interiors_root == null:
		return false
	_transitioning = true
	_lock_player(true)

	var interior := InteriorScene.instantiate() as WorldInterior
	if interior == null:
		_transitioning = false
		_lock_player(false)
		push_error("World interior scene root must use WorldInterior.gd")
		return false

	interior.global_position = STAGE_ORIGIN
	_interiors_root.add_child(interior)
	interior.configure(payload, _world_root)
	_active_interior = interior
	_return_position = _vector2_from_array(payload.get("return_position", []), _player.global_position)
	if _streamer != null:
		_streamer.set_suspended(true)

	await _cover_transition()
	_player.global_position = interior.get_spawn_world_position()
	_player.velocity = Vector2.ZERO
	_camera.position = Vector2.ZERO
	interior_state_changed.emit(true, String(payload.get("title", "INTERIOR")))
	await _reveal_transition(INTERIOR_ZOOM)

	_transitioning = false
	_lock_player(false)
	print("[World] INTERIOR_ENTER id=%s" % String(payload.get("interior_id", "unknown")))
	return true


func exit_interior() -> bool:
	if not is_active() or _transitioning or _player == null or _camera == null:
		return false
	_transitioning = true
	_lock_player(true)

	await _cover_transition()
	var old_interior := _active_interior
	_active_interior = null
	_player.global_position = _return_position
	_player.velocity = Vector2.ZERO
	_camera.position = Vector2.ZERO
	if old_interior != null:
		old_interior.queue_free()
	if _streamer != null:
		_streamer.set_suspended(false)
		_streamer.refresh_around_player()
	interior_state_changed.emit(false, "")
	await _reveal_transition(EXTERIOR_ZOOM)

	_transitioning = false
	_lock_player(false)
	print("[World] INTERIOR_EXIT")
	return true


func _build_transition_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "InteriorFocusTransition"
	layer.layer = 85
	add_child(layer)

	_overlay = ColorRect.new()
	_overlay.name = "FocusWash"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0.025, 0.12, 0.15, 1.0)
	_overlay.modulate.a = 0.0
	_overlay.visible = false
	layer.add_child(_overlay)


func _cover_transition() -> void:
	if _overlay == null or _camera == null:
		return
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_overlay, "modulate:a", 0.84, 0.20)
	tween.tween_property(_camera, "zoom", Vector2.ONE * TRANSITION_ZOOM, 0.20)
	await tween.finished


func _reveal_transition(target_zoom: float) -> void:
	if _overlay == null or _camera == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "modulate:a", 0.0, 0.28)
	tween.tween_property(_camera, "zoom", Vector2.ONE * target_zoom, 0.30)
	await tween.finished
	_overlay.visible = false


func _lock_player(locked: bool) -> void:
	if _player == null:
		return
	_player.movement_enabled = not locked
	_player.velocity = Vector2.ZERO
	_player.set_touch_direction(Vector2.ZERO)


func _vector2_from_array(raw, fallback: Vector2) -> Vector2:
	if raw is Array and raw.size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return fallback
