extends Node2D
class_name WorldAreaSection

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")
const TreeAmbientFXScript = preload("res://src/vfx/TreeAmbientFX.gd")
const ActorScript = preload("res://src/world/HubActor.gd")
const InteractableScript = preload("res://src/world/runtime/WorldInteractable.gd")
const OAK_TREE_SOURCE = preload("res://assets/terrain/Oak_Tree.png")
const NPC_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")
const DIGILAB_TEXTURE = preload("res://assets/world/tblack/digilab/digilab.png")
const DIGILAB_DOOR_SEMI_OPEN_TEXTURE = preload("res://assets/world/tblack/digilab/digilab-door-semi-open.png")
const DIGILAB_DOOR_OPEN_TEXTURE = preload("res://assets/world/tblack/digilab/digilab-door-open.png")
const TRAINING_CENTER_TEXTURE = preload("res://assets/world/tblack/training-center/training-center.png")
const HOSPITAL_TEXTURE = preload("res://assets/world/tblack/hospital/hospital.png")

const SECTION_SIZE := 14
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const CITY_CENTER_GLOBAL := Vector2i(7, 7)
const CITY_SHAPE_MANHATTAN_RADIUS := 54
const LARGE_OAK_REGION := Rect2(11.0, 9.0, 41.0, 63.0)
const LARGE_OAK_FOOT := Vector2(20.5, 62.0)
# The authored PNG is close to isometric, but its two ground axes are not an
# exact 2:1 pair. Match the same geometric correction strategy used by the
# Training Center: compress the source Y projection and rotate the complete
# authored structure so both dominant facade/roof axes land on the city's
# exact +/-26.565 degree 64x32 grid.
const DIGILAB_SCALE := Vector2(0.40, 0.31635585)
const DIGILAB_ROTATION_DEGREES := -2.48231
const DIGILAB_BASE_Z := 880
const DIGILAB_UPPER_OCCLUDER_Z := 1800
const DIGILAB_UPPER_OCCLUDER_CUTOFF_Y := 700.0
const DIGILAB_DOOR_FRAME_SECONDS := 0.10
const DIGILAB_DOOR_OPEN_HOLD_SECONDS := 0.14
const DIGILAB_DOOR_PIXEL := Vector2(754.0, 1054.0)
const DIGILAB_DOOR_CELL := Vector2i(8, 10)
const DIGILAB_RETURN_CELL := Vector2i(10, 12)
# Ground-contact footprint measured from the supplied source. The concave notch
# follows the staircase/door opening, so the player can reach the threshold
# while every visible ground-level wall remains solid.
# Additional side guards are intentional movement envelopes for the player
# capsule around the two visually protruding lower wings. The main footprint
# follows ground contact; these guards keep the 64px-tall trainer sprite from
# visually entering the side facades at oblique angles.
const DIGILAB_LEFT_SIDE_GUARD_SOURCE := [
	Vector2(35.0, 690.0),
	Vector2(320.0, 720.0),
	Vector2(470.0, 900.0),
	Vector2(430.0, 1040.0),
	Vector2(300.0, 1090.0),
	Vector2(35.0, 860.0),
]
const DIGILAB_RIGHT_SIDE_GUARD_SOURCE := [
	# Starts below the rear-open pavement. The reviewed penetration happens on
	# the lower utility wing, not on the walkable space behind the lab.
	Vector2(980.0, 760.0),
	Vector2(1210.0, 780.0),
	Vector2(1240.0, 970.0),
	Vector2(1090.0, 1130.0),
	Vector2(920.0, 1120.0),
	Vector2(880.0, 940.0),
]
const DIGILAB_UPPER_RIGHT_GUARD_SOURCE := [
	# Dedicated guard for the cyan antenna / upper-right utility platform seen
	# in playtest. It extends higher than the lower wing guard but deliberately
	# starts to the right of the rear-open pavement around source (925, 671).
	Vector2(1040.0, 625.0),
	Vector2(1165.0, 665.0),
	Vector2(1235.0, 755.0),
	Vector2(1235.0, 900.0),
	Vector2(1170.0, 960.0),
	Vector2(1030.0, 900.0),
	Vector2(970.0, 775.0),
]

const DIGILAB_FOOTPRINT_SOURCE := [
	# Preserve the open pavement behind the lab, then bulge only where the
	# authored right-side utility cluster actually reaches the ground.
	Vector2(635.0, 509.0),
	Vector2(1030.0, 760.0),
	Vector2(1217.0, 895.0),
	# Right facade / utility corner.
	Vector2(1217.0, 947.0),
	Vector2(1160.0, 1015.0),
	Vector2(985.0, 1130.0),
	Vector2(930.0, 1145.0),
	Vector2(890.0, 1115.0),
	Vector2(850.0, 1110.0),
	# Door recess: intentionally cuts inward so the staircase and threshold stay
	# reachable rather than becoming part of the collision hull.
	Vector2(763.0, 957.0),
	Vector2(667.0, 1011.0),
	Vector2(748.0, 1156.0),
	# Front-left facade and utility wing.
	Vector2(635.0, 1230.0),
	Vector2(585.0, 1205.0),
	Vector2(525.0, 1165.0),
	Vector2(490.0, 1130.0),
	Vector2(390.0, 1050.0),
	Vector2(350.0, 1030.0),
	Vector2(305.0, 1050.0),
	Vector2(54.0, 835.0),
	# Small source-silhouette correction for the far-left corner seen in the
	# playtest video, without extending the collision into the pavement behind.
	Vector2(40.0, 850.0),
	Vector2(80.0, 800.0),
]

# The Training Center source is close to the city isometric axes, but its
# authored vertical projection is slightly too tall and the two roof axes are
# not perfectly balanced. Correct both geometrically so the structure follows
# the same +/-26.565 degree 64x32 grid as the surrounding city instead of
# reading as a subtly side-turned building.
const TRAINING_CENTER_SCALE := Vector2(0.36, 0.28231)
const TRAINING_CENTER_ROTATION_DEGREES := -2.20613
const TRAINING_CENTER_BASE_Z := 880
const TRAINING_CENTER_UPPER_OCCLUDER_Z := 1800
const TRAINING_CENTER_UPPER_OCCLUDER_CUTOFF_Y := 720.0
const TRAINING_CENTER_DOOR_PIXEL := Vector2(414.0, 1035.0)
const TRAINING_CENTER_DOOR_CELL := Vector2i(7, 11)
const TRAINING_CENTER_RETURN_CELL := Vector2i(7, 13)
# Ground-contact silhouette measured from the supplied 1254x1254 source. The
# concave door recess deliberately leaves the stairs and entry threshold open.
const TRAINING_CENTER_FOOTPRINT_SOURCE := [
	Vector2(34.0, 790.0),
	Vector2(160.0, 690.0),
	Vector2(350.0, 690.0),
	Vector2(500.0, 620.0),
	Vector2(700.0, 650.0),
	Vector2(910.0, 580.0),
	Vector2(1210.0, 605.0),
	Vector2(1220.0, 855.0),
	Vector2(1000.0, 1030.0),
	Vector2(760.0, 1160.0),
	Vector2(590.0, 1175.0),
	Vector2(520.0, 1120.0),
	Vector2(500.0, 1035.0),
	Vector2(470.0, 980.0),
	Vector2(460.0, 960.0),
	Vector2(360.0, 960.0),
	Vector2(345.0, 985.0),
	Vector2(330.0, 1030.0),
	Vector2(260.0, 1010.0),
	Vector2(180.0, 940.0),
	Vector2(80.0, 870.0),
]

# The Hospital artwork is already authored with the correct internal
# proportions, including its doorway. Never anisotropically squash/stretch this
# sprite to force the city projection: doing so changes the apparent doorway
# height and makes the building read compressed next to the trainer. Preserve
# the source aspect ratio with one uniform render scale, and use only the small
# measured rotation to align its heading to the surrounding isometric grid.
const HOSPITAL_SCALE := Vector2(0.35, 0.35)
const HOSPITAL_ROTATION_DEGREES := -0.87567
const HOSPITAL_BASE_Z := 880
const HOSPITAL_UPPER_OCCLUDER_Z := 1800
const HOSPITAL_UPPER_OCCLUDER_CUTOFF_Y := 650.0
const HOSPITAL_DOOR_PIXEL := Vector2(627.0, 1000.0)
const HOSPITAL_DOOR_CELL := Vector2i(7, 10)
const HOSPITAL_RETURN_CELL := Vector2i(9, 12)
# Measured ground-contact silhouette for the supplied 1254x1254 asset. The
# centered concave recess keeps the stairs and straight-down doorway walkable.
const HOSPITAL_FOOTPRINT_SOURCE := [
	Vector2(54.0, 750.0),
	Vector2(160.0, 670.0),
	Vector2(310.0, 655.0),
	Vector2(430.0, 600.0),
	Vector2(520.0, 585.0),
	Vector2(627.0, 590.0),
	Vector2(735.0, 585.0),
	Vector2(825.0, 600.0),
	Vector2(945.0, 655.0),
	Vector2(1095.0, 670.0),
	Vector2(1200.0, 750.0),
	Vector2(1200.0, 865.0),
	Vector2(1100.0, 940.0),
	Vector2(980.0, 1020.0),
	Vector2(820.0, 1090.0),
	Vector2(735.0, 1110.0),
	Vector2(700.0, 1035.0),
	Vector2(690.0, 930.0),
	Vector2(565.0, 930.0),
	Vector2(555.0, 1035.0),
	Vector2(520.0, 1110.0),
	Vector2(435.0, 1090.0),
	Vector2(275.0, 1020.0),
	Vector2(155.0, 940.0),
	Vector2(55.0, 865.0),
]

var definition: Dictionary = {}
var section_coord := Vector2i.ZERO

var _player: Node2D = null
var _world_controller: Node = null
var _blocked_cells := PackedByteArray()
var _blocked_polygons: Array[PackedVector2Array] = []
var _ground_tiles: Array[Dictionary] = []
var _digilab_building_sprite: Sprite2D = null
var _digilab_upper_sprite: Sprite2D = null
var _digilab_entry_in_progress := false
var _leaf_particles: Array[CPUParticles2D] = []


func configure(section_definition: Dictionary, player: Node2D, world_controller: Node) -> void:
	definition = section_definition.duplicate(true)
	var raw_coord = definition.get("coord", [0, 0])
	section_coord = Vector2i(int(raw_coord[0]), int(raw_coord[1]))
	_player = player
	_world_controller = world_controller
	_blocked_cells.resize(SECTION_SIZE * SECTION_SIZE)
	_blocked_cells.fill(0)
	_blocked_polygons.clear()
	position = grid_to_world(Vector2(section_coord.x * SECTION_SIZE, section_coord.y * SECTION_SIZE))
	name = "Section_%d_%d" % [section_coord.x, section_coord.y]
	_build_section()


func is_walkable_world_position(world_position: Vector2) -> bool:
	var local_position := world_position - global_position
	var local_grid := world_to_grid(local_position)
	var cell := Vector2i(floori(local_grid.x + 0.5), floori(local_grid.y + 0.5))
	if cell.x < 0 or cell.y < 0 or cell.x >= SECTION_SIZE or cell.y >= SECTION_SIZE:
		return false
	if _blocked_cells[cell.y * SECTION_SIZE + cell.x] != 0:
		return false
	for polygon: PackedVector2Array in _blocked_polygons:
		if Geometry2D.is_point_in_polygon(local_position, polygon):
			return false
	return true


func grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_HALF_WIDTH,
		(grid.x + grid.y) * TILE_HALF_HEIGHT
	)


func world_to_grid(world: Vector2) -> Vector2:
	return Vector2(
		world.x / CITY.TILE_WIDTH + world.y / CITY.TILE_HEIGHT,
		-world.x / CITY.TILE_WIDTH + world.y / CITY.TILE_HEIGHT
	)


func _build_section() -> void:
	_prepare_ground_data()
	_build_natural_details()
	_build_theme_content()


func _prepare_ground_data() -> void:
	_ground_tiles.clear()
	var theme := String(definition.get("theme", "residential"))
	for x in range(SECTION_SIZE):
		for y in range(SECTION_SIZE):
			var cell := Vector2i(x, y)
			var presentation := _ground_presentation(cell, theme)
			if not bool(presentation.get("render", true)):
				_mark_blocked(cell)
				continue
			var surface := String(presentation.get("surface", CITY.SURFACE_MAIN))
			var global_grid := _global_grid(cell)
			_ground_tiles.append({
				"surface": surface,
				"position": position + grid_to_world(Vector2(cell)),
				"base_color": presentation.get("base_color", CITY.surface_base_color(surface)),
				"detail_tint": presentation.get("detail_tint", Color.WHITE),
				"detail_alpha": float(presentation.get("detail_alpha", 1.0)),
				"edge": _is_global_city_edge(global_grid),
			})
			if not bool(presentation.get("walkable", true)):
				_mark_blocked(cell)


func append_ground_tiles(target: Array[Dictionary]) -> void:
	target.append_array(_ground_tiles)


func _ground_presentation(cell: Vector2i, theme: String) -> Dictionary:
	var global_grid := _global_grid(cell)
	if not _is_global_city_land(global_grid):
		return {"render": false, "walkable": false}

	var delta := global_grid - CITY_CENTER_GLOBAL
	var ax := absi(delta.x)
	var ay := absi(delta.y)
	var city_ring := maxi(ax, ay)

	# Central Plaza is one authored civic space instead of a patchwork of
	# district materials: 0064 pool, a single teal rim, then 0054 pavement.
	if ax <= 1 and ay <= 1:
		return {"surface": CITY.SURFACE_WATER, "walkable": false}
	if city_ring == 2:
		return {"surface": CITY.SURFACE_TECH_TEAL, "walkable": true}
	if city_ring <= 6:
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}

	# City structure is defined before district styling. A wide north/south and
	# east/west promenade crosses the whole island, while every 14x14 authoring
	# section contributes a one-cell 0054 sidewalk around its lot. Neighbouring
	# sections therefore form coherent two-cell streets between city blocks.
	if ax <= 1 or ay <= 1:
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
	if _is_block_sidewalk(cell):
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}

	# Authored service exteriors use the neutral 0054 city pavement instead of
	# temporary colored service pads. DigiLab keeps its explicit door forecourt;
	# Training uses the same neutral pavement across its whole authored lot.
	if theme == "digilab" and _is_digilab_pavement(cell):
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}

	# Services without dedicated exterior art retain the temporary paved cross.
	if theme not in ["digilab", "training", "hospital"] and _is_service_district(theme) and _is_service_walkway(cell):
		return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}

	match theme:
		"garden":
			# Parks are bounded rectangles: mint edging, green interior and one
			# consistent checker cross. No coordinate hash/random alternation.
			var garden_border := cell.x in [2, 11] or cell.y in [2, 11]
			var garden_cross := cell.x in [6, 7] or cell.y in [6, 7]
			if garden_border:
				return {"surface": CITY.SURFACE_MINT, "walkable": true}
			if garden_cross:
				return {"surface": CITY.SURFACE_GRASS_CHECKER, "walkable": true}
			return {"surface": CITY.SURFACE_GRASS, "walkable": true}
		"digilab":
			return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
		"hospital":
			return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
		"training":
			return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
		"market":
			return {"surface": CITY.SURFACE_MARKET, "walkable": true}
		"archive":
			return {"surface": CITY.SURFACE_TECH_PURPLE, "walkable": true}
		"gate":
			# Gate wards stay sober and directional: dark buildable lots with a
			# 0054 central outbound lane.
			if cell.x in [6, 7] or cell.y in [6, 7]:
				return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
			return {"surface": CITY.SURFACE_DARK, "walkable": true}
		"canal":
			# A rectangular canal crosses the block. The center two columns form
			# the permanent 0054 bridge, keeping the route legible.
			if cell.y >= 5 and cell.y <= 8 and cell.x >= 2 and cell.x <= 11:
				if cell.x in [6, 7]:
					return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
				return {"surface": CITY.SURFACE_WATER, "walkable": false}
			return {"surface": CITY.SURFACE_MAIN, "walkable": true}
		"plaza":
			return {"surface": CITY.SURFACE_STONE_SOFT, "walkable": true}
		_:
			# 0072 is the neutral city-lot material. Residential and future
			# establishment blocks stay as large contiguous pads rather than
			# being sprinkled with unrelated surfaces.
			return {"surface": CITY.SURFACE_MAIN, "walkable": true}


func _is_block_sidewalk(cell: Vector2i) -> bool:
	return cell.x in [0, SECTION_SIZE - 1] or cell.y in [0, SECTION_SIZE - 1]


func _is_digilab_pavement(cell: Vector2i) -> bool:
	if cell.y in [10, 11] and cell.x >= 5 and cell.x <= 11:
		return true
	return cell in [Vector2i(9, 11), Vector2i(10, 12), Vector2i(11, 13)]


func _is_service_district(theme: String) -> bool:
	return theme in ["digilab", "hospital", "training", "market", "archive"]


func _is_service_walkway(cell: Vector2i) -> bool:
	return cell.x in [6, 7] or cell.y in [6, 7]


func _global_grid(cell: Vector2i) -> Vector2i:
	return section_coord * SECTION_SIZE + cell


func _is_global_city_land(global_grid: Vector2i) -> bool:
	var delta := global_grid - CITY_CENTER_GLOBAL
	var ax := absi(delta.x)
	var ay := absi(delta.y)
	return ax <= 34 and ay <= 34 and ax + ay <= CITY_SHAPE_MANHATTAN_RADIUS


func _is_global_city_edge(global_grid: Vector2i) -> bool:
	if not _is_global_city_land(global_grid):
		return false
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not _is_global_city_land(global_grid + step):
			return true
	return false


func _is_city_land(cell: Vector2i) -> bool:
	return _is_global_city_land(_global_grid(cell))


func _build_natural_details() -> void:
	var props := Node2D.new()
	props.name = "NaturalDetails"
	add_child(props)
	var theme := String(definition.get("theme", "residential"))
	var tree_cells: Array[Vector2i] = []
	match theme:
		"garden":
			tree_cells = [Vector2i(2, 2), Vector2i(11, 2), Vector2i(2, 11), Vector2i(11, 11)]
		"plaza":
			tree_cells = [Vector2i(2, 11), Vector2i(11, 2)]
		"canal":
			tree_cells = [Vector2i(2, 10), Vector2i(11, 10)]
		"residential":
			tree_cells = [Vector2i(2, 11)]
		_:
			tree_cells = []
	for index in range(tree_cells.size()):
		_add_tree(props, tree_cells[index], index)


func _build_theme_content() -> void:
	var theme := String(definition.get("theme", "residential"))
	match theme:
		"plaza":
			_spawn_npc(Vector2i(5, 9), "CITY GUIDE", "guide", "TALK", 20)
		"digilab":
			_build_digilab_exterior()
		"hospital":
			_build_hospital_exterior()
		"training":
			_build_training_center_exterior()
		"market":
			_build_service_pad(Color(0.42, 1.0, 0.52), "DATA MARKET", "shop", CITY.SURFACE_MARKET)
		"archive":
			_build_service_pad(Color(0.72, 0.52, 1.0), "DIGITAL ARCHIVE", "archive", CITY.SURFACE_TECH_PURPLE)


func _build_digilab_exterior() -> void:
	if not _is_city_land(DIGILAB_DOOR_CELL):
		return

	var exterior := Node2D.new()
	exterior.name = "DigiLabExterior"
	add_child(exterior)

	var door_world := grid_to_world(Vector2(DIGILAB_DOOR_CELL))
	var sprite := _create_digilab_sprite(
		"Building",
		door_world,
		Rect2(),
		DIGILAB_BASE_Z
	)
	_digilab_building_sprite = sprite
	exterior.add_child(sprite)

	# One full-image sprite cannot represent a large isometric building correctly
	# with a single Y-sort threshold: players at the lower-left exterior could be
	# placed behind the whole PNG even though they were standing in front of the
	# facade. Keep the full building below actors, then render only the genuinely
	# upper/back portion as a dedicated occlusion layer.
	var upper_region := Rect2(
		Vector2.ZERO,
		Vector2(float(DIGILAB_TEXTURE.get_width()), DIGILAB_UPPER_OCCLUDER_CUTOFF_Y)
	)
	var upper_occluder := _create_digilab_sprite(
		"UpperOccluder",
		door_world,
		upper_region,
		DIGILAB_UPPER_OCCLUDER_Z
	)
	_digilab_upper_sprite = upper_occluder
	exterior.add_child(upper_occluder)

	var door_marker := Marker2D.new()
	door_marker.name = "DoorAnchor"
	door_marker.position = door_world
	exterior.add_child(door_marker)

	# Use the same measured source footprint for both world walkability and
	# physics. This replaces the old rectangular cell approximation, which was
	# too large behind the lab and too small along the lower-left wall.
	var footprint := _digilab_footprint(door_world)
	_register_blocking_polygon(exterior, "FootprintCollision", footprint)
	_register_blocking_polygon(
		exterior,
		"LeftSideGuardCollision",
		_digilab_source_polygon_to_local(DIGILAB_LEFT_SIDE_GUARD_SOURCE, door_world)
	)
	_register_blocking_polygon(
		exterior,
		"RightSideGuardCollision",
		_digilab_source_polygon_to_local(DIGILAB_RIGHT_SIDE_GUARD_SOURCE, door_world)
	)
	_register_blocking_polygon(
		exterior,
		"UpperRightGuardCollision",
		_digilab_source_polygon_to_local(DIGILAB_UPPER_RIGHT_GUARD_SOURCE, door_world)
	)

	var entrance := _create_service_threshold(
		"DigiLabEntrance",
		"digilab",
		"DIGILAB",
		Color(0.28, 0.88, 1.0),
		DIGILAB_DOOR_CELL,
		DIGILAB_RETURN_CELL,
		14.0
	)
	exterior.add_child(entrance)


func _build_training_center_exterior() -> void:
	if not _is_city_land(TRAINING_CENTER_DOOR_CELL):
		return

	var exterior := Node2D.new()
	exterior.name = "TrainingCenterExterior"
	add_child(exterior)

	var door_world := grid_to_world(Vector2(TRAINING_CENTER_DOOR_CELL))
	var building := _create_training_center_sprite(
		"Building",
		door_world,
		Rect2(),
		TRAINING_CENTER_BASE_Z
	)
	exterior.add_child(building)

	# Match the DigiLab depth contract: the complete facade stays below actors,
	# while only the roof/back half can occlude actors walking behind the building.
	var upper_region := Rect2(
		Vector2.ZERO,
		Vector2(float(TRAINING_CENTER_TEXTURE.get_width()), TRAINING_CENTER_UPPER_OCCLUDER_CUTOFF_Y)
	)
	var upper_occluder := _create_training_center_sprite(
		"UpperOccluder",
		door_world,
		upper_region,
		TRAINING_CENTER_UPPER_OCCLUDER_Z
	)
	exterior.add_child(upper_occluder)

	var door_marker := Marker2D.new()
	door_marker.name = "DoorAnchor"
	door_marker.position = door_world
	exterior.add_child(door_marker)

	_register_blocking_polygon(
		exterior,
		"FootprintCollision",
		_training_center_footprint(door_world)
	)

	var entrance := _create_service_threshold(
		"TrainingCenterEntrance",
		"training",
		"TRAINING CENTER",
		Color(0.27, 0.84, 1.0),
		TRAINING_CENTER_DOOR_CELL,
		TRAINING_CENTER_RETURN_CELL,
		18.0
	)
	exterior.add_child(entrance)


func _build_hospital_exterior() -> void:
	if not _is_city_land(HOSPITAL_DOOR_CELL):
		return

	var exterior := Node2D.new()
	exterior.name = "HospitalExterior"
	add_child(exterior)

	var door_world := grid_to_world(Vector2(HOSPITAL_DOOR_CELL))
	var building := _create_hospital_sprite(
		"Building",
		door_world,
		Rect2(),
		HOSPITAL_BASE_Z
	)
	exterior.add_child(building)

	# Use the same foreground/upper split as the other authored city services:
	# the facade remains below nearby actors, while the roof and rear medical
	# tower can occlude actors correctly when they walk behind the hospital.
	var upper_region := Rect2(
		Vector2.ZERO,
		Vector2(float(HOSPITAL_TEXTURE.get_width()), HOSPITAL_UPPER_OCCLUDER_CUTOFF_Y)
	)
	var upper_occluder := _create_hospital_sprite(
		"UpperOccluder",
		door_world,
		upper_region,
		HOSPITAL_UPPER_OCCLUDER_Z
	)
	exterior.add_child(upper_occluder)

	var door_marker := Marker2D.new()
	door_marker.name = "DoorAnchor"
	door_marker.position = door_world
	exterior.add_child(door_marker)

	_register_blocking_polygon(
		exterior,
		"FootprintCollision",
		_hospital_footprint(door_world)
	)

	var entrance := _create_service_threshold(
		"HospitalEntrance",
		"hospital",
		"DIGI HOSPITAL",
		Color(0.28, 0.92, 0.96),
		HOSPITAL_DOOR_CELL,
		HOSPITAL_RETURN_CELL,
		18.0
	)
	exterior.add_child(entrance)


func _create_hospital_sprite(
	node_name: String,
	door_world: Vector2,
	source_region: Rect2,
	depth: int
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = HOSPITAL_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = HOSPITAL_SCALE
	sprite.rotation_degrees = HOSPITAL_ROTATION_DEGREES
	sprite.z_index = depth

	var texture_center := HOSPITAL_TEXTURE.get_size() * 0.5
	var authored_door_offset := (
		(HOSPITAL_DOOR_PIXEL - texture_center) * HOSPITAL_SCALE
	).rotated(sprite.rotation)
	var full_position := door_world - authored_door_offset

	if source_region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = source_region
		var region_center := source_region.position + source_region.size * 0.5
		var region_center_offset := (
			(region_center - texture_center) * HOSPITAL_SCALE
		).rotated(sprite.rotation)
		sprite.position = full_position + region_center_offset
	else:
		sprite.position = full_position
	return sprite


func _hospital_footprint(door_world: Vector2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for source_point: Vector2 in HOSPITAL_FOOTPRINT_SOURCE:
		polygon.append(_hospital_source_to_local(source_point, door_world))
	return polygon


func _hospital_source_to_local(source_pixel: Vector2, door_world: Vector2) -> Vector2:
	var scaled := (source_pixel - HOSPITAL_DOOR_PIXEL) * HOSPITAL_SCALE
	return door_world + scaled.rotated(deg_to_rad(HOSPITAL_ROTATION_DEGREES))


func _create_training_center_sprite(
	node_name: String,
	door_world: Vector2,
	source_region: Rect2,
	depth: int
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = TRAINING_CENTER_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = TRAINING_CENTER_SCALE
	sprite.rotation_degrees = TRAINING_CENTER_ROTATION_DEGREES
	sprite.z_index = depth

	var texture_center := TRAINING_CENTER_TEXTURE.get_size() * 0.5
	var authored_door_offset := (
		(TRAINING_CENTER_DOOR_PIXEL - texture_center) * TRAINING_CENTER_SCALE
	).rotated(sprite.rotation)
	var full_position := door_world - authored_door_offset

	if source_region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = source_region
		var region_center := source_region.position + source_region.size * 0.5
		var region_center_offset := (
			(region_center - texture_center) * TRAINING_CENTER_SCALE
		).rotated(sprite.rotation)
		sprite.position = full_position + region_center_offset
	else:
		sprite.position = full_position
	return sprite


func _training_center_footprint(door_world: Vector2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for source_point: Vector2 in TRAINING_CENTER_FOOTPRINT_SOURCE:
		polygon.append(_training_center_source_to_local(source_point, door_world))
	return polygon


func _training_center_source_to_local(source_pixel: Vector2, door_world: Vector2) -> Vector2:
	var scaled := (source_pixel - TRAINING_CENTER_DOOR_PIXEL) * TRAINING_CENTER_SCALE
	return door_world + scaled.rotated(deg_to_rad(TRAINING_CENTER_ROTATION_DEGREES))


func _create_digilab_sprite(
	node_name: String,
	door_world: Vector2,
	source_region: Rect2,
	depth: int
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = DIGILAB_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = DIGILAB_SCALE
	sprite.rotation_degrees = DIGILAB_ROTATION_DEGREES
	sprite.z_index = depth

	var texture_center := DIGILAB_TEXTURE.get_size() * 0.5
	var authored_door_offset := (
		(DIGILAB_DOOR_PIXEL - texture_center) * DIGILAB_SCALE
	).rotated(sprite.rotation)
	var full_position := door_world - authored_door_offset

	if source_region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = source_region
		var region_center := source_region.position + source_region.size * 0.5
		var region_center_offset := (
			(region_center - texture_center) * DIGILAB_SCALE
		).rotated(sprite.rotation)
		sprite.position = full_position + region_center_offset
	else:
		sprite.position = full_position
	return sprite


func _digilab_footprint(door_world: Vector2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for source_point: Vector2 in DIGILAB_FOOTPRINT_SOURCE:
		polygon.append(_digilab_source_to_local(source_point, door_world))
	return polygon


func _digilab_source_polygon_to_local(
	source_polygon: Array,
	door_world: Vector2
) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for raw_point in source_polygon:
		if raw_point is Vector2:
			polygon.append(_digilab_source_to_local(raw_point as Vector2, door_world))
	return polygon


func _digilab_source_to_local(source_pixel: Vector2, door_world: Vector2) -> Vector2:
	var scaled := (source_pixel - DIGILAB_DOOR_PIXEL) * DIGILAB_SCALE
	return door_world + scaled.rotated(deg_to_rad(DIGILAB_ROTATION_DEGREES))


func _register_blocking_polygon(
	parent: Node2D,
	node_name: String,
	polygon: PackedVector2Array
) -> void:
	_blocked_polygons.append(polygon)

	var body := StaticBody2D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D"
	collision.polygon = polygon
	body.add_child(collision)


func _build_service_pad(accent: Color, title: String, service_id: String, surface: String) -> void:
	var pad_cell := Vector2i(7, 7)
	if not _is_city_land(pad_cell):
		return
	var approach_cell := pad_cell + Vector2i(1, 0)

	var entrance := _create_service_threshold(
		"%sPad" % title.capitalize().replace(" ", ""),
		service_id,
		title,
		accent,
		pad_cell,
		approach_cell,
		17.0
	)
	add_child(entrance)

	var pad := CITY.create_surface_tile(surface, Vector2.ZERO, 0, 1.0)
	pad.name = "ServicePadSurface"
	entrance.add_child(pad)

	var label := Label.new()
	label.text = title
	label.position = Vector2(-76.0, -52.0)
	label.size = Vector2(152.0, 22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", accent.lightened(0.15))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 4
	entrance.add_child(label)


func _create_service_threshold(
	node_name: String,
	service_id: String,
	title: String,
	accent: Color,
	cell: Vector2i,
	return_cell: Vector2i,
	radius: float
) -> Area2D:
	var entrance := Area2D.new()
	entrance.name = node_name
	entrance.add_to_group("world_interior_threshold")
	entrance.position = grid_to_world(Vector2(cell))
	entrance.collision_layer = 0
	entrance.collision_mask = 1
	entrance.monitoring = true
	entrance.monitorable = false

	var threshold_shape := CollisionShape2D.new()
	var threshold_circle := CircleShape2D.new()
	threshold_circle.radius = radius
	threshold_shape.shape = threshold_circle
	threshold_shape.position = Vector2(0.0, -6.0)
	entrance.add_child(threshold_shape)

	var return_world := global_position + grid_to_world(Vector2(return_cell))
	var interior_id := "%s_%d_%d" % [service_id, section_coord.x, section_coord.y]
	entrance.set_meta("interior_payload", {
		"interior_id": interior_id,
		"service": service_id,
		"title": title,
		"accent": [accent.r, accent.g, accent.b, accent.a],
		"return_position": [return_world.x, return_world.y],
	})
	entrance.body_entered.connect(_on_interior_threshold_entered.bind(entrance))
	return entrance


func _on_interior_threshold_entered(body: Node2D, entrance: Area2D) -> void:
	if body != _player or _world_controller == null:
		return
	if not _world_controller.has_method("request_interior_entry"):
		return
	var payload = entrance.get_meta("interior_payload", {})
	if not payload is Dictionary:
		return
	var destination := payload as Dictionary
	if String(destination.get("service", "")) == "digilab":
		if _digilab_entry_in_progress:
			return
		_animate_digilab_entry(entrance, destination.duplicate(true))
		return
	_world_controller.call_deferred("request_interior_entry", destination.duplicate(true))


func _animate_digilab_entry(entrance: Area2D, payload: Dictionary) -> void:
	_digilab_entry_in_progress = true
	var player_actor := _player as HubActor
	var previous_movement_enabled := true
	if player_actor != null:
		previous_movement_enabled = player_actor.movement_enabled
		player_actor.movement_enabled = false
		player_actor.velocity = Vector2.ZERO

	# Closed is the idle frame. Crossing the authored doorway advances through
	# the two supplied frames before the seamless interior handoff.
	_set_digilab_door_texture(DIGILAB_DOOR_SEMI_OPEN_TEXTURE)
	await get_tree().create_timer(DIGILAB_DOOR_FRAME_SECONDS).timeout
	if not is_inside_tree():
		return
	_set_digilab_door_texture(DIGILAB_DOOR_OPEN_TEXTURE)
	await get_tree().create_timer(DIGILAB_DOOR_OPEN_HOLD_SECONDS).timeout
	if not is_inside_tree():
		return

	if player_actor != null:
		player_actor.movement_enabled = previous_movement_enabled
	if _world_controller != null and _world_controller.has_method("request_interior_entry"):
		_world_controller.call_deferred("request_interior_entry", payload)

	# Keep the exterior on the fully-open frame while the player is inside.
	# Closing is a separate return animation driven by WorldInteriorManager after
	# the city is visible again.
	_digilab_entry_in_progress = false
	entrance.set_deferred("monitoring", true)


func handles_service(service_id: String) -> bool:
	return String(definition.get("theme", "")) == service_id


func play_service_return_animation(service_id: String) -> void:
	if service_id != "digilab" or not handles_service(service_id):
		return
	if _digilab_building_sprite == null or not is_instance_valid(_digilab_building_sprite):
		return

	# The exterior stayed on the open frame while the interior was active.
	# Once the city has been revealed again, close the same authored doorway in
	# reverse order so entering and leaving read as one continuous interaction.
	_set_digilab_door_texture(DIGILAB_DOOR_OPEN_TEXTURE)
	await get_tree().create_timer(DIGILAB_DOOR_OPEN_HOLD_SECONDS).timeout
	if not is_inside_tree():
		return
	_set_digilab_door_texture(DIGILAB_DOOR_SEMI_OPEN_TEXTURE)
	await get_tree().create_timer(DIGILAB_DOOR_FRAME_SECONDS).timeout
	if not is_inside_tree():
		return
	_set_digilab_door_texture(DIGILAB_TEXTURE)


func _set_digilab_door_texture(texture: Texture2D) -> void:
	if _digilab_building_sprite != null and is_instance_valid(_digilab_building_sprite):
		_digilab_building_sprite.texture = texture
	if _digilab_upper_sprite != null and is_instance_valid(_digilab_upper_sprite):
		_digilab_upper_sprite.texture = texture


func _spawn_npc(cell: Vector2i, title: String, action_id: String, prompt_text: String, interaction_priority: int) -> void:
	if not _is_city_land(cell):
		return
	var actor := ActorScript.new() as HubActor
	actor.name = title.capitalize().replace(" ", "")
	actor.configure(NPC_TEXTURE, false, _world_controller, "southwest")
	actor.position = grid_to_world(Vector2(cell))
	add_child(actor)

	var label := Label.new()
	label.text = title
	label.position = Vector2(-78.0, -84.0)
	label.size = Vector2(156.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.74, 0.96, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	actor.add_child(label)

	var interactable := InteractableScript.new() as WorldInteractable
	interactable.configure(action_id, prompt_text, {"speaker": title}, 82.0, interaction_priority)
	actor.add_child(interactable)
	_mark_blocked(cell)


func _add_tree(parent: Node2D, cell: Vector2i, index: int) -> void:
	if not _is_city_land(cell):
		return
	var foot := grid_to_world(Vector2(cell))
	var texture := AtlasTexture.new()
	texture.atlas = OAK_TREE_SOURCE
	texture.region = LARGE_OAK_REGION
	var tree := Sprite2D.new()
	tree.name = "Oak_%d_%d" % [cell.x, cell.y]
	tree.texture = texture
	tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var center_to_foot := LARGE_OAK_FOOT - texture.get_size() * 0.5
	tree.position = foot + Vector2(0.0, 10.0) - center_to_foot
	tree.z_index = 1000 + int(round(global_position.y + foot.y))
	parent.add_child(tree)
	TreeAmbientFXScript.apply(
		tree,
		float(index) * 1.37 + float(section_coord.x * 3 + section_coord.y),
		2.8,
		4,
		Color(0.62, 0.91, 0.39, 0.72)
	)
	var leaves := tree.get_node_or_null("AmbientLeaves") as CPUParticles2D
	if leaves != null:
		_leaf_particles.append(leaves)
	_mark_blocked(cell)


func set_ambient_vfx_active(active: bool) -> void:
	for leaves: CPUParticles2D in _leaf_particles:
		if leaves == null or not is_instance_valid(leaves):
			continue
		leaves.visible = active
		leaves.emitting = active


func _mark_blocked(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= SECTION_SIZE or cell.y >= SECTION_SIZE:
		return
	_blocked_cells[cell.y * SECTION_SIZE + cell.x] = 1
