extends "res://src/world/HubTrainingGameplay.gd"


func _ready() -> void:
	super._ready()
	# MusicDirector is persistent across scenes, so returning from combat fades the
	# battle theme into the Terminal Commons theme instead of restarting audio
	# through a scene-local player.
	MusicDirector.play_zone_1()


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
		return

	# Complete the decoder handoff while the existing digital cover is animating.
	# The battle controller repeats this semantic request after the scene change,
	# where it becomes a no-op because the correct track is already playing.
	MusicDirector.play_battle_1()
