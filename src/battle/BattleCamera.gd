extends "res://src/MainCamera.gd"

const OPENING_BOOT_ZOOM := 1.10
const DESKTOP_BATTLE_ZOOM := 1.34
const LAPTOP_BATTLE_ZOOM := 1.28
const COMPACT_BATTLE_ZOOM := 1.18
const DESKTOP_INTRO_ZOOM := 1.44
const LAPTOP_INTRO_ZOOM := 1.38
const COMPACT_INTRO_ZOOM := 1.24
const OPENING_ZOOM_TIME := 0.42
const FOCUS_MOVE_TIME := 0.30
const FIRST_FOCUS_MOVE_TIME := 0.40
const GAMEPLAY_FOCUS_TIME := 0.46
const PAN_EDGE_MARGIN_SCREEN := Vector2(168.0, 112.0)

var _battle_default_zoom := DESKTOP_BATTLE_ZOOM


func _ready() -> void:
	super._ready()
	_battle_default_zoom = _preferred_battle_zoom()
	zoom = Vector2.ONE * minf(OPENING_BOOT_ZOOM, _battle_default_zoom)


func animate_opening_overview(duration: float = OPENING_ZOOM_TIME) -> void:
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	var target_position := _overview_center_for_zoom(OPENING_BOOT_ZOOM)
	await _animate_camera_to(target_position, OPENING_BOOT_ZOOM, duration)


func animate_intro_focus(world_position: Vector2, first_focus: bool = false) -> void:
	_refresh_pan_bounds()
	var target_zoom := _preferred_intro_zoom()
	var duration := FIRST_FOCUS_MOVE_TIME if first_focus else FOCUS_MOVE_TIME
	var target_position := _safe_focus_position(world_position, target_zoom)
	await _animate_camera_to(target_position, target_zoom, duration)


func animate_gameplay_focus(world_position: Vector2, duration: float = GAMEPLAY_FOCUS_TIME) -> void:
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	var target_position := _safe_focus_position(world_position, _battle_default_zoom)
	await _animate_camera_to(target_position, _battle_default_zoom, duration)


func focus_on(world_position: Vector2) -> void:
	_refresh_pan_bounds()
	global_position = _safe_focus_position(world_position, zoom.x)
	_clamp_to_pan_bounds()


func reset_view() -> void:
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	zoom = Vector2.ONE * _battle_default_zoom
	global_position = _overview_center_for_zoom(_battle_default_zoom)
	_clamp_to_pan_bounds()


func get_battle_default_zoom() -> float:
	return _battle_default_zoom


func _preferred_battle_zoom() -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.y < 560.0 or viewport_size.x < 1000.0:
		return COMPACT_BATTLE_ZOOM
	if viewport_size.y < 780.0:
		return LAPTOP_BATTLE_ZOOM
	return DESKTOP_BATTLE_ZOOM


func _preferred_intro_zoom() -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.y < 560.0 or viewport_size.x < 1000.0:
		return COMPACT_INTRO_ZOOM
	if viewport_size.y < 780.0:
		return LAPTOP_INTRO_ZOOM
	return DESKTOP_INTRO_ZOOM


func _animate_camera_to(target_position: Vector2, target_zoom: float, duration: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "zoom", Vector2.ONE * target_zoom, maxf(0.05, duration))
	tween.tween_property(self, "global_position", target_position, maxf(0.05, duration))
	await tween.finished
	zoom = Vector2.ONE * target_zoom
	global_position = target_position
	_clamp_to_pan_bounds()


func _safe_focus_position(world_position: Vector2, target_zoom: float) -> Vector2:
	var target := world_position
	var viewport_size := get_viewport_rect().size
	# On desktop the left command rail is much wider than the turn-order rail.
	# Place the focused Digimon in the center of the usable battlefield area,
	# not in the geometric center of the browser where the HUD can cover it.
	if viewport_size.y >= 560.0 and viewport_size.x >= 1000.0:
		var left_reserved := minf(300.0, viewport_size.x * 0.22)
		var right_reserved := minf(108.0, viewport_size.x * 0.085)
		var screen_bias := (left_reserved - right_reserved) * 0.5
		target.x -= screen_bias / maxf(target_zoom, 0.01)
	return target


func _overview_center_for_zoom(target_zoom: float) -> Vector2:
	if not _has_pan_bounds:
		return Vector2.ZERO
	var center := _pan_bounds.position + _pan_bounds.size * 0.5
	return _safe_focus_position(center, target_zoom)


func _clamp_to_pan_bounds() -> void:
	if not _has_pan_bounds:
		return

	# Tactical battles must be able to center an actor standing on any legal edge
	# tile. The generic camera clamp keeps most of the board inside the viewport,
	# which made left-edge spawns impossible to move out from under the command
	# HUD. Battle panning instead clamps the camera center to the board extents
	# plus a small screen-space margin. This keeps edge actors fully inspectable
	# without allowing unbounded travel into the background.
	var zoom_value := maxf(zoom.x, 0.01)
	var margin_world := PAN_EDGE_MARGIN_SCREEN / zoom_value
	var min_x := _pan_bounds.position.x - margin_world.x
	var max_x := _pan_bounds.end.x + margin_world.x
	var min_y := _pan_bounds.position.y - margin_world.y
	var max_y := _pan_bounds.end.y + margin_world.y
	global_position = Vector2(
		clampf(global_position.x, min_x, max_x),
		clampf(global_position.y, min_y, max_y)
	)
