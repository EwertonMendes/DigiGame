extends RefCounted

## Reassembles the compact music payload from text-safe chunks committed through
## the repository API. Keeping the source payload as Base64 GDScript resources
## avoids binary transport corruption while remaining fully offline in Web builds.

const TRACK_ZONE_1 := "zone_1"
const TRACK_BATTLE_1 := "battle_1"

const TRACKS := {
	TRACK_ZONE_1: {
		"prefix": "zone",
		"chunks": 15,
		"sha256": "83420c41e1e649cb4ee6f1d9925c47418015bae9214124566029d28fff035fff",
	},
	TRACK_BATTLE_1: {
		"prefix": "battle",
		"chunks": 18,
		"sha256": "295aeb84616196acb93698069d981836169eb1ad2c9ca2a203e337ac2e854041",
	},
}

const CHUNK_PATH := "res://src/audio/embedded/%s_%02d.gd"


static func build_stream(track_id: String) -> AudioStreamMP3:
	if not TRACKS.has(track_id):
		push_error("[Music] Unknown embedded track: %s" % track_id)
		return null
	var definition: Dictionary = TRACKS[track_id]
	var encoded := ""
	var prefix := str(definition.get("prefix", ""))
	var chunk_count := int(definition.get("chunks", 0))
	for index in range(chunk_count):
		var path := CHUNK_PATH % [prefix, index]
		var script := load(path) as Script
		if script == null:
			push_error("[Music] Missing embedded music chunk: %s" % path)
			return null
		var chunk_instance = script.new()
		var data = chunk_instance.get("DATA")
		if data == null or str(data).is_empty():
			push_error("[Music] Empty embedded music chunk: %s" % path)
			return null
		encoded += str(data)

	var raw := Marshalls.base64_to_raw(encoded)
	if raw.is_empty():
		push_error("[Music] Embedded track decoded to no data: %s" % track_id)
		return null
	var stream := AudioStreamMP3.load_from_buffer(raw)
	if stream == null:
		push_error("[Music] Embedded MP3 could not be decoded: %s" % track_id)
		return null
	stream.loop = true
	return stream
