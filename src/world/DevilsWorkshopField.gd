extends "res://src/Field.gd"
class_name DevilsWorkshopField

const ART = preload("res://src/world/DevilsWorkshopArt.gd")

const GRASS_TINT := Color(0.93, 1.0, 0.91, 1.0)
const GRASS_EDGE_TINT := Color(0.82, 0.91, 0.80, 1.0)
const ROUTE_TINT := Color(0.74, 0.80, 0.58, 1.0)
const DATA_TINT := Color(0.78, 0.72, 0.94, 1.0)
const WATER_TINT := Color(0.76, 0.92, 1.0, 1.0)


func _ready() -> void:
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

			var texture: Texture2D = presentation["texture"]
			var tint: Color = presentation["tint"]
			var block := ART.create_block(texture, world_position, -120 + x + y, tint)
			block.name = "%s_%02d_%02d" % [String(presentation["name"]), x, y]
			add_child(block)

	_build_perimeter_water()
	_build_corner_beacons()
	selectedTile = Vector2i(grid_to_world(Vector2i(GRID_SIZE_X / 2, GRID_SIZE_Y / 2)))


func _battle_surface(grid: Vector2i) -> Dictionary:
	# Deliberate visual hierarchy: a calm green combat core, authored staging
	# terraces at both ends, and sparse magenta data anchors. Unlike the previous
	# noise-generated board, variation now communicates composition instead of
	# reading as random texture noise.
	if _is_data_anchor(grid):
		return {"name": "data", "texture": ART.DATA_BLOCK, "tint": DATA_TINT}
	if _is_staging_terrace(grid):
		return {"name": "route", "texture": ART.WARM_BLOCK, "tint": ROUTE_TINT}
	if grid.x == 0 or grid.x == GRID_SIZE_X - 1 or grid.y == 0 or grid.y == GRID_SIZE_Y - 1:
		return {"name": "grass_edge", "texture": ART.GRASS_BLOCK, "tint": GRASS_EDGE_TINT}
	return {"name": "grass", "texture": ART.GRASS_BLOCK, "tint": GRASS_TINT}


func _is_staging_terrace(grid: Vector2i) -> bool:
	var north_deck := grid.y >= 2 and grid.y <= 4 and grid.x >= 3 and grid.x <= 11
	var south_deck := grid.y >= GRID_SIZE_Y - 5 and grid.y <= GRID_SIZE_Y - 3 and grid.x >= 3 and grid.x <= 11
	var north_spur := grid.y >= 5 and grid.y <= 7 and (grid.x == 4 or grid.x == 10)
	var south_spur := grid.y >= GRID_SIZE_Y - 8 and grid.y <= GRID_SIZE_Y - 6 and (grid.x == 4 or grid.x == 10)
	return north_deck or south_deck or north_spur or south_spur


func _is_data_anchor(grid: Vector2i) -> bool:
	var anchors: Array[Vector2i] = [
		Vector2i(7, 2), Vector2i(3, 4), Vector2i(11, 4),
		Vector2i(7, GRID_SIZE_Y - 3),
		Vector2i(3, GRID_SIZE_Y - 5),
		Vector2i(11, GRID_SIZE_Y - 5),
	]
	return grid in anchors


func _build_perimeter_water() -> void:
	var water := Node2D.new()
	water.name = "PerimeterWater"
	water.z_index = -20
	add_child(water)

	for x in range(-1, GRID_SIZE_X + 1):
		_add_water_block(water, Vector2i(x, -1))
		_add_water_block(water, Vector2i(x, GRID_SIZE_Y))
	for y in range(GRID_SIZE_Y):
		_add_water_block(water, Vector2i(-1, y))
		_add_water_block(water, Vector2i(GRID_SIZE_X, y))


func _add_water_block(parent: Node2D, grid: Vector2i) -> void:
	var top_center := grid_to_world(grid) + Vector2(0.0, 18.0)
	var block := ART.create_block(
		ART.WATER_BLOCK,
		top_center,
		-230 + grid.x + grid.y,
		WATER_TINT
	)
	block.name = "Water_%02d_%02d" % [grid.x, grid.y]
	parent.add_child(block)


func _build_corner_beacons() -> void:
	var beacons := Node2D.new()
	beacons.name = "CornerBeacons"
	add_child(beacons)
	var anchors: Array[Vector2i] = [
		Vector2i(-2, -1), Vector2i(GRID_SIZE_X + 1, -1),
		Vector2i(-2, GRID_SIZE_Y), Vector2i(GRID_SIZE_X + 1, GRID_SIZE_Y),
	]
	for index in range(anchors.size()):
		var top_center := grid_to_world(anchors[index]) + Vector2(0.0, 12.0)
		var base := ART.create_block(ART.DATA_BLOCK, top_center, -80 + int(round(top_center.y)), DATA_TINT)
		base.name = "BeaconBase%02d" % index
		beacons.add_child(base)
		var cap := ART.create_block(ART.WARM_BLOCK, top_center, -78 + int(round(top_center.y)), ROUTE_TINT, 1)
		cap.name = "BeaconCap%02d" % index
		beacons.add_child(cap)


func _create_board_foundation() -> void:
	var outline := _board_outline()

	var shadow := Polygon2D.new()
	shadow.name = "BoardShadow"
	shadow.polygon = _offset_polygon(outline, Vector2(0.0, 36.0))
	shadow.color = Color(0.0, 0.01, 0.025, 0.70)
	shadow.z_index = -300
	add_child(shadow)

	var underglow := Line2D.new()
	underglow.name = "BoardUnderglow"
	underglow.points = PackedVector2Array([
		outline[0], outline[1], outline[2], outline[3], outline[0]
	])
	underglow.width = 2.0
	underglow.default_color = Color(0.18, 0.72, 0.78, 0.24)
	underglow.z_index = -70
	add_child(underglow)
