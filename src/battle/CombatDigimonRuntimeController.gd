extends "res://src/DigimonRuntimeController.gd"

const SPAWN_ZONE_DEPTH := 5

var _spawn_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_spawn_rng.randomize()
	super._ready()


func _spawn_demo_rosters() -> void:
	var field := get_node_or_null("../Blocks") as Node2D
	if field == null or not field.has_method("grid_to_world"):
		super._spawn_demo_rosters()
		_prepare_existing_actors_for_intro()
		orient_battle_actors_toward_opponents()
		return

	var player_candidates := _spawn_zone_candidates(field, true)
	var enemy_candidates := _spawn_zone_candidates(field, false)
	_shuffle_grids(player_candidates)
	_shuffle_grids(enemy_candidates)

	for descriptor in PLAYER_ROSTER:
		var species_name := String(descriptor.get("species", ""))
		var level := int(descriptor.get("level", 1))
		var scan := int(descriptor.get("scan", 100))
		var instance: DigimonInstance = _factory.create_player_by_name(species_name, level, scan)
		var actor := _spawn_instance_in_zone(instance, true, player_candidates, field)
		_prepare_actor_for_intro(actor, field)

	for descriptor in ENEMY_ENCOUNTER:
		var species_name := String(descriptor.get("species", ""))
		var min_level := int(descriptor.get("level_min", 1))
		var max_level := maxi(min_level, int(descriptor.get("level_max", min_level)))
		var level := _encounter_rng.randi_range(min_level, max_level)
		var profile := String(descriptor.get("profile", "wild"))
		var instance: DigimonInstance = _factory.create_enemy_by_name(species_name, level, profile)
		var actor := _spawn_instance_in_zone(instance, false, enemy_candidates, field)
		_prepare_actor_for_intro(actor, field)

	# Initial facing is only authoritative after both teams have been created.
	# Face each actor toward a real opponent rather than a fixed screen direction.
	orient_battle_actors_toward_opponents()


func _spawn_instance_in_zone(instance: DigimonInstance, player_controlled: bool, candidates: Array[Vector2i], field: Node2D) -> CharacterBody2D:
	if instance == null:
		return null
	var initial_world := Vector2i.ZERO
	if not candidates.is_empty():
		var grid: Vector2i = candidates.pop_back()
		initial_world = Vector2i(field.call("grid_to_world", grid))
		print("[BattleSpawn] team=%s grid=%s" % ["player" if player_controlled else "enemy", grid])
	return _instantiate_actor(instance, player_controlled, initial_world)


func _spawn_zone_candidates(field: Node2D, player_side: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var map_data_variant = field.get("tile_map_data")
	if not map_data_variant is Dictionary:
		return result
	var map_data: Dictionary = map_data_variant
	if map_data.is_empty():
		return result

	var min_y := 1_000_000
	var max_y := -1_000_000
	for key in map_data.keys():
		if not key is Vector2i:
			continue
		var grid := Vector2i(key)
		min_y = mini(min_y, grid.y)
		max_y = maxi(max_y, grid.y)

	var blocked_variant = field.get("_static_blocked_tiles")
	var blocked: Dictionary = blocked_variant if blocked_variant is Dictionary else {}
	var threshold_min := max_y - SPAWN_ZONE_DEPTH + 1 if player_side else min_y
	var threshold_max := max_y if player_side else min_y + SPAWN_ZONE_DEPTH - 1

	for key in map_data.keys():
		if not key is Vector2i:
			continue
		var grid := Vector2i(key)
		if grid.y < threshold_min or grid.y > threshold_max:
			continue
		if blocked.has(grid):
			continue
		result.append(grid)
	return result


func _shuffle_grids(grids: Array[Vector2i]) -> void:
	for index in range(grids.size() - 1, 0, -1):
		var swap_index := _spawn_rng.randi_range(0, index)
		if swap_index == index:
			continue
		var value := grids[index]
		grids[index] = grids[swap_index]
		grids[swap_index] = value


func _prepare_actor_for_intro(actor: CharacterBody2D, field: Node2D) -> void:
	if actor == null:
		return
	# The normalized Koromon source sheet has the horizontal visual convention
	# opposite to the runtime directional groups. Correct it as actor metadata so
	# logical facing/movement remains identical to every other Digimon.
	actor.set("horizontal_facing_inverted", String(actor.get("digimon_key")) == "koromon")
	# Center-facing is only a temporary fallback while the opposite roster may not
	# exist yet. A second pass below replaces it with nearest-opponent facing.
	if actor.has_method("face_toward_world_position"):
		actor.call("face_toward_world_position", field.to_global(Vector2.ZERO))
	# Only the real battle scene owns the cinematic opening. Isolated controller
	# tests intentionally omit BattleController and need actors at their normal
	# scale/opacity for pointer and overlap regressions.
	if get_node_or_null("../BattleController") != null and actor.has_method("prepare_battle_spawn"):
		actor.call("prepare_battle_spawn")


func _prepare_existing_actors_for_intro() -> void:
	var field := get_node_or_null("../Blocks") as Node2D
	if field == null:
		return
	for actor: Node in get_battle_digimons():
		if actor is CharacterBody2D:
			_prepare_actor_for_intro(actor as CharacterBody2D, field)


func orient_battle_actors_toward_opponents() -> void:
	for actor: Node in get_battle_digimons():
		face_actor_toward_nearest_opponent(actor)


func face_actor_toward_nearest_opponent(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor) or not actor is Node2D:
		return
	if not actor.has_method("face_toward_world_position"):
		return

	var actor_2d := actor as Node2D
	var actor_team := bool(actor.get("is_player_controlled"))
	var nearest: Node2D = null
	var nearest_distance := INF
	for candidate: Node in get_battle_digimons():
		if candidate == actor or not candidate is Node2D:
			continue
		if bool(candidate.get("is_player_controlled")) == actor_team:
			continue
		if candidate.has_method("is_available_for_turn") and not bool(candidate.call("is_available_for_turn")):
			continue
		var candidate_2d := candidate as Node2D
		var distance := actor_2d.global_position.distance_squared_to(candidate_2d.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate_2d

	if nearest != null:
		actor.call("face_toward_world_position", nearest.global_position)
		return

	var field := get_node_or_null("../Blocks") as Node2D
	if field != null:
		actor.call("face_toward_world_position", field.to_global(Vector2.ZERO))


func get_digimon_at_tile(tile_world_position: Vector2, ignored_digimon: Node = null) -> Node:
	for child in get_children():
		if child == ignored_digimon or not child is CharacterBody2D:
			continue
		if child.has_method("is_available_for_turn") and not bool(child.call("is_available_for_turn")):
			continue
		if not child.has_method("get_tile_world_position"):
			continue
		var occupied_position := Vector2(child.call("get_tile_world_position"))
		if occupied_position.distance_squared_to(tile_world_position) < 0.25:
			return child
	return null


func is_tile_occupied(tile_world_position: Vector2, ignored_digimon: Node = null) -> bool:
	return get_digimon_at_tile(tile_world_position, ignored_digimon) != null


func get_digimon_under_pointer(world_position: Vector2) -> Node:
	# Tactical interaction belongs to the occupied grid tile, not to a sprite's
	# rectangular texture bounds. Large sprites (notably Greymon) can overlap the
	# visual area of neighboring units and must never steal hover/target input.
	var field := get_node_or_null("../Blocks") as Node2D
	if field == null or not field.has_method("world_to_grid") or not field.has_method("grid_to_world"):
		return null

	var grid := Vector2i(field.call("world_to_grid", field.to_local(world_position)))
	var map_data: Dictionary = field.get("tile_map_data")
	if not map_data.has(grid):
		return null

	var tile_local_position := Vector2(field.call("grid_to_world", grid))
	var tile_world_position := field.to_global(tile_local_position)
	return get_digimon_at_tile(tile_world_position)
