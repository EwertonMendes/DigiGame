extends Node
class_name SmoothScrollBehavior

# Shared scrolling behavior for every scrollable game UI. Mouse wheel keeps a
# soft eased feel, touch can drag anywhere inside the container, and gamepads
# use the right stick so scrolling does not compete with focus navigation.

const WHEEL_STEP := 56.0
const DURATION := 0.30
const STICK_DEADZONE := 0.22
const STICK_SCROLL_SPEED := 540.0
const STICK_HORIZONTAL_SPEED := 500.0

var _scroll: ScrollContainer = null
var _target_vertical := 0.0
var _tween: Tween = null


static func attach(scroll: ScrollContainer) -> SmoothScrollBehavior:
	if scroll == null:
		return null
	var existing := scroll.get_node_or_null("SmoothScrollBehavior") as SmoothScrollBehavior
	if existing != null:
		return existing
	var behavior := SmoothScrollBehavior.new()
	behavior.name = "SmoothScrollBehavior"
	scroll.add_child(behavior)
	behavior._install(scroll)
	return behavior


func _install(scroll: ScrollContainer) -> void:
	_scroll = scroll
	_target_vertical = float(scroll.scroll_vertical)
	_scroll.scroll_deadzone = 8
	if not scroll.gui_input.is_connected(_on_gui_input):
		scroll.gui_input.connect(_on_gui_input)
	set_process(true)


func _process(delta: float) -> void:
	if _scroll == null or not _scroll.is_visible_in_tree() or not _owns_controller_focus():
		return
	var axes := _right_stick_axes()
	if absf(axes.y) > 0.001:
		_kill_tween()
		var vbar := _scroll.get_v_scroll_bar()
		var v_max := maxf(0.0, vbar.max_value - vbar.page)
		if v_max > 0.0:
			var next_vertical := clampf(
				float(_scroll.scroll_vertical) + axes.y * STICK_SCROLL_SPEED * delta,
				0.0,
				v_max
			)
			_scroll.scroll_vertical = int(round(next_vertical))
			_target_vertical = next_vertical
	if _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and absf(axes.x) > 0.001:
		var hbar := _scroll.get_h_scroll_bar()
		var h_max := maxf(0.0, hbar.max_value - hbar.page)
		if h_max > 0.0:
			_scroll.scroll_horizontal = int(round(clampf(
				float(_scroll.scroll_horizontal) + axes.x * STICK_HORIZONTAL_SPEED * delta,
				0.0,
				h_max
			)))


func _right_stick_axes() -> Vector2:
	var best := Vector2.ZERO
	for device in Input.get_connected_joypads():
		var raw := Vector2(
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		)
		var filtered := Vector2(_apply_deadzone(raw.x), _apply_deadzone(raw.y))
		if filtered.length_squared() > best.length_squared():
			best = filtered
	return best


func _apply_deadzone(value: float) -> float:
	var magnitude := absf(value)
	if magnitude <= STICK_DEADZONE:
		return 0.0
	var normalized := (magnitude - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
	return normalized if value >= 0.0 else -normalized


func _owns_controller_focus() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var focus := viewport.gui_get_focus_owner()
	if focus == null:
		return false
	var cursor: Node = focus
	while cursor != null:
		if cursor is ScrollContainer:
			return cursor == _scroll
		cursor = cursor.get_parent()
	return false


func _on_gui_input(event: InputEvent) -> void:
	if _scroll == null:
		return
	if event is InputEventScreenDrag:
		_kill_tween()
		var drag := event as InputEventScreenDrag
		var vbar := _scroll.get_v_scroll_bar()
		var v_max := maxf(0.0, vbar.max_value - vbar.page)
		_scroll.scroll_vertical = int(round(clampf(float(_scroll.scroll_vertical) - drag.relative.y, 0.0, v_max)))
		_target_vertical = float(_scroll.scroll_vertical)
		if _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			var hbar := _scroll.get_h_scroll_bar()
			var h_max := maxf(0.0, hbar.max_value - hbar.page)
			_scroll.scroll_horizontal = int(round(clampf(float(_scroll.scroll_horizontal) - drag.relative.x, 0.0, h_max)))
		_scroll.accept_event()
		return
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed:
		return
	var direction := 0.0
	if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = 1.0
	elif mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = -1.0
	else:
		return

	var bar := _scroll.get_v_scroll_bar()
	var maximum := maxf(0.0, bar.max_value - bar.page)
	if _tween == null or not _tween.is_valid():
		_target_vertical = float(_scroll.scroll_vertical)
	_target_vertical = clampf(_target_vertical + direction * WHEEL_STEP, 0.0, maximum)

	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_vertical, float(_scroll.scroll_vertical), _target_vertical, DURATION)
	_scroll.accept_event()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _set_vertical(value: float) -> void:
	if _scroll != null:
		_scroll.scroll_vertical = int(round(value))
