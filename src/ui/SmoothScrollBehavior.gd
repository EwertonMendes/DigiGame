extends Node
class_name SmoothScrollBehavior

# Comfortable mouse-wheel scrolling while preserving ScrollContainer's native
# focus behavior. Touch drag is also handled inside the container so mobile
# users can swipe anywhere in its content instead of targeting the scrollbar.

const WHEEL_STEP := 56.0
const DURATION := 0.30

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


func _on_gui_input(event: InputEvent) -> void:
	if _scroll == null:
		return
	if event is InputEventScreenDrag:
		_kill_tween()
		var drag := event as InputEventScreenDrag
		var vbar := _scroll.get_v_scroll_bar()
		var v_max := maxf(0.0, vbar.max_value - vbar.page)
		_scroll.scroll_vertical = int(round(clampf(float(_scroll.scroll_vertical) - drag.relative.y, 0.0, v_max)))
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
