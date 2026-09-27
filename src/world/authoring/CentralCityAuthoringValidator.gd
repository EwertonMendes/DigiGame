@tool
extends RefCounted
class_name CentralCityAuthoringValidator

const MATH = preload("res://src/world/authoring/CentralCityEditorMath.gd")
const AUTHORING_DATA = preload("res://src/world/authoring/CentralCityAuthoringData.gd")
const EPSILON := 0.01


static func validate(root: Node) -> Array[String]:
	var issues: Array[String] = []
	if root == null:
		issues.append("CentralCityAuthoring root is missing.")
		return issues
	_validate_roads(root.get_node_or_null("Roads"), issues)
	_validate_polygons(root.get_node_or_null("Surfaces"), "surface", issues)
	_validate_polygons(root.get_node_or_null("Transitions"), "transition", issues)
	_validate_ids(root, issues)
	_validate_road_graph(root, issues)
	return issues


static func _validate_roads(container: Node, issues: Array[String]) -> void:
	if container == null:
		issues.append("Roads container is missing.")
		return
	for child in container.get_children():
		if not child is Line2D:
			continue
		var road := child as Line2D
		if road.points.size() < 2:
			issues.append("%s has fewer than two points." % road.name)
			continue
		for index in range(road.points.size() - 1):
			if road.points[index].distance_to(road.points[index + 1]) < 8.0:
				issues.append("%s contains a zero/near-zero length segment." % road.name)


static func _validate_polygons(container: Node, label: String, issues: Array[String]) -> void:
	if container == null:
		return
	for child in container.get_children():
		if child is Polygon2D and (child as Polygon2D).polygon.size() < 3:
			issues.append("%s %s needs at least three vertices." % [label.capitalize(), child.name])


static func _validate_road_graph(root: Node, issues: Array[String]) -> void:
	var snapshot := AUTHORING_DATA.snapshot_from_root(root)
	var topology_value = snapshot.get("topology", {})
	if not topology_value is Dictionary:
		return
	var network_value = (topology_value as Dictionary).get("road_network", {})
	if not network_value is Dictionary:
		return
	var network := network_value as Dictionary
	var nodes_value = network.get("nodes", [])
	var edges_value = network.get("edges", [])
	if not nodes_value is Array or not edges_value is Array or (nodes_value as Array).is_empty():
		issues.append("Road graph has no authored nodes.")
		return

	var adjacency := {}
	for raw_node in nodes_value as Array:
		if raw_node is Dictionary:
			adjacency[String((raw_node as Dictionary).get("id", ""))] = []
	for raw_edge in edges_value as Array:
		if not raw_edge is Dictionary:
			continue
		var edge := raw_edge as Dictionary
		var a := String(edge.get("from", ""))
		var b := String(edge.get("to", ""))
		if adjacency.has(a) and adjacency.has(b):
			(adjacency[a] as Array).append(b)
			(adjacency[b] as Array).append(a)

	var start := String(adjacency.keys()[0])
	var visited := {start: true}
	var queue: Array[String] = [start]
	while not queue.is_empty():
		var current := queue.pop_front()
		for next_value in adjacency.get(current, []) as Array:
			var next := String(next_value)
			if visited.has(next):
				continue
			visited[next] = true
			queue.append(next)
	if visited.size() != adjacency.size():
		issues.append("Road graph is disconnected: %d of %d nodes are reachable." % [visited.size(), adjacency.size()])


static func _validate_ids(root: Node, issues: Array[String]) -> void:
	var seen := {}
	for container_name in ["Roads", "Transitions"]:
		var container := root.get_node_or_null(container_name)
		if container == null:
			continue
		for child in container.get_children():
			var id_value = child.get("road_id") if container_name == "Roads" else child.get("transition_id")
			var id := String(id_value)
			if id.is_empty():
				issues.append("%s has no stable authoring id." % child.name)
			elif seen.has(id):
				issues.append("Duplicate authoring id: %s" % id)
			else:
				seen[id] = true
