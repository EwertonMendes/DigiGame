extends Node

const MenuScript = preload("res://src/ui/DigiSystemProgressionMenu.gd")
const SettingsStoreScript = preload("res://src/settings/SettingsStore.gd")
const CombatPresentationScript = preload("res://src/battle/CombatPresentationLibrary.gd")
const Buses = preload("res://src/audio/AudioBusIds.gd")

const TEST_SETTINGS_PATH := "user://digigame-settings-regression.json"


func _ready() -> void:
	GameInputBootstrap.configure_gamepad_actions()
	GameSettings.set_persistence_enabled(false)
	GameSettings.reset_audio_defaults(false)

	_test_bus_layout()
	_test_persistence_store()
	await _test_system_workspace()
	await _test_audio_routing()

	GameSettings.reset_audio_defaults(false)
	print("system audio settings regression passed")
	get_tree().quit(0)


func _test_bus_layout() -> void:
	for bus_name: StringName in [Buses.MASTER, Buses.MUSIC, Buses.SFX, Buses.BATTLE, Buses.UI]:
		assert(AudioServer.get_bus_index(bus_name) >= 0, "Semantic audio bus must exist: %s" % String(bus_name))
	assert(AudioServer.get_bus_send(AudioServer.get_bus_index(Buses.MUSIC)) == Buses.MASTER, "Music must route to Master")
	assert(AudioServer.get_bus_send(AudioServer.get_bus_index(Buses.SFX)) == Buses.MASTER, "SFX must route to Master")
	assert(AudioServer.get_bus_send(AudioServer.get_bus_index(Buses.BATTLE)) == Buses.SFX, "Battle must route through SFX")
	assert(AudioServer.get_bus_send(AudioServer.get_bus_index(Buses.UI)) == Buses.SFX, "UI must route through SFX")


func _test_persistence_store() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	var store: SettingsStore = SettingsStoreScript.new() as SettingsStore
	var payload := {
		"version": 1,
		"audio": {
			"master": 0.8,
			"music": 0.45,
			"sfx": 0.9,
			"battle": 1.0,
			"ui": 0.65,
			"muted": true,
		},
		"future_section": {"kept": true},
	}
	assert(store.save_settings(payload, TEST_SETTINGS_PATH), "Settings store must save independently from player progress")
	var loaded := store.load_settings(TEST_SETTINGS_PATH)
	assert(is_equal_approx(float((loaded["audio"] as Dictionary)["music"]), 0.45), "Settings store must preserve audio values")
	assert(bool((loaded["future_section"] as Dictionary)["kept"]), "Settings store must preserve future sections")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))


func _test_system_workspace() -> void:
	var menu := MenuScript.new() as DigiSystemProgressionMenu
	add_child(menu)
	menu.open_menu()
	await get_tree().process_frame
	await get_tree().process_frame

	menu.call("_set_main_tab", "system")
	await get_tree().process_frame
	await get_tree().process_frame

	var system_panel := menu.get("_system_panel") as DigiSystemSettingsPanel
	assert(system_panel != null and system_panel.visible, "System tab must show the settings workspace")
	assert(not (menu.get("_soon_label") as Label).visible, "System tab must no longer show the Soon placeholder")
	assert(not (menu.get("_collection_panel") as Control).visible, "Party roster must be hidden while System is active")
	assert(not (menu.get("_detail_panel") as Control).visible, "Party details must be hidden while System is active")
	assert(menu.has_nested_view_open(), "System must count as a nested menu so Back returns to Party before closing the game menu")

	var master_row := system_panel.get_volume_row("master")
	assert(master_row != null and master_row.has_focus(), "System audio must focus Master Volume first")
	assert(is_equal_approx(master_row.get_value(), 1.0), "Master Volume must reflect persisted settings state")

	var left := InputEventAction.new()
	left.action = "ui_left"
	left.pressed = true
	assert(system_panel.handle_input(left), "System panel must own horizontal adjustment input")
	assert(is_equal_approx(GameSettings.get_audio_volume("master"), 0.95), "Keyboard/controller adjustment must move volume in 5 percent steps")

	var master_index := AudioServer.get_bus_index(Buses.MASTER)
	assert(is_equal_approx(AudioServer.get_bus_volume_db(master_index), linear_to_db(0.95)), "Master slider must apply immediately to AudioServer")

	GameSettings.set_audio_volume("music", 0.42)
	var music_row := system_panel.get_volume_row("music")
	assert(music_row != null and is_equal_approx(music_row.get_value(), 0.42), "Settings UI must stay synchronized with external changes")

	var mute := system_panel.get_mute_button()
	assert(mute != null, "Audio workspace must expose an easy Mute All control")
	mute.set_pressed_no_signal(true)
	mute.toggled.emit(true)
	await get_tree().process_frame
	assert(GameSettings.is_audio_muted(), "Mute All must update settings state")
	assert(AudioServer.is_bus_mute(master_index), "Mute All must mute Master without overwriting slider values")
	assert(is_equal_approx(GameSettings.get_audio_volume("music"), 0.42), "Mute All must preserve channel levels")
	GameSettings.set_audio_muted(false)
	assert(not AudioServer.is_bus_mute(master_index), "Unmute must restore audio without changing channel levels")

	menu.call("_set_main_tab", "party")
	await get_tree().process_frame
	assert(not system_panel.visible, "Leaving System must hide settings without destroying their state")
	assert((menu.get("_collection_panel") as Control).visible, "Returning to Party must restore Party content")
	menu.queue_free()
	await get_tree().process_frame


func _test_audio_routing() -> void:
	var music_players := MusicDirector.get("_players") as Array
	assert(not music_players.is_empty(), "MusicDirector must own persistent players")
	for raw_player in music_players:
		assert((raw_player as AudioStreamPlayer).bus == Buses.MUSIC, "MusicDirector players must use Music bus")

	var ui_players := UiSfxDirector.get("_players") as Dictionary
	assert(not ui_players.is_empty(), "UI SFX director must own semantic players")
	for raw_player in ui_players.values():
		assert((raw_player as AudioStreamPlayer).bus == Buses.UI, "UI effects must use UI bus")

	var combat := CombatPresentationScript.new() as CombatPresentationLibrary
	add_child(combat)
	assert(combat.load_default(), "Combat presentation library must load for audio routing regression")
	assert(combat.play_audio_phase({"audioProfile": "normal"}, "start"), "Combat presentation must play a routed test cue")
	await get_tree().process_frame
	var combat_player := combat.find_child("CombatPresentationAudio", true, false) as AudioStreamPlayer
	assert(combat_player != null and combat_player.bus == Buses.BATTLE, "Combat effects must use Battle bus")
	combat.queue_free()
	await get_tree().process_frame
