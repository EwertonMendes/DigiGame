extends SceneTree

const Planner = preload("res://src/combat/FootprintDeploymentPlanner.gd")
const Footprint = preload("res://src/combat/BattleFootprint.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_three_expanded_digimon_fit_side_by_side()
	_test_plan_fails_when_zone_is_too_small()
	_test_footprint_cannot_extend_outside_deployment_zone()
	_test_existing_occupancy_is_respected()
	_test_single_and_large_footprints_share_zone_without_overlap()
	_test_seeded_randomization_is_reproducible_and_varied()
	_test_randomized_large_footprints_remain_inside_zone()

	if _failures.is_empty():
		print("[FootprintDeploymentTest] PASS")
		quit(0)
		return

	for failure in _failures:
		push_error("[FootprintDeploymentTest] %s" % failure)
	quit(1)


func _test_three_expanded_digimon_fit_side_by_side() -> void:
	var zone := _rect_cells(0, 0, 6, 2)
	var plan := Planner.plan([
		Footprint.LARGE_2X2,
		Footprint.LARGE_2X2,
		Footprint.LARGE_2X2,
	], zone)
	_expect(bool(plan.get("ok", false)), "A 6x2 deployment zone must fit three 2x2 Digimon.")
	if not bool(plan.get("ok", false)):
		return
	_assert_plan_is_valid(plan.get("anchors", []), [
		Footprint.LARGE_2X2,
		Footprint.LARGE_2X2,
		Footprint.LARGE_2X2,
	], zone, [])


func _test_plan_fails_when_zone_is_too_small() -> void:
	var zone := _rect_cells(0, 0, 5, 2)
	var plan := Planner.plan([
		Footprint.LARGE_2X2,
		Footprint.LARGE_2X2,
		Footprint.LARGE_2X2,
	], zone)
	_expect(not bool(plan.get("ok", true)), "A 5x2 deployment zone must reject three 2x2 Digimon.")
	_expect(not String(plan.get("reason", "")).is_empty(), "A rejected deployment must provide a clear reason.")


func _test_footprint_cannot_extend_outside_deployment_zone() -> void:
	var zone: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, 1),
	]
	var plan := Planner.plan([Footprint.LARGE_2X2], zone)
	_expect(not bool(plan.get("ok", true)), "Every occupied cell of a 2x2 footprint must remain inside the deployment zone.")


func _test_existing_occupancy_is_respected() -> void:
	var zone := _rect_cells(0, 0, 4, 2)
	var blocked: Array[Vector2i] = [Vector2i(0, 0)]
	var plan := Planner.plan([Footprint.LARGE_2X2], zone, blocked)
	_expect(bool(plan.get("ok", false)), "Planner should find an alternative anchor around existing occupancy.")
	if not bool(plan.get("ok", false)):
		return
	var anchors: Array = plan.get("anchors", [])
	var occupied := Footprint.occupied_grids(Vector2i(anchors[0]), Footprint.LARGE_2X2)
	_expect(not occupied.has(Vector2i(0, 0)), "Planned footprint must not intersect a pre-occupied cell.")


func _test_single_and_large_footprints_share_zone_without_overlap() -> void:
	var zone := _rect_cells(0, 0, 4, 3)
	var footprints := [Footprint.SINGLE, Footprint.LARGE_2X2, Footprint.SINGLE]
	var plan := Planner.plan(footprints, zone)
	_expect(bool(plan.get("ok", false)), "Mixed 1x1/2x2 parties should be planned together.")
	if not bool(plan.get("ok", false)):
		return
	_assert_plan_is_valid(plan.get("anchors", []), footprints, zone, [])


func _test_seeded_randomization_is_reproducible_and_varied() -> void:
	var zone := _rect_cells(0, 0, 9, 5)
	var footprints := [Footprint.SINGLE, Footprint.SINGLE, Footprint.SINGLE]
	var blocked: Array[Vector2i] = []

	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 1729
	var first_plan := Planner.plan(footprints, zone, blocked, first_rng)
	var repeated_rng := RandomNumberGenerator.new()
	repeated_rng.seed = 1729
	var repeated_plan := Planner.plan(footprints, zone, blocked, repeated_rng)
	_expect(bool(first_plan.get("ok", false)), "Seeded randomized deployment must produce a valid plan.")
	_expect(first_plan.get("anchors", []) == repeated_plan.get("anchors", []), "The same spawn seed must reproduce the same deployment layout.")

	var layouts: Dictionary = {}
	for seed_value in [11, 29, 47, 83, 131, 197]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var plan := Planner.plan(footprints, zone, blocked, rng)
		_expect(bool(plan.get("ok", false)), "Randomized deployment must remain solvable for seed %d." % seed_value)
		if not bool(plan.get("ok", false)):
			continue
		var anchors: Array = plan.get("anchors", [])
		_assert_plan_is_valid(anchors, footprints, zone, blocked)
		layouts[_anchors_signature(anchors)] = true
	_expect(layouts.size() > 1, "Different spawn seeds must not collapse to the same deterministic side-by-side layout.")


func _test_randomized_large_footprints_remain_inside_zone() -> void:
	var zone := _rect_cells(0, 0, 8, 5)
	var footprints := [Footprint.LARGE_2X2, Footprint.SINGLE, Footprint.LARGE_2X2]
	var blocked: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2)]
	for seed_value in [3, 7, 13, 31, 61]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var plan := Planner.plan(footprints, zone, blocked, rng)
		_expect(bool(plan.get("ok", false)), "Footprint-aware randomized deployment must find a legal layout for seed %d." % seed_value)
		if bool(plan.get("ok", false)):
			_assert_plan_is_valid(plan.get("anchors", []), footprints, zone, blocked)


func _assert_plan_is_valid(anchors: Array, footprints: Array, allowed: Array[Vector2i], blocked: Array[Vector2i]) -> void:
	_expect(anchors.size() == footprints.size(), "Deployment plan must preserve one anchor per party member.")
	if anchors.size() != footprints.size():
		return
	var occupied_lookup: Dictionary = {}
	for index in range(anchors.size()):
		for grid: Vector2i in Footprint.occupied_grids(Vector2i(anchors[index]), String(footprints[index])):
			_expect(allowed.has(grid), "Planned occupied cell %s must be inside the deployment zone." % grid)
			_expect(not blocked.has(grid), "Planned occupied cell %s must not be blocked." % grid)
			_expect(not occupied_lookup.has(grid), "Two deployed Digimon must never overlap at %s." % grid)
			occupied_lookup[grid] = true


func _anchors_signature(anchors: Array) -> String:
	var parts := PackedStringArray()
	for raw_anchor in anchors:
		var anchor := Vector2i(raw_anchor)
		parts.append("%d,%d" % [anchor.x, anchor.y])
	return ";".join(parts)


func _rect_cells(start_x: int, start_y: int, width: int, height: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(start_y, start_y + height):
		for x in range(start_x, start_x + width):
			result.append(Vector2i(x, y))
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
