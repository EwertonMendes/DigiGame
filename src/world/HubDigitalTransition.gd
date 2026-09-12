extends "res://src/world/HubProgressionGameplay.gd"


func _ready() -> void:
	super._ready()
	# Start the frame-budgeted detached battle preparation as soon as the hub is
	# playable. It advances in tiny chunks between rendered frames, so by the time
	# the player reaches the operator there is normally nothing left to create.
	if _supports_transition_prewarm():
		DigitalSceneTransition.prepare_scene(BATTLE_SCENE_PATH)


func _open_dialog() -> void:
	super._open_dialog()
	if _dialog_open and _supports_transition_prewarm():
		# Idempotent safety net for unusually fast players or very slow devices.
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
	print("[Hub] START_TEST_BATTLE digital_transition=true prepared=%s" % str(DigitalSceneTransition.is_scene_prepared(BATTLE_SCENE_PATH)))
	if not DigitalSceneTransition.enter_battle(BATTLE_SCENE_PATH):
		resume_after_battle_transition()


func resume_after_battle_transition() -> void:
	# This hub instance is retained dormant during combat instead of reconstructed.
	# Reset the transient interaction lock and immediately begin preparing the next
	# possible battle again in small chunks.
	_transitioning = false
	_dialog_open = false
	_dialog_panel.visible = false
	if _start_battle_button != null:
		_start_battle_button.disabled = false
	if _player != null:
		_player.movement_enabled = true
	_layout_ui()
	_refresh_interaction()
	if _supports_transition_prewarm():
		DigitalSceneTransition.prepare_scene(BATTLE_SCENE_PATH)
	print("[Hub] RESUMED_FROM_BATTLE")


func _supports_transition_prewarm() -> bool:
	return DisplayServer.get_name() != "headless"
