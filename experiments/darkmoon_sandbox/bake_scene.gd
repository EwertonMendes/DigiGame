extends SceneTree

const Sandbox = preload("res://experiments/darkmoon_sandbox/DarkmoonSandbox.gd")
const Guide = preload("res://experiments/darkmoon_sandbox/CityGuide.gd")
const Piece = preload("res://experiments/darkmoon_sandbox/CityPiece.gd")
const GUIDE_TEXTURE = preload("res://assets/characters/koromon/field.png")
const OUTLINE := [Vector2(0,-576),Vector2(1152,0),Vector2(0,576),Vector2(-1152,0)]
var scene: Node2D


func _initialize() -> void:
	call_deferred("_bake")


func _node(parent: Node, node: Node, node_name: String) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = scene
	return node


func _polygon(parent: Node, node_name: String, points: Array, color: Color, visible := true) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array(points)
	polygon.color = color
	polygon.visible = visible
	_node(parent, polygon, node_name)
	return polygon


func _line(parent: Node, node_name: String, points: Array, color: Color, width := 2.0) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array(points)
	line.default_color = color
	line.width = width
	line.antialiased = false
	_node(parent, line, node_name)


func _surface(parent: Node, node_name: String, points: Array, brush: String, depth: int) -> Polygon2D:
	var mask := _polygon(parent, node_name, points, Color.WHITE)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.z_index = depth
	mask.set_meta("surface_brush", brush)
	return mask


func _entity(parent: Node, node_name: String, at: Vector2, brush: String,
		offset: Vector2, footprint: Array, silhouette: Array = []) -> Node2D:
	var entity := Node2D.new()
	entity.position = at
	entity.set_meta("brush", brush)
	entity.set_meta("art_offset", offset)
	if not silhouette.is_empty():
		entity.set_meta("art_mask", PackedVector2Array(silhouette))
	if footprint.is_empty():
		entity.z_index = -6
	_node(parent, entity, node_name)
	if not footprint.is_empty():
		_polygon(entity, "Footprint", footprint, Color("e94472"), false)
		var min_y := INF
		var max_y := -INF
		for point: Vector2 in footprint:
			min_y = minf(min_y,point.y)
			max_y = maxf(max_y,point.y)
		entity.z_index = 1000 + roundi(at.y+(min_y+max_y)*0.5)
	return entity


func _building(parent: Node, node_name: String, at: Vector2, title: String) -> void:
	var base := [Vector2(-192,-96),Vector2(32,-208),Vector2(224,-112),Vector2.ZERO]
	var face := [Vector2(-192,-208),Vector2(0,-112),Vector2(224,-224),
		Vector2(224,-112),Vector2.ZERO,Vector2(-192,-96)]
	var entity := _entity(parent, node_name, at, "facade", Vector2(-192,-208), base, face)
	var roof_points := [Vector2(-192,-208),Vector2(32,-320),Vector2(224,-224),Vector2(0,-112)]
	var roof := _polygon(entity,"Roof",roof_points,Color.WHITE)
	roof.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var roof_piece := _entity(roof,"RoofPieces",Vector2.ZERO,
		"roof_blue" if title == "DIGILAB" else "roof_orange",Vector2(-192,-328),[])
	roof_piece.z_index = 0
	var sign := Label.new()
	sign.text = title
	sign.position = Vector2(-146,-154)
	sign.add_theme_color_override("font_color", Color("f9effb"))
	sign.add_theme_font_size_override("font_size", 13)
	_node(entity, sign, "Sign")
	entity.set_meta("service_label", title)
	entity.set_meta("service_point", Vector2(-92,-18))
	entity.set_meta("service_text", "A research station for growing partners. The terminal hums behind the closed gate." if title == "DIGILAB" else "Supplies are arriving. The vendor is preparing the western courtyard.")


func _bake() -> void:
	scene = Node2D.new()
	scene.name = "DarkmoonSandbox"
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.set_script(Sandbox)
	var walkable := _node(scene, Node2D.new(), "Walkable")
	_polygon(walkable, "CityPlatform", OUTLINE, Color.WHITE, false)
	# One continuous platform, smooth authored edges, and a visible supporting face.
	var base := _node(scene, Node2D.new(), "PlatformBase") as Node2D
	base.z_index = -30
	_polygon(base, "WestFace", [Vector2(-1152,0),Vector2(0,576),Vector2(0,624),Vector2(-1152,48)], Color("7a1f76"))
	_polygon(base, "EastFace", [Vector2(0,576),Vector2(1152,0),Vector2(1152,48),Vector2(0,624)], Color("471044"))
	_line(base, "LowerRim", [Vector2(-1152,48),Vector2(0,624),Vector2(1152,48)], Color("bd58bb"), 4)
	var ground := _surface(scene, "GroundMask", OUTLINE, "floor", -20)
	# Matching isometric courses replace arbitrary diagonal fragments in square cells.
	for index in range(-14,15):
		var x := index * 128
		_line(ground, "CourseA%d" % (index+14), [Vector2(x-1600,-800),Vector2(x+1600,800)], Color("b665c5"), 2)
		_line(ground, "CourseB%d" % (index+14), [Vector2(x+1600,-800),Vector2(x-1600,800)], Color("b665c5"), 2)
	var rim := _node(scene, Node2D.new(), "PlatformRim") as Node2D
	rim.z_index = -15
	_line(rim, "Edge", OUTLINE + [OUTLINE[0]], Color("d978d6"), 8)
	_line(rim, "InnerEdge", OUTLINE + [OUTLINE[0]], Color("662369"), 2)
	var courts := _node(scene, Node2D.new(), "Courts")
	var outer := [Vector2(0,-176),Vector2(352,0),Vector2(0,176),Vector2(-352,0)]
	var inner := [Vector2(0,-144),Vector2(288,0),Vector2(0,144),Vector2(-288,0)]
	for index in range(4):
		var next := (index+1)%4
		_surface(courts,"FountainWalk%d" % index,[outer[index],outer[next],inner[next],inner[index]],"court",-12)
	for side in [-1,1]:
		_surface(courts,"CourtLink%d" % side,[Vector2(side*320,-16),Vector2(side*512,80),
			Vector2(side*464,104),Vector2(side*272,8)],"court",-12)
	for side in [-1,1]:
		var court_points := [Vector2(side*560,8),Vector2(side*560+192,104),
			Vector2(side*560,200),Vector2(side*560-192,104)]
		_surface(courts, "MarketCourt" if side == -1 else "DataCourt", court_points, "court", -12)
		_line(courts, "CourtBorder%d" % side, court_points+[court_points[0]], Color("715484"), 4)
	var depth := _node(scene, Node2D.new(), "Depth") as Node2D
	depth.y_sort_enabled = true
	_building(depth, "DigiLab", Vector2(0,-232), "DIGILAB")
	_building(depth, "Market", Vector2(-560,48), "MARKET")
	var bench_shape := [Vector2(-48,-24),Vector2(128,-112),Vector2(176,-88),Vector2.ZERO]
	var bench_mask := [Vector2(-48,-84),Vector2(-16,-100),Vector2(-16,-116),Vector2(48,-116),
		Vector2(48,-112),Vector2(96,-136),Vector2(96,-152),Vector2(144,-152),
		Vector2(144,-120),Vector2(176,-120),Vector2(176,-48),Vector2.ZERO,Vector2(-48,-24)]
	_entity(depth, "MarketCounter", Vector2(-648,144), "bench", Vector2(-48,-152), bench_shape, bench_mask)
	var guide := _node(depth, Node2D.new(), "KoromonGuide") as Node2D
	guide.position = Vector2(-552,128)
	guide.z_index = 1128
	guide.set_script(Guide)
	guide.set_meta("service_label", "Koromon")
	guide.set_meta("service_text", "Welcome to Moonrise Commons! Take the path around the fountain, then visit the eastern court. Its display shows the whole district.")
	_polygon(guide, "Footprint", [Vector2(-14,-8),Vector2(0,-16),Vector2(14,-8),Vector2.ZERO], Color.WHITE, false)
	var shadow_points: Array = []
	for index in range(24):
		shadow_points.append(Vector2(cos(index*TAU/24)*18,sin(index*TAU/24)*5-2))
	_polygon(guide, "Shadow", shadow_points, Color(0.16,0.05,0.23,0.25))
	var body := Sprite2D.new()
	body.texture = GUIDE_TEXTURE
	body.hframes = 12
	body.position = Vector2(0,-32)
	body.scale = Vector2(2,2)
	_node(guide, body, "Body")
	var pool_mask := [Vector2(-256,0),Vector2(0,-128),Vector2(256,0),Vector2(0,128)]
	var pool_base := [Vector2(-240,0),Vector2(0,-120),Vector2(240,0),Vector2(0,120)]
	var pool := _entity(depth, "Fountain", Vector2.ZERO, "pool", Vector2(-320,-160), pool_base, pool_mask)
	pool.z_index = -5
	_line(pool, "BasinRim", pool_mask+[pool_mask[0]], Color("c581ad"), 10)
	_line(pool, "BasinInset", pool_mask+[pool_mask[0]], Color("efe5f4"), 2)
	var terminal_shape := [Vector2(-58,-28),Vector2(0,-57),Vector2(58,-28),Vector2.ZERO]
	var terminal_mask := [Vector2(-64,-80),Vector2(0,-112),Vector2(64,-80),
		Vector2(64,-32),Vector2.ZERO,Vector2(-64,-32)]
	for item in [
		["DataTerminalA",Vector2(536,72)], ["DataTerminalB",Vector2(672,128)]]:
		var terminal := _entity(depth, item[0], item[1], "terminal", Vector2(-64,-112), terminal_shape, terminal_mask)
		terminal.set_meta("service_label","Data console")
		terminal.set_meta("service_text","The console displays a directory of this district. This experimental console does not modify the owned roster.")
		terminal.set_meta("service_point",Vector2(0,24))
	var billboard_mask := [Vector2(-64,-116),Vector2(64,-176),Vector2(64,-56),Vector2(-64,4)]
	var display := _entity(depth, "DataDisplay", Vector2(600,-88), "billboard", Vector2(-72,-176),
		[Vector2(-44,-12),Vector2(44,-12),Vector2(44,4),Vector2(-44,4)], billboard_mask)
	display.set_meta("service_label", "District display")
	display.set_meta("map_link", true)
	# The narrow column modules are platform supports, not freestanding lights.
	# Keep them in the piece catalogue until an authored edge uses their full base.
	var plaza_mask := [Vector2(-128,0),Vector2(0,-64),Vector2(128,0),Vector2(0,64)]
	_entity(depth, "ArrivalPlaza", Vector2(0,240), "plaza", Vector2(-192,-96), [], plaza_mask)
	scene.bake_tiles()
	# Reusable modules contain their complete art, ground base and interaction
	# anchors. Original map placements are never part of these pieces.
	DirAccess.make_dir_recursive_absolute("res://experiments/darkmoon_sandbox/pieces")
	for piece_name in ["DigiLab","Market","MarketCounter","DataTerminalA","DataDisplay","Fountain","ArrivalPlaza"]:
		var piece := depth.get_node(piece_name).duplicate() as Node2D
		piece.position = Vector2.ZERO
		piece.set_script(Piece)
		if piece.z_index >= 0:
			piece.z_index -= roundi(depth.get_node(piece_name).position.y)
		for child: Node in piece.find_children("*","",true,false):
			child.owner = piece
		var module := PackedScene.new()
		assert(module.pack(piece) == OK)
		assert(ResourceSaver.save(module,"res://experiments/darkmoon_sandbox/pieces/%s.tscn" % piece_name) == OK)
		piece.free()
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, "res://experiments/darkmoon_sandbox/DarkmoonSandbox.tscn") == OK)
	scene.free()
	print("[DarkmoonSandbox] Authored city scene baked")
	quit()
