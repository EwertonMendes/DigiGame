extends "res://src/EscapeBattleHUD.gd"


func _build_escape_ui() -> void:
	super._build_escape_ui()
	if _escape_result_return == null:
		return
	for connection: Dictionary in _escape_result_return.pressed.get_connections():
		var existing_callable: Callable = connection.get("callable", Callable())
		if existing_callable.is_valid() and _escape_result_return.pressed.is_connected(existing_callable):
			_escape_result_return.pressed.disconnect(existing_callable)
	_escape_result_return.pressed.connect(_return_to_terminal_commons)


func _on_result_return_requested() -> void:
	_return_to_terminal_commons()


func _return_to_terminal_commons() -> void:
	if DigitalSceneTransition.is_transitioning():
		return
	DigitalSceneTransition.return_to_hub()
