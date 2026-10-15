extends SceneTree

const SCENE = preload("res://experiments/darkmoon_sandbox/DarkmoonSandbox.tscn")
const InputBootstrap = preload("res://src/input/GameInputBootstrap.gd")
var failures: Array[String] = []


func _initialize() -> void:
	InputBootstrap.configure_gamepad_actions()
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var sandbox := SCENE.instantiate()
	sandbox.use_private_art = "--private" in OS.get_cmdline_user_args()
	root.add_child(sandbox)
	await physics_frame
	var raw_cells := sandbox.get_node("GroundMask/Ground").tile_set.get_source(1) as TileSetAtlasSource
	_check(raw_cells.get_tiles_count() == 3825 and not raw_cells.has_tile(Vector2i(17,119)),
		"Raw source catalogue includes missing cells or the unused atlas tail")
	if true:
		_check(sandbox.art_mode == "Bundled city atlas","Native city atlas was not loaded")
		var source: Image = sandbox.CityAtlas.RAW_TEMPLATE.get_image()
		_check(raw_cells.texture.get_image().get_data() == source.get_data(),"Raw authoring tiles changed the native atlas")
		var palette: Image = sandbox.CityAtlas.assemble()
		var brushes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sandbox.BRUSHES_PATH))
		for brush: Dictionary in brushes.values():
			for y in range(brush.private_cells.size()):
				for x in range(brush.private_cells[y].size()):
					var cell: Variant = brush.private_cells[y][x]
					if cell == null:
						continue
					var index := int(cell)
					_check(palette.get_region(Rect2i(int(brush.rect[0])+x*8,int(brush.rect[1])+y*8,8,8)).get_data() ==
						source.get_region(Rect2i((index%32)*8,(index/32)*8,8,8)).get_data(),
						"A city piece altered native pixels")
		# The editor save guard swaps only the palette, preserving editable cells.
		sandbox.CityAtlas.set_palette(sandbox,sandbox.PUBLIC_PALETTE)
		var saved := PackedScene.new()
		_check(saved.pack(sandbox) == OK,"Could not pack the edited city")
		_check(ResourceSaver.save(saved,"res://.tmp/city-save-guard.tscn") == OK,"Could not save the edited city")
		var serialized := FileAccess.get_file_as_string("res://.tmp/city-save-guard.tscn")
		_check(not serialized.contains("ImageTexture") and not serialized.contains("assets/local/"),
			"Editor preview leaked private pixels into a saved scene")
		sandbox.CityAtlas.set_palette(sandbox,ImageTexture.create_from_image(palette),ImageTexture.create_from_image(source))
	sandbox.player.movement_enabled = false
	_check(sandbox.can_stand_at(sandbox.SPAWN), "Invalid spawn clearance")
	for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,
		Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		sandbox.player.position = sandbox.SPAWN
		var expected: Vector2 = sandbox.player.position + direction.normalized() * 24
		sandbox.player._try_move(direction.normalized() * 24)
		_check(sandbox.player.position.distance_to(expected) < 0.1, "Eight-direction motion failed: %s" % direction)
		_check(sandbox.can_stand_at(sandbox.player.position), "Motion entered a void")
	# Walk the complete road loop and both courts through the actual actor.
	sandbox.player.position = sandbox.SPAWN
	_check(sandbox._run_route_check(), "Complete road and court route failed")
	_check(sandbox.can_stand_at(Vector2(-96,-416)), "Roof pixels incorrectly block ground behind the lab")
	_check(not sandbox.can_stand_at(Vector2.ZERO), "Fountain basin must be solid")
	_check(not sandbox.can_stand_at(Vector2(0,-288)), "DigiLab base must be solid")
	_check(sandbox.can_stand_at(Vector2(350,160)), "City plaza must be continuous")
	_check(not sandbox.can_stand_at(Vector2(1200,0)), "Exterior void must be blocked")
	# A long step across a footprint must stop; diagonal sliding must stay valid.
	sandbox.player.position = Vector2(-360,0)
	sandbox.player._try_move(Vector2(720,0))
	_check(sandbox.player.position.x < -235, "Long motion tunneled through the fountain")
	for index in range(80):
		sandbox.player._try_move(Vector2(2,2))
		_check(sandbox.can_stand_at(sandbox.player.position), "Diagonal slide entered an obstacle")
	# Contour the base through individually validated route segments.
	sandbox.player.position = Vector2(-360,0)
	for target: Vector2 in [Vector2(-360,176),Vector2(360,176),Vector2(360,0)]:
		for index in range(500):
			if sandbox.player.position.distance_to(target) < 2:
				break
			sandbox.player._try_move((target - sandbox.player.position).limit_length(2))
		_check(sandbox.player.position.distance_to(target) < 2, "Obstacle contour stalled")
	sandbox.player.position = Vector2(960,0)
	sandbox.player._try_move(Vector2(200,0))
	_check(sandbox.player.position.x < 1152, "Actor crossed the external edge")
	_check(sandbox.can_stand_at(sandbox.player.position), "Edge stopped without full body clearance")
	var counter: Node2D = sandbox.get_node("Depth/MarketCounter")
	for probe in [{"point":Vector2(-480,88),"front":true},{"point":Vector2(-688,96),"front":false}]:
		sandbox.player.position = probe.point
		_check(sandbox.can_stand_at(probe.point), "Depth probe is not a valid standing position")
		var depth: int = sandbox.resolve_actor_depth(sandbox.player)
		_check(depth > counter.z_index if probe.front else depth < counter.z_index,
			"Angled counter depth does not match its ground base")
	# A local NPC interaction must pause input and then resume it without saves.
	sandbox.player.position = Vector2(-552,164)
	_check(sandbox.can_stand_at(sandbox.player.position), "NPC approach has insufficient clearance")
	sandbox._inspect_nearby()
	_check(sandbox.dialogue.visible and not sandbox.player.movement_enabled, "NPC interaction did not pause movement")
	sandbox._inspect_nearby()
	_check(not sandbox.dialogue.visible and sandbox.player.movement_enabled, "NPC interaction did not resume movement")
	sandbox.player.position = sandbox.SPAWN
	sandbox.player.movement_enabled = false
	if DisplayServer.get_name() != "headless":
		for index in range(10):
			await process_frame
		var prefix := "private" if sandbox.use_private_art else "public"
		root.get_texture().get_image().save_png("res://.tmp/sandbox-%s-desktop.png" % prefix)
		sandbox.overview = true
		for index in range(4):
			await process_frame
		root.get_texture().get_image().save_png("res://.tmp/sandbox-%s-map.png" % prefix)
		sandbox.debug_view.visible = true
		for index in range(4):
			await process_frame
		root.get_texture().get_image().save_png("res://.tmp/sandbox-%s-collision.png" % prefix)
	print("[DarkmoonSandboxTest] %s failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
