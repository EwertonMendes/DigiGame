extends RefCounted
class_name TargetingSystem


func distance_between(field: Node, source: Node, target: Node) -> int:
	if field == null or source == null or target == null:
		return 999999
	var source_grid := _grid_for_actor(field, source)
	var target_grid := _grid_for_actor(field, target)
	return absi(source_grid.x - target_grid.x) + absi(source_grid.y - target_grid.y)


func is_valid_target(field: Node, source: Node, target: Node, action: Dictionary) -> bool:
	if source == null or target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_available_for_turn") and not bool(target.call("is_available_for_turn")):
		return false
	var targets = action.get("targets", ["enemy"])
	if not targets is Array:
		return false
	var source_player := bool(source.get("is_player_controlled"))
	var target_player := bool(target.get("is_player_controlled"))
	var relationship := "self" if source == target else ("ally" if source_player == target_player else "enemy")
	if not targets.has(relationship):
		return false
	var range_data = action.get("range", {})
	if not range_data is Dictionary:
		return source == target
	var min_range := maxi(0, int(range_data.get("min", 0)))
	var max_range := maxi(min_range, int(range_data.get("max", min_range)))
	var distance := distance_between(field, source, target)
	return distance >= min_range and distance <= max_range


func valid_targets(field: Node, source: Node, actors: Array[Node], action: Dictionary) -> Array[Node]:
	var result: Array[Node] = []
	for actor: Node in actors:
		if is_valid_target(field, source, actor, action):
			result.append(actor)
	return result


func grids_in_range(field: Node, source: Node, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if field == null or source == null:
		return result
	var range_data = action.get("range", {})
	if not range_data is Dictionary:
		return result
	var min_range := maxi(0, int(range_data.get("min", 0)))
	var max_range := maxi(min_range, int(range_data.get("max", min_range)))
	var origin := _grid_for_actor(field, source)
	for x in range(origin.x - max_range, origin.x + max_range + 1):
		for y in range(origin.y - max_range, origin.y + max_range + 1):
			var grid := Vector2i(x, y)
			var distance := absi(grid.x - origin.x) + absi(grid.y - origin.y)
			if distance < min_range or distance > max_range:
				continue
			if field.has_method("get_static_tile_block_reason") and String(field.call("get_static_tile_block_reason", grid)) == "out_of_bounds":
				continue
			result.append(grid)
	return result


func _grid_for_actor(field: Node, actor: Node) -> Vector2i:
	if actor == null or field == null or not actor.has_method("get_tile_world_position"):
		return Vector2i.ZERO
	var world_position := Vector2(actor.call("get_tile_world_position"))
	return Vector2i(field.call("world_to_grid", field.to_local(world_position)))
