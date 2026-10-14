extends SceneTree

const Sandbox = preload("res://experiments/darkmoon_sandbox/DarkmoonSandbox.gd")


func _initialize() -> void:
	call_deferred("_bake")


func _region(parent: Node, node_name: String, points: Array) -> Polygon2D:
	var region := Polygon2D.new()
	region.name = node_name
	region.polygon = PackedVector2Array(points)
	region.visible = false
	parent.add_child(region)
	region.owner = parent.owner
	return region


func _entity(parent: Node, node_name: String, at: Vector2, brush: String,
		offset: Vector2, footprint: Array) -> void:
	var entity := Node2D.new()
	entity.name = node_name
	entity.position = at
	entity.set_meta("brush", brush)
	entity.set_meta("art_offset", offset)
	if footprint.is_empty():
		entity.z_index = -5
	parent.add_child(entity)
	entity.owner = parent.owner
	if not footprint.is_empty():
		_region(entity, "Footprint", footprint)
		entity.get_node("Footprint").owner = parent.owner


func _bake() -> void:
	var sandbox := Node2D.new()
	sandbox.name = "DarkmoonSandbox"
	sandbox.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sandbox.set_script(Sandbox)
	var surfaces := Node2D.new()
	surfaces.name = "Walkable"
	sandbox.add_child(surfaces)
	surfaces.owner = sandbox
	# Four road strips form a continuous loop with four deliberate interior voids.
	_region(surfaces, "NortheastRoad", [Vector2(0,-500),Vector2(1000,0),Vector2(640,0),Vector2(0,-320)])
	_region(surfaces, "SoutheastRoad", [Vector2(1000,0),Vector2(0,500),Vector2(0,320),Vector2(640,0)])
	_region(surfaces, "SouthwestRoad", [Vector2(0,500),Vector2(-1000,0),Vector2(-640,0),Vector2(0,320)])
	_region(surfaces, "NorthwestRoad", [Vector2(-1000,0),Vector2(0,-500),Vector2(0,-320),Vector2(-640,0)])
	_region(surfaces, "ArrivalPlaza", [Vector2(0,-180),Vector2(360,0),Vector2(0,180),Vector2(-360,0)])
	_region(surfaces, "EastWestPassage", [Vector2(-900,-48),Vector2(900,-48),Vector2(900,48),Vector2(-900,48)])
	_region(surfaces, "NorthSouthPassage", [Vector2(-72,-440),Vector2(72,-440),Vector2(72,440),Vector2(-72,440)])
	for side in [-1, 1]:
		var region := _region(surfaces, "WestCourt" if side == -1 else "EastCourt",
			[Vector2(0,-160),Vector2(320,0),Vector2(0,160),Vector2(-320,0)])
		region.position.x = side * 750
	var depth := Node2D.new()
	depth.name = "Depth"
	depth.y_sort_enabled = true
	sandbox.add_child(depth)
	depth.owner = sandbox
	var kiosk_base := [Vector2(-76,-28),Vector2(0,-66),Vector2(76,-28),Vector2(0,10)]
	_entity(depth, "WestMarket", Vector2(-750,-72), "pavilion", Vector2(-96,-176), kiosk_base)
	_entity(depth, "EastMarket", Vector2(750,-72), "pavilion", Vector2(-96,-176), kiosk_base)
	_entity(depth, "NorthMarket", Vector2(0,-460), "pavilion", Vector2(-96,-176), kiosk_base)
	var terminal_base := [Vector2(-44,-16),Vector2(0,-38),Vector2(44,-16),Vector2(0,6)]
	_entity(depth, "PlazaTerminal", Vector2.ZERO, "terminal", Vector2(-64,-116), terminal_base)
	_entity(depth, "WestTerminal", Vector2(-750,80), "terminal", Vector2(-64,-116), terminal_base)
	_entity(depth, "EastTerminal", Vector2(750,80), "terminal", Vector2(-64,-116), terminal_base)
	_entity(depth, "SouthTerminal", Vector2(0,472), "terminal", Vector2(-64,-116), terminal_base)
	var light_base := [Vector2(-11,-8),Vector2(0,-14),Vector2(11,-8),Vector2(0,-2)]
	for side in [-1, 1]:
		_entity(depth, "PlazaLight%s" % side, Vector2(side*240,38), "light", Vector2(-32,-120), light_base)
		_entity(depth, "NorthLight%s" % side, Vector2(side*500,-288), "light", Vector2(-32,-120), light_base)
		_entity(depth, "SouthLight%s" % side, Vector2(side*500,288), "light", Vector2(-32,-120), light_base)
	# These shallow visual stairs belong to the same walkable plane.
	_entity(depth, "WestSteps", Vector2(-480,0), "steps", Vector2(-64,-32), [])
	_entity(depth, "EastSteps", Vector2(480,0), "steps", Vector2(-64,-32), [])
	_entity(depth, "ArrivalMedallion", Vector2(0,128), "medallion", Vector2(-64,-64), [])
	for side in [-1, 1]:
		_entity(depth, "CourtWall%s" % side, Vector2(side*920,66), "wall", Vector2(-96,-64),
			[Vector2(-80,-20),Vector2(80,-20),Vector2(80,-5),Vector2(-80,-5)])
	sandbox.bake_tiles()
	var packed := PackedScene.new()
	assert(packed.pack(sandbox) == OK)
	assert(ResourceSaver.save(packed, "res://experiments/darkmoon_sandbox/DarkmoonSandbox.tscn") == OK)
	sandbox.free()
	print("[DarkmoonSandbox] Scene baked")
	quit()
