extends SceneTree

const SCENE = preload("res://experiments/darkmoon_sandbox/DarkmoonSandbox.tscn")
var failures: Array[String] = []


func _initialize() -> void:
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
	sandbox.player.movement_enabled = false
	_check(sandbox.can_stand_at(sandbox.SPAWN), "Invalid spawn clearance")
	for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,
		Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		sandbox.player.position = Vector2(0,112)
		var expected: Vector2 = sandbox.player.position + direction.normalized() * 24
		sandbox.player._try_move(direction.normalized() * 24)
		_check(sandbox.player.position.distance_to(expected) < 0.1, "Eight-direction motion failed: %s" % direction)
		_check(sandbox.can_stand_at(sandbox.player.position), "Motion entered a void")
	# Walk the complete road loop and both courts through the actual actor.
	sandbox.player.position = sandbox.SPAWN
	_check(sandbox._run_route_check(), "Complete road and court route failed")
	_check(sandbox.can_stand_at(Vector2(0,-85)), "Roof pixels incorrectly block ground behind the terminal")
	_check(not sandbox.can_stand_at(Vector2.ZERO), "Terminal footprint must be solid")
	_check(not sandbox.can_stand_at(Vector2(350,160)), "Interior void must be blocked")
	# A long step across a footprint must stop; diagonal sliding must stay valid.
	sandbox.player.position = Vector2(-100,0)
	sandbox.player._try_move(Vector2(200,0))
	_check(sandbox.player.position.x < -35, "Long motion tunneled through the terminal")
	for index in range(80):
		sandbox.player._try_move(Vector2(2,2))
		_check(sandbox.can_stand_at(sandbox.player.position), "Diagonal slide entered an obstacle")
	# Contour the base through individually validated route segments.
	sandbox.player.position = Vector2(-100,0)
	for target: Vector2 in [Vector2(-100,50),Vector2(100,50),Vector2(100,0)]:
		for index in range(160):
			if sandbox.player.position.distance_to(target) < 2:
				break
			sandbox.player._try_move((target - sandbox.player.position).limit_length(2))
		_check(sandbox.player.position.distance_to(target) < 2, "Obstacle contour stalled")
	sandbox.player.position = Vector2(1000,0)
	sandbox.player._try_move(Vector2(200,0))
	_check(sandbox.player.position.x < 1070, "Actor crossed the external edge")
	_check(sandbox.can_stand_at(sandbox.player.position), "Edge stopped without full body clearance")
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
