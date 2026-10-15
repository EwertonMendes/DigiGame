@tool
extends Node2D

const Actor = preload("res://experiments/darkmoon_sandbox/SandboxActor.gd")
const DebugView = preload("res://experiments/darkmoon_sandbox/SandboxDebug.gd")
const TouchJoystick = preload("res://src/ui/TouchJoystick.gd")
const DepthRule = preload("res://src/world/runtime/WorldDepth.gd")
const InputBootstrap = preload("res://src/input/GameInputBootstrap.gd")
const PLAYER_TEXTURE = preload("res://assets/characters/world/player_blond.png")
const PUBLIC_PALETTE = preload("res://assets/scenery/darkmoon_city/pieces.png")
const CityAtlas = preload("res://experiments/darkmoon_sandbox/CityAtlas.gd")
const SPAWN := Vector2(0, 208)
const BRUSHES_PATH := "res://experiments/darkmoon_sandbox/brushes.json"
const SAMPLE_STEP := 4.0
# The inherited capsule is radius 10, height 22, centered 11 pixels above feet.
# Match its footprint instead of blocking the character's entire sprite.
const CLEARANCE := [Vector2(0, -11), Vector2(0, 0), Vector2(0, -22),
	Vector2(-10, -11), Vector2(10, -11), Vector2(-7.1, -18.1),
	Vector2(7.1, -18.1), Vector2(-7.1, -3.9), Vector2(7.1, -3.9)]

@export var use_private_art := true
@export var rebuild_tiles := false:
	set(value):
		if value and Engine.is_editor_hint() and is_inside_tree():
			bake_tiles()
		rebuild_tiles = false

var player: CharacterBody2D
var camera: Camera2D
var debug_view: Node2D
var status: Label
var art_mode := "Bundled city atlas"
var overview := false
var _trace_elapsed := 0.0
var dialogue: PanelContainer
var dialogue_text: Label
var _brush_cache: Dictionary = {}


func _init() -> void:
	InputBootstrap.configure_gamepad_actions()


func _ready() -> void:
	if Engine.is_editor_hint():
		if use_private_art:
			CityAtlas.preview_in_editor(self)
		return
	# This standalone scene draws at the actual window size. Scaling a 1280-wide
	# HUD down to a phone first rasterizes enlarged glyphs at the wrong size.
	# Runtime window state stays local to F6/the sandbox Web entry point.
	get_window().content_scale_size = Vector2i.ZERO
	RenderingServer.set_default_clear_color(Color("14182a"))
	_apply_runtime_palette()
	for entity: Node2D in get_node("Depth").get_children():
		var base := entity.get_node_or_null("Footprint") as Polygon2D
		if base == null or entity.z_index < 0:
			continue
		var minimum := INF
		var maximum := -INF
		for point: Vector2 in base.polygon:
			var ground_y := base.to_global(point).y
			minimum = minf(minimum,ground_y)
			maximum = maxf(maximum,ground_y)
		entity.z_index = DepthRule.z_for_ground_y((minimum+maximum)*0.5)
	player = Actor.new()
	player.name = "SandboxPlayer"
	player.configure(PLAYER_TEXTURE, true, self, "south")
	player.position = SPAWN
	get_node("Depth").add_child(player)
	player.collision_mask = 0 # Geometry queries are the only collision authority.
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false # Integer camera position avoids seams.
	add_child(camera)
	debug_view = DebugView.new()
	debug_view.sandbox = self
	debug_view.z_index = 100
	debug_view.visible = false
	add_child(debug_view)
	_build_controls()
	assert(can_stand_at(SPAWN), "Sandbox spawn must have full capsule clearance")
	print("[DarkmoonSandbox] READY art=%s" % art_mode)
	_update_camera()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		CityAtlas.set_palette(self,PUBLIC_PALETTE)
	elif what == NOTIFICATION_EDITOR_POST_SAVE and use_private_art:
		CityAtlas.preview_in_editor(self)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	_update_camera()
	if debug_view.visible:
		debug_view.queue_redraw()
	_trace_elapsed += delta
	if _trace_elapsed >= 0.25:
		_trace_elapsed = 0.0
		print("[DarkmoonSandbox] POSITION %.2f %.2f" % [player.position.x, player.position.y])
	var nearby := _nearest_interactable()
	var hint := "E: %s" % nearby.get_meta("service_label") if nearby != null else "E interact"
	status.text = "MOONRISE COMMONS\nWASD / Arrows · Shift run · %s · F3 debug · Tab map" % hint


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F3:
			debug_view.visible = not debug_view.visible
		KEY_TAB:
			overview = not overview
			print("[DarkmoonSandbox] MAP %s" % overview)
		KEY_R:
			if dialogue.visible:
				_inspect_nearby()
			player.position = SPAWN
			player.velocity = Vector2.ZERO
		KEY_E:
			_inspect_nearby()
		KEY_ESCAPE:
			if not dialogue.visible:
				return
			_inspect_nearby()
		KEY_F4:
			# Deterministic route uses the real actor's movement, not teleportation.
			_run_route_check()
		_:
			return
	get_viewport().set_input_as_handled()


func _update_camera() -> void:
	if overview:
		camera.position = Vector2(0, -48)
		var size := get_viewport_rect().size
		camera.zoom = Vector2.ONE * minf(size.x / 2350.0, size.y / 1600.0)
	else:
		camera.position = player.position.round() + Vector2(0,-96)
		camera.zoom = Vector2.ONE * _presentation_scale()


func _presentation_scale() -> float:
	# The game's 1280-pixel logical width shrinks controls on portrait browsers.
	# Compensate in this scene's camera/HUD, preserving the project's settings.
	return maxf(1.0, get_viewport_rect().size.x / maxf(1.0, float(get_window().size.x)))


func is_walkable_position(point: Vector2) -> bool:
	var surface := false
	for region: Polygon2D in get_node("Walkable").get_children():
		if Geometry2D.is_point_in_polygon(region.to_local(point), region.polygon):
			surface = true
			break
	if not surface:
		return false
	for entity: Node2D in get_node("Depth").get_children():
		var base := entity.get_node_or_null("Footprint") as Polygon2D
		if base != null and Geometry2D.is_point_in_polygon(base.to_local(point), base.polygon):
			return false
	return true


func can_stand_at(point: Vector2) -> bool:
	for offset: Vector2 in CLEARANCE:
		if not is_walkable_position(point + offset):
			return false
	return true


func resolve_actor_depth(actor: Node2D) -> int:
	# Contact Y varies across an angled base. Correct collision alone cannot keep
	# actors in front of a long counter when all its art uses one front anchor.
	if _brush_cache.is_empty():
		_brush_cache = JSON.parse_string(FileAccess.get_file_as_string(BRUSHES_PATH))
	var sprite := actor.get_node_or_null("CharacterSprite") as Sprite2D
	if sprite == null:
		sprite = actor.get_node_or_null("Body") as Sprite2D
	if sprite == null:
		return DepthRule.z_for_ground_y(actor.global_position.y)
	var body_bounds: Rect2 = sprite.global_transform * sprite.get_rect()
	var lower := -4096
	var upper := 4096
	for entity: Node2D in get_node("Depth").get_children():
		var base := entity.get_node_or_null("Footprint") as Polygon2D
		if base == null or entity == actor or entity.z_index < 0:
			continue
		var bounds := _piece_art_bounds(entity)
		var roof := entity.get_node_or_null("Roof") as Polygon2D
		if roof != null:
			for point: Vector2 in roof.polygon:
				bounds = bounds.expand(roof.to_global(point))
		if not body_bounds.intersects(bounds):
			continue
		var world_points := PackedVector2Array()
		var min_x := INF
		var max_x := -INF
		for point: Vector2 in base.polygon:
			var world := base.to_global(point)
			world_points.append(world)
			min_x = minf(min_x,world.x)
			max_x = maxf(max_x,world.x)
		var x := clampf(actor.global_position.x,min_x+0.01,max_x-0.01)
		var near_y := -INF
		var far_y := INF
		for index in range(world_points.size()):
			var a := world_points[index]
			var b := world_points[(index+1)%world_points.size()]
			if absf(a.x-b.x)<0.001 or x<minf(a.x,b.x) or x>maxf(a.x,b.x):
				continue
			var y := lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
			near_y = maxf(near_y,y)
			far_y = minf(far_y,y)
		if actor.global_position.y > near_y:
			lower = maxi(lower,entity.z_index+1)
		elif actor.global_position.y < far_y:
			upper = mini(upper,entity.z_index-1)
	return clampi(DepthRule.z_for_ground_y(actor.global_position.y),lower,maxi(lower,upper))


func _piece_art_bounds(entity: Node2D) -> Rect2:
	if entity.has_meta("brush"):
		var rect: Array = _brush_cache[String(entity.get_meta("brush"))].rect
		return entity.global_transform * Rect2(entity.get_meta("art_offset",Vector2.ZERO),Vector2(rect[2],rect[3])*2)
	# Custom authored modules may paint raw source cells instead of a catalogue
	# brush. Their used tile cells still provide correct front/back occlusion.
	var result := Rect2()
	for layer: TileMapLayer in entity.find_children("*","TileMapLayer",true,false):
		var cells := layer.get_used_rect()
		if cells.size == Vector2i.ZERO:
			continue
		var tile_size := layer.tile_set.tile_size
		var bounds: Rect2 = layer.global_transform * Rect2(cells.position*tile_size,cells.size*tile_size)
		result = bounds if result.size == Vector2.ZERO else result.merge(bounds)
	for body: Sprite2D in entity.find_children("*","Sprite2D",true,false):
		var bounds: Rect2 = body.global_transform * body.get_rect()
		result = bounds if result.size == Vector2.ZERO else result.merge(bounds)
	return result


func can_actor_move_to(candidate: Vector2, actor: Node) -> bool:
	if not actor is Node2D:
		return can_stand_at(candidate)
	var start := (actor as Node2D).global_position
	var steps := maxi(1, ceili(start.distance_to(candidate) / SAMPLE_STEP))
	for index in range(1, steps + 1):
		if not can_stand_at(start.lerp(candidate, float(index) / steps)):
			return false
	return true


func _apply_runtime_palette() -> void:
	CityAtlas.set_palette(self,PUBLIC_PALETTE,CityAtlas.RAW_TEMPLATE)


func _build_controls() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 100
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182038e8")
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("d4e6e4"))
	status.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	panel.add_child(status)
	var joystick := TouchJoystick.new()
	hud.add_child(joystick)
	joystick.direction_changed.connect(player.set_touch_direction)
	var reset := Button.new()
	reset.text = "Reset"
	hud.add_child(reset)
	reset.pressed.connect(func(): player.position = SPAWN; player.velocity = Vector2.ZERO)
	var debug_button := Button.new()
	debug_button.text = "Collision"
	hud.add_child(debug_button)
	debug_button.pressed.connect(func(): debug_view.visible = not debug_view.visible)
	var map_button := Button.new()
	map_button.text = "Map"
	hud.add_child(map_button)
	map_button.pressed.connect(func(): overview = not overview)
	var talk_button := Button.new()
	talk_button.text = "Interact"
	hud.add_child(talk_button)
	talk_button.pressed.connect(_inspect_nearby)
	for button: Button in [talk_button,reset,debug_button,map_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",14)
		var button_style := style.duplicate() as StyleBoxFlat
		button_style.set_corner_radius_all(4)
		button_style.set_border_width_all(1)
		button_style.border_color = Color("7f729e")
		button.add_theme_stylebox_override("normal",button_style)
	dialogue = PanelContainer.new()
	dialogue.visible = false
	dialogue.add_theme_stylebox_override("panel",style)
	hud.add_child(dialogue)
	dialogue_text = Label.new()
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.add_theme_font_size_override("font_size",18)
	dialogue_text.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	dialogue.add_child(dialogue_text)
	var layout := func():
		var ui_scale := _presentation_scale()
		hud.scale = Vector2.ONE * ui_scale
		var size := get_viewport_rect().size / ui_scale
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.custom_minimum_size.x = minf(size.x - 64, 548)
		panel.size.x = minf(size.x - 32, 580)
		joystick.visible = get_window().size.x < 900
		joystick.position = Vector2(20, size.y - 166)
		joystick.size = Vector2(146, 146)
		for index in range(4):
			var button: Button = [talk_button,map_button,debug_button,reset][index]
			button.visible = joystick.visible
			button.size = Vector2(96,36)
			button.position = Vector2(size.x-116,size.y-198+index*44)
		dialogue_text.custom_minimum_size.x = minf(size.x-64,548)
		dialogue.size.x = minf(size.x-32,580)
		dialogue.position = Vector2((size.x-dialogue.size.x)/2,size.y-250)
	get_viewport().size_changed.connect(layout)
	layout.call()


func _nearest_interactable() -> Node2D:
	var closest: Node2D = null
	var best := 72.0
	for entity: Node2D in get_node("Depth").get_children():
		if not entity.has_meta("service_label"):
			continue
		var point: Vector2 = entity.position + entity.get_meta("service_point",Vector2.ZERO)
		var distance := player.position.distance_to(point)
		if distance < best:
			closest = entity
			best = distance
	return closest


func _inspect_nearby() -> void:
	if dialogue.visible:
		dialogue.visible = false
		player.movement_enabled = true
		return
	var nearby := _nearest_interactable()
	if nearby == null:
		return
	if bool(nearby.get_meta("map_link",false)):
		overview = not overview
		return
	dialogue_text.text = "%s\n\n%s\n\nE / Esc to close" % [nearby.get_meta("service_label"),nearby.get_meta("service_text","")]
	dialogue.visible = true
	player.movement_enabled = false
	player.velocity = Vector2.ZERO
	print("[DarkmoonSandbox] INTERACT %s" % nearby.get_meta("service_label"))


func _run_route_check() -> bool:
	var original_position := player.position
	var was_enabled := bool(player.movement_enabled)
	player.movement_enabled = false
	player.velocity = Vector2.ZERO
	var waypoints := [SPAWN,Vector2(400,224),Vector2(760,144),Vector2(860,48),Vector2(912,0),Vector2(240,-336),
		Vector2(192,-392),Vector2(0,-472),Vector2(-192,-376),Vector2(-480,-200),
		Vector2(-840,-64),Vector2(-840,88),Vector2(-768,176),Vector2(-560,176),Vector2(-400,240),SPAWN]
	var passed := true
	for target: Vector2 in waypoints:
		var attempts := 0
		while player.position.distance_to(target) > 3.0 and attempts < 1200:
			player._try_move((target - player.position).limit_length(3.0))
			if not can_stand_at(player.position):
				passed = false
			attempts += 1
		if player.position.distance_to(target) > 3.0:
			passed = false
			push_error("Sandbox route stalled at %s toward %s" % [player.position, target])
	player.position = original_position
	player.movement_enabled = was_enabled
	print("[DarkmoonSandbox] ROUTE %s" % ("PASS" if passed else "FAIL"))
	return passed


func _make_tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(8, 8)
	var source := TileSetAtlasSource.new()
	source.resource_name = "Assembled city pieces"
	source.texture = PUBLIC_PALETTE
	source.texture_region_size = Vector2i(8, 8)
	source.margins = Vector2i.ZERO
	source.separation = Vector2i.ZERO
	# Create only the curated brush rectangles, including transparent cells that
	# can contain pixels in the private palette. Ignore unused atlas tail cells.
	var brushes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BRUSHES_PATH))
	for brush: Dictionary in brushes.values():
		var rect: Array = brush.rect
		for y in range(int(rect[1]) / 8, (int(rect[1]) + int(rect[3])) / 8):
			for x in range(int(rect[0]) / 8, (int(rect[0]) + int(rect[2])) / 8):
				if not source.has_tile(Vector2i(x, y)):
					source.create_tile(Vector2i(x, y))
	tiles.add_source(source, 0)
	var raw := TileSetAtlasSource.new()
	raw.resource_name = "Native 8x8 source cells"
	raw.texture = CityAtlas.RAW_TEMPLATE
	raw.texture_region_size = Vector2i(8,8)
	for index in range(3825):
		raw.create_tile(Vector2i(index%32,index/32))
	tiles.add_source(raw,1)
	return tiles


func _paint_surface(mask: Polygon2D, brush: Dictionary, tiles: TileSet, layer_name: String) -> void:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tiles
	layer.scale = Vector2(2,2)
	mask.add_child(layer)
	mask.move_child(layer, 0)
	layer.owner = self
	var bounds := Rect2(mask.polygon[0], Vector2.ZERO)
	for point: Vector2 in mask.polygon:
		bounds = bounds.expand(point)
	var rect: Array = brush.rect
	for y in range(floori(bounds.position.y/16)-1,ceili(bounds.end.y/16)+1):
		for x in range(floori(bounds.position.x/16)-1,ceili(bounds.end.x/16)+1):
			var atlas := Vector2i(int(rect[0])/8+posmod(x,int(rect[2])/8),
				int(rect[1])/8+posmod(y,int(rect[3])/8))
			layer.set_cell(Vector2i(x,y),0,atlas)


func bake_tiles() -> void:
	var brushes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BRUSHES_PATH))
	var tiles := _make_tileset()
	assert(ResourceSaver.save(tiles,"res://experiments/darkmoon_sandbox/CityTiles.tres",ResourceSaver.FLAG_CHANGE_PATH) == OK)
	tiles.take_over_path("res://experiments/darkmoon_sandbox/CityTiles.tres")
	for existing: Node in find_children("*", "TileMapLayer", true, false):
		existing.get_parent().remove_child(existing)
		existing.queue_free()
	for mask: Polygon2D in find_children("*", "Polygon2D", true, false):
		if mask.has_meta("surface_brush"):
			_paint_surface(mask,brushes[String(mask.get_meta("surface_brush"))],tiles,
				"Ground" if mask.name == "GroundMask" else "Tiles")
	for entity: Node2D in get_node("Depth").find_children("*","Node2D",true,false):
		if not entity.has_meta("brush"):
			continue
		var rect: Array = brushes[String(entity.get_meta("brush"))].rect
		var parent: Node2D = entity
		var existing := entity.get_node_or_null("ArtMask")
		if existing != null:
			entity.remove_child(existing)
			existing.queue_free()
		if entity.has_meta("art_mask"):
			var mask := Polygon2D.new()
			mask.name = "ArtMask"
			mask.polygon = entity.get_meta("art_mask")
			mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
			entity.add_child(mask)
			mask.owner = self
			var roof := entity.get_node_or_null("Roof")
			entity.move_child(mask, roof.get_index()+1 if roof != null else 0)
			parent = mask
		var layer := TileMapLayer.new()
		layer.name = "Art"
		layer.tile_set = tiles
		layer.scale = Vector2(2,2)
		layer.position = entity.get_meta("art_offset",Vector2.ZERO)
		parent.add_child(layer)
		layer.owner = self
		for y in range(int(rect[3])/8):
			for x in range(int(rect[2])/8):
				var atlas := Vector2i(int(rect[0])/8+x,int(rect[1])/8+y)
				if (tiles.get_source(0) as TileSetAtlasSource).has_tile(atlas):
					layer.set_cell(Vector2i(x,y),0,atlas)
	print("[DarkmoonSandbox] Curated editable 8x8 layers rebuilt")
