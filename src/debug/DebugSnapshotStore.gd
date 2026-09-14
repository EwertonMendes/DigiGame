extends RefCounted
class_name DebugSnapshotStore

const SNAPSHOT_PATH := "user://digigame-debug-snapshots.json"
const MAX_SNAPSHOTS := 24

var _snapshots: Dictionary = {}

func _init() -> void:
	load_from_disk()

func load_from_disk() -> void:
	_snapshots.clear()
	if not FileAccess.file_exists(SNAPSHOT_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_PATH))
	if not parsed is Dictionary:
		return
	var raw_snapshots = (parsed as Dictionary).get("snapshots", {})
	if raw_snapshots is Dictionary:
		_snapshots = (raw_snapshots as Dictionary).duplicate(true)

func list_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_name in _snapshots.keys():
		var name := String(raw_name)
		var entry = _snapshots[raw_name]
		if not entry is Dictionary:
			continue
		var row := (entry as Dictionary).duplicate(true)
		row["name"] = name
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_unix", 0)) > int(b.get("created_unix", 0))
	)
	return result

func capture(name: String, state: Dictionary) -> bool:
	var clean_name := _sanitize_name(name)
	if clean_name.is_empty() or state.is_empty():
		return false
	_snapshots[clean_name] = {
		"created_unix": Time.get_unix_time_from_system(),
		"created_text": Time.get_datetime_string_from_system(false, true),
		"state": state.duplicate(true),
	}
	_trim_oldest()
	return _save_to_disk()

func get_state(name: String) -> Dictionary:
	var entry = _snapshots.get(name, {})
	if not entry is Dictionary:
		return {}
	var state = (entry as Dictionary).get("state", {})
	return (state as Dictionary).duplicate(true) if state is Dictionary else {}

func delete(name: String) -> bool:
	if not _snapshots.has(name):
		return false
	_snapshots.erase(name)
	return _save_to_disk()

func clear() -> bool:
	_snapshots.clear()
	return _save_to_disk()

func _trim_oldest() -> void:
	if _snapshots.size() <= MAX_SNAPSHOTS:
		return
	var rows := list_snapshots()
	while rows.size() > MAX_SNAPSHOTS:
		var removed := rows.pop_back() as Dictionary
		_snapshots.erase(String(removed.get("name", "")))

func _save_to_disk() -> bool:
	var file := FileAccess.open(SNAPSHOT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("DebugSnapshotStore: could not open %s" % SNAPSHOT_PATH)
		return false
	file.store_string(JSON.stringify({"version": 1, "snapshots": _snapshots}, "\t"))
	file.close()
	return true

func _sanitize_name(raw_name: String) -> String:
	var clean := raw_name.strip_edges()
	if clean.is_empty():
		clean = "Snapshot %s" % Time.get_datetime_string_from_system(false, true)
	return clean.substr(0, 80)
