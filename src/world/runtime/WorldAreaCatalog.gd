extends RefCounted
class_name WorldAreaCatalog

const AREA_FILES := {
	"central_city": "res://assets/resources/world/central_city.json",
}


func load_area(area_id: String) -> Dictionary:
	var path := String(AREA_FILES.get(area_id, ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		push_error("World area definition is missing: %s" % area_id)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("World area definition must be an object: %s" % path)
		return {}
	var definition := (parsed as Dictionary).duplicate(true)
	if not _validate(definition):
		return {}
	return definition


func _validate(definition: Dictionary) -> bool:
	var area_id := String(definition.get("id", "")).strip_edges()
	if area_id.is_empty():
		push_error("World area definition requires a stable id")
		return false
	var sections = definition.get("sections", [])
	if not sections is Array or sections.is_empty():
		push_error("World area '%s' requires at least one section" % area_id)
		return false
	var seen: Dictionary = {}
	for raw_section in sections:
		if not raw_section is Dictionary:
			push_error("World area '%s' contains a non-object section" % area_id)
			return false
		var section := raw_section as Dictionary
		var coord = section.get("coord", [])
		if not coord is Array or coord.size() < 2:
			push_error("World area '%s' contains a section without a valid coord" % area_id)
			return false
		var key := "%d:%d" % [int(coord[0]), int(coord[1])]
		if seen.has(key):
			push_error("World area '%s' duplicates section %s" % [area_id, key])
			return false
		seen[key] = true
	return true
