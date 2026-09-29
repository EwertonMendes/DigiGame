extends Node

const ActorScript := preload("res://src/world/runtime/OverworldActor.gd")


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
	_assert_diagonal_navigation_slides_instead_of_sticking()
	_assert_head_on_boundary_stops_without_sideways_drift()
	print("overworld collision sliding regression passed")


func _assert_diagonal_navigation_slides_instead_of_sticking() -> void:
	var controller := DiagonalCorridorWorld.new()
	add_child(controller)

	var actor := ActorScript.new() as OverworldActor
	actor.configure(null, false, controller, "south")
	add_child(actor)
	actor.global_position = Vector2.ZERO
	actor.velocity = Vector2(180.0, 60.0)

	var requested_motion := Vector2(3.0, 1.0)
	actor.call("_try_move", requested_motion)

	var actual_motion := actor.global_position
	assert(
		actual_motion.length() > 2.0,
		"Overworld movement must keep progressing along a valid diagonal tangent instead of sticking when X/Y fallbacks are both blocked"
	)
	assert(
		absf(actor.global_position.x - actor.global_position.y) <= 0.751,
		"Navigation sliding must never leave the authored walkable corridor"
	)
	assert(
		actual_motion.dot(requested_motion) > 0.0,
		"Navigation sliding must preserve forward player intent"
	)

	actor.queue_free()
	controller.queue_free()


func _assert_head_on_boundary_stops_without_sideways_drift() -> void:
	var controller := RightBoundaryWorld.new()
	add_child(controller)

	var actor := ActorScript.new() as OverworldActor
	actor.configure(null, false, controller, "east")
	add_child(actor)
	actor.global_position = Vector2(-0.2, 0.0)
	actor.velocity = Vector2(180.0, 0.0)

	actor.call("_try_move", Vector2(3.0, 0.0))

	assert(
		actor.global_position.x <= 0.001,
		"Collision sliding must never cross a hard authored map boundary"
	)
	assert(
		absf(actor.global_position.y) <= 0.001,
		"A head-on collision must not invent arbitrary sideways movement"
	)
	assert(
		actor.velocity.length_squared() <= 0.001,
		"A fully blocked head-on movement must settle instead of keeping the walk velocity alive"
	)

	actor.queue_free()
	controller.queue_free()
