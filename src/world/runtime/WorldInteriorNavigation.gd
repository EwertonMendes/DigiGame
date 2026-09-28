extends RefCounted
class_name WorldInteriorNavigation

# Canonical navigation model for seamless service interiors. Rendering code
# registers every occupied layout cell here while it builds the corresponding
# wall/fixture, so visuals and movement cannot silently drift apart.
var room_size := Vector2i.ZERO
var preferred_spawn_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO

var _blocked_cells: Dictionary = {}
var _blocked_sources: Dictionary = {}
var _resolved_spawn_cell := Vector2i.ZERO
var _finalized := false


func _init(size: Vector2i, spawn_cell: Vector2i, interior_exit_cell: Vector2i) -> void:
	room_size = size
	preferred_spawn_cell = spawn_cell
	exit_cell = interior_exit_cell
	_resolved_spawn_cell = preferred_spawn_cell


func block_cell(cell: Vector2i, source: String = "") -> void:
	_blocked_cells[_cell_key(cell)] = true
	if not source.is_empty():
		_blocked_sources[_cell_key(cell)] = source
	_finalized = false


func block_cells(cells: Array[Vector2i], source: String = "") -> void:
	for cell: Vector2i in cells:
		block_cell(cell, source)


func is_cell_walkable(cell: Vector2i) -> bool:
	# The room envelope is the complete authored floor (0..size-1). Perimeter
	# walls decide what is blocked. This distinction is essential at the front
	# doorway: row 13 contains both wall cells and the actual open passage.
	if cell.x < 0 or cell.y < 0:
		return false
	if cell.x >= room_size.x or cell.y >= room_size.y:
		return false
	return not _blocked_cells.has(_cell_key(cell))


func is_grid_position_walkable(grid_position: Vector2) -> bool:
	return is_grid_footprint_walkable(grid_position, Vector2.ZERO)


func is_grid_footprint_walkable(
	center: Vector2,
	half_extents: Vector2
) -> bool:
	# Collision is resolved in canonical isometric ground space, not by
	# rounding the actor center to one tile. Each blocked layout cell occupies
	# the exact square [cell-0.5, cell+0.5] in grid space; on screen that is the
	# same 64x32 diamond rendered for the floor/wall top face.
	#
	# The actor footprint is also expressed in grid space, so the upper and
	# lower room edges are mathematically symmetric. This removes the old
	# center-sampling error where the player could enter the back wall but was
	# stopped too early at the front wall.
	var half := Vector2(maxf(0.0, half_extents.x), maxf(0.0, half_extents.y))
	var footprint_min := center - half
	var footprint_max := center + half
	const EPSILON := 0.0001

	var room_min := Vector2(-0.5, -0.5)
	var room_max := Vector2(float(room_size.x) - 0.5, float(room_size.y) - 0.5)
	if footprint_min.x < room_min.x - EPSILON or footprint_min.y < room_min.y - EPSILON:
		return false
	if footprint_max.x > room_max.x + EPSILON or footprint_max.y > room_max.y + EPSILON:
		return false

	# Only cells touched by the tiny ground footprint need inspection.
	var min_x := maxi(0, floori(footprint_min.x + 0.5))
	var min_y := maxi(0, floori(footprint_min.y + 0.5))
	var max_x := mini(room_size.x - 1, floori(footprint_max.x + 0.5))
	var max_y := mini(room_size.y - 1, floori(footprint_max.y + 0.5))

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var cell := Vector2i(x, y)
			if not _blocked_cells.has(_cell_key(cell)):
				continue
			var cell_min := Vector2(float(x) - 0.5, float(y) - 0.5)
			var cell_max := Vector2(float(x) + 0.5, float(y) + 0.5)
			var overlaps_x := (
				footprint_max.x > cell_min.x + EPSILON
				and footprint_min.x < cell_max.x - EPSILON
			)
			var overlaps_y := (
				footprint_max.y > cell_min.y + EPSILON
				and footprint_min.y < cell_max.y - EPSILON
			)
			if overlaps_x and overlaps_y:
				return false
	return true


func finalize() -> bool:
	_finalized = true
	if not is_cell_walkable(exit_cell):
		push_error("Interior exit cell %s is blocked or outside the walkable room" % str(exit_cell))
		return false

	if is_cell_walkable(preferred_spawn_cell) and _has_path(preferred_spawn_cell, exit_cell):
		_resolved_spawn_cell = preferred_spawn_cell
		return true

	var recovered := _nearest_reachable_cell(preferred_spawn_cell, exit_cell)
	if recovered == Vector2i(-999999, -999999):
		push_error(
			"Interior has no walkable spawn connected to exit %s (preferred spawn=%s)"
			% [str(exit_cell), str(preferred_spawn_cell)]
		)
		return false

	_resolved_spawn_cell = recovered
	push_warning(
		"Interior spawn %s became invalid; recovered to nearest reachable cell %s"
		% [str(preferred_spawn_cell), str(_resolved_spawn_cell)]
	)
	return true


func resolved_spawn_cell() -> Vector2i:
	if not _finalized:
		finalize()
	return _resolved_spawn_cell


func has_spawn_to_exit_path() -> bool:
	if not _finalized and not finalize():
		return false
	return _has_path(_resolved_spawn_cell, exit_cell)


func blocked_cell_count() -> int:
	return _blocked_cells.size()


func blocker_source(cell: Vector2i) -> String:
	return String(_blocked_sources.get(_cell_key(cell), ""))


func _nearest_reachable_cell(origin: Vector2i, target: Vector2i) -> Vector2i:
	var best := Vector2i(-999999, -999999)
	var best_distance := INF
	for x in range(room_size.x):
		for y in range(room_size.y):
			var cell := Vector2i(x, y)
			if not is_cell_walkable(cell) or not _has_path(cell, target):
				continue
			var distance := Vector2(cell - origin).length_squared()
			if distance < best_distance:
				best_distance = distance
				best = cell
	return best


func _has_path(start: Vector2i, target: Vector2i) -> bool:
	if not is_cell_walkable(start) or not is_cell_walkable(target):
		return false
	if start == target:
		return true

	var frontier: Array[Vector2i] = [start]
	var visited := {_cell_key(start): true}
	var index := 0
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]

	while index < frontier.size():
		var current := frontier[index]
		index += 1
		for direction: Vector2i in directions:
			var next := current + direction
			var key := _cell_key(next)
			if visited.has(key) or not is_cell_walkable(next):
				continue
			if next == target:
				return true
			visited[key] = true
			frontier.append(next)
	return false


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
