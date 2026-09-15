extends "res://src/MainCamera.gd"

const GameInputBootstrapForBattle = preload("res://src/input/GameInputBootstrap.gd")
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
var _web_intro_virtualized := false
var _web_intro_prepared := false
var _web_physical_position := Vector2.ZERO
var _web_physical_zoom := 1.0
var _web_view_position := Vector2.ZERO
var _web_view_zoom := 1.0
var _web_world_roots: Array[Node2D] = []
var _web_world_base_transforms: Dictionary = {}


func _ready() -> void:
	# The scripted cubic motion already provides the intended smoothing. Keeping
	# Camera2D's native position smoother enabled would run a second interpolation
	# path on the same frames.
	position_smoothing_enabled = false
	_web_intro_virtualized = OS.has_feature("web")
	if _web_intro_virtualized:
		# MainCamera._ready() writes Camera2D.zoom and schedules a clamp that can write
		# global_position. Both are exactly the native transform path we must keep out
		# of the Web scene-startup window. Reproduce the non-transform setup here and
		# keep the authored scene transform immutable until the battle is established.
		GameInputBootstrapForBattle.configure_gamepad_actions()
		_shake_rng.randomize()
		get_viewport().size_changed.connect(_clamp_to_pan_bounds)
		call_deferred("_refresh_pan_bounds")
		_battle_default_zoom = _preferred_battle_zoom()
		_web_physical_position = global_position
		_web_physical_zoom = zoom.x
		_web_view_position = global_position
		_web_view_zoom = zoom.x
		return

	super._ready()
	_battle_default_zoom = _preferred_battle_zoom()
	zoom = Vector2.ONE * minf(OPENING_BOOT_ZOOM, _battle_default_zoom)


func _exit_tree() -> void:
	_camera_move_generation += 1
	_camera_move_active = false
	_reset_web_world_roots()


func _physics_process(delta: float) -> void:
	if _web_intro_virtualized or _camera_move_active:
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
	if _web_intro_virtualized:
		_is_panning = false
		_touch_positions.clear()
		return
	if _post_battle_locked():
		_is_panning = false
		_touch_positions.clear()
		return
	super._unhandled_input(event)


func zoom_in() -> void:
	if _web_intro_virtualized or _post_battle_locked():
		return
	super.zoom_in()


func zoom_out() -> void:
	if _web_intro_virtualized or _post_battle_locked():
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


func prepare_web_intro_base(_world_position: Vector2) -> void:
	if not _web_intro_virtualized or _web_intro_prepared:
		return

	# This method is called only after RenderingServer.frame_post_draw. At that
	# point the scene's canvas items are established, so ordinary Node2D transforms
	# can safely reproduce the camera presentation without mutating Camera2D.
	_battle_default_zoom = _preferred_battle_zoom()
	_web_physical_position = global_position
	_web_physical_zoom = zoom.x
	_web_view_position = global_position
	_web_view_zoom = minf(OPENING_BOOT_ZOOM, _battle_default_zoom)
	_collect_web_world_roots()
	_web_intro_prepared = true
	_refresh_pan_bounds()
	_apply_web_world_view(_web_view_position, _web_view_zoom)


func finish_web_intro() -> void:
	if not _web_intro_virtualized:
		return

	# The opening has naturally completed all roster focuses. Transfer the already
	# visible final framing to Camera2D only now, well after scene startup, and put
	# every presentation root back on its exact logical transform before combat.
	var final_position := _web_view_position
	var final_zoom := _web_view_zoom
	_reset_web_world_roots()
	_web_intro_prepared = false
	_web_intro_virtualized = false
	zoom = Vector2.ONE * final_zoom
	global_position = final_position
	_clamp_to_pan_bounds()


func focus_on(world_position: Vector2) -> void:
	_refresh_pan_bounds()
	if _web_intro_virtualized:
		_web_view_position = _safe_focus_position(world_position, _web_view_zoom)
		_clamp_to_pan_bounds()
		return
	global_position = _safe_focus_position(world_position, zoom.x)
	_clamp_to_pan_bounds()


func reset_view() -> void:
	if _post_battle_locked():
		return
	_refresh_pan_bounds()
	_battle_default_zoom = _preferred_battle_zoom()
	if _web_intro_virtualized:
		_web_view_zoom = _battle_default_zoom
		_web_view_position = _overview_center_for_zoom(_battle_default_zoom)
		_clamp_to_pan_bounds()
		return
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
	# Avoid Camera2D property Tweens entirely. Each move owns its interpolation and
	# advances only on real process frames. On Web the physical camera remains fixed
	# during the opening and the same cubic view is projected through world roots.
	_camera_move_generation += 1
	var generation := _camera_move_generation
	var move_duration := maxf(0.05, duration)
	var start_position := _web_view_position if _web_intro_virtualized else global_position
	var start_zoom := _web_view_zoom if _web_intro_virtualized else zoom.x
	var elapsed := 0.0
	_camera_move_active = true

	while elapsed < move_duration:
		await get_tree().process_frame
		if not is_inside_tree() or generation != _camera_move_generation:
			return
		elapsed = minf(move_duration, elapsed + maxf(get_process_delta_time(), 0.0))
		var progress := _cubic_ease_in_out(elapsed / move_duration)
		var current_position := start_position.lerp(target_position, progress)
		var current_zoom := lerpf(start_zoom, target_zoom, progress)
		if _web_intro_virtualized:
			_apply_web_world_view(current_position, current_zoom)
		else:
			zoom = Vector2.ONE * current_zoom
			global_position = current_position

	if generation != _camera_move_generation:
		return
	if _web_intro_virtualized:
		_apply_web_world_view(target_position, target_zoom)
	else:
		zoom = Vector2.ONE * target_zoom
		global_position = target_position
		_clamp_to_pan_bounds()
	_camera_move_active = false


func _collect_web_world_roots() -> void:
	_web_world_roots.clear()
	_web_world_base_transforms.clear()
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	# Spawn VFX are children of the Digimon actors during the opening. Keeping the
	# field and roster roots together preserves the same visual camera effect while
	# HUD CanvasLayers and all logical coordinates remain untouched.
	for node_name in ["Blocks", "DigimonController"]:
		var root := main.get_node_or_null(node_name) as Node2D
		if root == null:
			continue
		_web_world_roots.append(root)
		_web_world_base_transforms[root.get_instance_id()] = root.transform


func _apply_web_world_view(view_position: Vector2, view_zoom: float) -> void:
	_web_view_position = view_position
	_web_view_zoom = view_zoom
	if not _web_intro_prepared:
		return
	var scale_factor := view_zoom / maxf(_web_physical_zoom, 0.01)
	var presentation_transform := Transform2D.IDENTITY.scaled(Vector2.ONE * scale_factor)
	presentation_transform.origin = _web_physical_position - view_position * scale_factor
	for root: Node2D in _web_world_roots:
		if not is_instance_valid(root):
			continue
		var base_transform: Transform2D = _web_world_base_transforms.get(
			root.get_instance_id(),
			Transform2D.IDENTITY
		)
		root.transform = presentation_transform * base_transform


func _reset_web_world_roots() -> void:
	for root: Node2D in _web_world_roots:
		if not is_instance_valid(root):
			continue
		var base_transform: Transform2D = _web_world_base_transforms.get(
			root.get_instance_id(),
			Transform2D.IDENTITY
		)
		root.transform = base_transform
	_web_world_roots.clear()
	_web_world_base_transforms.clear()


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
	var virtual_clamp := _web_intro_virtualized
	var zoom_value := maxf(_web_view_zoom if virtual_clamp else zoom.x, 0.01)
	var margin_world := PAN_EDGE_MARGIN_SCREEN / zoom_value
	var min_x := _pan_bounds.position.x - margin_world.x
	var max_x := _pan_bounds.end.x + margin_world.x
	var min_y := _pan_bounds.position.y - margin_world.y
	var max_y := _pan_bounds.end.y + margin_world.y
	if virtual_clamp:
		_web_view_position = Vector2(
			clampf(_web_view_position.x, min_x, max_x),
			clampf(_web_view_position.y, min_y, max_y)
		)
		if _web_intro_prepared:
			_apply_web_world_view(_web_view_position, _web_view_zoom)
		return
	global_position = Vector2(
		clampf(global_position.x, min_x, max_x),
		clampf(global_position.y, min_y, max_y)
	)
