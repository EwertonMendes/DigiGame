extends Node
class_name GameInputBootstrap

# Godot's UI actions are kept as the single navigation contract across the game.
# Standard Gamepad bindings are added at runtime so Web/desktop builds behave the
# same on Xbox, PlayStation and compatible controllers.
const STICK_DEADZONE := 0.42


static func configure_gamepad_actions() -> void:
	_ensure_button("ui_accept", JOY_BUTTON_A)
	_ensure_button("ui_cancel", JOY_BUTTON_B)
	_ensure_button("ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_button("game_menu", JOY_BUTTON_START)
	_ensure_key("game_menu", KEY_ESCAPE)
	_ensure_key("game_menu", KEY_M)

	_ensure_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_ensure_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)


static func _ensure_button(action_name: StringName, button_index: int) -> void:
	_ensure_action(action_name)
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button_index
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)


static func _ensure_key(action_name: StringName, keycode: Key) -> void:
	_ensure_action(action_name)
	var event := InputEventKey.new()
	event.device = -1
	event.keycode = keycode
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)


static func _ensure_axis(action_name: StringName, axis: int, axis_value: float) -> void:
	_ensure_action(action_name)
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = axis_value
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)
	InputMap.action_set_deadzone(action_name, maxf(InputMap.action_get_deadzone(action_name), STICK_DEADZONE))


static func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, STICK_DEADZONE)
