extends RefCounted
class_name EvolutionGraphService

const RANK_ORDER: Array[String] = [
	"Fresh", "In-Training", "Rookie", "Champion", "Ultimate", "Mega", "Ultra", "Armor", "Hybrid"
]


func build_connected_graph(start_seed: String, database: DigimonDatabase) -> Dictionary:
	var result: Dictionary = {"nodes": [], "edges": []}
	if database == null or start_seed.is_empty() or not database.has_seed(start_seed):
		return result

	var queue: Array[String] = [start_seed]
	var visited: Dictionary = {}
	var nodes: Array[Dictionary] = []
	var edges_by_key: Dictionary = {}

	while not queue.is_empty():
		var seed: String = queue.pop_front()
		if visited.has(seed):
			continue
		visited[seed] = true
		var species: Dictionary = database.get_by_seed(seed)
		if species.is_empty():
			continue
		nodes.append({
			"seed": seed,
			"name": String(species.get("name", "Unknown")),
			"rank": String(species.get("rank", "Unknown")),
			"rank_index": rank_index(String(species.get("rank", "Unknown"))),
			"type": String(species.get("type", species.get("attribute", "Free"))),
			"family": String(species.get("family", species.get("species", "Unknown"))),
		})

		for route: Dictionary in database.get_evolution_routes(seed):
			var target_seed := String(route.get("targetSeed", ""))
			if target_seed.is_empty() or not database.has_seed(target_seed):
				continue
			_add_edge(edges_by_key, seed, target_seed, route.get("requirements", []))
			if not visited.has(target_seed):
				queue.append(target_seed)

		for route: Dictionary in database.get_degeneration_routes(seed):
			var lower_seed := String(route.get("targetSeed", ""))
			if lower_seed.is_empty() or not database.has_seed(lower_seed):
				continue
			_add_edge(edges_by_key, lower_seed, seed, [])
			if not visited.has(lower_seed):
				queue.append(lower_seed)

	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ar := int(a.get("rank_index", 999))
		var br := int(b.get("rank_index", 999))
		if ar == br:
			return String(a.get("name", "")) < String(b.get("name", ""))
		return ar < br
	)
	var edges: Array[Dictionary] = []
	for key in edges_by_key.keys():
		edges.append((edges_by_key[key] as Dictionary).duplicate(true))
	result["nodes"] = nodes
	result["edges"] = edges
	return result


func find_shortest_path(start_seed: String, target_seed: String, database: DigimonDatabase) -> Array[String]:
	var empty: Array[String] = []
	if database == null or start_seed.is_empty() or target_seed.is_empty():
		return empty
	if start_seed == target_seed:
		return [start_seed]

	var queue: Array[String] = [start_seed]
	var previous: Dictionary = {start_seed: ""}
	while not queue.is_empty():
		var seed: String = queue.pop_front()
		for neighbor: String in _neighbors(seed, database):
			if previous.has(neighbor):
				continue
			previous[neighbor] = seed
			if neighbor == target_seed:
				return _reconstruct_path(previous, start_seed, target_seed)
			queue.append(neighbor)
	return empty


func route_direction(from_seed: String, to_seed: String, database: DigimonDatabase) -> String:
	if database == null:
		return ""
	for route: Dictionary in database.get_evolution_routes(from_seed):
		if String(route.get("targetSeed", "")) == to_seed:
			return "digivolution"
	for route: Dictionary in database.get_degeneration_routes(from_seed):
		if String(route.get("targetSeed", "")) == to_seed:
			return "degeneration"
	return ""


func history_edge_keys(history: Array[Dictionary]) -> Dictionary:
	var keys: Dictionary = {}
	for record: Dictionary in history:
		var from_seed := String(record.get("fromSeed", ""))
		var to_seed := String(record.get("toSeed", ""))
		if from_seed.is_empty() or to_seed.is_empty():
			continue
		keys[_undirected_key(from_seed, to_seed)] = true
	return keys


func path_edge_keys(path: Array[String]) -> Dictionary:
	var keys: Dictionary = {}
	for index in range(maxi(0, path.size() - 1)):
		keys[_undirected_key(path[index], path[index + 1])] = true
	return keys


func rank_index(rank: String) -> int:
	var index: int = RANK_ORDER.find(rank)
	return index if index >= 0 else RANK_ORDER.size()


func _neighbors(seed: String, database: DigimonDatabase) -> Array[String]:
	var result: Array[String] = []
	for route: Dictionary in database.get_evolution_routes(seed):
		var target := String(route.get("targetSeed", ""))
		if not target.is_empty() and database.has_seed(target) and not result.has(target):
			result.append(target)
	for route: Dictionary in database.get_degeneration_routes(seed):
		var target := String(route.get("targetSeed", ""))
		if not target.is_empty() and database.has_seed(target) and not result.has(target):
			result.append(target)
	return result


func _add_edge(edges: Dictionary, from_seed: String, to_seed: String, raw_requirements) -> void:
	if from_seed.is_empty() or to_seed.is_empty() or from_seed == to_seed:
		return
	var key := _undirected_key(from_seed, to_seed)
	if edges.has(key):
		var existing := edges[key] as Dictionary
		if (existing.get("requirements", []) as Array).is_empty() and raw_requirements is Array and not (raw_requirements as Array).is_empty():
			existing["requirements"] = (raw_requirements as Array).duplicate(true)
		return
	edges[key] = {
		"key": key,
		"from": from_seed,
		"to": to_seed,
		"requirements": (raw_requirements as Array).duplicate(true) if raw_requirements is Array else [],
	}


func _reconstruct_path(previous: Dictionary, start_seed: String, target_seed: String) -> Array[String]:
	var reversed: Array[String] = []
	var cursor := target_seed
	while not cursor.is_empty():
		reversed.append(cursor)
		if cursor == start_seed:
			break
		cursor = String(previous.get(cursor, ""))
	if reversed.is_empty() or reversed[reversed.size() - 1] != start_seed:
		return []
	reversed.reverse()
	return reversed


func _undirected_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
