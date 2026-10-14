@tool
extends Node2D

const Actor = preload("res://experiments/darkmoon_sandbox/SandboxActor.gd")
const DebugView = preload("res://experiments/darkmoon_sandbox/SandboxDebug.gd")
const TouchJoystick = preload("res://src/ui/TouchJoystick.gd")
const PLAYER_TEXTURE = preload("res://assets/characters/world/player_blond.png")
const PUBLIC_PALETTE = preload("res://experiments/darkmoon_sandbox/palette.svg")
const PRIVATE_PALETTE := "res://assets/local/darkmoon_sandbox/palette.png"
const SPAWN := Vector2(0, 112)
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
var art_mode := "Original preview art"
var overview := false
var _trace_elapsed := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	RenderingServer.set_default_clear_color(Color("14182a"))
	_apply_runtime_palette()
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
	status.text = "NIGHT CIRCUIT  /  %s\nWASD / Arrows · Shift run · F3 collision · Tab map · R reset" % art_mode


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F3:
			debug_view.visible = not debug_view.visible
		KEY_TAB:
			overview = not overview
		KEY_R:
			player.position = SPAWN
			player.velocity = Vector2.ZERO
		KEY_F4:
			# Deterministic route uses the real actor's movement, not teleportation.
			_run_route_check()


func _update_camera() -> void:
	if overview:
		camera.position = Vector2(0, -20)
		var size := get_viewport_rect().size
		camera.zoom = Vector2.ONE * minf(size.x / 2350.0, size.y / 1600.0)
	else:
		camera.position = player.position.round()
		camera.zoom = Vector2.ONE


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
	if not use_private_art or not FileAccess.file_exists(PRIVATE_PALETTE):
		return
	var native := Image.load_from_file(PRIVATE_PALETTE)
	if native == null or native.get_size() != Vector2i(256, 192):
		push_warning("Invalid private palette; using original preview art")
		return
	var texture := ImageTexture.create_from_image(native)
	var tiles := (get_node("Ground") as TileMapLayer).tile_set.duplicate(true) as TileSet
	(tiles.get_source(0) as TileSetAtlasSource).texture = texture
	for layer: Node in find_children("*", "TileMapLayer", true, false):
		(layer as TileMapLayer).tile_set = tiles
	art_mode = "Private local atlas"


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
	var layout := func():
		var size := get_viewport_rect().size
		panel.size.x = minf(size.x - 32, 730)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.custom_minimum_size.x = minf(size.x - 64, 698)
		joystick.position = Vector2(20, size.y - 166)
		joystick.size = Vector2(146, 146)
		for index in range(3):
			var button: Button = [reset, debug_button, map_button][index]
			button.size = Vector2(96, 40)
			button.position = Vector2(size.x - 116, size.y - 160 + index * 46)
	get_viewport().size_changed.connect(layout)
	layout.call()


func _run_route_check() -> bool:
	var original_position := player.position
	player.movement_enabled = false
	player.velocity = Vector2.ZERO
	var waypoints := [SPAWN, Vector2(200, 0), Vector2(750, 0),
		Vector2(0, 410), Vector2(-750, 0), Vector2(0, -410),
		Vector2(750, 0), Vector2(200, 0), SPAWN]
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
	player.movement_enabled = true
	print("[DarkmoonSandbox] ROUTE %s" % ("PASS" if passed else "FAIL"))
	return passed


func _make_tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(8, 8)
	var source := TileSetAtlasSource.new()
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
	return tiles


func bake_tiles() -> void:
	var brushes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BRUSHES_PATH))
	var tiles := _make_tileset()
	for existing: Node in find_children("*", "TileMapLayer", true, false):
		existing.get_parent().remove_child(existing)
		existing.queue_free()
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tiles
	ground.scale = Vector2(2, 2)
	ground.z_index = -10
	add_child(ground)
	ground.owner = self
	for y in range(-33, 33):
		for x in range(-69, 69):
			var point := Vector2(x * 16 + 8, y * 16 + 8)
			var on_surface := false
			for region: Polygon2D in get_node("Walkable").get_children():
				if Geometry2D.is_point_in_polygon(region.to_local(point), region.polygon):
					on_surface = true
					break
			if on_surface:
				var brush := "paver" if absf(point.x) > 380 or absf(point.y) > 190 else "floor"
				var rect: Array = brushes[brush].rect
				var atlas := Vector2i(int(rect[0]) / 8 + posmod(x, 4), posmod(y, 4))
				ground.set_cell(Vector2i(x, y), 0, atlas)
	for entity: Node2D in get_node("Depth").get_children():
		if not entity.has_meta("brush"):
			continue
		var brush := String(entity.get_meta("brush"))
		var rect: Array = brushes[brush].rect
		var layer := TileMapLayer.new()
		layer.name = "Art"
		layer.tile_set = tiles
		layer.scale = Vector2(2, 2)
		layer.position = entity.get_meta("art_offset", Vector2.ZERO)
		entity.add_child(layer)
		layer.owner = self
		for y in range(int(rect[3]) / 8):
			for x in range(int(rect[2]) / 8):
				var atlas := Vector2i(int(rect[0]) / 8 + x, int(rect[1]) / 8 + y)
				if (tiles.get_source(0) as TileSetAtlasSource).has_tile(atlas):
					layer.set_cell(Vector2i(x, y), 0, atlas)
	print("[DarkmoonSandbox] Editable 8x8 layers rebuilt")
