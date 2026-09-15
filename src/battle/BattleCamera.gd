extends "res://src/MainCamera.gd"

signal camera_move_finished(generation: int)

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
var _camera_move_generation := 0
var _camera_move_active := false
var _camera_move_elapsed := 0.0
var _camera_move_duration := 0.0
var _camera_move_start_position := Vector2.ZERO
var _camera_move_target_position := Vector2.ZERO
var _camera_move_start_zoom := 1.0
var _camera_move_target_zoom := 1.0
var _web_world_motion := false
var _web_base_position := Vector2.ZERO
var _web_base_zoom := 1.0
var _web_view_position := Vector2.ZERO
var _web_view_zoom := 1.0
var _web_world_items: Array[CanvasItem] = []

func _ready() -> void:
	# The scripted cubic motion already provides the intended smoothing. Keeping
	# Camera2D's native position smoother enabled would run a second transform
	# interpolation path on the same frames, which is unstable in Web builds.
	position_smoothing_enabled = false
	super._ready()
	_battle_default_zoom = _preferred_battle_zoom()
	zoom = Vector2.ONE * minf(OPENING_BOOT_ZOOM, _battle_default_zoom)
	_web_world_motion = OS.has_feature("web")
	if _web_world_motion:
		_collect_web_world_items()

func _process(delta: float) -> void:
	if not _camera_move_active:
		return
	_camera_move_elapsed = minf(
		_camera_move_duration,
		_camera_move_elapsed + maxf(delta, 0.0)
	)
	var progress := _camera_move_elapsed / _camera_move_duration
	var eased_progress := _cubic_ease_in_out(progress)
	var current_zoom := lerpf(
		_camera_move_start_zoom,
		_camera_move_target_zoom,
		eased_progress
	)
	var current_position := _camera_move_start_position.lerp(
		_camera_move_target_position,
		eased_progress
	)
	if _web_world_motion:
		_apply_web_world_view(current_position, current_zoom)
	else:
		zoom = Vector2.ONE * current_zoom
		global_position = current_position
	if _camera_move_elapsed < _camera_move_duration:
		return

	_camera_move_active = false
	if _web_world_motion:
		_apply_web_world_view(_camera_move_target_position, _camera_move_target_zoom)
	else:
		zoom = Vector2.ONE * _camera_move_target_zoom
		global_position = _camera_move_target_position
		_clamp_to_pan_bounds()
	camera_move_finished.emit(_camera_move_generation)

func _physics_process(delta: float) -> void:
	if _camera_move_active:
		_is_panning = false
		_touch_positions.clear()
		return
	if _post_battle_locked():
		_is_panning = false
		_touch_positions.clear()
		_update_shake(delta)
		return
	super._physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _post_battle_locked():
		_is_panning = false
		_touch_positions.clear()
		return
	super._unhandled_input(event)

func zoom_in() -> void:
	if _post_battle_locked():
		return
	super.zoom_in()

func zoom_out() -> void:
	if _post_battle_locked():
		return
	super.zoom_out()

func animate_opening_overview(duration: float = OPENING_ZOOM_TIME) -> void:
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	var target_position := _overview_center_for_zoom(OPENING_BOOT_ZOOM)
	await _animate_camera_to(target_position, OPENING_BOOT_ZOOM, duration)

func animate_intro_focus(world_position: Vector2, first_focus: bool = false) -> void:
	_refresh_pan_bounds()
	var target_zoom := _preferred_intro_zoom()
	var duration := FIRST_FOCUS_MOVE_TIME if first_focus else FOCUS_MOVE_TIME
	await _animate_camera_to(world_position, target_zoom, duration)

func animate_gameplay_focus(world_position: Vector2, duration: float = GAMEPLAY_FOCUS_TIME) -> void:
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	var target_position := _safe_focus_position(world_position, _battle_default_zoom)
	await _animate_camera_to(target_position, _battle_default_zoom, duration)

func prepare_web_intro_base(world_position: Vector2) -> void:
	if not _web_world_motion:
		return
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	_web_base_zoom = _battle_default_zoom
	_web_base_position = _safe_focus_position(world_position, _web_base_zoom)
	_web_view_position = _web_base_position
	_web_view_zoom = _web_base_zoom
	zoom = Vector2.ONE * _web_base_zoom
	global_position = _web_base_position
	_apply_web_world_view(_web_base_position, _web_base_zoom)

func focus_on(world_position: Vector2) -> void:
	_refresh_pan_bounds()
	global_position = _safe_focus_position(world_position, zoom.x)
	_clamp_to_pan_bounds()

func reset_view() -> void:
	if _post_battle_locked():
		return
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	zoom = Vector2.ONE * _battle_default_zoom
	global_position = _overview_center_for_zoom(_battle_default_zoom)
	_clamp_to_pan_bounds()

func get_battle_default_zoom() -> float:
	return _battle_default_zoom

func _post_battle_locked() -> bool:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return false
	var battle := main.get_node_or_null("BattleController")
	if battle == null or not battle.has_method("get_hud_state"):
		return false
	var state = battle.call("get_hud_state")
	return state is Dictionary and bool((state as Dictionary).get("battle_over", false))

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
	# Camera2D property Tweens can hit an intermittent native Web/Wasm failure
	# during battle-scene startup. Drive the same cubic ease directly from rendered
	# frames; Web moves only the world presentation branches while native targets
	# update Camera2D normally. Timing stays identical without delay timers.
	_camera_move_generation += 1
	var generation := _camera_move_generation
	_camera_move_elapsed = 0.0
	_camera_move_duration = maxf(0.05, duration)
	_camera_move_start_position = _web_view_position if _web_world_motion else global_position
	_camera_move_target_position = target_position
	_camera_move_start_zoom = _web_view_zoom if _web_world_motion else zoom.x
	_camera_move_target_zoom = target_zoom
	_camera_move_active = true
	await camera_move_finished
	if generation != _camera_move_generation:
		return

func _collect_web_world_items() -> void:
	_web_world_items.clear()
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	for node_name in ["Blocks", "DigimonController", "BattlePresentationFX"]:
		var item := main.get_node_or_null(node_name) as CanvasItem
		if item != null:
			_web_world_items.append(item)

func _apply_web_world_view(view_position: Vector2, view_zoom: float) -> void:
	_web_view_position = view_position
	_web_view_zoom = view_zoom
	var scale_factor := view_zoom / maxf(_web_base_zoom, 0.01)
	var render_transform := Transform2D.IDENTITY.scaled(Vector2.ONE * scale_factor)
	render_transform.origin = _web_base_position - view_position * scale_factor
	for item: CanvasItem in _web_world_items:
		if is_instance_valid(item):
			RenderingServer.canvas_item_set_transform(item.get_canvas_item(), render_transform)

func _cubic_ease_in_out(value: float) -> float:
	var progress := clampf(value, 0.0, 1.0)
	if progress < 0.5:
		return 4.0 * progress * progress * progress
	var inverse := -2.0 * progress + 2.0
	return 1.0 - inverse * inverse * inverse * 0.5

func _safe_focus_position(world_position: Vector2, target_zoom: float) -> Vector2:
	var target := world_position
	var viewport_size := get_viewport_rect().size
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
