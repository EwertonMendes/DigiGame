extends RefCounted
class_name MovementSystem

const CARDINAL_NEIGHBORS := [
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
	var result := _search(field, controller, moving_digimon, origin, movement_points)
	var distances: Dictionary = result["distances"]
	var reachable: Dictionary = {}

	for grid in distances:
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

	var result := _search(field, controller, moving_digimon, origin, movement_points)
	var distances: Dictionary = result["distances"]
	var previous: Dictionary = result["previous"]
	if not distances.has(destination) or not _can_end_on(controller, field, moving_digimon, destination):
		return []

	var reversed_path: Array[Vector2i] = []
	var cursor := destination
	while cursor != origin:
		reversed_path.append(cursor)
		if not previous.has(cursor):
			return []
		cursor = previous[cursor]

	reversed_path.reverse()
	return reversed_path


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
		var current := _pop_lowest_cost(frontier, distances)
		var current_cost := int(distances[current])

		for offset in CARDINAL_NEIGHBORS:
			var neighbor := current + offset
			if not _can_traverse(field, controller, moving_digimon, neighbor):
				continue

			var step_cost := _movement_cost(field, moving_digimon, neighbor)
			if step_cost <= 0:
				continue

			var next_cost := current_cost + step_cost
			if next_cost > movement_points:
				continue

			var known_cost := int(distances.get(neighbor, INF))
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
	var best_index := 0
	var best_cost := int(distances.get(frontier[0], INF))
	for index in range(1, frontier.size()):
		var candidate_cost := int(distances.get(frontier[index], INF))
		if candidate_cost < best_cost:
			best_index = index
			best_cost = candidate_cost
	return frontier.pop_at(best_index)


func _can_traverse(field: Node, controller: Node, moving_digimon: Node, grid: Vector2i) -> bool:
	if field == null or not field.has_method("get_static_tile_block_reason"):
		return false
	if not String(field.call("get_static_tile_block_reason", grid)).is_empty():
		return false

	var occupant := _occupant_at(controller, field, grid, moving_digimon)
	if occupant == null:
		return true

	# Allies can be crossed but can never be the final destination. Enemies stop
	# pathfinding completely, which also gives us the correct basis for future
	# zones of control without changing the grid/path API.
	return _same_team(occupant, moving_digimon)


func _can_end_on(controller: Node, field: Node, moving_digimon: Node, grid: Vector2i) -> bool:
	return _occupant_at(controller, field, grid, moving_digimon) == null


func _occupant_at(controller: Node, field: Node, grid: Vector2i, ignored: Node) -> Node:
	if controller == null or field == null or not controller.has_method("get_digimon_at_tile"):
		return null
	var world_position := Vector2(field.call("grid_to_world", grid))
	return controller.call("get_digimon_at_tile", world_position, ignored) as Node


func _same_team(first: Node, second: Node) -> bool:
	return bool(first.get("is_player_controlled")) == bool(second.get("is_player_controlled"))


func _movement_cost(field: Node, moving_digimon: Node, grid: Vector2i) -> int:
	if field.has_method("get_movement_cost"):
		return maxi(1, int(field.call("get_movement_cost", grid, moving_digimon)))
	return 1
