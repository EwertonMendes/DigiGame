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
	_validate_paint(root.get_node_or_null("GroundPaint"), issues)
	_validate_polygons(root.get_node_or_null("Surfaces"), "surface", issues)
	_validate_polygons(root.get_node_or_null("Transitions"), "transition", issues)
	_validate_ids(root, issues)
	return issues


static func _validate_paint(node: Node, issues: Array[String]) -> void:
	if node == null:
		issues.append("GroundPaint node is missing.")
		return
	var value = node.get("cells")
	if not value is Dictionary:
		issues.append("GroundPaint cells must be a Dictionary.")
		return
	for raw_key in (value as Dictionary).keys():
		var key := String(raw_key)
		var parts := key.split(",", false)
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			issues.append("GroundPaint has invalid cell key: %s" % key)


static func _validate_polygons(container: Node, label: String, issues: Array[String]) -> void:
	if container == null:
		return
	for child in container.get_children():
		if child is Polygon2D and (child as Polygon2D).polygon.size() < 3:
			issues.append("%s %s needs at least three vertices." % [label.capitalize(), child.name])


static func _validate_ids(root: Node, issues: Array[String]) -> void:
	var seen := {}
	for container_name in ["Transitions"]:
		var container := root.get_node_or_null(container_name)
		if container == null:
			continue
		for child in container.get_children():
			var id_value = child.get("transition_id")
			var id := String(id_value)
			if id.is_empty():
				issues.append("%s has no stable authoring id." % child.name)
			elif seen.has(id):
				issues.append("Duplicate authoring id: %s" % id)
			else:
				seen[id] = true
