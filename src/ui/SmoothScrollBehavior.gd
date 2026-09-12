extends Node
class_name SmoothScrollBehavior

# Comfortable mouse-wheel scrolling for ScrollContainer while keeping Godot's
# native touch drag and scrollbar behavior intact.

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
	if not scroll.gui_input.is_connected(_on_gui_input):
		scroll.gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if _scroll == null or not event is InputEventMouseButton:
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

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_vertical, float(_scroll.scroll_vertical), _target_vertical, DURATION)
	_scroll.accept_event()


func _set_vertical(value: float) -> void:
	if _scroll != null:
		_scroll.scroll_vertical = int(round(value))
