extends Node

## Persistent user-preference service shared by all scenes.
##
## Runtime systems talk to semantic settings rather than directly manipulating
## UI controls. Audio changes apply immediately to Godot buses while disk writes
## are debounced so dragging a slider does not hammer storage (especially Web).

signal audio_volume_changed(setting_key: String, value: float)
signal audio_mute_changed(muted: bool)

const Buses = preload("res://src/audio/AudioBusIds.gd")
const StoreScript = preload("res://src/settings/SettingsStore.gd")

const SETTINGS_VERSION := 1
const SAVE_DEBOUNCE_SECONDS := 0.25
const MIN_LINEAR_VOLUME := 0.0001

const DEFAULT_AUDIO := {
	"master": 1.0,
	"music": 1.0,
	"sfx": 1.0,
	"battle": 1.0,
	"ui": 1.0,
	"muted": false,
}

var _store: SettingsStore
var _settings: Dictionary = {}
var _save_timer: Timer
var _dirty := false
var _persistence_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_store = StoreScript.new() as SettingsStore
	_save_timer = Timer.new()
	_save_timer.name = "SettingsSaveDebounce"
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SECONDS
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_flush_if_dirty)
	add_child(_save_timer)
	_load_settings()
	_apply_all_audio()


func get_audio_volume(setting_key: String) -> float:
	if not Buses.VOLUME_SETTING_KEYS.has(setting_key):
		return 1.0
	var audio := _audio_section()
	return clampf(float(audio.get(setting_key, DEFAULT_AUDIO[setting_key])), 0.0, 1.0)


func set_audio_volume(setting_key: String, value: float) -> void:
	if not Buses.VOLUME_SETTING_KEYS.has(setting_key):
		push_warning("[Settings] Unknown audio setting: %s" % setting_key)
		return
	var normalized := clampf(value, 0.0, 1.0)
	var audio := _audio_section()
	var previous := clampf(float(audio.get(setting_key, DEFAULT_AUDIO[setting_key])), 0.0, 1.0)
	if is_equal_approx(previous, normalized):
		return
	audio[setting_key] = normalized
	_settings["audio"] = audio
	_apply_bus_volume(setting_key, normalized)
	audio_volume_changed.emit(setting_key, normalized)
	_mark_dirty()


func is_audio_muted() -> bool:
	return bool(_audio_section().get("muted", false))


func set_audio_muted(muted: bool) -> void:
	var audio := _audio_section()
	if bool(audio.get("muted", false)) == muted:
		return
	audio["muted"] = muted
	_settings["audio"] = audio
	_apply_master_mute(muted)
	audio_mute_changed.emit(muted)
	_mark_dirty()


func get_audio_snapshot() -> Dictionary:
	return _audio_section().duplicate(true)


func reset_audio_defaults(persist: bool = true) -> void:
	var audio := DEFAULT_AUDIO.duplicate(true)
	_settings["audio"] = audio
	_apply_all_audio()
	for setting_key: String in Buses.VOLUME_SETTING_KEYS:
		audio_volume_changed.emit(setting_key, float(audio[setting_key]))
	audio_mute_changed.emit(bool(audio["muted"]))
	if persist:
		_mark_dirty()


func set_persistence_enabled(enabled: bool) -> void:
	_persistence_enabled = enabled
	if not enabled and _save_timer != null:
		_save_timer.stop()
		_dirty = false


func save_now() -> bool:
	if not _persistence_enabled:
		_dirty = false
		return true
	if _store == null:
		return false
	var success := _store.save_settings(_settings)
	if success:
		_dirty = false
	return success


func _load_settings() -> void:
	var loaded := _store.load_settings() if _store != null else {}
	_settings = loaded.duplicate(true) if loaded is Dictionary else {}
	_settings["version"] = SETTINGS_VERSION
	var audio_raw = _settings.get("audio", {})
	var audio: Dictionary = (audio_raw as Dictionary).duplicate(true) if audio_raw is Dictionary else {}
	for setting_key: String in Buses.VOLUME_SETTING_KEYS:
		audio[setting_key] = clampf(float(audio.get(setting_key, DEFAULT_AUDIO[setting_key])), 0.0, 1.0)
	audio["muted"] = bool(audio.get("muted", DEFAULT_AUDIO["muted"]))
	_settings["audio"] = audio


func _audio_section() -> Dictionary:
	var raw = _settings.get("audio", {})
	if raw is Dictionary:
		return raw as Dictionary
	var audio := DEFAULT_AUDIO.duplicate(true)
	_settings["audio"] = audio
	return audio


func _apply_all_audio() -> void:
	for setting_key: String in Buses.VOLUME_SETTING_KEYS:
		_apply_bus_volume(setting_key, get_audio_volume(setting_key))
	_apply_master_mute(is_audio_muted())


func _apply_bus_volume(setting_key: String, value: float) -> void:
	var bus_name: StringName = Buses.bus_for_setting(setting_key)
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("[Settings] Audio bus is missing: %s" % String(bus_name))
		return
	var linear := maxf(clampf(value, 0.0, 1.0), MIN_LINEAR_VOLUME)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))


func _apply_master_mute(muted: bool) -> void:
	var master_index := AudioServer.get_bus_index(Buses.MASTER)
	if master_index < 0:
		push_warning("[Settings] Master audio bus is missing")
		return
	AudioServer.set_bus_mute(master_index, muted)


func _mark_dirty() -> void:
	if not _persistence_enabled:
		return
	_dirty = true
	if _save_timer != null:
		_save_timer.start(SAVE_DEBOUNCE_SECONDS)


func _flush_if_dirty() -> void:
	if _dirty:
		save_now()


func _exit_tree() -> void:
	if _dirty:
		save_now()
