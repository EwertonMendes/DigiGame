extends Node

## Persistent background-music coordinator shared by world and battle scenes.
##
## Two AudioStreamPlayers stay alive as an autoload so scene changes can
## crossfade instead of cutting music abruptly. Track selection is centralized
## here so future areas, bosses, and story scenes only request a semantic track
## id instead of owning their own music players.

signal track_changed(track_id: String)

const TRACK_ZONE_1 := "zone_1"
const TRACK_BATTLE_1 := "battle_1"
const TRACK_VICTORY_THEME := "victory_theme"
const TRACK_GAME_OVER := "game_over"
const DEFAULT_CROSSFADE_SECONDS := 0.55
const SILENT_VOLUME_DB := -60.0

const TRACKS := {
	TRACK_ZONE_1: {
		"path": "res://assets/audio/music/zone_1.ogg",
		# Exploration music stays present while gameplay SFX remain slightly ahead.
		"volume_db": -3.0,
		"loop": true,
	},
	TRACK_BATTLE_1: {
		"path": "res://assets/audio/music/battle_1.ogg",
		# Battle music has more perceived density, so leave a little extra headroom.
		"volume_db": -6.0,
		"loop": true,
	},
	TRACK_VICTORY_THEME: {
		"path": "res://assets/audio/music/victory-theme.ogg",
		"volume_db": -3.0,
		"loop": false,
	},
	TRACK_GAME_OVER: {
		"path": "res://assets/audio/music/game-over.ogg",
		"volume_db": -3.0,
		"loop": false,
	},
}

var _players: Array[AudioStreamPlayer] = []
var _active_index := -1
var _current_track_id := ""
var _crossfade: Tween = null
var _stream_cache: Dictionary = {}
var _headless_runtime := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless_runtime = DisplayServer.get_name() == "headless"
	if _headless_runtime:
		# Headless regressions validate game state/UI contracts, not audio output.
		# Preserve MusicDirector's semantic state/signals without creating players or
		# loading OGG resources that intentionally survive normal scene changes and
		# would otherwise be reported as leaks when an isolated test quits Godot.
		return
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (index + 1)
		player.volume_db = SILENT_VOLUME_DB
		player.finished.connect(_on_player_finished.bind(index))
		add_child(player)
		_players.append(player)


func _exit_tree() -> void:
	if _crossfade != null and is_instance_valid(_crossfade):
		_crossfade.kill()
		_crossfade = null
	for player: AudioStreamPlayer in _players:
		if not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	_players.clear()
	_stream_cache.clear()
	_active_index = -1
	_current_track_id = ""


func play_zone_1(fade_seconds: float = DEFAULT_CROSSFADE_SECONDS) -> void:
	play_track(TRACK_ZONE_1, fade_seconds)


func play_battle_1(fade_seconds: float = DEFAULT_CROSSFADE_SECONDS) -> void:
	play_track(TRACK_BATTLE_1, fade_seconds)


func play_victory_theme(fade_seconds: float = 0.0) -> void:
	play_track(TRACK_VICTORY_THEME, fade_seconds)


func play_game_over(fade_seconds: float = 0.0) -> void:
	play_track(TRACK_GAME_OVER, fade_seconds)


func play_track(track_id: String, fade_seconds: float = DEFAULT_CROSSFADE_SECONDS) -> void:
	if not TRACKS.has(track_id):
		push_warning("[Music] Unknown track: %s" % track_id)
		return
	if _headless_runtime:
		if _current_track_id == track_id:
			return
		_current_track_id = track_id
		track_changed.emit(track_id)
		return
	if _current_track_id == track_id and _active_index >= 0 and _players[_active_index].playing:
		return

	var stream := _stream_for(track_id)
	if stream == null:
		push_error("[Music] Could not load track: %s" % track_id)
		return

	if _crossfade != null and is_instance_valid(_crossfade):
		_crossfade.kill()
		_crossfade = null

	var previous_index := _active_index
	var next_index := 0 if previous_index != 0 else 1
	var next_player := _players[next_index]
	var previous_player: AudioStreamPlayer = _players[previous_index] if previous_index >= 0 else null
	var target_volume := float((TRACKS[track_id] as Dictionary).get("volume_db", -3.0))

	if next_player.playing:
		next_player.stop()
	next_player.stream = stream
	next_player.volume_db = SILENT_VOLUME_DB
	next_player.play()

	_active_index = next_index
	_current_track_id = track_id
	track_changed.emit(track_id)

	var duration := maxf(fade_seconds, 0.0)
	if duration <= 0.0:
		next_player.volume_db = target_volume
		if previous_player != null and previous_player != next_player:
			previous_player.stop()
		return

	_crossfade = create_tween()
	_crossfade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_crossfade.set_parallel(true)
	_crossfade.tween_property(next_player, "volume_db", target_volume, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if previous_player != null and previous_player.playing and previous_player != next_player:
		_crossfade.tween_property(previous_player, "volume_db", SILENT_VOLUME_DB, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_crossfade.set_parallel(false)
	_crossfade.tween_callback(_finish_crossfade.bind(previous_player, next_player))


func stop(fade_seconds: float = DEFAULT_CROSSFADE_SECONDS) -> void:
	if _headless_runtime:
		if _current_track_id.is_empty():
			return
		_current_track_id = ""
		track_changed.emit("")
		return
	if _active_index < 0:
		return
	var active := _players[_active_index]
	_current_track_id = ""
	if _crossfade != null and is_instance_valid(_crossfade):
		_crossfade.kill()
		_crossfade = null
	if fade_seconds <= 0.0 or not active.playing:
		active.stop()
		_active_index = -1
		return
	_crossfade = create_tween()
	_crossfade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_crossfade.tween_property(active, "volume_db", SILENT_VOLUME_DB, fade_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_crossfade.tween_callback(func():
		active.stop()
		_active_index = -1
	)


func current_track_id() -> String:
	return _current_track_id


func has_track(track_id: String) -> bool:
	return TRACKS.has(track_id)


func _stream_for(track_id: String) -> AudioStream:
	if _stream_cache.has(track_id):
		return _stream_cache[track_id] as AudioStream

	var definition := TRACKS[track_id] as Dictionary
	var path := str(definition.get("path", ""))
	if path.is_empty():
		return null

	# Keep loading runtime-based instead of preload-based: during a clean Godot
	# import, the Ogg importer has not registered the resource yet when autoload
	# scripts are first parsed. By _ready/runtime the import exists and ResourceLoader
	# can resolve the file normally on desktop and Web.
	var source := ResourceLoader.load(path) as AudioStream
	if source == null:
		return null

	var stream := source.duplicate() as AudioStream
	var should_loop := bool(definition.get("loop", true))
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = should_loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = should_loop

	_stream_cache[track_id] = stream
	return stream


func _finish_crossfade(previous_player: AudioStreamPlayer, active_player: AudioStreamPlayer) -> void:
	if previous_player != null and previous_player != active_player and previous_player.playing:
		previous_player.stop()
	_crossfade = null


func _on_player_finished(index: int) -> void:
	if index != _active_index:
		return
	_active_index = -1
	_current_track_id = ""
	track_changed.emit("")
