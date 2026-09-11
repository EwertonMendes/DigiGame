extends RefCounted
class_name TargetingSystem

const TargetPatternResolverScript = preload("res://src/battle/combat/TargetPatternResolver.gd")

var _patterns = TargetPatternResolverScript.new()


func distance_between(field: Node, source: Node, target: Node) -> int:
	if field == null or source == null or target == null:
		return 999999
	var source_grid := _grid_for_actor(field, source)
	var target_grid := _grid_for_actor(field, target)
	return absi(source_grid.x - target_grid.x) + absi(source_grid.y - target_grid.y)


func selection_mode(action: Dictionary) -> String:
	return _patterns.selection_mode(action)


func is_valid_target(field: Node, source: Node, target: Node, action: Dictionary) -> bool:
	if source == null or target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_available_for_turn") and not bool(target.call("is_available_for_turn")):
		return false
	if not _patterns.relationship_matches(source, target, action):
		return false
	var source_grid := _grid_for_actor(field, source)
	var target_grid := _grid_for_actor(field, target)
	return _patterns.is_valid_aim_grid(field, source_grid, action, target_grid)


func is_valid_aim_grid(field: Node, source: Node, action: Dictionary, aim_grid: Vector2i) -> bool:
	if field == null or source == null:
		return false
	return _patterns.is_valid_aim_grid(field, _grid_for_actor(field, source), action, aim_grid)


func valid_targets(field: Node, source: Node, actors: Array[Node], action: Dictionary) -> Array[Node]:
	var result: Array[Node] = []
	for actor: Node in actors:
		if is_valid_target(field, source, actor, action):
			result.append(actor)
	return result


func valid_targets_for_aim(field: Node, source: Node, actors: Array[Node], action: Dictionary, aim_grid: Vector2i) -> Array[Node]:
	var result: Array[Node] = []
	if field == null or source == null:
		return result
	var effect := effect_grids(field, source, action, aim_grid)
	for actor: Node in actors:
		if actor == null or not is_instance_valid(actor):
			continue
		if actor.has_method("is_available_for_turn") and not bool(actor.call("is_available_for_turn")):
			continue
		if not _patterns.relationship_matches(source, actor, action):
			continue
		if effect.has(_grid_for_actor(field, actor)):
			result.append(actor)
	return result


func grids_in_range(field: Node, source: Node, action: Dictionary) -> Array[Vector2i]:
	if field == null or source == null:
		return []
	return _patterns.cast_grids(field, _grid_for_actor(field, source), action)


func effect_grids(field: Node, source: Node, action: Dictionary, aim_grid: Vector2i) -> Array[Vector2i]:
	if field == null or source == null:
		return []
	return _patterns.effect_grids(field, _grid_for_actor(field, source), aim_grid, action)


func _grid_for_actor(field: Node, actor: Node) -> Vector2i:
	if actor == null or field == null or not actor.has_method("get_tile_world_position"):
		return Vector2i.ZERO
	var world_position := Vector2(actor.call("get_tile_world_position"))
	return Vector2i(field.call("world_to_grid", field.to_local(world_position)))
