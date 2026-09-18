extends "res://src/Field.gd"
class_name DevilsWorkshopField

const ART = preload("res://src/world/DevilsWorkshopArt.gd")
const ENVIRONMENT = preload("res://src/world/BattlefieldEnvironment.gd")
const BattlefieldCatalogScript = preload("res://src/world/BattlefieldCatalog.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

const LOWER_LEVEL_OFFSET := 24.0
const BOARD_SKIRT_DEPTH := 24.0

const GRASS_BASE := Color(0.30, 0.52, 0.29, 1.0)
const GRASS_ALT_BASE := Color(0.27, 0.48, 0.27, 1.0)
const GRASS_EDGE_BASE := Color(0.22, 0.40, 0.24, 1.0)
const GRASS_DETAIL := Color(0.92, 1.0, 0.88, 1.0)
const ROUGH_GRASS_BASE := Color(0.24, 0.43, 0.23, 1.0)
const ROUGH_GRASS_DETAIL := Color(0.76, 0.90, 0.70, 1.0)
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

var _catalog: BattlefieldCatalog
var _definition: BattlefieldDefinition


func _ready() -> void:
	_catalog = BattlefieldCatalogScript.new() as BattlefieldCatalog
	if not _catalog.load_default():
		for error in _catalog.validation_errors():
			push_error("Battlefield catalog: %s" % error)
	_definition = _resolve_definition()
	if _definition == null:
		push_error("Battlefield generation cannot continue without a valid definition.")
		return

	configure_grid_size(_definition.grid_size)
	_map_center = _grid_to_raw(Vector2((_grid_size.x - 1) * 0.5, (_grid_size.y - 1) * 0.5))
	_create_board_foundation()
	_create_hover_indicator()
	_generate_terrain()
	print("[Battlefield] %s" % _definition.summary())


func get_battlefield_id() -> String:
	return _definition.battlefield_id if _definition != null else ""


func get_battlefield_display_name() -> String:
	return _definition.display_name if _definition != null else ""


func get_battlefield_definition() -> BattlefieldDefinition:
	return _definition


func get_deployment_cells(player_side: bool) -> Array[Vector2i]:
	return _definition.deployment_cells(player_side) if _definition != null else []


func get_max_supported_footprint_id() -> String:
	return _definition.max_supported_footprint_id() if _definition != null else FootprintScript.LARGE_2X2


func _resolve_definition() -> BattlefieldDefinition:
	var config := _pending_battle_config()
	var preferred_id := String(config.get("battle_map", "")).strip_edges()
	if not preferred_id.is_empty() and _catalog.get_by_id(preferred_id) == null:
		push_warning("Requested battlefield '%s' does not exist; selecting a compatible catalog field." % preferred_id)
		preferred_id = ""

	var player_footprints := _player_footprints()
	var enemy_footprints := _enemy_footprints(config)
	var seed := int(config.get("seed", 0))
	var selected := _catalog.select_for_battle(player_footprints, enemy_footprints, preferred_id, seed)
	if selected == null:
		return _catalog.default_definition()
	return selected


func _pending_battle_config() -> Dictionary:
	var session_config := BattleEncounterSession.peek_pending_encounter()
	if not session_config.is_empty():
		return session_config
	var toolkit := get_node_or_null("/root/DeveloperToolkit")
	if toolkit != null and toolkit.has_method("peek_pending_battle_config"):
		var raw = toolkit.call("peek_pending_battle_config")
		if raw is Dictionary:
			return (raw as Dictionary).duplicate(true)
	return {}


func _player_footprints() -> Array:
	var result: Array = []
	for instance: DigimonInstance in OverworldState.get_battle_ready_active_instances():
		if instance != null:
			result.append(instance.battle_footprint_id)
	return result


func _enemy_footprints(config: Dictionary) -> Array:
	var result: Array = []
	var enemies = config.get("enemy_party", config.get("enemies", []))
	if not enemies is Array:
		return result
	for raw_enemy in enemies:
		if raw_enemy is Dictionary:
			result.append(String((raw_enemy as Dictionary).get("footprint", FootprintScript.SINGLE)))
	return result


func _generate_terrain() -> void:
	tile_map_data.clear()
	_static_blocked_tiles.clear()

	for y in range(_grid_size.y):
		for x in range(_grid_size.x):
			var grid := Vector2i(x, y)
			var world_position := grid_to_world(grid)
			var presentation := _battle_surface(grid)
			var movement_cost := _definition.movement_cost_at(grid)
			tile_map_data[grid] = {
				"type": String(presentation["name"]),
				"world_position": world_position,
				"movement_cost": movement_cost,
			}

			var blocker_kind := _definition.blocker_kind_at(grid)
			if not blocker_kind.is_empty():
				set_static_tile_blocked(grid, "terrain_blocked")
				tile_map_data[grid]["blocked"] = true
				tile_map_data[grid]["blocker_kind"] = blocker_kind

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
	_build_battlefield_environment()
	selectedTile = Vector2i(grid_to_world(Vector2i(_grid_size.x / 2, _grid_size.y / 2)))


func _build_battlefield_environment() -> void:
	var environment := ENVIRONMENT.new() as BattlefieldEnvironment
	environment.name = "BattlefieldEnvironment"
	add_child(environment)
	environment.configure(self, _definition.props)


func _battle_surface(grid: Vector2i) -> Dictionary:
	var surface_type := _definition.surface_type_at(grid)
	match surface_type:
		"data":
			return {
				"name": "data",
				"texture": ART.DATA_BLOCK,
				"base_color": DATA_BASE,
				"detail_tint": DATA_DETAIL,
				"detail_alpha": 0.28,
			}
		"route":
			return {
				"name": "route",
				"texture": ART.WATER_BLOCK,
				"base_color": STAGING_BASE,
				"detail_tint": STAGING_DETAIL,
				"detail_alpha": 0.52,
			}
		"rough_grass":
			return {
				"name": "rough_grass",
				"texture": ART.GRASS_BLOCK,
				"base_color": ROUGH_GRASS_BASE,
				"detail_tint": ROUGH_GRASS_DETAIL,
				"detail_alpha": 0.48,
			}

	if grid.x == 0 or grid.x == _grid_size.x - 1 or grid.y == 0 or grid.y == _grid_size.y - 1:
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
	# Deterministic visual variation only. Gameplay surfaces and costs come from
	# BattlefieldDefinition; this pattern never changes collision or movement.
	var hash_value := absi(grid.x * 31 + grid.y * 17 + _grid_size.x * 7 + _grid_size.y * 11)
	return GRASS_ALT_BASE if hash_value % 13 < 3 else GRASS_BASE


func _build_perimeter_water() -> void:
	var water := Node2D.new()
	water.name = "PerimeterWater"
	add_child(water)

	for x in range(-1, _grid_size.x + 1):
		_add_water_tile(water, Vector2i(x, -1))
		_add_water_tile(water, Vector2i(x, _grid_size.y))
	for y in range(_grid_size.y):
		_add_water_tile(water, Vector2i(-1, y))
		_add_water_tile(water, Vector2i(_grid_size.x, y))


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
