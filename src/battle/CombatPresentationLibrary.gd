extends Node
class_name CombatPresentationLibrary

const VFX_LIBRARY_PATH := "res://database/vfx-library.json"
const PRESENTATIONS_PATH := "res://database/combat-presentations.json"
const DEFAULT_Z_INDEX := 101
const PROJECTILE_Z_INDEX := 102

var _effects: Dictionary = {}
var _presentations: Dictionary = {}
var _atlas_cache: Dictionary = {}
var _audio_cache: Dictionary = {}
var _loaded := false


func load_default() -> bool:
	_effects.clear()
	_presentations.clear()
	_atlas_cache.clear()
	_audio_cache.clear()
	_loaded = _load_json_databases()
	return _loaded


func is_loaded() -> bool:
	return _loaded


func get_presentation(action_id: String, element: String) -> Dictionary:
	if not _loaded:
		return {}
	var actions = _presentations.get("actions", {})
	if actions is Dictionary and actions.has(action_id):
		var explicit = actions[action_id]
		if explicit is Dictionary:
			return (explicit as Dictionary).duplicate(true)
	var fallbacks = _presentations.get("elementFallbacks", {})
	var element_key := element.to_lower().strip_edges()
	if fallbacks is Dictionary and fallbacks.has(element_key):
		var fallback = fallbacks[element_key]
		if fallback is Dictionary:
			return (fallback as Dictionary).duplicate(true)
	if fallbacks is Dictionary and fallbacks.has("neutral"):
		var neutral = fallbacks["neutral"]
		if neutral is Dictionary:
			return (neutral as Dictionary).duplicate(true)
	return {}


func resolve_on(presentation: Dictionary) -> String:
	return String(presentation.get("resolveOn", "damage"))


func play_phase(
	phase: String,
	presentation: Dictionary,
	attacker: Node,
	target: Node,
	element_color: Color,
	travel_time: float = 0.0
) -> int:
	if not _loaded or presentation.is_empty():
		return 0
	var raw_specs = presentation.get(phase, [])
	if not raw_specs is Array:
		return 0
	var played := 0
	for raw_spec in raw_specs:
		if not raw_spec is Dictionary:
			continue
		var spec: Dictionary = raw_spec
		var delay: float = maxf(0.0, float(spec.get("delay", 0.0)))
		if delay > 0.001:
			var callback := Callable(self, "_play_spec").bind(
				phase,
				spec.duplicate(true),
				attacker,
				target,
				element_color,
				travel_time
			)
			get_tree().create_timer(delay).timeout.connect(callback, CONNECT_ONE_SHOT)
		else:
			_play_spec(phase, spec, attacker, target, element_color, travel_time)
		played += 1
	return played


func play_audio_phase(presentation: Dictionary, phase: String, default_to_technique: bool = true) -> bool:
	if not _loaded:
		return false
	var profile_name := String(presentation.get("audioProfile", ""))
	if profile_name.is_empty() and default_to_technique:
		profile_name = String(_presentations.get("defaultTechniqueAudioProfile", "technique"))
	var profiles = _presentations.get("audioProfiles", {})
	if not profiles is Dictionary or not profiles.has(profile_name):
		return false
	var profile = profiles[profile_name]
	if not profile is Dictionary:
		return false
	var path := String((profile as Dictionary).get(phase, ""))
	if path.is_empty():
		return false
	var stream: AudioStream = _load_audio(path)
	if stream == null:
		push_error("[CombatPresentation] missing audio cue: %s" % path)
		return false
	var player := AudioStreamPlayer.new()
	player.name = "CombatPresentationAudio"
	player.stream = stream
	player.volume_db = float(presentation.get("volumeDb", -1.5))
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()
	return true


func _load_json_databases() -> bool:
	if not FileAccess.file_exists(VFX_LIBRARY_PATH):
		push_error("Missing combat VFX library: %s" % VFX_LIBRARY_PATH)
		return false
	if not FileAccess.file_exists(PRESENTATIONS_PATH):
		push_error("Missing combat presentation database: %s" % PRESENTATIONS_PATH)
		return false
	var vfx_raw = JSON.parse_string(FileAccess.get_file_as_string(VFX_LIBRARY_PATH))
	var presentations_raw = JSON.parse_string(FileAccess.get_file_as_string(PRESENTATIONS_PATH))
	if not vfx_raw is Dictionary or not presentations_raw is Dictionary:
		push_error("Combat presentation databases must be JSON objects")
		return false
	var vfx_effects = (vfx_raw as Dictionary).get("effects", {})
	if not vfx_effects is Dictionary or (vfx_effects as Dictionary).is_empty():
		push_error("Combat VFX library contains no effects")
		return false
	_effects = (vfx_effects as Dictionary).duplicate(true)
	_presentations = (presentations_raw as Dictionary).duplicate(true)
	return true


func _play_spec(
	phase: String,
	spec: Dictionary,
	attacker: Node,
	target: Node,
	element_color: Color,
	travel_time: float
) -> void:
	var effect_id := String(spec.get("effect", ""))
	if effect_id.is_empty() or not _effects.has(effect_id):
		push_error("[CombatPresentation] unknown effect: %s" % effect_id)
		return
	var definition = _effects[effect_id]
	if not definition is Dictionary:
		return
	var anchor := String(spec.get("anchor", "attacker" if phase == "start" else "target"))
	var start := _anchor_position(anchor, attacker, target)
	var offset_raw = spec.get("offset", [0.0, 0.0])
	if offset_raw is Array and offset_raw.size() >= 2:
		start += Vector2(float(offset_raw[0]), float(offset_raw[1]))
	var scale_value := maxf(0.05, float(spec.get("scale", 1.0)))
	var rotation := deg_to_rad(float(spec.get("rotationDeg", 0.0)))
	var tint := _resolve_tint(String(spec.get("tint", "none")), element_color)
	var fx := _spawn_effect(
		effect_id,
		definition,
		start,
		scale_value,
		rotation,
		tint,
		PROJECTILE_Z_INDEX if phase == "projectile" else DEFAULT_Z_INDEX
	)
	if fx == null:
		return
	if phase == "projectile" and attacker != null and target != null:
		var finish := _anchor_position("target", attacker, target)
		var move_time := maxf(0.08, travel_time)
		var move_tween := fx.create_tween()
		move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		move_tween.tween_property(fx, "global_position", finish, move_time)


func _spawn_effect(
	effect_id: String,
	definition: Dictionary,
	world_position: Vector2,
	scale_value: float,
	rotation_value: float,
	tint: Color,
	z_index: int
) -> Node2D:
	var frames = definition.get("frames", [])
	if not frames is Array or frames.is_empty():
		return null
	var atlas_path := String(definition.get("atlas", ""))
	var atlas := _load_atlas(atlas_path)
	if atlas == null:
		push_error("[CombatPresentation] missing atlas: %s" % atlas_path)
		return null
	var holder := Node2D.new()
	holder.name = "TechniqueVFX_%s" % effect_id.replace("/", "_")
	holder.global_position = world_position
	holder.rotation = rotation_value
	holder.scale = Vector2.ONE * scale_value
	holder.z_index = z_index
	var parent_node := get_parent()
	if parent_node == null:
		return null
	parent_node.add_child(holder)
	var sprite := Sprite2D.new()
	sprite.name = "Frame"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = tint
	holder.add_child(sprite)
	var tween := holder.create_tween()
	var fps := maxf(1.0, float(definition.get("fps", 12.0)))
	for index in range(frames.size()):
		var frame = frames[index]
		if not frame is Dictionary:
			continue
		tween.tween_callback(Callable(self, "_apply_frame").bind(sprite, atlas, frame))
		var duration := 1.0 / fps
		if (frame as Dictionary).has("duration_ms"):
			duration = maxf(0.01, float((frame as Dictionary).get("duration_ms", 1000.0 / fps)) / 1000.0)
		tween.tween_interval(duration)
	tween.tween_callback(holder.queue_free)
	return holder


func _apply_frame(sprite: Sprite2D, atlas: Texture2D, frame: Dictionary) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var region_raw = frame.get("region", [])
	if not region_raw is Array or region_raw.size() < 4:
		return
	var region := Rect2(
		float(region_raw[0]),
		float(region_raw[1]),
		float(region_raw[2]),
		float(region_raw[3])
	)
	var frame_texture := AtlasTexture.new()
	frame_texture.atlas = atlas
	frame_texture.region = region
	frame_texture.filter_clip = true
	sprite.texture = frame_texture
	sprite.offset = Vector2.ZERO
	var pivot_raw = frame.get("pivot", [])
	if pivot_raw is Array and pivot_raw.size() >= 2:
		var pivot := Vector2(float(pivot_raw[0]), float(pivot_raw[1]))
		sprite.offset = region.size * 0.5 - pivot


func _anchor_position(anchor: String, attacker: Node, target: Node) -> Vector2:
	var attacker_position := _node_anchor(attacker)
	var target_position := _node_anchor(target)
	match anchor:
		"attacker": return attacker_position
		"target": return target_position
		"midpoint": return attacker_position.lerp(target_position, 0.5)
	return target_position


func _node_anchor(node: Node) -> Vector2:
	if node != null and node.has_method("get_combat_fx_anchor_world"):
		return Vector2(node.call("get_combat_fx_anchor_world"))
	if node is Node2D:
		return (node as Node2D).global_position + Vector2(0.0, -28.0)
	return Vector2.ZERO


func _resolve_tint(mode: String, element_color: Color) -> Color:
	match mode:
		"element": return Color(element_color.r, element_color.g, element_color.b, 1.0)
		"white": return Color.WHITE
	return Color.WHITE


func _load_atlas(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _atlas_cache.has(path):
		return _atlas_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture != null:
		_atlas_cache[path] = texture
	return texture


func _load_audio(path: String) -> AudioStream:
	if _audio_cache.has(path):
		return _audio_cache[path] as AudioStream
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		_audio_cache[path] = stream
	return stream
