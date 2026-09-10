extends RefCounted
class_name MovementSystem

const CARDINAL_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]
const INF := 1_000_000


func get_reachable_tiles(
	field: Node,
	controller: Node,
	moving_digimon: Node,
	origin: Vector2i,
	movement_points: int
) -> Dictionary:
	var result: Dictionary = _search(field, controller, moving_digimon, origin, movement_points)
	var distances: Dictionary = result["distances"]
	var reachable: Dictionary = {}

	for raw_grid in distances:
		var grid: Vector2i = raw_grid
		if grid == origin:
			continue
		if _can_end_on(controller, field, moving_digimon, grid):
			reachable[grid] = int(distances[grid])

	return reachable


func find_path(
	field: Node,
	controller: Node,
	moving_digimon: Node,
	origin: Vector2i,
	destination: Vector2i,
	movement_points: int
) -> Array[Vector2i]:
	if destination == origin:
		return []

	var result: Dictionary = _search(field, controller, moving_digimon, origin, movement_points)
	var distances: Dictionary = result["distances"]
	var previous: Dictionary = result["previous"]
	if not distances.has(destination) or not _can_end_on(controller, field, moving_digimon, destination):
		return []

	var reversed_path: Array[Vector2i] = []
	var cursor: Vector2i = destination
	while cursor != origin:
		reversed_path.append(cursor)
		if not previous.has(cursor):
			return []
		cursor = Vector2i(previous[cursor])

	reversed_path.reverse()
	return reversed_path


func get_path_cost(field: Node, moving_digimon: Node, path: Array[Vector2i]) -> int:
	var total: int = 0
	for grid: Vector2i in path:
		total += _movement_cost(field, moving_digimon, grid)
	return total


func get_valid_next_steps(
	field: Node,
	controller: Node,
	moving_digimon: Node,
	origin: Vector2i,
	path: Array[Vector2i],
	movement_points: int
) -> Dictionary:
	var endpoint: Vector2i = origin if path.is_empty() else path[path.size() - 1]
	var spent: int = get_path_cost(field, moving_digimon, path)
	var options: Dictionary = {}
	for offset: Vector2i in CARDINAL_NEIGHBORS:
		var candidate: Vector2i = endpoint + offset
		if candidate == origin:
			options[candidate] = 0
			continue
		var previous_index: int = path.find(candidate)
		if previous_index >= 0:
			options[candidate] = _path_cost_through_index(field, moving_digimon, path, previous_index)
			continue
		if not _can_traverse(field, controller, moving_digimon, candidate):
			continue
		var next_cost: int = spent + _movement_cost(field, moving_digimon, candidate)
		if next_cost <= movement_points:
			options[candidate] = next_cost
	return options


func can_confirm_manual_path(
	field: Node,
	controller: Node,
	moving_digimon: Node,
	path: Array[Vector2i],
	movement_points: int
) -> bool:
	if path.is_empty():
		return false
	if get_path_cost(field, moving_digimon, path) > movement_points:
		return false
	return _can_end_on(controller, field, moving_digimon, path[path.size() - 1])


func _path_cost_through_index(field: Node, moving_digimon: Node, path: Array[Vector2i], index: int) -> int:
	var total: int = 0
	for path_index in range(index + 1):
		total += _movement_cost(field, moving_digimon, path[path_index])
	return total


func _search(
	field: Node,
	controller: Node,
	moving_digimon: Node,
	origin: Vector2i,
	movement_points: int
) -> Dictionary:
	var distances: Dictionary = {origin: 0}
	var previous: Dictionary = {}
	var frontier: Array[Vector2i] = [origin]

	while not frontier.is_empty():
		var current: Vector2i = _pop_lowest_cost(frontier, distances)
		var current_cost: int = int(distances[current])

		for offset: Vector2i in CARDINAL_NEIGHBORS:
			var neighbor: Vector2i = current + offset
			if not _can_traverse(field, controller, moving_digimon, neighbor):
				continue

			var step_cost: int = _movement_cost(field, moving_digimon, neighbor)
			if step_cost <= 0:
				continue

			var next_cost: int = current_cost + step_cost
			if next_cost > movement_points:
				continue

			var known_cost: int = int(distances.get(neighbor, INF))
			if next_cost >= known_cost:
				continue

			distances[neighbor] = next_cost
			previous[neighbor] = current
			if not frontier.has(neighbor):
				frontier.append(neighbor)

	return {
		"distances": distances,
		"previous": previous,
	}


func _pop_lowest_cost(frontier: Array[Vector2i], distances: Dictionary) -> Vector2i:
	var best_index: int = 0
	var best_cost: int = int(distances.get(frontier[0], INF))
	for index in range(1, frontier.size()):
		var candidate_cost: int = int(distances.get(frontier[index], INF))
		if candidate_cost < best_cost:
			best_index = index
			best_cost = candidate_cost
	return frontier.pop_at(best_index)


func _can_traverse(field: Node, controller: Node, moving_digimon: Node, grid: Vector2i) -> bool:
	if field == null or not field.has_method("get_static_tile_block_reason"):
		return false
	if not String(field.call("get_static_tile_block_reason", grid)).is_empty():
		return false

	var occupant: Node = _occupant_at(controller, field, grid, moving_digimon)
	if occupant == null:
		return true
	return _same_team(occupant, moving_digimon)


func _can_end_on(controller: Node, field: Node, moving_digimon: Node, grid: Vector2i) -> bool:
	return _occupant_at(controller, field, grid, moving_digimon) == null


func _occupant_at(controller: Node, field: Node, grid: Vector2i, ignored: Node) -> Node:
	if controller == null or field == null or not controller.has_method("get_digimon_at_tile"):
		return null
	var world_position: Vector2 = Vector2(field.call("grid_to_world", grid))
	return controller.call("get_digimon_at_tile", world_position, ignored) as Node


func _same_team(first: Node, second: Node) -> bool:
	return bool(first.get("is_player_controlled")) == bool(second.get("is_player_controlled"))


func _movement_cost(field: Node, moving_digimon: Node, grid: Vector2i) -> int:
	if field.has_method("get_movement_cost"):
		return maxi(1, int(field.call("get_movement_cost", grid, moving_digimon)))
	return 1
