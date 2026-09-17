extends Node

## Persistent semantic UI sound coordinator.
##
## Player-facing controls request intent (navigate, confirm, back or open) rather
## than loading audio themselves. Existing Button controls are observed globally
## so mouse/touch activation gets the same feedback as keyboard/gamepad input.
## Screens can opt into a specific role by setting `ui_sfx_role` metadata to one
## of the ROLE_* constants; shared Digi UI naming conventions are recognized
## centrally so individual screens do not duplicate audio plumbing.
##
## This autoload deliberately does not reference script class_names from the UI
## layer. During a clean Godot import autoload scripts are compiled before image
## and SVG resources have finished importing; referencing a UI class here would
## force those scripts (and their texture preloads) to compile too early.

const ROLE_CONFIRM := "confirm"
const ROLE_NAVIGATION := "navigation"
const ROLE_BACK := "back"
const ROLE_OPEN := "open"
const ROLE_SILENT := "silent"
const ROLE_META := "ui_sfx_role"
const BOUND_META := "_ui_sfx_bound"

const CUE_NAVIGATION := "navigation"
const CUE_CONFIRM := "confirm"
const CUE_BACK := "back"
const CUE_OPEN := "open"

const NAVIGATION_INTENT_MSEC := 220
const OPEN_FOCUS_SUPPRESS_MSEC := 180
const NAVIGATION_REPLAY_MSEC := 28
const CONFIRM_REPLAY_MSEC := 45
const BACK_REPLAY_MSEC := 70
const OPEN_REPLAY_MSEC := 120
const JOYPAD_NAV_THRESHOLD := 0.58

const CUES := {
	CUE_NAVIGATION: {
		"path": "res://assets/audio/sfx/select-small.mp3",
		"volume_db": 0.0,
		"replay_msec": NAVIGATION_REPLAY_MSEC,
	},
	CUE_CONFIRM: {
		"path": "res://assets/audio/sfx/select-medium.mp3",
		"volume_db": 0.0,
		"replay_msec": CONFIRM_REPLAY_MSEC,
	},
	CUE_BACK: {
		"path": "res://assets/audio/sfx/ui-modal-close-soft-tap.mp3",
		"volume_db": 0.0,
		"replay_msec": BACK_REPLAY_MSEC,
	},
	CUE_OPEN: {
		"path": "res://assets/audio/sfx/chrysalyn-clean-minimalist-future-ui-interaction-sound.mp3",
		"volume_db": 0.0,
		"replay_msec": OPEN_REPLAY_MSEC,
	},
}

var _players: Dictionary = {}
var _last_played_msec: Dictionary = {}
var _last_override_msec := -1
var _navigation_intent_until_msec := -1
var _suppress_navigation_until_msec := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_build_players()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_bind_existing_scene")


func play_navigation() -> void:
	var now := Time.get_ticks_msec()
	if now < _suppress_navigation_until_msec:
		return
	_last_override_msec = now
	_play(CUE_NAVIGATION)


func play_confirm() -> void:
	_play(CUE_CONFIRM)


func play_back() -> void:
	_last_override_msec = Time.get_ticks_msec()
	_play(CUE_BACK)


func play_open() -> void:
	var now := Time.get_ticks_msec()
	_last_override_msec = now
	_suppress_navigation_until_msec = now + OPEN_FOCUS_SUPPRESS_MSEC
	_navigation_intent_until_msec = -1
	_play(CUE_OPEN)


func set_button_role(button: Button, role: String) -> void:
	if button == null:
		return
	button.set_meta(ROLE_META, role)


func has_cue(cue: String) -> bool:
	return _players.has(cue) and is_instance_valid(_players.get(cue))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		if _has_active_ui_focus():
			play_back()
		return

	if event.is_action_pressed("ui_accept"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and focused.is_visible_in_tree():
			if focused is BaseButton and (focused as BaseButton).disabled:
				return
			var request_msec := Time.get_ticks_msec()
			call_deferred("_play_confirm_if_unclaimed", request_msec)
		return

	if _is_navigation_event(event):
		_register_navigation_intent()
		var focused := get_viewport().gui_get_focus_owner()
		var before_id := focused.get_instance_id() if focused != null else 0
		call_deferred("_play_navigation_if_focus_changed", before_id)


func _is_navigation_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		return true

	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and key.keycode == KEY_TAB

	if event is InputEventJoypadButton:
		var joy_button := event as InputEventJoypadButton
		if not joy_button.pressed:
			return false
		return joy_button.button_index == JOY_BUTTON_LEFT_SHOULDER or joy_button.button_index == JOY_BUTTON_RIGHT_SHOULDER

	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			return false
		return absf(motion.axis_value) >= JOYPAD_NAV_THRESHOLD

	return false


func _register_navigation_intent() -> void:
	_navigation_intent_until_msec = Time.get_ticks_msec() + NAVIGATION_INTENT_MSEC


func _play_navigation_if_focus_changed(before_id: int) -> void:
	var now := Time.get_ticks_msec()
	if now > _navigation_intent_until_msec or now < _suppress_navigation_until_msec:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree():
		return
	if focused.get_instance_id() == before_id:
		return
	play_navigation()


func _play_confirm_if_unclaimed(request_msec: int) -> void:
	# A button may open/close/navigate in the same frame. Those more specific
	# semantic cues win over the generic confirmation sound, preventing doubles.
	if _last_override_msec >= request_msec:
		return
	play_confirm()


func _has_active_ui_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and focused.is_visible_in_tree()


func _build_players() -> void:
	for cue: String in CUES.keys():
		var definition := CUES[cue] as Dictionary
		var path := String(definition.get("path", ""))
		var source := ResourceLoader.load(path) as AudioStream
		if source == null:
			push_error("[UI SFX] Could not load %s from %s" % [cue, path])
			continue

		var stream := source.duplicate() as AudioStream
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = false
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false

		var player := AudioStreamPlayer.new()
		player.name = "UiSfx_%s" % cue.capitalize()
		player.stream = stream
		player.volume_db = float(definition.get("volume_db", 0.0))
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players[cue] = player


func _play(cue: String) -> void:
	var player := _players.get(cue) as AudioStreamPlayer
	if player == null or not is_instance_valid(player):
		return
	var now := Time.get_ticks_msec()
	var definition := CUES.get(cue, {}) as Dictionary
	var replay_msec := int(definition.get("replay_msec", 0))
	var last := int(_last_played_msec.get(cue, -1000000))
	if now - last < replay_msec:
		return
	_last_played_msec[cue] = now
	if player.playing:
		player.stop()
	player.play()


func _bind_existing_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_bind_branch(scene)


func _bind_branch(node: Node) -> void:
	_bind_node(node)
	for child: Node in node.get_children():
		_bind_branch(child)


func _on_node_added(node: Node) -> void:
	call_deferred("_bind_instance_id", node.get_instance_id())


func _bind_instance_id(instance_id: int) -> void:
	var candidate := instance_from_id(instance_id)
	if candidate is Node:
		_bind_node(candidate as Node)


func _bind_node(node: Node) -> void:
	if not node is Button:
		return
	var button := node as Button
	if button.has_meta(BOUND_META):
		return
	button.set_meta(BOUND_META, true)
	button.pressed.connect(_on_button_pressed.bind(button.get_instance_id()))


func _on_button_pressed(instance_id: int) -> void:
	var candidate := instance_from_id(instance_id)
	if not candidate is Button:
		return
	var button := candidate as Button
	if button.disabled:
		return

	match _resolve_button_role(button):
		ROLE_SILENT:
			return
		ROLE_NAVIGATION:
			play_navigation()
		ROLE_BACK:
			play_back()
		ROLE_OPEN:
			play_open()
		_:
			var request_msec := Time.get_ticks_msec()
			call_deferred("_play_confirm_if_unclaimed", request_msec)


func _resolve_button_role(button: Button) -> String:
	var explicit := String(button.get_meta(ROLE_META, ""))
	if explicit in [ROLE_CONFIRM, ROLE_NAVIGATION, ROLE_BACK, ROLE_OPEN, ROLE_SILENT]:
		return explicit

	# Classify shared controls by their stable public names/copy instead of
	# depending on script class_names. This keeps the autoload isolated from UI
	# texture preloads during a clean Godot import while preserving semantics.
	var node_name := String(button.name)
	if node_name.begins_with("Close") or node_name == "ModalClose" or node_name.ends_with("Back") or "BackTo" in node_name:
		return ROLE_BACK
	if node_name.begins_with("Tab_") or node_name in ["PreviousPage", "NextPage", "PreviousPatients", "NextPatients"] or button.text in ["‹", "›"]:
		return ROLE_NAVIGATION
	return ROLE_CONFIRM
