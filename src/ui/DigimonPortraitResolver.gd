extends RefCounted
class_name DigimonPortraitResolver

const PORTRAIT_ROOT := "res://assets/characters"


static func resolve_key(species_or_key: String) -> String:
	var normalized := species_or_key.strip_edges().to_lower()
	if normalized.is_empty():
		return ""
	var candidates: Array[String] = []
	for raw_candidate in [
		normalized,
		normalized.replace(" ", ""),
		normalized.replace(" ", "_"),
		normalized.replace("-", "").replace(" ", ""),
		compact_key(normalized),
	]:
		var candidate := String(raw_candidate)
		if not candidate.is_empty() and not candidates.has(candidate):
			candidates.append(candidate)
	for candidate: String in candidates:
		if has_portrait(candidate):
			return candidate
	return ""


static func compact_key(value: String) -> String:
	var regex := RegEx.new()
	if regex.compile("[^a-z0-9]+") != OK:
		return value.to_lower().replace(" ", "").replace("-", "")
	return regex.sub(value.to_lower(), "", true)


static func has_portrait(key: String) -> bool:
	if key.is_empty():
		return false
	return FileAccess.file_exists(metadata_path(key)) and ResourceLoader.exists(strip_path(key))


static func metadata_path(key: String) -> String:
	return "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, key]


static func strip_path(key: String) -> String:
	return "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, key]
