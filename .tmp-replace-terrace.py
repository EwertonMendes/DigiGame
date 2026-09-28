from pathlib import Path
p=Path('src/world/runtime/CentralCityTerrace.gd')
s=p.read_text(encoding='utf-8')
s=s.replace('const TERRACE_POST = preload("res://assets/world/central_city/terrace_post.svg")','const KIT = preload("res://src/world/runtime/CentralCityTerraceKit.gd")')
start=s.index('\tvar stair_landings: Array[Dictionary]')
end=s.index('\n\troot.set_meta("visual_level_count"',start)
s=s[:start]+'''	var landings: Array[Dictionary] = []
	var stair_art: Array[Dictionary] = []
	var bridge_art: Array[Dictionary] = []
	var rail_art: Array[Dictionary] = []
	var bank_art: Array[Dictionary] = []
	var post_art: Array[Dictionary] = []
	for raw_stair in TOPOLOGY.stairs():
		if raw_stair is Dictionary:
			_append_staircase(raw_stair as Dictionary, landings, stair_art, rail_art, post_art)
	_add_paver_batch(root, "StairLandings", landings, 2)
	root.add_child(KIT.build(stair_art, "StairAssets", 3))

	var water_surfaces: Array[Dictionary] = []
	var water_edges: Array[Dictionary] = []
	for raw_void in TOPOLOGY.voids():
		if raw_void is Dictionary:
			_append_void_frame(raw_void as Dictionary, water_surfaces, water_edges, bank_art, post_art)
	if not water_surfaces.is_empty():
		var water := CITY.create_world_uv_polygon_batch(water_surfaces, CITY.create_water_material(), 6)
		water.name = "CanalWater"
		root.add_child(water)
	_add_color_batch(root, "WaterEdgeHighlights", water_edges, 7)
	root.add_child(KIT.build(bank_art, "CanalBankAssets", 8))

	for raw_bridge in TOPOLOGY.bridges():
		if raw_bridge is Dictionary:
			_append_bridge(raw_bridge as Dictionary, bridge_art, rail_art, post_art)
	root.add_child(KIT.build(bridge_art, "BridgeAssets", 11))
	root.add_child(KIT.build(rail_art, "HandrailAssets", 12))
	root.add_child(KIT.build(post_art, "CornerPostAssets", 13))
''' + s[end:]
start=s.index('static func _append_staircase(')
end=s.index('static func _grid_quad(',start)
s=s[:start]+'''static func _append_staircase(
	stair: Dictionary,
	landings: Array[Dictionary],
	art: Array[Dictionary],
	rails: Array[Dictionary],
	posts: Array[Dictionary]
) -> void:
	var quad := _grid_quad(stair, float(stair.get("x_min", 0.0)), float(stair.get("x_max", 0.0)), float(stair.get("y_start", 0.0)), float(stair.get("y_end", 1.0)))
	var from_level := String(stair.get("from_level", "upper_civic"))
	var to_level := String(stair.get("to_level", "south_terrace"))
	var along := ((quad[3] - quad[0]) + (quad[2] - quad[1])).normalized()
	KIT.append_stair(art, quad, from_level, to_level)
	_append_paver_spec(landings, PackedVector2Array([
		quad[0] - along * 0.55, quad[1] - along * 0.55,
		quad[1] + along * 0.08, quad[0] + along * 0.08,
	]), from_level, LANDING_TOP)
	_append_paver_spec(landings, PackedVector2Array([
		quad[3] - along * 0.08, quad[2] - along * 0.08,
		quad[2] + along * 0.55, quad[3] + along * 0.55,
	]), to_level, LANDING_TOP)
	for side in range(2):
		var upper := TOPOLOGY.grid_to_display(quad[side], from_level)
		var lower := TOPOLOGY.grid_to_display(quad[3 - side], to_level)
		KIT.append_edge(rails, "rail", upper, lower, 18.0)
		KIT.append_post(posts, upper)
		KIT.append_post(posts, lower)


static func _append_void_frame(
	void_region: Dictionary,
	water_surfaces: Array[Dictionary],
	water_edges: Array[Dictionary],
	banks: Array[Dictionary],
	posts: Array[Dictionary]
) -> void:
	var x0 := float(void_region.get("x_min", 0.0))
	var x1 := float(void_region.get("x_max", 0.0))
	var y0 := float(void_region.get("y_min", 0.0))
	var y1 := float(void_region.get("y_max", 0.0))
	var level := TOPOLOGY.level_at_grid(Vector2((x0 + x1) * 0.5, y0 - 0.5))
	var elevation := TOPOLOGY.elevation_for_level(level)
	var footprint := _grid_quad(void_region, x0, x1, y0, y1)
	var polygon_value = void_region.get("grid_polygon")
	if polygon_value is PackedVector2Array and (polygon_value as PackedVector2Array).size() >= 3:
		footprint = polygon_value as PackedVector2Array
	var has_water := String(void_region.get("fill", "water")) == "water"
	if has_water:
		var logical := _grid_to_logical(footprint)
		water_surfaces.append({
			"points": _logical_at_elevation(logical, elevation - WATER_INSET_PX),
			"logical_points": logical,
			"color": Color.WHITE,
		})
	var signed_area := 0.0
	for index in range(footprint.size()):
		signed_area += footprint[index].cross(footprint[(index + 1) % footprint.size()])
	var outward_sign := 1.0 if signed_area >= 0.0 else -1.0
	for index in range(footprint.size()):
		var a_grid := footprint[index]
		var b_grid := footprint[(index + 1) % footprint.size()]
		var a := TOPOLOGY.grid_to_display(a_grid, level)
		var b := TOPOLOGY.grid_to_display(b_grid, level)
		var bank_drop := Vector2(0.0, TRENCH_DEPTH_PX)
		KIT.append_edge(banks, "parapet", a + bank_drop, b + bank_drop, TRENCH_DEPTH_PX)
		KIT.append_post(posts, a, 16.0)
		if has_water:
			var edge := b_grid - a_grid
			var inward := -Vector2(edge.y, -edge.x).normalized() * outward_sign
			var strip := PackedVector2Array([
				a_grid + inward * 0.08, b_grid + inward * 0.08,
				b_grid + inward * 0.19, a_grid + inward * 0.19,
			])
			water_edges.append({
				"points": _logical_at_elevation(_grid_to_logical(strip), elevation - WATER_INSET_PX),
				"color": Color(0.27, 0.68, 0.70, 0.20),
			})


static func _append_bridge(
	bridge: Dictionary,
	art: Array[Dictionary],
	rails: Array[Dictionary],
	posts: Array[Dictionary]
) -> void:
	var quad := _grid_quad(bridge, float(bridge.get("x_min", 0.0)), float(bridge.get("x_max", 0.0)), float(bridge.get("y_min", 0.0)), float(bridge.get("y_max", 1.0)))
	var level := String(bridge.get("level", "south_terrace"))
	KIT.append_bridge(art, quad, level)
	for side in range(2):
		var start := TOPOLOGY.grid_to_display(quad[side], level)
		var end := TOPOLOGY.grid_to_display(quad[3 - side], level)
		KIT.append_edge(rails, "rail", start, end, 18.0)
		KIT.append_post(posts, start)
		KIT.append_post(posts, end)


''' + s[end:]
start=s.index('static func _append_parapet(')
end=s.index('static func _append_paver_spec(',start)
s=s[:start]+s[end:]
for line in list(s.splitlines()):
    if line.startswith(('const STAIR_','const PARAPET_','const TRENCH_CAP','const TRENCH_FACE','const BRIDGE_')):
        s=s.replace(line+'\n','')
p.write_text(s,encoding='utf-8')
