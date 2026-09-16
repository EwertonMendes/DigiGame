extends "res://src/world/HubHospitalGameplay.gd"


func _ready() -> void:
	super._ready()
	# MusicDirector is persistent across scenes, so returning from combat fades the
	# battle theme into the Terminal Commons theme instead of restarting audio
	# through a scene-local player.
	MusicDirector.play_zone_1()


func _open_dialog() -> void:
	super._open_dialog()
	if not _dialog_open:
		return
	var party_error := OverworldState.battle_party_validation_error()
	if _mobile_dialog_body != null:
		_mobile_dialog_body.text = party_error if not party_error.is_empty() else "START A TEST BATTLE?"
	if _start_battle_button != null:
		_start_battle_button.disabled = not party_error.is_empty()
	if not party_error.is_empty() and _mobile_dialog_cancel != null:
		_mobile_dialog_cancel.grab_focus()


func _start_test_battle() -> void:
	if _transitioning or DigitalSceneTransition.is_transitioning():
		return
	var party_error := OverworldState.battle_party_validation_error()
	if not party_error.is_empty():
		if _mobile_dialog_body != null:
			_mobile_dialog_body.text = party_error
		if _start_battle_button != null:
			_start_battle_button.disabled = true
		if _mobile_dialog_cancel != null:
			_mobile_dialog_cancel.grab_focus()
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
