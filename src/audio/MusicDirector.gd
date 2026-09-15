extends Node

## Persistent background-music coordinator shared by world and battle scenes.
##
## Music transitions intentionally keep a single decoder active at a time.
## This avoids overlapping native Ogg decoders during scene changes while still
## providing a smooth fade-through-silence transition between semantic tracks.

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
		"volume_db": -3.0,
		"loop": true,
	},
	TRACK_BATTLE_1: {
		"path": "res://assets/audio/music/battle_1.ogg",
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

var _player: AudioStreamPlayer = null
var _current_track_id := ""
var _transition: Tween = null
var _transition_generation := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.volume_db = SILENT_VOLUME_DB
	_player.finished.connect(_on_player_finished)
	add_child(_player)
	_trace_web("ready")


func _exit_tree() -> void:
	_cancel_transition()
	if _player != null:
		_player.stop()
		_player.stream = null
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
	_trace_web("play-track-begin id=%s current=%s" % [track_id, _current_track_id])
	if not TRACKS.has(track_id):
		push_warning("[Music] Unknown track: %s" % track_id)
		return
	if _player == null:
		return
	if _current_track_id == track_id and _player.playing:
		_trace_web("play-track-same-active id=%s" % track_id)
		return

	var stream := _stream_for(track_id)
	_trace_web("stream-loaded id=%s valid=%s" % [track_id, str(stream != null)])
	if stream == null:
		push_error("[Music] Could not load track: %s" % track_id)
		return

	var target_volume := float((TRACKS[track_id] as Dictionary).get("volume_db", -3.0))
	var duration := maxf(fade_seconds, 0.0)
	_cancel_transition()
	var generation := _transition_generation

	if duration <= 0.0 or not _player.playing:
		_trace_web("start-immediate id=%s" % track_id)
		_start_stream(track_id, stream, target_volume)
		return

	var leg_duration := maxf(0.01, duration * 0.5)
	_trace_web("fade-through-begin id=%s leg=%.3f" % [track_id, leg_duration])
	_transition = create_tween()
	_transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition.tween_property(_player, "volume_db", SILENT_VOLUME_DB, leg_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_callback(_swap_stream.bind(generation, track_id, stream))
	_transition.tween_property(_player, "volume_db", target_volume, leg_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_callback(_finish_transition.bind(generation))


func stop(fade_seconds: float = DEFAULT_CROSSFADE_SECONDS) -> void:
	if _player == null:
		return
	_current_track_id = ""
	_cancel_transition()
	var generation := _transition_generation
	var duration := maxf(fade_seconds, 0.0)
	if duration <= 0.0 or not _player.playing:
		_release_player_stream()
		return
	_transition = create_tween()
	_transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition.tween_property(_player, "volume_db", SILENT_VOLUME_DB, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_callback(_finish_stop.bind(generation))


func current_track_id() -> String:
	return _current_track_id


func has_track(track_id: String) -> bool:
	return TRACKS.has(track_id)


func _stream_for(track_id: String) -> AudioStream:
	var definition := TRACKS[track_id] as Dictionary
	var path := str(definition.get("path", ""))
	if path.is_empty():
		return null
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		return null
	var should_loop := bool(definition.get("loop", true))
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = should_loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = should_loop
	return stream


func _start_stream(track_id: String, stream: AudioStream, target_volume: float) -> void:
	if _player == null:
		return
	_trace_web("player-start-before id=%s" % track_id)
	_player.stop()
	_player.stream = stream
	_player.volume_db = target_volume
	_player.play()
	_trace_web("player-start-after id=%s" % track_id)
	_current_track_id = track_id
	track_changed.emit(track_id)


func _swap_stream(generation: int, track_id: String, stream: AudioStream) -> void:
	if generation != _transition_generation or _player == null:
		return
	_trace_web("swap-before id=%s" % track_id)
	_player.stop()
	_player.stream = stream
	_player.volume_db = SILENT_VOLUME_DB
	_player.play()
	_trace_web("swap-after id=%s" % track_id)
	_current_track_id = track_id
	track_changed.emit(track_id)


func _finish_transition(generation: int) -> void:
	if generation != _transition_generation:
		return
	_trace_web("transition-finished current=%s" % _current_track_id)
	_transition = null


func _finish_stop(generation: int) -> void:
	if generation != _transition_generation:
		return
	_release_player_stream()
	_transition = null


func _release_player_stream() -> void:
	if _player == null:
		return
	_player.stop()
	_player.stream = null
	_player.volume_db = SILENT_VOLUME_DB


func _cancel_transition() -> void:
	_transition_generation += 1
	if _transition != null and is_instance_valid(_transition):
		_transition.kill()
	_transition = null


func _on_player_finished() -> void:
	if _player != null:
		_player.stream = null
		_player.volume_db = SILENT_VOLUME_DB
	_current_track_id = ""
	track_changed.emit("")


func _trace_web(message: String) -> void:
	if OS.has_feature("web"):
		push_error("[MusicTrace] %s" % message)
