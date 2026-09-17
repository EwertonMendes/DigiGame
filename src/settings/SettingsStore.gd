extends RefCounted
class_name SettingsStore

## Independent persistence for user preferences.
## Gameplay progression deliberately lives elsewhere so deleting or replacing a
## save file never resets audio, display, control or accessibility preferences.

const DEFAULT_PATH := "user://digigame-settings.json"


func load_settings(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("[Settings] Ignoring malformed settings file: %s" % path)
		return {}
	return (parsed as Dictionary).duplicate(true)


func save_settings(settings: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var json := JSON.stringify(settings, "\t", false)
	var absolute_path := ProjectSettings.globalize_path(path)
	var temporary_path := absolute_path + ".tmp"
	var backup_path := absolute_path + ".bak"

	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("[Settings] Could not open temporary settings file: %s" % temporary_path)
		return false
	file.store_string(json)
	file.flush()
	file.close()

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(absolute_path):
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_path)
			push_error("[Settings] Could not rotate existing settings file: %s" % backup_error)
			return false

	var replace_error := DirAccess.rename_absolute(temporary_path, absolute_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, absolute_path)
		push_error("[Settings] Could not replace settings file: %s" % replace_error)
		return false

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	return true
