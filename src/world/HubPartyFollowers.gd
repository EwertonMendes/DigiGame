extends Node2D
class_name HubPartyFollowers

const FOLLOWER_SCRIPT = preload("res://src/world/OverworldDigimonFollower.gd")
const DIGIMON_RESOURCE_TEMPLATE := "res://assets/resources/%s.tres"
const FOLLOW_SPACING := 56.0
const MIN_TEAM_SEPARATION := 40.0
const PATH_SAMPLE_DISTANCE := 5.0
const TELEPORT_RESET_DISTANCE := 180.0
const MAX_TRAIL_POINTS := 256
const MAX_BIND_ATTEMPTS := 12
const SPAWN_ANGLE_OFFSETS := [0.0, 0.78539816, -0.78539816, 1.57079633, -1.57079633, 2.35619449, -2.35619449, 3.14159265]
const HUB_FACING_VECTORS := {
	"east": Vector2.RIGHT,
	"southeast": Vector2(0.70710678, 0.70710678),
	"south": Vector2.DOWN,
	"southwest": Vector2(-0.70710678, 0.70710678),
	"west": Vector2.LEFT,
	"northwest": Vector2(-0.70710678, -0.70710678),
	"north": Vector2.UP,
	"northeast": Vector2(0.70710678, -0.70710678),
}

var _hub: Node = null
var _player: Node2D = null
var _followers_root: Node2D = null
var _followers: Array[Node2D] = []
var _active_party_keys: Array[String] = []
var _trail: Array[Vector2] = []
var _bound := false
var _bind_attempts := 0


func _ready() -> void:
	_followers_root = Node2D.new()
	_followers_root.name = "Followers"
	add_child(_followers_root)

	var party_changed := Callable(self, "_on_active_party_changed")
	if not OverworldState.active_party_changed.is_connected(party_changed):
		OverworldState.active_party_changed.connect(party_changed)
	call_deferred("_bind_to_hub")


func _exit_tree() -> void:
	var party_changed := Callable(self, "_on_active_party_changed")
	if OverworldState.active_party_changed.is_connected(party_changed):
		OverworldState.active_party_changed.disconnect(party_changed)
	if _player != null:
		var moved := Callable(self, "_on_player_world_position_changed")
		if _player.is_connected("world_position_changed", moved):
			_player.disconnect("world_position_changed", moved)


func _physics_process(delta: float) -> void:
	if not _bound or _player == null:
		return
	_record_player_position(_player.global_position)
	_update_followers(delta)


func get_follower_count() -> int:
	return _followers.size()


func get_active_party_keys() -> Array[String]:
	return _active_party_keys.duplicate()


func get_follow_spacing() -> float:
	return FOLLOW_SPACING


func get_minimum_team_separation() -> float:
	return MIN_TEAM_SEPARATION


func _bind_to_hub() -> void:
	if _bound:
		return
	_hub = get_parent()
	if _hub == null:
		return
	_player = _hub.get_node_or_null("Actors/Player") as Node2D
	if _player == null:
		_bind_attempts += 1
		if _bind_attempts < MAX_BIND_ATTEMPTS:
			call_deferred("_bind_to_hub")
		else:
			push_warning("HubPartyFollowers could not find Actors/Player")
		return

	_bound = true
	var moved := Callable(self, "_on_player_world_position_changed")
	if _player.has_signal("world_position_changed") and not _player.is_connected("world_position_changed", moved):
		_player.connect("world_position_changed", moved)
	_trail.clear()
	_trail.append(_player.global_position)
	_sync_party()


func _on_active_party_changed(_party: Array) -> void:
	if _bound:
		_sync_party()


func _on_player_world_position_changed(_world_position: Vector2) -> void:
	if _player != null:
		_record_player_position(_player.global_position)


func _sync_party() -> void:
	for follower in _followers:
		follower.visible = false
		follower.queue_free()
	_followers.clear()
	_active_party_keys.clear()

	var party := OverworldState.get_active_party()
	var occupied: Array[Vector2] = []
	if _player != null:
		occupied.append(_player.global_position)

	for party_slot in range(party.size()):
		var key := String(party[party_slot])
		var resource_path := DIGIMON_RESOURCE_TEMPLATE % key
		if not ResourceLoader.exists(resource_path):
			push_warning("Active party Digimon resource is missing: %s" % resource_path)
			continue
		var digimon := load(resource_path) as Digimon
		if digimon == null:
			push_warning("Active party resource is not a Digimon: %s" % resource_path)
			continue

		var follower := FOLLOWER_SCRIPT.new() as Node2D
		follower.call("configure", digimon, key, party_slot)
		_followers_root.add_child(follower)
		var spawn_position := _find_safe_spawn_position(party_slot, occupied)
		follower.call("teleport_to", spawn_position, _initial_digimon_facing())
		_followers.append(follower)
		_active_party_keys.append(key)
		occupied.append(spawn_position)


func _update_followers(delta: float) -> void:
	var occupied: Array[Vector2] = [_player.global_position]
	for index in range(_followers.size()):
		var follower := _followers[index]
		if not is_instance_valid(follower):
			continue
		var desired_distance := FOLLOW_SPACING * float(index + 1)
		var trail_target := _trail_target_at_distance(desired_distance)
		if bool(trail_target.get("valid", false)):
			var target_position := Vector2(trail_target.get("position", follower.global_position))
			follower.call("step_toward", target_position, delta, occupied)
		else:
			follower.call("set_idle")
		occupied.append(follower.global_position)


func _record_player_position(world_position: Vector2) -> void:
	if _trail.is_empty():
		_trail.append(world_position)
		return

	var previous := _trail[_trail.size() - 1]
	var distance := previous.distance_to(world_position)
	if distance > TELEPORT_RESET_DISTANCE:
		_trail.clear()
		_trail.append(world_position)
		_reposition_followers_around_player()
		return
	if distance < PATH_SAMPLE_DISTANCE:
		return

	_trail.append(world_position)
	while _trail.size() > MAX_TRAIL_POINTS:
		_trail.remove_at(0)


func _trail_target_at_distance(distance_behind: float) -> Dictionary:
	if _trail.size() < 2:
		return {"valid": false}

	var remaining := distance_behind
	for index in range(_trail.size() - 1, 0, -1):
		var newer := _trail[index]
		var older := _trail[index - 1]
		var segment_length := newer.distance_to(older)
		if segment_length <= 0.001:
			continue
		if remaining <= segment_length:
			return {
				"valid": true,
				"position": newer.lerp(older, remaining / segment_length),
			}
		remaining -= segment_length

	return {"valid": false}


func _reposition_followers_around_player() -> void:
	if _player == null:
		return
	var occupied: Array[Vector2] = [_player.global_position]
	for index in range(_followers.size()):
		var follower := _followers[index]
		if not is_instance_valid(follower):
			continue
		var spawn_position := _find_safe_spawn_position(index, occupied)
		follower.call("teleport_to", spawn_position, _initial_digimon_facing())
		occupied.append(spawn_position)


func _find_safe_spawn_position(party_slot: int, occupied: Array[Vector2]) -> Vector2:
	if _player == null:
		return Vector2.ZERO

	var player_facing := String(_player.get("facing_direction"))
	var facing_vector := Vector2(HUB_FACING_VECTORS.get(player_facing, Vector2.UP)).normalized()
	var behind := -facing_vector
	var base_radius := FOLLOW_SPACING * float(party_slot + 1)

	for ring_offset in range(3):
		var radius := base_radius + FOLLOW_SPACING * float(ring_offset)
		for angle_offset in SPAWN_ANGLE_OFFSETS:
			var candidate := _player.global_position + behind.rotated(float(angle_offset)) * radius
			if _is_walkable(candidate) and _has_clearance(candidate, occupied):
				return candidate

	# Extremely defensive fallback: keep visual separation even if the hub's
	# walkability query cannot find a free ring around a future spawn point.
	return _player.global_position + Vector2(0.0, FOLLOW_SPACING * float(party_slot + 1))


func _is_walkable(candidate: Vector2) -> bool:
	if _hub == null or _player == null or not _hub.has_method("can_actor_move_to"):
		return true
	return bool(_hub.call("can_actor_move_to", candidate, _player))


func _has_clearance(candidate: Vector2, occupied: Array[Vector2]) -> bool:
	for point in occupied:
		if candidate.distance_to(point) < MIN_TEAM_SEPARATION:
			return false
	return true


func _initial_digimon_facing() -> String:
	if _player == null:
		return "up_right"
	match String(_player.get("facing_direction")):
		"southwest", "west":
			return "down_left"
		"northwest":
			return "up_left"
		"north", "northeast":
			return "up_right"
		_:
			return "down_right"
