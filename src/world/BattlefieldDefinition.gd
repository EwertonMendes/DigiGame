extends RefCounted
class_name BattlefieldDefinition

const FootprintScript = preload("res://src/combat/BattleFootprint.gd")
const DeploymentPlannerScript = preload("res://src/combat/FootprintDeploymentPlanner.gd")
const MapValidatorScript = preload("res://src/combat/FootprintMapValidator.gd")

const VALID_SIZE_CLASSES: Array[String] = ["compact", "standard", "large", "colossal"]
const VALID_PROP_KINDS: Array[String] = ["tree", "rock", "stump"]

var battlefield_id: String = ""
var display_name: String = ""
var size_class: String = "standard"
var grid_size := Vector2i(13, 17)
var recommended_team_size := 3
var max_footprint_extent := 2
var environment_theme := "digital_plains"
var player_deployment_cells: Array[Vector2i] = []
var enemy_deployment_cells: Array[Vector2i] = []
var route_cells: Array[Vector2i] = []
var data_cells: Array[Vector2i] = []
var props: Array[Dictionary] = []
var movement_cost_cells: Array[Dictionary] = []

var _blocker_kind_by_grid: Dictionary = {}
var _movement_cost_by_grid: Dictionary = {}
var _movement_surface_by_grid: Dictionary = {}
var _route_lookup: Dictionary = {}
var _data_lookup: Dictionary = {}


static func from_dict(data: Dictionary) -> BattlefieldDefinition:
	var definition := BattlefieldDefinition.new()
	definition.battlefield_id = String(data.get("id", "")).strip_edges()
	definition.display_name = String(data.get("name", definition.battlefield_id)).strip_edges()
	definition.size_class = String(data.get("size_class", "standard")).strip_edges().to_lower()
	definition.grid_size = _vector2i(data.get("grid", [13, 17]), Vector2i(13, 17))
	definition.recommended_team_size = clampi(int(data.get("recommended_team_size", 3)), 1, 6)
	definition.max_footprint_extent = clampi(int(data.get("max_footprint_extent", 2)), 1, 3)
	definition.environment_theme = String(data.get("environment_theme", "digital_plains")).strip_edges()

	definition.player_deployment_cells = _expanded_cells(
		data.get("player_deployment_cells", []),
		data.get("player_deployment_rects", [])
	)
	definition.enemy_deployment_cells = _expanded_cells(
		data.get("enemy_deployment_cells", []),
		data.get("enemy_deployment_rects", [])
	)
	definition.route_cells = _expanded_cells(data.get("route_cells", []), data.get("route_rects", []))
	definition.data_cells = _expanded_cells(data.get("data_cells", []), data.get("data_rects", []))

	for raw_prop in Array(data.get("props", [])):
		if not raw_prop is Dictionary:
			continue
		var prop := (raw_prop as Dictionary).duplicate(true)
		prop["grid"] = _vector2i(prop.get("grid", []), Vector2i(-1, -1))
		definition.props.append(prop)

	for raw_cost in Array(data.get("movement_costs", [])):
		if not raw_cost is Dictionary:
			continue
		var cost := (raw_cost as Dictionary).duplicate(true)
		cost["grid"] = _vector2i(cost.get("grid", []), Vector2i(-1, -1))
		definition.movement_cost_cells.append(cost)

	definition._rebuild_indexes()
	return definition


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if battlefield_id.is_empty():
		errors.append("Battlefield id is required.")
	if display_name.is_empty():
		errors.append("Battlefield '%s' requires a display name." % battlefield_id)
	if grid_size.x < 7 or grid_size.y < 9:
		errors.append("Battlefield '%s' grid is too small: %s." % [battlefield_id, grid_size])
	if not VALID_SIZE_CLASSES.has(size_class):
		errors.append("Battlefield '%s' has invalid size class '%s'." % [battlefield_id, size_class])
	if player_deployment_cells.is_empty() or enemy_deployment_cells.is_empty():
		errors.append("Battlefield '%s' requires both deployment zones." % battlefield_id)

	var player_lookup := _lookup(player_deployment_cells)
	var enemy_lookup := _lookup(enemy_deployment_cells)
	for grid: Vector2i in player_deployment_cells:
		if not contains(grid):
			errors.append("Battlefield '%s' player deployment contains out-of-bounds cell %s." % [battlefield_id, grid])
		if enemy_lookup.has(grid):
			errors.append("Battlefield '%s' deployment zones overlap at %s." % [battlefield_id, grid])
	for grid: Vector2i in enemy_deployment_cells:
		if not contains(grid):
			errors.append("Battlefield '%s' enemy deployment contains out-of-bounds cell %s." % [battlefield_id, grid])

	var prop_grids: Dictionary = {}
	for prop: Dictionary in props:
		var grid := Vector2i(prop.get("grid", Vector2i(-1, -1)))
		var kind := String(prop.get("kind", "")).strip_edges().to_lower()
		if not contains(grid):
			errors.append("Battlefield '%s' prop '%s' is out of bounds at %s." % [battlefield_id, kind, grid])
			continue
		if not VALID_PROP_KINDS.has(kind):
			errors.append("Battlefield '%s' uses unsupported prop kind '%s'." % [battlefield_id, kind])
		if prop_grids.has(grid):
			errors.append("Battlefield '%s' has more than one physical prop at %s." % [battlefield_id, grid])
		prop_grids[grid] = true
		if player_lookup.has(grid) or enemy_lookup.has(grid):
			errors.append("Battlefield '%s' physical prop occupies deployment cell %s." % [battlefield_id, grid])

	for cost: Dictionary in movement_cost_cells:
		var grid := Vector2i(cost.get("grid", Vector2i(-1, -1)))
		var value := int(cost.get("cost", 1))
		if not contains(grid):
			errors.append("Battlefield '%s' movement-cost cell is out of bounds at %s." % [battlefield_id, grid])
		if value < 1:
			errors.append("Battlefield '%s' movement cost at %s must be positive." % [battlefield_id, grid])
		if value > 1 and (player_lookup.has(grid) or enemy_lookup.has(grid)):
			errors.append("Battlefield '%s' difficult terrain cannot occupy deployment cell %s." % [battlefield_id, grid])

	for grid: Vector2i in route_cells + data_cells:
		if not contains(grid):
			errors.append("Battlefield '%s' surface override is out of bounds at %s." % [battlefield_id, grid])

	var footprint_id := max_supported_footprint_id()
	if footprint_id.is_empty():
		errors.append("Battlefield '%s' has unsupported max footprint extent %d." % [battlefield_id, max_footprint_extent])
		return errors

	var max_footprints: Array = []
	for _index in range(recommended_team_size):
		max_footprints.append(footprint_id)
	var blockers := blocker_cells()
	var player_plan := DeploymentPlannerScript.plan(max_footprints, player_deployment_cells, blockers)
	var enemy_plan := DeploymentPlannerScript.plan(max_footprints, enemy_deployment_cells, blockers)
	if not bool(player_plan.get("ok", false)):
		errors.append("Battlefield '%s' player deployment cannot fit %d %s Digimon." % [battlefield_id, recommended_team_size, FootprintScript.display_label(footprint_id)])
	if not bool(enemy_plan.get("ok", false)):
		errors.append("Battlefield '%s' enemy deployment cannot fit %d %s Digimon." % [battlefield_id, recommended_team_size, FootprintScript.display_label(footprint_id)])

	var route_validation := MapValidatorScript.validate_layout(
		walkable_cells(),
		player_deployment_cells,
		enemy_deployment_cells,
		footprint_id,
		recommended_team_size
	)
	if not bool(route_validation.get("ok", false)):
		var route_errors = route_validation.get("errors", [])
		var detail := "; ".join(PackedStringArray(route_errors)) if route_errors is Array else "unknown route error"
		errors.append("Battlefield '%s' max-footprint route is invalid: %s" % [battlefield_id, detail])
	return errors


func contains(grid: Vector2i) -> bool:
	return grid.x >= 0 and grid.x < grid_size.x and grid.y >= 0 and grid.y < grid_size.y


func all_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			result.append(Vector2i(x, y))
	return result


func walkable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for grid: Vector2i in all_cells():
		if not _blocker_kind_by_grid.has(grid):
			result.append(grid)
	return result


func blocker_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raw_grid in _blocker_kind_by_grid.keys():
		if raw_grid is Vector2i:
			result.append(Vector2i(raw_grid))
	return result


func blocker_kind_at(grid: Vector2i) -> String:
	return String(_blocker_kind_by_grid.get(grid, ""))


func movement_cost_at(grid: Vector2i) -> int:
	return maxi(1, int(_movement_cost_by_grid.get(grid, 1)))


func surface_type_at(grid: Vector2i) -> String:
	if _data_lookup.has(grid):
		return "data"
	if _movement_surface_by_grid.has(grid):
		return String(_movement_surface_by_grid[grid])
	if _route_lookup.has(grid):
		return "route"
	return ""


func deployment_cells(player_side: bool) -> Array[Vector2i]:
	return player_deployment_cells.duplicate() if player_side else enemy_deployment_cells.duplicate()


func max_supported_footprint_id() -> String:
	return FootprintScript.id_for_extent(max_footprint_extent)


func supports_teams(player_footprints: Array, enemy_footprints: Array) -> bool:
	for footprint in player_footprints + enemy_footprints:
		if FootprintScript.max_extent(String(footprint)) > max_footprint_extent:
			return false
	var blockers := blocker_cells()
	var player_plan := DeploymentPlannerScript.plan(player_footprints, player_deployment_cells, blockers)
	if not bool(player_plan.get("ok", false)):
		return false
	var enemy_plan := DeploymentPlannerScript.plan(enemy_footprints, enemy_deployment_cells, blockers)
	return bool(enemy_plan.get("ok", false))


func summary() -> String:
	return "%s · %dx%d · %s · up to %s · %d props" % [
		display_name,
		grid_size.x,
		grid_size.y,
		size_class.to_upper(),
		FootprintScript.display_label(max_supported_footprint_id()),
		props.size(),
	]


func _rebuild_indexes() -> void:
	_blocker_kind_by_grid.clear()
	_movement_cost_by_grid.clear()
	_movement_surface_by_grid.clear()
	_route_lookup = _lookup(route_cells)
	_data_lookup = _lookup(data_cells)

	for prop: Dictionary in props:
		var grid := Vector2i(prop.get("grid", Vector2i(-1, -1)))
		_blocker_kind_by_grid[grid] = String(prop.get("kind", "")).strip_edges().to_lower()
	for cost: Dictionary in movement_cost_cells:
		var grid := Vector2i(cost.get("grid", Vector2i(-1, -1)))
		_movement_cost_by_grid[grid] = maxi(1, int(cost.get("cost", 1)))
		_movement_surface_by_grid[grid] = String(cost.get("surface", "rough_grass"))


static func _expanded_cells(raw_cells, raw_rects) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	if raw_cells is Array:
		for raw_cell in raw_cells:
			var grid := _vector2i(raw_cell, Vector2i(-1, -1))
			if not seen.has(grid):
				seen[grid] = true
				result.append(grid)
	if raw_rects is Array:
		for raw_rect in raw_rects:
			if not raw_rect is Array or (raw_rect as Array).size() < 4:
				continue
			var rect := raw_rect as Array
			var start_x := int(rect[0])
			var start_y := int(rect[1])
			var width := maxi(0, int(rect[2]))
			var height := maxi(0, int(rect[3]))
			for y in range(start_y, start_y + height):
				for x in range(start_x, start_x + width):
					var grid := Vector2i(x, y)
					if not seen.has(grid):
						seen[grid] = true
						result.append(grid)
	return result


static func _vector2i(raw, fallback: Vector2i) -> Vector2i:
	if raw is Vector2i:
		return Vector2i(raw)
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return fallback


static func _lookup(cells: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for grid: Vector2i in cells:
		result[grid] = true
	return result
