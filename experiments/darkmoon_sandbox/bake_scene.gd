extends SceneTree

const Sandbox = preload("res://experiments/darkmoon_sandbox/DarkmoonSandbox.gd")
const Guide = preload("res://experiments/darkmoon_sandbox/CityGuide.gd")
const Piece = preload("res://experiments/darkmoon_sandbox/CityPiece.gd")
const GUIDE_TEXTURE = preload("res://assets/characters/koromon/field.png")
# Authored districts share one paving plane. Every edge follows the native
# 2:1 projection and accepts whole 64-pixel structural modules at scale two.
const OUTLINE := [Vector2(0,-512),Vector2(896,-64),Vector2(640,64),
	Vector2(768,128),Vector2(384,320),Vector2(256,256),Vector2(0,384),
	Vector2(-256,256),Vector2(-384,320),Vector2(-768,128),
	Vector2(-512,0),Vector2(-768,-128)]
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


func _structure(parent: Node) -> void:
	# Sweep the complete edge downwards. Merging only the top and a translated
	# copy leaves holes beneath narrow corners and would cut the wall artwork.
	var envelope := PackedVector2Array(OUTLINE)
	for index in range(OUTLINE.size()):
		var a: Vector2 = OUTLINE[index]
		var b: Vector2 = OUTLINE[(index+1)%OUTLINE.size()]
		var face := PackedVector2Array([a,b,b+Vector2(0,96),a+Vector2(0,96)])
		envelope = Geometry2D.merge_polygons(envelope,face)[0]
	for index in range(OUTLINE.size()):
		var a: Vector2 = OUTLINE[index]
		var b: Vector2 = OUTLINE[(index+1)%OUTLINE.size()]
		var right := b.x > a.x
		var front := not right
		var start := a if right else b
		var end := b if right else a
		var rising := end.y < start.y
		var brush := "edge_front_right" if rising else "edge_front_left"
		if not front:
			brush = "edge_back_left" if rising else "edge_back_right"
		var count := roundi((end.x-start.x)/128)
		for step in range(count):
			var at := start + Vector2(128, -64 if rising else 64)*step
			var offset := Vector2(0,-112 if rising and front else -48)
			var top := -40.0 if front else 0.0
			var bottom := 64.0 if front else 48.0
			if not front:
				offset = Vector2(0,-72 if rising else -24)
			var dy := -64.0 if rising else 64.0
			var mask := [Vector2(0,top),Vector2(128,dy+top),
				Vector2(128,dy+bottom),Vector2(0,bottom)]
			var world_mask := PackedVector2Array()
			for point: Vector2 in mask:
				world_mask.append(point+at)
			var clipped := Geometry2D.intersect_polygons(world_mask,envelope)
			for part in range(clipped.size()):
				var local: Array = []
				for point: Vector2 in clipped[part]:
					local.append(point-at)
				var structure := _entity(parent,"Structure%d_%d_%d" % [index,step,part],at,brush,offset,[],local)
				structure.z_index = -8 if front else -10
	# Frontmost corners get the source's complete vertical seam and lower pin.
	for index in range(OUTLINE.size()):
		var before: Vector2 = OUTLINE[posmod(index-1,OUTLINE.size())]
		var at: Vector2 = OUTLINE[index]
		var after: Vector2 = OUTLINE[(index+1)%OUTLINE.size()]
		if at.y > before.y and at.y > after.y:
			_entity(parent,"Corner%d" % index,at,"edge_front_corner",Vector2(-32,-32),[],
				[Vector2(-24,-12),Vector2(0,0),Vector2(24,-12),Vector2(24,48),Vector2(0,96),Vector2(-24,48)])
		elif (at-before).cross(after-at) > 0:
			if at.y < before.y and at.y < after.y:
				_entity(parent,"Corner%d" % index,at,"edge_back_corner",Vector2(-32,-24),[],
					[Vector2.ZERO,Vector2(32,16),Vector2(0,32),Vector2(-32,16)])


func _bake() -> void:
	scene = Node2D.new()
	scene.name = "DarkmoonSandbox"
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.set_script(Sandbox)
	var walkable := _node(scene, Node2D.new(), "Walkable")
	_polygon(walkable, "CityPlatform", OUTLINE, Color.WHITE, false)
	_surface(scene, "GroundMask", OUTLINE, "floor", -20)
	var depth := _node(scene, Node2D.new(), "Depth") as Node2D
	depth.y_sort_enabled = true
	_structure(depth)
	_building(depth, "DigiLab", Vector2(256,-96), "DIGILAB")
	_building(depth, "Market", Vector2(-384,-32), "MARKET")
	var guide := _node(depth, Node2D.new(), "KoromonGuide") as Node2D
	guide.position = Vector2(-432,64)
	guide.z_index = 1064
	guide.set_script(Guide)
	guide.set_meta("service_label", "Koromon")
	guide.set_meta("service_text", "Welcome to Moonrise Commons! The market is just behind me. Walk around the fountain to reach the research station and the eastern district display.")
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
	# Follow the actual basin and its inset lower rim; never trim it into a
	# synthetic diamond or paint a replacement rim over the original artwork.
	var pool_mask := [Vector2(32,-144),Vector2(256,-32),Vector2(128,32),
		Vector2(192,64),Vector2(272,112),Vector2(160,168),Vector2(48,112),
		Vector2(-96,48),Vector2(-128,64),Vector2(-256,128),Vector2(-384,64),Vector2(-288,16)]
	var pool_base := [Vector2(32,-136),Vector2(248,-32),Vector2(112,40),
		Vector2(184,80),Vector2(64,128),Vector2(-96,48),Vector2(-128,64),Vector2(-296,-16)]
	var pool := _entity(depth, "Fountain", Vector2(0,64), "pool", Vector2(-384,-160), pool_base, pool_mask)
	pool.z_index = -5
	var terminal_shape := [Vector2(-58,-80),Vector2(0,-109),Vector2(58,-80),Vector2(0,-51)]
	var terminal_mask := [Vector2(-64,-80),Vector2(0,-112),Vector2(64,-80),
		Vector2(64,-32),Vector2.ZERO,Vector2(-64,-32)]
	# This native module hangs from a platform edge. Its roof, rather than the
	# bottom of its hanging cabinet, defines contact with the walkable plane.
	for item in [["DataTerminalA",Vector2(512,336)]]:
		var terminal := _entity(depth, item[0], item[1], "terminal", Vector2(-64,-112), terminal_shape, terminal_mask)
		terminal.set_meta("service_label","Data console")
		terminal.set_meta("service_text","The console displays a directory of this district. This experimental console does not modify the owned roster.")
		terminal.set_meta("service_point",Vector2(0,-128))
	var billboard_mask := [Vector2(-64,-116),Vector2(64,-176),Vector2(64,-56),Vector2(-64,4)]
	var display := _entity(depth, "DataDisplay", Vector2(608,48), "billboard", Vector2(-72,-176),
		[Vector2(-44,-12),Vector2(44,-12),Vector2(44,4),Vector2(-44,4)], billboard_mask)
	display.set_meta("service_label", "District display")
	display.set_meta("map_link", true)
	# The narrow column modules are platform supports, not freestanding lights.
	# Keep them in the piece catalogue until an authored edge uses their full base.
	var plaza_mask := [Vector2(-128,0),Vector2(0,-64),Vector2(128,0),Vector2(0,64)]
	_entity(depth, "ArrivalPlaza", Vector2(0,288), "arrival_inlay", Vector2(-128,-64), [], plaza_mask)
	scene.bake_tiles()
	# Reusable modules contain their complete art, ground base and interaction
	# anchors. Original map placements are never part of these pieces.
	DirAccess.make_dir_recursive_absolute("res://experiments/darkmoon_sandbox/pieces")
	for piece_name in ["DigiLab","Market","DataTerminalA","DataDisplay","Fountain","ArrivalPlaza"]:
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
