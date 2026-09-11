extends "res://src/world/HubVisualRedesign.gd"

const TouchJoystickScript = preload("res://src/ui/TouchJoystick.gd")

const PORTRAIT_EDGE := 24.0
const PORTRAIT_BOTTOM := 30.0
const LANDSCAPE_EDGE := 18.0
const LANDSCAPE_BOTTOM := 18.0
const MOBILE_INTERACTION_DISTANCE := 128.0

var _touch_joystick: Control = null
var _last_touch_marker := ""
var _mobile_dialog_content: Control = null
var _mobile_dialog_title: Label = null
var _mobile_dialog_body: Label = null
var _mobile_dialog_cancel: Button = null
var _fallback_action_touch := -1


# Keep the battle prompt independent from content-driven Container minimum sizes.
# The explicit layout below gives the Kenney frame a real safe area so buttons
# never touch or cross the decorative border on desktop or mobile Web exports.
func _build_dialog() -> void:
	_dialog_panel = PanelContainer.new()
	_dialog_panel.name = "BattleDialog"
	_dialog_panel.visible = false
	_dialog_panel.clip_contents = true
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_panel.add_theme_stylebox_override("panel", UI.panel_strong(UI.CYAN, 12))
	_ui_root.add_child(_dialog_panel)

	_mobile_dialog_content = Control.new()
	_mobile_dialog_content.name = "Content"
	_mobile_dialog_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_dialog_content.custom_minimum_size = Vector2.ZERO
	_dialog_panel.add_child(_mobile_dialog_content)

	_mobile_dialog_title = _label("BATTLE OPERATOR", 13, UI.CYAN)
	_mobile_dialog_title.name = "Title"
	_mobile_dialog_content.add_child(_mobile_dialog_title)

	_mobile_dialog_body = _label("START A TEST BATTLE?", 19, UI.TEXT)
	_mobile_dialog_body.name = "Prompt"
	_mobile_dialog_content.add_child(_mobile_dialog_body)

	_mobile_dialog_cancel = _dialog_button("NOT NOW", UI.MUTED)
	_mobile_dialog_cancel.name = "CancelBattleDialog"
	_mobile_dialog_cancel.pressed.connect(_close_dialog)
	_mobile_dialog_content.add_child(_mobile_dialog_cancel)

	_start_battle_button = _dialog_button("START TEST BATTLE", UI.GOLD)
	_start_battle_button.name = "StartBattle"
	_start_battle_button.pressed.connect(_start_test_battle)
	_mobile_dialog_content.add_child(_start_battle_button)


func _build_mobile_controls() -> void:
	_mobile_controls = Control.new()
	_mobile_controls.name = "MobileControls"
	_mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.z_index = 20
	_ui_root.add_child(_mobile_controls)

	_touch_joystick = TouchJoystickScript.new()
	_touch_joystick.name = "MovementJoystick"
	_touch_joystick.size = Vector2(164.0, 164.0)
	_touch_joystick.direction_changed.connect(_on_touch_joystick_changed)
	_mobile_controls.add_child(_touch_joystick)

	_mobile_talk_button = _dialog_button("TALK", UI.GOLD)
	_mobile_talk_button.name = "Talk"
	_mobile_talk_button.custom_minimum_size = Vector2(120.0, 72.0)
	_mobile_talk_button.size = Vector2(120.0, 72.0)
	_mobile_talk_button.focus_mode = Control.FOCUS_NONE
	# button_down reacts on contact instead of waiting for a synthesized click on
	# mobile Web. The explicit ScreenTouch fallback below covers browsers/devices
	# that do not synthesize the GUI press consistently.
	_mobile_talk_button.button_down.connect(_on_mobile_interact)
	_mobile_controls.add_child(_mobile_talk_button)

	var move_label := _label("MOVE", 11, UI.MUTED)
	move_label.name = "MoveLabel"
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_label.size = Vector2(164.0, 18.0)
	_mobile_controls.add_child(move_label)


func _input(event: InputEvent) -> void:
	if _transitioning or not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		if _fallback_action_touch != -1:
			return
		if not _dialog_open and _mobile_controls != null and _mobile_controls.visible and _mobile_talk_button != null:
			if _control_contains_viewport_point(_mobile_talk_button, touch.position, 10.0):
				_fallback_action_touch = touch.index
				_on_mobile_interact()
				get_viewport().set_input_as_handled()
				return
		# The dialog buttons already receive regular GUI events. These fallbacks
		# make the complete Battle Operator flow dependable on mobile Web exports.
		if _dialog_open and _start_battle_button != null and _control_contains_viewport_point(_start_battle_button, touch.position, 8.0):
			_fallback_action_touch = touch.index
			_start_test_battle()
			get_viewport().set_input_as_handled()
			return
		if _dialog_open and _mobile_dialog_cancel != null and _control_contains_viewport_point(_mobile_dialog_cancel, touch.position, 8.0):
			_fallback_action_touch = touch.index
			_close_dialog()
			get_viewport().set_input_as_handled()
			return
	elif touch.index == _fallback_action_touch:
		_fallback_action_touch = -1


func _layout_ui() -> void:
	super._layout_ui()
	if _ui_root == null or _mobile_controls == null:
		return

	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	var compact := UI.is_compact(viewport_obj, 820.0)
	var landscape := physical.x > physical.y
	var touch_layout := DisplayServer.is_touchscreen_available() or compact
	var edge := LANDSCAPE_EDGE if landscape else PORTRAIT_EDGE
	var bottom := LANDSCAPE_BOTTOM if landscape else PORTRAIT_BOTTOM

	_mobile_controls.visible = touch_layout and not _dialog_open and not _transitioning
	_mobile_controls.scale = Vector2.ONE * ui_scale
	var joystick_side := 146.0 if landscape else clampf(physical.x * 0.42, 158.0, 174.0)
	_mobile_controls.position = Vector2(edge * ui_scale, (physical.y - joystick_side - bottom) * ui_scale)
	_mobile_controls.size = Vector2(maxf(1.0, physical.x - edge * 2.0), joystick_side)

	if _touch_joystick != null:
		_touch_joystick.position = Vector2.ZERO
		_touch_joystick.size = Vector2(joystick_side, joystick_side)
		var move_label := _mobile_controls.get_node_or_null("MoveLabel") as Label
		if move_label != null:
			move_label.position = Vector2(0.0, joystick_side - 21.0)
			move_label.size = Vector2(joystick_side, 18.0)

	if _mobile_talk_button != null:
		var talk_width := 112.0 if landscape else clampf(physical.x * 0.30, 116.0, 124.0)
		var talk_height := 66.0 if landscape else 72.0
		_mobile_talk_button.size = Vector2(talk_width, talk_height)
		_mobile_talk_button.position = Vector2(
			maxf(joystick_side + 28.0, _mobile_controls.size.x - talk_width),
			maxf(0.0, (joystick_side - talk_height) * 0.5)
		)

	_layout_mobile_dialog(physical, ui_scale, landscape, edge)

	if landscape and compact and _location_panel != null:
		var location_width := minf(330.0, physical.x * 0.44)
		_location_panel.position = Vector2(edge * ui_scale, 10.0 * ui_scale)
		_location_panel.size = Vector2(location_width, 108.0)


func _layout_mobile_dialog(physical: Vector2, ui_scale: float, landscape: bool, edge: float) -> void:
	if _dialog_panel == null or _mobile_dialog_content == null:
		return

	var dialog_width := minf(620.0 if landscape else 660.0, physical.x - edge * 2.0)
	var desired_height := 184.0 if landscape else 196.0
	var dialog_height := minf(desired_height, physical.y - edge * 2.0)
	_dialog_panel.scale = Vector2.ONE * ui_scale
	_dialog_panel.position = Vector2(
		(physical.x - dialog_width) * 0.5 * ui_scale,
		(physical.y - dialog_height) * 0.5 * ui_scale
	)
	_dialog_panel.size = Vector2(dialog_width, dialog_height)

	var side_pad := 28.0 if landscape else 24.0
	var top_pad := 20.0 if landscape else 22.0
	_mobile_dialog_content.position = Vector2.ZERO
	_mobile_dialog_content.size = Vector2(dialog_width, dialog_height)

	_mobile_dialog_title.position = Vector2(side_pad, top_pad)
	_mobile_dialog_title.size = Vector2(dialog_width - side_pad * 2.0, 20.0)
	_mobile_dialog_title.add_theme_font_size_override("font_size", 11 if landscape else 12)

	_mobile_dialog_body.position = Vector2(side_pad, top_pad + 30.0)
	_mobile_dialog_body.size = Vector2(dialog_width - side_pad * 2.0, 32.0)
	_mobile_dialog_body.add_theme_font_size_override("font_size", 17 if landscape else 19)

	var button_height := 48.0 if not landscape else 44.0
	var bottom_pad := 30.0 if not landscape else 34.0
	var gap := 14.0
	var group_width := minf(dialog_width - side_pad * 2.0, 500.0)
	var button_width := (group_width - gap) * 0.5
	var actions_x := (dialog_width - group_width) * 0.5
	var actions_y := dialog_height - bottom_pad - button_height

	_mobile_dialog_cancel.custom_minimum_size = Vector2.ZERO
	_mobile_dialog_cancel.position = Vector2(actions_x, actions_y)
	_mobile_dialog_cancel.size = Vector2(button_width, button_height)
	_mobile_dialog_cancel.add_theme_font_size_override("font_size", 13 if landscape else 14)

	_start_battle_button.custom_minimum_size = Vector2.ZERO
	_start_battle_button.position = Vector2(actions_x + button_width + gap, actions_y)
	_start_battle_button.size = Vector2(button_width, button_height)
	_start_battle_button.add_theme_font_size_override("font_size", 13 if landscape else 14)


func _open_dialog() -> void:
	_release_touch_movement()
	_fallback_action_touch = -1
	super._open_dialog()


func _close_dialog() -> void:
	_release_touch_movement()
	_fallback_action_touch = -1
	super._close_dialog()


func _on_touch_joystick_changed(direction: Vector2) -> void:
	if _player != null:
		_player.set_touch_direction(direction)

	var marker := ""
	if direction.length_squared() > 0.0225:
		if absf(direction.x) >= absf(direction.y):
			marker = "right" if direction.x >= 0.0 else "left"
		else:
			marker = "down" if direction.y >= 0.0 else "up"
	if marker == _last_touch_marker:
		return
	if not _last_touch_marker.is_empty():
		print("[Hub] TOUCH_MOVE direction=%s pressed=false" % _last_touch_marker)
	_last_touch_marker = marker
	if not marker.is_empty():
		print("[Hub] TOUCH_MOVE direction=%s pressed=true" % marker)


func _release_touch_movement() -> void:
	if _touch_joystick != null and _touch_joystick.has_method("force_release"):
		_touch_joystick.call("force_release")
	if _player != null:
		_player.set_touch_direction(Vector2.ZERO)
	if not _last_touch_marker.is_empty():
		print("[Hub] TOUCH_MOVE direction=%s pressed=false" % _last_touch_marker)
	_last_touch_marker = ""


func _is_operator_nearby() -> bool:
	if _player == null or _operator == null:
		return false
	var viewport_obj := get_viewport()
	var compact := UI.is_compact(viewport_obj, 820.0)
	var touch_layout := DisplayServer.is_touchscreen_available() or compact
	var distance := MOBILE_INTERACTION_DISTANCE if touch_layout else INTERACTION_DISTANCE
	return _player.position.distance_to(_operator.position) <= distance


func _control_contains_viewport_point(control: Control, viewport_pos: Vector2, padding: float = 0.0) -> bool:
	if control == null or not control.visible:
		return false
	var local_pos := control.get_global_transform_with_canvas().affine_inverse() * viewport_pos
	return Rect2(
		Vector2(-padding, -padding),
		control.size + Vector2.ONE * padding * 2.0
	).has_point(local_pos)
