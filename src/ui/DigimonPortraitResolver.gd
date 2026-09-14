extends RefCounted
class_name DigimonPortraitResolver

const PORTRAIT_ROOT := "res://assets/characters"


static func resolve_key(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized.is_empty():
		return ""
	var candidates: Array[String] = []
	for raw_candidate in [
		normalized,
		normalized.replace(" ", ""),
		normalized.replace(" ", "_"),
		normalized.replace("-", "").replace(" ", ""),
		_compact_key(normalized),
	]:
		var candidate := String(raw_candidate)
		if not candidate.is_empty() and not candidates.has(candidate):
			candidates.append(candidate)
	for candidate: String in candidates:
		var metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, candidate]
		var strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, candidate]
		if FileAccess.file_exists(metadata_path) and ResourceLoader.exists(strip_path):
			return candidate
	return ""


static func metadata_path(value: String) -> String:
	var key := resolve_key(value)
	return "" if key.is_empty() else "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, key]


static func strip_path(value: String) -> String:
	var key := resolve_key(value)
	return "" if key.is_empty() else "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, key]


static func _compact_key(value: String) -> String:
	var regex := RegEx.new()
	if regex.compile("[^a-z0-9]+") != OK:
		return value.replace(" ", "").replace("-", "")
	return regex.sub(value.to_lower(), "", true)
