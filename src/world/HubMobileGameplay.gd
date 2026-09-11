extends "res://src/world/HubVisualRedesign.gd"

const TouchJoystickScript = preload("res://src/ui/TouchJoystick.gd")

var _touch_joystick: Control = null
var _last_touch_marker := ""


func _build_mobile_controls() -> void:
	_mobile_controls = Control.new()
	_mobile_controls.name = "MobileControls"
	_mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls.z_index = 20
	_ui_root.add_child(_mobile_controls)

	_touch_joystick = TouchJoystickScript.new()
	_touch_joystick.name = "MovementJoystick"
	_touch_joystick.size = Vector2(148.0, 148.0)
	_touch_joystick.direction_changed.connect(_on_touch_joystick_changed)
	_mobile_controls.add_child(_touch_joystick)

	_mobile_talk_button = _dialog_button("TALK", UI.GOLD)
	_mobile_talk_button.name = "Talk"
	_mobile_talk_button.custom_minimum_size = Vector2(118.0, 68.0)
	_mobile_talk_button.size = Vector2(118.0, 68.0)
	_mobile_talk_button.focus_mode = Control.FOCUS_NONE
	_mobile_talk_button.pressed.connect(_on_mobile_interact)
	_mobile_controls.add_child(_mobile_talk_button)

	var move_label := _label("MOVE", 11, UI.MUTED)
	move_label.name = "MoveLabel"
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_label.size = Vector2(148.0, 18.0)
	_mobile_controls.add_child(move_label)


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
	var edge := 14.0
	var bottom := 14.0

	# The browser UI and phone gesture area can steal a little vertical space in
	# landscape. Keep every interactive control visibly inside the canvas instead
	# of placing it flush against the physical bottom edge.
	_mobile_controls.visible = touch_layout and not _dialog_open and not _transitioning
	_mobile_controls.scale = Vector2.ONE * ui_scale
	var joystick_side := 132.0 if landscape else 148.0
	_mobile_controls.position = Vector2(edge * ui_scale, (physical.y - joystick_side - bottom) * ui_scale)
	_mobile_controls.size = Vector2(maxf(1.0, physical.x - edge * 2.0), joystick_side)

	if _touch_joystick != null:
		_touch_joystick.position = Vector2.ZERO
		_touch_joystick.size = Vector2(joystick_side, joystick_side)
		var move_label := _mobile_controls.get_node_or_null("MoveLabel") as Label
		if move_label != null:
			move_label.position = Vector2(0.0, joystick_side - 20.0)
			move_label.size = Vector2(joystick_side, 18.0)

	if _mobile_talk_button != null:
		_mobile_talk_button.size = Vector2(118.0, 68.0)
		_mobile_talk_button.position = Vector2(
			maxf(joystick_side + 24.0, physical.x - edge * 2.0 - 118.0),
			maxf(0.0, (joystick_side - 68.0) * 0.5)
		)

	# The original dialog sat almost flush with the bottom of mobile browsers and
	# could be clipped after an orientation change. Keep it centered/contained and
	# slightly shorter while preserving the same content and buttons.
	if _dialog_panel != null:
		var dialog_width := minf(620.0 if landscape else 660.0, physical.x - edge * 2.0)
		var dialog_height := 190.0 if landscape else 220.0
		dialog_height = minf(dialog_height, physical.y - edge * 2.0)
		_dialog_panel.scale = Vector2.ONE * ui_scale
		_dialog_panel.position = Vector2(
			(physical.x - dialog_width) * 0.5 * ui_scale,
			(physical.y - dialog_height) * 0.5 * ui_scale
		)
		_dialog_panel.size = Vector2(dialog_width, dialog_height)

	# The information card should not dominate a short landscape phone viewport.
	if landscape and compact and _location_panel != null:
		var location_width := minf(330.0, physical.x * 0.44)
		_location_panel.position = Vector2(edge * ui_scale, 10.0 * ui_scale)
		_location_panel.size = Vector2(location_width, 108.0)


func _open_dialog() -> void:
	_release_touch_movement()
	super._open_dialog()


func _close_dialog() -> void:
	_release_touch_movement()
	super._close_dialog()


func _on_touch_joystick_changed(direction: Vector2) -> void:
	if _player != null:
		_player.set_touch_direction(direction)

	var marker := ""
	if direction.length_squared() > 0.04:
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
