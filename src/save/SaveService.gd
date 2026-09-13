extends RefCounted
class_name SaveService

const SaveDataScript = preload("res://src/save/PlayerProgressSaveData.gd")
const MigrationScript = preload("res://src/save/SaveMigration.gd")

const DEFAULT_PATH := "user://digigame-save.json"

var _migration = MigrationScript.new()


func save_roster(roster: PlayerRoster, path: String = DEFAULT_PATH) -> bool:
	if roster == null:
		return false
	var dto: PlayerProgressSaveData = SaveDataScript.from_roster(roster)
	return save_data(dto, path)


func save_data(data: PlayerProgressSaveData, path: String = DEFAULT_PATH) -> bool:
	if data == null:
		return false
	var json := JSON.stringify(data.to_dict(), "\t", false)
	var absolute_path := ProjectSettings.globalize_path(path)
	var temporary_path := absolute_path + ".tmp"
	var backup_path := absolute_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open temporary save file: %s" % temporary_path)
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
			push_error("Could not rotate existing save file: %s" % backup_error)
			return false
	var replace_error := DirAccess.rename_absolute(temporary_path, absolute_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, absolute_path)
		push_error("Could not replace save file: %s" % replace_error)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	return true


func load_data(path: String = DEFAULT_PATH) -> PlayerProgressSaveData:
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Player save root must be an object")
		return null
	var migrated: Dictionary = _migration.migrate(parsed as Dictionary)
	if migrated.is_empty():
		return null
	return SaveDataScript.from_dict(migrated)


func load_roster(path: String = DEFAULT_PATH) -> PlayerRoster:
	var data := load_data(path)
	if data == null:
		return null
	var roster := PlayerRoster.new()
	roster.load_dict(data.roster)
	return roster


func delete_save(path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
