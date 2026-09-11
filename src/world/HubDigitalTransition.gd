extends "res://src/world/HubProgressionGameplay.gd"


func _start_test_battle() -> void:
	if _transitioning or DigitalSceneTransition.is_transitioning():
		return
	_transitioning = true
	_dialog_open = false
	_dialog_panel.visible = false
	if _player != null:
		_player.movement_enabled = false
	_mobile_controls.visible = false
	if _start_battle_button != null:
		_start_battle_button.disabled = true
	print("[Hub] START_TEST_BATTLE digital_transition=true")
	if not DigitalSceneTransition.enter_battle(BATTLE_SCENE_PATH):
		_transitioning = false
		if _player != null:
			_player.movement_enabled = true
		if _start_battle_button != null:
			_start_battle_button.disabled = false
		_layout_ui()
