extends "res://src/world/HubProgressionGameplay.gd"


func _ready() -> void:
	super._ready()
	# Dependencies start streaming while the player is still exploring the hub.
	# This is threaded and does not instantiate the battle scene yet.
	DigitalSceneTransition.preload_scene(BATTLE_SCENE_PATH)


func _open_dialog() -> void:
	super._open_dialog()
	if _dialog_open:
		# The operator dialog is a natural idle moment. Build the detached battle
		# field and Digimon here so pressing START only has to run the visual gate.
		DigitalSceneTransition.prepare_scene(BATTLE_SCENE_PATH)


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
