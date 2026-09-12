extends "res://src/Field.gd"
class_name DevilsWorkshopField

const ART = preload("res://src/world/DevilsWorkshopArt.gd")

const LOWER_LEVEL_OFFSET := 24.0
const BOARD_SKIRT_DEPTH := 24.0

const GRASS_BASE := Color(0.30, 0.52, 0.29, 1.0)
const GRASS_ALT_BASE := Color(0.27, 0.48, 0.27, 1.0)
const GRASS_EDGE_BASE := Color(0.22, 0.40, 0.24, 1.0)
const GRASS_DETAIL := Color(0.92, 1.0, 0.88, 1.0)
const STAGING_BASE := Color(0.17, 0.34, 0.39, 1.0)
const STAGING_DETAIL := Color(0.78, 0.94, 1.0, 1.0)
const CROSSING_BASE := Color(0.35, 0.38, 0.35, 1.0)
const CROSSING_DETAIL := Color(0.86, 0.90, 0.82, 1.0)
const DATA_BASE := Color(0.18, 0.34, 0.43, 1.0)
const DATA_DETAIL := Color(0.74, 0.82, 1.0, 1.0)
const WATER_BASE := Color(0.055, 0.29, 0.37, 1.0)
const WATER_DETAIL := Color(0.72, 0.94, 1.0, 1.0)
const SKIRT_LEFT := Color(0.14, 0.27, 0.18, 1.0)
const SKIRT_RIGHT := Color(0.10, 0.22, 0.16, 1.0)

var _transition_prepared := false


func _ready() -> void:
	_ensure_battlefield_ready()


func prepare_transition_offtree() -> void:
	_ensure_battlefield_ready()


func _ensure_battlefield_ready() -> void:
	if _transition_prepared:
		return
	_transition_prepared = true
	_map_center = _grid_to_raw(Vector2((GRID_SIZE_X - 1) * 0.5, (GRID_SIZE_Y - 1) * 0.5))
	_create_board_foundation()
	_create_hover_indicator()
	_generate_terrain()


func _generate_terrain() -> void:
	tile_map_data.clear()

	for y in range(GRID_SIZE_Y):
		for x in range(GRID_SIZE_X):
			var grid := Vector2i(x, y)
			var world_position := grid_to_world(grid)
			var presentation := _battle_surface(grid)
			tile_map_data[grid] = {
				"type": String(presentation["name"]),
				"world_position": world_position,
			}

			var tile := ART.create_surface_tile(
				presentation["texture"],
				world_position,
				-120 + x + y,
				presentation["base_color"],
				presentation["detail_tint"],
				float(presentation["detail_alpha"])
			)
			tile.name = "%s_%02d_%02d" % [String(presentation["name"]), x, y]
			add_child(tile)

	_build_perimeter_water()
	selectedTile = Vector2i(grid_to_world(Vector2i(GRID_SIZE_X / 2, GRID_SIZE_Y / 2)))


func _battle_surface(grid: Vector2i) -> Dictionary:
	if _is_data_anchor(grid):
		return {
			"name": "data",
			"texture": ART.DATA_BLOCK,
			"base_color": DATA_BASE,
			"detail_tint": DATA_DETAIL,
			"detail_alpha": 0.28,
		}

	if _is_staging_terrace(grid):
		# The more detailed blue source face reads as a digital deployment deck
		# while remaining a normal walkable tile mechanically.
		return {
			"name": "route",
			"texture": ART.WATER_BLOCK,
			"base_color": STAGING_BASE,
			"detail_tint": STAGING_DETAIL,
			"detail_alpha": 0.52,
		}

	if _is_center_crossing(grid):
		return {
			"name": "route",
			"texture": ART.WARM_BLOCK,
			"base_color": CROSSING_BASE,
			"detail_tint": CROSSING_DETAIL,
			"detail_alpha": 0.30,
		}

	if grid.x == 0 or grid.x == GRID_SIZE_X - 1 or grid.y == 0 or grid.y == GRID_SIZE_Y - 1:
		return {
			"name": "grass_edge",
			"texture": ART.GRASS_BLOCK,
			"base_color": GRASS_EDGE_BASE,
			"detail_tint": GRASS_DETAIL,
			"detail_alpha": 0.36,
		}

	return {
		"name": "grass",
		"texture": ART.GRASS_BLOCK,
		"base_color": _grass_base_for(grid),
		"detail_tint": GRASS_DETAIL,
		"detail_alpha": 0.40,
	}


func _grass_base_for(grid: Vector2i) -> Color:
	# Large, subtle authored patches break up the single-color carpet without
	# turning the battlefield back into noisy procedural terrain.
	var patch_a_dx := grid.x - 3
	var patch_a_dy := grid.y - 9
	var patch_b_dx := grid.x - 11
	var patch_b_dy := grid.y - 15
	var patch_c_dx := grid.x - 5
	var patch_c_dy := grid.y - 17
	var patch_a := patch_a_dx * patch_a_dx + patch_a_dy * patch_a_dy <= 12
	var patch_b := patch_b_dx * patch_b_dx + patch_b_dy * patch_b_dy <= 10
	var patch_c := patch_c_dx * patch_c_dx + patch_c_dy * patch_c_dy <= 8
	return GRASS_ALT_BASE if patch_a or patch_b or patch_c else GRASS_BASE


func _is_staging_terrace(grid: Vector2i) -> bool:
	# Compact deployment plazas leave much more natural grass visible than the
	# first pass's large mustard rectangles.
	var north_deck := grid.y >= 2 and grid.y <= 4 and grid.x >= 4 and grid.x <= 10
	var south_deck := grid.y >= GRID_SIZE_Y - 5 and grid.y <= GRID_SIZE_Y - 3 and grid.x >= 4 and grid.x <= 10
	return north_deck or south_deck


func _is_center_crossing(grid: Vector2i) -> bool:
	var center_y := GRID_SIZE_Y / 2
	return grid.y >= center_y - 1 and grid.y <= center_y + 1 and grid.x >= 6 and grid.x <= 8


func _is_data_anchor(grid: Vector2i) -> bool:
	var anchors: Array[Vector2i] = [
		Vector2i(7, 3),
		Vector2i(7, GRID_SIZE_Y - 4),
		Vector2i(3, GRID_SIZE_Y / 2),
		Vector2i(11, GRID_SIZE_Y / 2),
	]
	return grid in anchors


func _build_perimeter_water() -> void:
	var water := Node2D.new()
	water.name = "PerimeterWater"
	add_child(water)

	for x in range(-1, GRID_SIZE_X + 1):
		_add_water_tile(water, Vector2i(x, -1))
		_add_water_tile(water, Vector2i(x, GRID_SIZE_Y))
	for y in range(GRID_SIZE_Y):
		_add_water_tile(water, Vector2i(-1, y))
		_add_water_tile(water, Vector2i(GRID_SIZE_X, y))


func _add_water_tile(parent: Node2D, grid: Vector2i) -> void:
	var top_center := grid_to_world(grid) + Vector2(0.0, LOWER_LEVEL_OFFSET)
	var tile := ART.create_surface_tile(
		ART.WATER_BLOCK,
		top_center,
		-240 + grid.x + grid.y,
		WATER_BASE,
		WATER_DETAIL,
		0.64
	)
	tile.name = "Water_%02d_%02d" % [grid.x, grid.y]
	parent.add_child(tile)


func _create_board_foundation() -> void:
	var outline := _board_outline()
	var drop := Vector2(0.0, BOARD_SKIRT_DEPTH)

	var shadow := Polygon2D.new()
	shadow.name = "BoardShadow"
	shadow.polygon = _offset_polygon(outline, Vector2(0.0, BOARD_SKIRT_DEPTH + 12.0))
	shadow.color = Color(0.0, 0.01, 0.025, 0.66)
	shadow.z_index = -300
	add_child(shadow)

	var left_face := Polygon2D.new()
	left_face.name = "BoardLeftSkirt"
	left_face.polygon = PackedVector2Array([
		outline[3], outline[2], outline[2] + drop, outline[3] + drop,
	])
	left_face.color = SKIRT_LEFT
	left_face.z_index = -176
	add_child(left_face)

	var right_face := Polygon2D.new()
	right_face.name = "BoardRightSkirt"
	right_face.polygon = PackedVector2Array([
		outline[1], outline[2], outline[2] + drop, outline[1] + drop,
	])
	right_face.color = SKIRT_RIGHT
	right_face.z_index = -175
	add_child(right_face)

	# A continuous top underlay hides any rasterization crack underneath the
	# exact 64x32 surface diamonds at every supported camera zoom.
	var underlay := Polygon2D.new()
	underlay.name = "BoardUnderlay"
	underlay.polygon = outline
	underlay.color = GRASS_EDGE_BASE
	underlay.z_index = -145
	add_child(underlay)

	var rim := Line2D.new()
	rim.name = "BoardRim"
	rim.points = PackedVector2Array([
		outline[0], outline[1], outline[2], outline[3], outline[0],
	])
	rim.width = 1.25
	rim.default_color = Color(0.45, 0.76, 0.60, 0.34)
	rim.z_index = -70
	add_child(rim)