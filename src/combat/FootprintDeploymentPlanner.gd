extends RefCounted
class_name FootprintDeploymentPlanner

const FootprintScript = preload("res://src/combat/BattleFootprint.gd")


static func plan(
	footprint_ids: Array,
	allowed_cells: Array[Vector2i],
	blocked_cells: Array[Vector2i] = [],
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var anchors: Array[Vector2i] = []
	anchors.resize(footprint_ids.size())
	if footprint_ids.is_empty():
		return {
			"ok": true,
			"anchors": anchors,
			"reason": "",
		}

	var allowed_lookup := _grid_lookup(allowed_cells)
	var blocked_lookup := _grid_lookup(blocked_cells)
	var candidates := allowed_cells.duplicate()
	if rng != null:
		_shuffle_candidates(candidates, rng)
	else:
		# Keep non-runtime callers deterministic. Story-map validation and focused
		# regression tests do not need battle randomness and are easier to diagnose
		# when they always traverse anchors in the same order.
		candidates.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
			if first.y == second.y:
				return first.x < second.x
			return first.y < second.y
		)

	var actor_order: Array[int] = []
	for actor_index in range(footprint_ids.size()):
		actor_order.append(actor_index)
	actor_order.sort_custom(func(first_index: int, second_index: int) -> bool:
		var first_area := FootprintScript.offsets_for(String(footprint_ids[first_index])).size()
		var second_area := FootprintScript.offsets_for(String(footprint_ids[second_index])).size()
		if first_area == second_area:
			return first_index < second_index
		return first_area > second_area
	)

	var reserved: Dictionary = {}
	if _search_plan(actor_order, 0, footprint_ids, candidates, allowed_lookup, blocked_lookup, reserved, anchors):
		return {
			"ok": true,
			"anchors": anchors,
			"reason": "",
		}

	return {
		"ok": false,
		"anchors": [],
		"reason": "Deployment zone cannot fit all Digimon footprints without overlap.",
	}


static func can_place_footprint(
	anchor: Vector2i,
	footprint_id: String,
	allowed_lookup: Dictionary,
	blocked_lookup: Dictionary,
	reserved_lookup: Dictionary
) -> bool:
	# Validate the complete occupied-cell set, not just the anchor. This keeps
	# deployment correct for every registered footprint shape (1x1, 2x2 and
	# future larger shapes such as 3x3) without dimension-specific edge rules.
	for grid: Vector2i in FootprintScript.occupied_grids(anchor, footprint_id):
		if not allowed_lookup.has(grid):
			return false
		if blocked_lookup.has(grid) or reserved_lookup.has(grid):
			return false
	return true


static func _search_plan(
	actor_order: Array[int],
	cursor: int,
	footprint_ids: Array,
	candidates: Array[Vector2i],
	allowed_lookup: Dictionary,
	blocked_lookup: Dictionary,
	reserved: Dictionary,
	anchors: Array[Vector2i]
) -> bool:
	if cursor >= actor_order.size():
		return true

	var actor_index := actor_order[cursor]
	var footprint_id := String(footprint_ids[actor_index])
	for anchor: Vector2i in candidates:
		if not can_place_footprint(anchor, footprint_id, allowed_lookup, blocked_lookup, reserved):
			continue

		var occupied := FootprintScript.occupied_grids(anchor, footprint_id)
		for grid: Vector2i in occupied:
			reserved[grid] = true
		anchors[actor_index] = anchor

		if _search_plan(actor_order, cursor + 1, footprint_ids, candidates, allowed_lookup, blocked_lookup, reserved, anchors):
			return true

		for grid: Vector2i in occupied:
			reserved.erase(grid)

	return false


static func _shuffle_candidates(candidates: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		if swap_index == index:
			continue
		var value := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = value


static func _grid_lookup(grids: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for grid: Vector2i in grids:
		result[grid] = true
	return result
