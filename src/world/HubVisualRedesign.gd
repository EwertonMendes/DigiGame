extends "res://src/world/HubController.gd"

const ART = preload("res://src/world/DevilsWorkshopArt.gd")

const PLATFORM_MIN := -6
const PLATFORM_MAX := 6
const WATER_MIN := -8
const WATER_MAX := 8

const GRASS_TINT := Color(0.96, 1.0, 0.94, 1.0)
const EDGE_GRASS_TINT := Color(0.84, 0.92, 0.82, 1.0)
const PATH_TINT := Color(0.78, 0.82, 0.62, 1.0)
const DATA_TINT := Color(0.80, 0.76, 0.96, 1.0)
const WATER_TINT := Color(0.78, 0.92, 1.0, 1.0)


# The previous hub moved every water tile and rotated whole tree sprites each
# frame. The new block environment stays deliberately stable; motion belongs to
# authored effects, not to the terrain itself.
func _process(_delta: float) -> void:
	_refresh_interaction()


func _build_world() -> void:
	_blockers.clear()
	_build_lower_water_terrace()
	_build_recovery_platform()
	_build_sector_markers()


func _build_ambient_particles() -> void:
	# Intentionally disabled for this first art-direction pass. The former moving
	# pixel motes competed with the block silhouettes and made the hub shimmer.
	pass


func _build_lower_water_terrace() -> void:
	var water_layer := Node2D.new()
	water_layer.name = "LowerWaterTerrace"
	add_child(water_layer)

	for grid_x in range(WATER_MIN, WATER_MAX + 1):
		for grid_y in range(WATER_MIN, WATER_MAX + 1):
			if grid_x >= PLATFORM_MIN and grid_x <= PLATFORM_MAX and grid_y >= PLATFORM_MIN and grid_y <= PLATFORM_MAX:
				continue
			var edge_distance := maxi(absi(grid_x), absi(grid_y))
			if edge_distance > WATER_MAX:
				continue
			var grid := Vector2i(grid_x, grid_y)
			var top_center := _grid_to_world(Vector2(grid)) + Vector2(0.0, 18.0)
			var block := ART.create_block(
				ART.WATER_BLOCK,
				top_center,
				-420 + grid_x + grid_y,
				WATER_TINT
			)
			block.name = "Water_%02d_%02d" % [grid_x, grid_y]
			water_layer.add_child(block)


func _build_recovery_platform() -> void:
	var ground_layer := Node2D.new()
	ground_layer.name = "RecoveryPlatform"
	add_child(ground_layer)

	for grid_x in range(PLATFORM_MIN, PLATFORM_MAX + 1):
		for grid_y in range(PLATFORM_MIN, PLATFORM_MAX + 1):
			var grid := Vector2i(grid_x, grid_y)
			var presentation := _surface_presentation(grid)
			var texture: Texture2D = presentation["texture"]
			var tint: Color = presentation["tint"]
			var block := ART.create_block(
				texture,
				_grid_to_world(Vector2(grid)),
				-160 + grid_x + grid_y,
				tint
			)
			block.name = "%s_%02d_%02d" % [String(presentation["name"]), grid_x, grid_y]
			ground_layer.add_child(block)


func _surface_presentation(grid: Vector2i) -> Dictionary:
	# The diagonal route deliberately connects spawn -> operator -> portal, making
	# the first interaction readable without painting the whole map a different
	# color. The central data pad establishes the digital-world identity.
	if grid == Vector2i(-1, -1):
		return {"name": "DataPad", "texture": ART.DATA_BLOCK, "tint": DATA_TINT}
	if grid.x == grid.y and grid.x >= -3 and grid.x <= 5:
		return {"name": "RecoveryRoute", "texture": ART.WARM_BLOCK, "tint": PATH_TINT}
	if absi(grid.x) <= 1 and absi(grid.y) <= 1:
		return {"name": "CommonsPlaza", "texture": ART.WARM_BLOCK, "tint": PATH_TINT}
	if absi(grid.x) == PLATFORM_MAX or absi(grid.y) == PLATFORM_MAX:
		return {"name": "EdgeGrass", "texture": ART.GRASS_BLOCK, "tint": EDGE_GRASS_TINT}
	return {"name": "Grass", "texture": ART.GRASS_BLOCK, "tint": GRASS_TINT}


func _build_sector_markers() -> void:
	var markers := Node2D.new()
	markers.name = "SectorMarkers"
	add_child(markers)

	# Four paired pylons frame the playable platform without cluttering the route.
	# They sit outside the movement bounds, so they are purely visual landmarks.
	var anchors: Array[Vector2i] = [
		Vector2i(-7, -4), Vector2i(-4, -7),
		Vector2i(7, 4), Vector2i(4, 7),
	]
	for index in range(anchors.size()):
		var grid := anchors[index]
		var top_center := _grid_to_world(Vector2(grid))
		var base_texture := ART.WARM_BLOCK if index % 2 == 0 else ART.DATA_BLOCK
		var cap_texture := ART.DATA_BLOCK if index % 2 == 0 else ART.WARM_BLOCK
		var base_tint := PATH_TINT if index % 2 == 0 else DATA_TINT
		var cap_tint := DATA_TINT if index % 2 == 0 else PATH_TINT

		var base := ART.create_block(base_texture, top_center, 820 + int(round(top_center.y)), base_tint)
		base.name = "MarkerBase%02d" % index
		markers.add_child(base)

		var cap := ART.create_block(cap_texture, top_center, 822 + int(round(top_center.y)), cap_tint, 1)
		cap.name = "MarkerCap%02d" % index
		markers.add_child(cap)
