extends RefCounted
class_name FootprintMapValidator

const BattleFootprintScript = preload("res://src/combat/BattleFootprint.gd")
const DeploymentPlannerScript = preload("res://src/combat/FootprintDeploymentPlanner.gd")

const OBJECTIVE_MODE_REGION := "region"
const OBJECTIVE_MODE_ALL := "all"
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]


static func validate_layout(
	walkable_cells: Array[Vector2i],
	deployment_cells: Array[Vector2i],
	objective_cells: Array[Vector2i],
	footprint_id: String,
	team_size: int = 3,
	objective_mode: String = OBJECTIVE_MODE_REGION
) -> Dictionary:
	var normalized_footprint := BattleFootprintScript.normalize_id(footprint_id)
	var footprint_label := BattleFootprintScript.display_label(normalized_footprint)
	var result := {
		"ok": false,
		"deployment_ok": false,
		"route_ok": false,
		"deployment_anchors": [],
		"reachable_objectives": [],
		"objective_mode": _normalized_objective_mode(objective_mode),
		"footprint": normalized_footprint,
		"errors": [],
	}
	if walkable_cells.is_empty():
		(result["errors"] as Array).append("Map has no walkable cells.")
		return result
	if deployment_cells.is_empty():
		(result["errors"] as Array).append("Map has no deployment cells.")
		return result
	if objective_cells.is_empty():
		(result["errors"] as Array).append("Map has no objective cells.")
		return result

	var footprints: Array = []
	for _index in range(maxi(1, team_size)):
		footprints.append(normalized_footprint)
	var deployment := DeploymentPlannerScript.plan(footprints, deployment_cells)
	result["deployment_ok"] = bool(deployment.get("ok", false))
	result["deployment_anchors"] = (deployment.get("anchors", []) as Array).duplicate() if deployment.get("anchors", []) is Array else []
	if not bool(result["deployment_ok"]):
		(result["errors"] as Array).append("Deployment zone cannot fit %d %s Digimon." % [maxi(1, team_size), footprint_label])

	var legal_anchors := _legal_anchors(walkable_cells, normalized_footprint)
	if legal_anchors.is_empty():
		(result["errors"] as Array).append("Map contains no valid %s traversal anchors." % footprint_label)
		return result
	var legal_set: Dictionary = {}
	for anchor: Vector2i in legal_anchors:
		legal_set[anchor] = true

	var frontier: Array[Vector2i] = []
	var visited: Dictionary = {}
	for raw_anchor in result["deployment_anchors"] as Array:
		var anchor := Vector2i(raw_anchor)
		if legal_set.has(anchor) and not visited.has(anchor):
			visited[anchor] = true
			frontier.append(anchor)
	if frontier.is_empty():
		for anchor: Vector2i in legal_anchors:
			if _footprint_is_subset(anchor, deployment_cells, normalized_footprint):
				visited[anchor] = true
				frontier.append(anchor)

	var cursor := 0
	while cursor < frontier.size():
		var anchor := frontier[cursor]
		cursor += 1
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var next_anchor := anchor + direction
			if not legal_set.has(next_anchor) or visited.has(next_anchor):
				continue
			visited[next_anchor] = true
			frontier.append(next_anchor)

	var reachable_objectives: Array[Vector2i] = []
	for objective: Vector2i in objective_cells:
		if _objective_reachable(objective, visited, normalized_footprint):
			reachable_objectives.append(objective)
	result["reachable_objectives"] = reachable_objectives

	if String(result["objective_mode"]) == OBJECTIVE_MODE_ALL:
		result["route_ok"] = reachable_objectives.size() == objective_cells.size()
	else:
		result["route_ok"] = not reachable_objectives.is_empty()
	if not bool(result["route_ok"]):
		var error := "No continuous %s route reaches the objective region." % footprint_label
		if String(result["objective_mode"]) == OBJECTIVE_MODE_ALL:
			error = "At least one required objective has no continuous %s route from deployment." % footprint_label
		(result["errors"] as Array).append(error)
	result["ok"] = bool(result["deployment_ok"]) and bool(result["route_ok"])
	return result


static func validate_story_layout(
	walkable_cells: Array[Vector2i],
	deployment_cells: Array[Vector2i],
	objective_cells: Array[Vector2i],
	team_size: int = 3,
	objective_mode: String = OBJECTIVE_MODE_REGION
) -> Dictionary:
	return validate_layout(
		walkable_cells,
		deployment_cells,
		objective_cells,
		BattleFootprintScript.LARGE_2X2,
		team_size,
		objective_mode
	)


static func validate_required_objectives(
	walkable_cells: Array[Vector2i],
	deployment_cells: Array[Vector2i],
	objective_cells: Array[Vector2i],
	team_size: int = 3
) -> Dictionary:
	return validate_story_layout(walkable_cells, deployment_cells, objective_cells, team_size, OBJECTIVE_MODE_ALL)


static func _normalized_objective_mode(value: String) -> String:
	return OBJECTIVE_MODE_ALL if value.strip_edges().to_lower() == OBJECTIVE_MODE_ALL else OBJECTIVE_MODE_REGION


static func _legal_anchors(walkable_cells: Array[Vector2i], footprint_id: String) -> Array[Vector2i]:
	var walkable: Dictionary = {}
	for cell: Vector2i in walkable_cells:
		walkable[cell] = true
	var result: Array[Vector2i] = []
	for anchor: Vector2i in walkable_cells:
		var valid := true
		for occupied: Vector2i in BattleFootprintScript.occupied_grids(anchor, footprint_id):
			if not walkable.has(occupied):
				valid = false
				break
		if valid:
			result.append(anchor)
	return result


static func _footprint_is_subset(anchor: Vector2i, cells: Array[Vector2i], footprint_id: String) -> bool:
	var cell_set: Dictionary = {}
	for cell: Vector2i in cells:
		cell_set[cell] = true
	for occupied: Vector2i in BattleFootprintScript.occupied_grids(anchor, footprint_id):
		if not cell_set.has(occupied):
			return false
	return true


static func _objective_reachable(objective: Vector2i, visited_anchors: Dictionary, footprint_id: String) -> bool:
	for raw_anchor in visited_anchors.keys():
		if not raw_anchor is Vector2i:
			continue
		var anchor := Vector2i(raw_anchor)
		for occupied: Vector2i in BattleFootprintScript.occupied_grids(anchor, footprint_id):
			if occupied == objective:
				return true
	return false
