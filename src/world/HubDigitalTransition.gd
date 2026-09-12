extends "res://src/world/HubProgressionGameplay.gd"


func _ready() -> void:
	super._ready()
	# Headless regressions intentionally create and destroy the hub within a few
	# frames. Do not leave a threaded scene load alive while that test process is
	# shutting down. Browser/mobile builds still exercise the full prewarm path.
	if _supports_transition_prewarm():
		DigitalSceneTransition.preload_scene(BATTLE_SCENE_PATH)


func _open_dialog() -> void:
	super._open_dialog()
	if _dialog_open and _supports_transition_prewarm():
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
		resume_after_battle_transition()


func resume_after_battle_transition() -> void:
	# This hub instance is retained dormant during combat instead of reconstructed.
	# Reset every transient interaction flag that was intentionally locked when the
	# battle started so the exact same instance is immediately playable on return.
	_transitioning = false
	_dialog_open = false
	_dialog_panel.visible = false
	if _start_battle_button != null:
		_start_battle_button.disabled = false
	if _player != null:
		_player.movement_enabled = true
	_layout_ui()
	_refresh_interaction()
	print("[Hub] RESUMED_FROM_BATTLE")


func _supports_transition_prewarm() -> bool:
	return DisplayServer.get_name() != "headless"
