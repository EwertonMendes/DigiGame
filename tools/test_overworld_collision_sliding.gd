extends Node


class PhysicsProbeActor:
	extends OverworldActor

	var _queued_test_motion := Vector2.ZERO
	var _test_motion_pending := false
	var test_motion_finished := false

	func queue_test_motion(motion: Vector2) -> void:
		_queued_test_motion = motion
		_test_motion_pending = true
		test_motion_finished = false

	func _physics_process(_delta: float) -> void:
		if not _test_motion_pending:
			return
		_try_move(_queued_test_motion)
		_test_motion_pending = false
		test_motion_finished = true


class DiagonalCorridorWorld:
	extends Node

	func can_actor_move_to(candidate: Vector2, _actor: Node) -> bool:
		# A narrow diagonal lane reproduces the important isometric failure mode:
		# direct, screen-horizontal and screen-vertical endpoints can all be
		# blocked even though a forward tangent along the lane is available.
		return absf(candidate.x - candidate.y) <= 0.75


class RightBoundaryWorld:
	extends Node

	func can_actor_move_to(candidate: Vector2, _actor: Node) -> bool:
		return candidate.x <= 0.0


func _ready() -> void:
	await _assert_diagonal_navigation_slides_instead_of_sticking()
	await _assert_head_on_boundary_stops_without_sideways_drift()
	print("overworld collision sliding regression passed")


func _assert_diagonal_navigation_slides_instead_of_sticking() -> void:
	var controller := DiagonalCorridorWorld.new()
	add_child(controller)

	var actor := PhysicsProbeActor.new()
	actor.configure(null, false, controller, "south")
	# This regression isolates the authored-navigation resolver. The parent
	# world-area suite is building Central City in the same World2D, so leaving
	# the synthetic body on layer/mask 1 would let unrelated city colliders push
	# it during PhysicsServer2D recovery and invalidate this controlled probe.
	actor.collision_layer = 0
	actor.collision_mask = 0
	add_child(actor)

	await get_tree().physics_frame
	actor.global_position = Vector2.ZERO
	actor.velocity = Vector2(180.0, 60.0)

	var requested_motion := Vector2(3.0, 1.0)
	await _run_test_motion(actor, requested_motion)

	var actual_motion := actor.global_position
	assert(
		actual_motion.length() > 2.0,
		"Overworld movement must keep progressing along a valid diagonal tangent instead of sticking when X/Y fallbacks are both blocked; actual=%s" % str(actual_motion)
	)
	assert(
		absf(actor.global_position.x - actor.global_position.y) <= 0.751,
		"Navigation sliding must never leave the authored walkable corridor; position=%s" % str(actor.global_position)
	)
	assert(
		actual_motion.dot(requested_motion) > 0.0,
		"Navigation sliding must preserve forward player intent; actual=%s requested=%s" % [str(actual_motion), str(requested_motion)]
	)

	actor.queue_free()
	controller.queue_free()
	await get_tree().physics_frame


func _assert_head_on_boundary_stops_without_sideways_drift() -> void:
	var controller := RightBoundaryWorld.new()
	add_child(controller)

	var actor := PhysicsProbeActor.new()
	actor.configure(null, false, controller, "east")
	actor.collision_layer = 0
	actor.collision_mask = 0
	add_child(actor)

	await get_tree().physics_frame
	actor.global_position = Vector2(-0.2, 0.0)
	actor.velocity = Vector2(180.0, 0.0)

	await _run_test_motion(actor, Vector2(3.0, 0.0))

	assert(
		actor.global_position.x <= 0.001,
		"Collision sliding must never cross a hard authored map boundary; position=%s" % str(actor.global_position)
	)
	assert(
		absf(actor.global_position.y) <= 0.001,
		"A head-on collision must not invent arbitrary sideways movement; position=%s" % str(actor.global_position)
	)
	assert(
		actor.velocity.length_squared() <= 0.001,
		"A fully blocked head-on movement must settle instead of keeping the walk velocity alive; velocity=%s position=%s" % [str(actor.velocity), str(actor.global_position)]
	)

	actor.queue_free()
	controller.queue_free()


func _run_test_motion(actor: PhysicsProbeActor, motion: Vector2) -> void:
	actor.queue_test_motion(motion)
	# SceneTree.physics_frame is emitted before _physics_process(). The first
	# await enters the frame that executes the queued motion; the following
	# signal observes its completed result.
	for _frame in range(4):
		await get_tree().physics_frame
		if actor.test_motion_finished:
			return
	assert(false, "Synthetic OverworldActor did not execute queued motion inside _physics_process()")
