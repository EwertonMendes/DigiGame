extends RefCounted
class_name TargetingSystem

const TargetPatternResolverScript = preload("res://src/battle/combat/TargetPatternResolver.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

var _patterns = TargetPatternResolverScript.new()


func distance_between(field: Node, source: Node, target: Node) -> int:
	if field == null or source == null or target == null:
		return 999999
	return FootprintScript.minimum_distance(_grids_for_actor(field, source), _grids_for_actor(field, target))


func selection_mode(action: Dictionary) -> String:
	return _patterns.selection_mode(action)


func is_valid_target(field: Node, source: Node, target: Node, action: Dictionary) -> bool:
	if source == null or target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_available_for_turn") and not bool(target.call("is_available_for_turn")) and not _allows_knocked_out_target(action):
		return false
	if not _patterns.relationship_matches(source, target, action):
		return false
	var source_grids := _grids_for_actor(field, source)
	var target_grids := _grids_for_actor(field, target)
	if not _patterns.is_valid_target_footprint(field, source_grids, target_grids, action):
		return false
	return not _requires_line_of_sight(action) or _has_any_line_of_sight(field, source_grids, target_grids)


func is_valid_aim_grid(field: Node, source: Node, action: Dictionary, aim_grid: Vector2i) -> bool:
	if field == null or source == null:
		return false
	var source_grids := _grids_for_actor(field, source)
	if not _patterns.is_valid_aim_grid_for_footprint(field, source_grids, action, aim_grid):
		return false
	var target_grids: Array[Vector2i] = [aim_grid]
	return not _requires_line_of_sight(action) or _has_any_line_of_sight(field, source_grids, target_grids)


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
		if actor.has_method("is_available_for_turn") and not bool(actor.call("is_available_for_turn")) and not _allows_knocked_out_target(action):
			continue
		if not _patterns.relationship_matches(source, actor, action):
			continue
		if FootprintScript.intersects(effect, _grids_for_actor(field, actor)):
			result.append(actor)
	return result


func grids_in_range(field: Node, source: Node, action: Dictionary) -> Array[Vector2i]:
	if field == null or source == null:
		return []
	var grids := _patterns.cast_grids_for_footprint(field, _grids_for_actor(field, source), action)
	if not _requires_line_of_sight(action):
		return grids
	var visible: Array[Vector2i] = []
	for grid: Vector2i in grids:
		var target_grids: Array[Vector2i] = [grid]
		if _has_any_line_of_sight(field, _grids_for_actor(field, source), target_grids):
			visible.append(grid)
	return visible


func effect_grids(field: Node, source: Node, action: Dictionary, aim_grid: Vector2i) -> Array[Vector2i]:
	if field == null or source == null:
		return []
	return _patterns.effect_grids_for_footprint(field, _grids_for_actor(field, source), aim_grid, action)


func _grid_for_actor(field: Node, actor: Node) -> Vector2i:
	if actor != null and actor.has_method("get_grid_anchor"):
		return Vector2i(actor.call("get_grid_anchor"))
	if actor == null or field == null or not actor.has_method("get_tile_world_position"):
		return Vector2i.ZERO
	var world_position := Vector2(actor.call("get_tile_world_position"))
	return Vector2i(field.call("world_to_grid", field.to_local(world_position)))


func _grids_for_actor(field: Node, actor: Node) -> Array[Vector2i]:
	if actor != null and actor.has_method("get_occupied_grids"):
		return actor.call("get_occupied_grids")
	var result: Array[Vector2i] = []
	result.append(_grid_for_actor(field, actor))
	return result


func _requires_line_of_sight(action: Dictionary) -> bool:
	return bool(action.get("requiresLineOfSight", action.get("requires_line_of_sight", false)))


func _has_any_line_of_sight(field: Node, source_grids: Array[Vector2i], target_grids: Array[Vector2i]) -> bool:
	if field == null or not field.has_method("get_static_tile_block_reason"):
		return true
	for source_grid: Vector2i in source_grids:
		for target_grid: Vector2i in target_grids:
			var line := _bresenham_line(source_grid, target_grid)
			var clear := true
			for index in range(1, maxi(1, line.size() - 1)):
				if not String(field.call("get_static_tile_block_reason", line[index])).is_empty():
					clear = false
					break
			if clear:
				return true
	return false


func _bresenham_line(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x := start.x
	var y := start.y
	var dx := absi(finish.x - start.x)
	var sx := 1 if start.x < finish.x else -1
	var dy := -absi(finish.y - start.y)
	var sy := 1 if start.y < finish.y else -1
	var error := dx + dy
	while true:
		result.append(Vector2i(x, y))
		if x == finish.x and y == finish.y:
			break
		var doubled := 2 * error
		if doubled >= dy:
			error += dy
			x += sx
		if doubled <= dx:
			error += dx
			y += sy
	return result


func _allows_knocked_out_target(action: Dictionary) -> bool:
	var effects = action.get("effects", [])
	if effects is Array:
		for effect in effects:
			if effect is Dictionary and String((effect as Dictionary).get("type", "")) == "revive":
				return true
	return false
