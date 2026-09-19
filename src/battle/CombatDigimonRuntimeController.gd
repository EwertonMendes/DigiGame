extends "res://src/DigimonRuntimeController.gd"

const SPAWN_ZONE_DEPTH := 5
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")
const DeploymentPlanner = preload("res://src/combat/FootprintDeploymentPlanner.gd")
const FootprintMapValidatorScript = preload("res://src/combat/FootprintMapValidator.gd")

var _occupancy_by_grid: Dictionary = {}
var _spawn_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_spawn_rng.randomize()
	super._ready()


func _spawn_demo_rosters() -> void:
	var field := get_node_or_null("../Blocks") as Node2D
	if field == null or not field.has_method("grid_to_world"):
		super._spawn_demo_rosters()
		_prepare_existing_actors_for_intro()
		refresh_occupancy_index()
		orient_battle_actors_toward_opponents()
		return

	var player_entries: Array[Dictionary] = []
	for descriptor in PLAYER_ROSTER:
		var species_name := String(descriptor.get("species", ""))
		var level := int(descriptor.get("level", 1))
		var scan := int(descriptor.get("scan", 100))
		var instance: DigimonInstance = _factory.create_player_by_name(species_name, level, scan)
		player_entries.append({"instance": instance, "profile": ""})

	var enemy_entries: Array[Dictionary] = []
	for descriptor in ENEMY_ENCOUNTER:
		var species_name := String(descriptor.get("species", ""))
		var min_level := int(descriptor.get("level_min", 1))
		var max_level := maxi(min_level, int(descriptor.get("level_max", min_level)))
		var level := _encounter_rng.randi_range(min_level, max_level)
		var profile := String(descriptor.get("profile", "wild")).to_lower()
		var tier := String(descriptor.get("tier", "E"))
		var footprint := String(descriptor.get("footprint", "single"))
		var instance: DigimonInstance = _factory.create_enemy_by_name(species_name, level, profile, tier, footprint)
		enemy_entries.append({"instance": instance, "profile": profile})

	var player_candidates := _spawn_zone_candidates(field, true)
	var enemy_candidates := _spawn_zone_candidates(field, false)
	if not _validate_current_story_layout(field, player_candidates, enemy_candidates):
		return
	var initially_occupied := _current_occupied_grids()
	var player_plan := _plan_team_deployment(player_entries, player_candidates, initially_occupied)
	if not bool(player_plan.get("ok", false)):
		_report_deployment_failure("player", player_plan)
		return

	var player_anchors: Array = player_plan.get("anchors", [])
	var enemy_blocked := initially_occupied.duplicate()
	enemy_blocked.append_array(_planned_occupied_grids(player_entries, player_anchors))
	var enemy_plan := _plan_team_deployment(enemy_entries, enemy_candidates, enemy_blocked)
	if not bool(enemy_plan.get("ok", false)):
		_report_deployment_failure("enemy", enemy_plan)
		return

	# Both teams are fully validated before the first actor is instantiated. This
	# prevents partially-started battles when a later 2x2 footprint cannot fit.
	_spawn_team_from_plan(player_entries, true, player_anchors, field)
	_spawn_team_from_plan(enemy_entries, false, enemy_plan.get("anchors", []), field)
	refresh_occupancy_index()
	orient_battle_actors_toward_opponents()


func _validate_current_story_layout(field: Node2D, player_candidates: Array[Vector2i], objective_cells: Array[Vector2i]) -> bool:
	var raw_map = field.get("tile_map_data")
	if not raw_map is Dictionary:
		push_error("Battle cannot start: field has no authoring map data for footprint validation.")
		return false
	var walkable: Array[Vector2i] = []
	for raw_grid in (raw_map as Dictionary).keys():
		if not raw_grid is Vector2i:
			continue
		var grid := Vector2i(raw_grid)
		if field.has_method("get_static_tile_block_reason") and not String(field.call("get_static_tile_block_reason", grid)).is_empty():
			continue
		walkable.append(grid)

	var footprint_id := FootprintScript.LARGE_2X2
	if field.has_method("get_max_supported_footprint_id"):
		footprint_id = FootprintScript.normalize_id(String(field.call("get_max_supported_footprint_id")))
	var validation := FootprintMapValidatorScript.validate_layout(
		walkable,
		player_candidates,
		objective_cells,
		footprint_id,
		3
	)
	if bool(validation.get("ok", false)):
		return true
	var errors = validation.get("errors", [])
	var detail := "; ".join(PackedStringArray(errors)) if errors is Array else "unknown footprint authoring error"
	push_error(
		"Battle cannot start: map fails %s layout validation. %s"
		% [FootprintScript.display_label(footprint_id), detail]
	)
	return false


func _plan_team_deployment(entries: Array[Dictionary], candidates: Array[Vector2i], blocked_cells: Array[Vector2i]) -> Dictionary:
	var footprints: Array = []
	for entry in entries:
		var instance := entry.get("instance") as DigimonInstance
		if instance == null:
			return {"ok": false, "anchors": [], "reason": "Encounter contains an invalid Digimon instance."}
		footprints.append(instance.battle_footprint_id)
	return DeploymentPlanner.plan(footprints, candidates, blocked_cells, _spawn_rng)


func _spawn_team_from_plan(entries: Array[Dictionary], player_controlled: bool, anchors: Array, field: Node2D) -> void:
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var instance := entry.get("instance") as DigimonInstance
		var anchor := Vector2i(anchors[index])
		var actor := _spawn_instance_at_anchor(instance, player_controlled, anchor, field)
		if actor != null:
			var profile := String(entry.get("profile", ""))
			if not profile.is_empty():
				actor.set_meta("encounter_profile", profile)
			if entry.has("reward_modifier"):
				actor.set_meta("reward_modifier", maxf(0.0, float(entry.get("reward_modifier", 1.0))))
		_prepare_actor_for_intro(actor, field)


func _spawn_instance_at_anchor(instance: DigimonInstance, player_controlled: bool, anchor: Vector2i, field: Node2D) -> CharacterBody2D:
	if instance == null:
		return null
	var initial_world := Vector2i(field.call("grid_to_world", anchor))
	print("[BattleSpawn] team=%s grid=%s footprint=%s tier=%s" % ["player" if player_controlled else "enemy", anchor, instance.battle_footprint_id, instance.tier])
	return _instantiate_actor(instance, player_controlled, initial_world)


func _planned_occupied_grids(entries: Array[Dictionary], anchors: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in range(mini(entries.size(), anchors.size())):
		var instance := entries[index].get("instance") as DigimonInstance
		if instance == null:
			continue
		result.append_array(FootprintScript.occupied_grids(Vector2i(anchors[index]), instance.battle_footprint_id))
	return result


func _current_occupied_grids() -> Array[Vector2i]:
	refresh_occupancy_index()
	var result: Array[Vector2i] = []
	for key in _occupancy_by_grid.keys():
		if key is Vector2i:
			result.append(Vector2i(key))
	return result


func _report_deployment_failure(team_name: String, plan: Dictionary) -> void:
	var reason := String(plan.get("reason", "Deployment zone cannot fit the requested footprints."))
	push_error("Battle cannot start: %s team deployment is invalid. %s" % [team_name, reason])


func _spawn_zone_candidates(field: Node2D, player_side: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	# Authored BattlefieldDefinition zones are the primary source of truth.
	# The legacy band fallback remains only for isolated/custom fields that have
	# not migrated to the catalog yet.
	if field.has_method("get_deployment_cells"):
		var authored = field.call("get_deployment_cells", player_side)
		if authored is Array:
			for raw_grid in authored:
				if not raw_grid is Vector2i:
					continue
				var grid := Vector2i(raw_grid)
				if field.has_method("get_static_tile_block_reason") and not String(field.call("get_static_tile_block_reason", grid)).is_empty():
					continue
				result.append(grid)
			if not result.is_empty():
				return result

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

	var threshold_min := max_y - SPAWN_ZONE_DEPTH + 1 if player_side else min_y
	var threshold_max := max_y if player_side else min_y + SPAWN_ZONE_DEPTH - 1
	for key in map_data.keys():
		if not key is Vector2i:
			continue
		var grid := Vector2i(key)
		if grid.y < threshold_min or grid.y > threshold_max:
			continue
		if field.has_method("get_static_tile_block_reason") and not String(field.call("get_static_tile_block_reason", grid)).is_empty():
			continue
		result.append(grid)
	return result


func _prepare_actor_for_intro(actor: CharacterBody2D, field: Node2D) -> void:
	if actor == null:
		return
	if actor.has_method("face_toward_world_position"):
		actor.call("face_toward_world_position", field.to_global(Vector2.ZERO))
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
	if actor == null or not is_instance_valid(actor) or not actor is Node2D or not actor.has_method("face_toward_world_position"):
		return
	var actor_team := bool(actor.get("is_player_controlled"))
	var actor_cells := _actor_cells(actor)
	var nearest: Node2D = null
	var nearest_distance := 999999
	for candidate: Node in get_battle_digimons():
		if candidate == actor or not candidate is Node2D:
			continue
		if bool(candidate.get("is_player_controlled")) == actor_team:
			continue
		if candidate.has_method("is_available_for_turn") and not bool(candidate.call("is_available_for_turn")):
			continue
		var distance := FootprintScript.minimum_distance(actor_cells, _actor_cells(candidate))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate as Node2D
	if nearest != null:
		var target_world := nearest.global_position
		if nearest.has_method("get_footprint_center_world"):
			target_world = Vector2(nearest.call("get_footprint_center_world"))
		actor.call("face_toward_world_position", target_world)
		return
	var field := get_node_or_null("../Blocks") as Node2D
	if field != null:
		actor.call("face_toward_world_position", field.to_global(Vector2.ZERO))


func get_digimon_at_tile(tile_world_position: Vector2, ignored_digimon: Node = null) -> Node:
	var field := get_node_or_null("../Blocks") as Node2D
	if field == null or not field.has_method("world_to_grid"):
		return null
	var grid := Vector2i(field.call("world_to_grid", field.to_local(tile_world_position)))
	return get_digimon_at_grid(grid, ignored_digimon)


func get_digimon_at_grid(grid: Vector2i, ignored_digimon: Node = null) -> Node:
	var actor = _occupancy_by_grid.get(grid)
	if actor == ignored_digimon:
		return null
	if actor is Node and is_instance_valid(actor):
		if not actor.has_method("is_available_for_turn") or bool(actor.call("is_available_for_turn")):
			return actor as Node
	return null


func refresh_occupancy_index() -> void:
	_occupancy_by_grid.clear()
	var field := get_node_or_null("../Blocks") as Node2D
	for actor: Node in get_battle_digimons():
		if bool(actor.get_meta("battle_switching_out", false)):
			continue
		if actor.has_method("is_available_for_turn") and not bool(actor.call("is_available_for_turn")):
			continue
		var cells := _actor_cells(actor)
		_update_actor_front_depth(actor, cells)
		_update_actor_terrain_context(actor, cells, field)
		for grid: Vector2i in cells:
			_occupancy_by_grid[grid] = actor


func _actor_cells(actor: Node) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if actor == null or not actor.has_method("get_occupied_grids"):
		return result
	var raw_cells = actor.call("get_occupied_grids")
	if not raw_cells is Array:
		return result
	for raw_cell in raw_cells:
		if raw_cell is Vector2i:
			result.append(Vector2i(raw_cell))
	return result


func _update_actor_front_depth(actor: Node, cells: Array[Vector2i]) -> void:
	if not actor is CanvasItem or cells.is_empty():
		return
	(actor as CanvasItem).z_index = FootprintScript.isometric_front_depth(cells)


func _update_actor_terrain_context(actor: Node, cells: Array[Vector2i], field: Node2D) -> void:
	if actor == null or field == null or cells.is_empty():
		return
	var raw_map = field.get("tile_map_data")
	if not raw_map is Dictionary:
		return
	var map_data := raw_map as Dictionary
	var defense_modifier := INF
	var hazards: Array[String] = []
	var min_height := INF
	var max_height := -INF
	var all_supported := true
	for grid: Vector2i in cells:
		if not map_data.has(grid) or not map_data[grid] is Dictionary:
			all_supported = false
			continue
		var tile := map_data[grid] as Dictionary
		defense_modifier = minf(defense_modifier, float(tile.get("defense_modifier", 0.0)))
		var height := float(tile.get("height", 0.0))
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)
		var hazard_id := String(tile.get("hazard_id", "")).strip_edges()
		if not hazard_id.is_empty() and not hazards.has(hazard_id):
			hazards.append(hazard_id)
		var raw_hazards = tile.get("hazards", [])
		if raw_hazards is Array:
			for raw_hazard in raw_hazards:
				var id := String(raw_hazard).strip_edges()
				if not id.is_empty() and not hazards.has(id):
					hazards.append(id)
	actor.set_meta("terrain_defense_modifier", 0.0 if is_inf(defense_modifier) else defense_modifier)
	actor.set_meta("terrain_hazard_ids", hazards)
	actor.set_meta("terrain_height_min", 0.0 if is_inf(min_height) else min_height)
	actor.set_meta("terrain_height_max", 0.0 if is_inf(max_height) else max_height)
	actor.set_meta("terrain_height_supported", all_supported)


func is_tile_occupied(tile_world_position: Vector2, ignored_digimon: Node = null) -> bool:
	return get_digimon_at_tile(tile_world_position, ignored_digimon) != null


func get_digimon_under_pointer(world_position: Vector2) -> Node:
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
