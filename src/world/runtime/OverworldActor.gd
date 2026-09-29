extends "res://src/world/HubActor.gd"
class_name OverworldActor

const NAVIGATION_SUBSTEP := 4.0
const NAVIGATION_MIN_MOTION := 0.05
const NAVIGATION_CONTACT_SEARCH_ITERATIONS := 7
const NAVIGATION_SLIDE_ANGLES := [
	PI / 12.0, # 15 degrees
	PI / 6.0,  # 30 degrees
	PI / 4.0,  # 45 degrees
	PI / 3.0,  # 60 degrees
]
const PHYSICS_MAX_SLIDES := 4
const MOTION_EPSILON_SQUARED := 0.000001


func _try_move(offset: Vector2) -> void:
	if offset.length_squared() <= MOTION_EPSILON_SQUARED:
		return

	# Authored navigation remains the source of truth. Resolve long/low-FPS
	# movement in small swept steps so running can never tunnel through a wall,
	# building footprint, map boundary or level transition.
	#
	# A blocked step is resolved in two phases:
	# 1. advance as far as possible to the contact plane;
	# 2. spend the remaining movement budget along the closest valid tangent.
	#
	# This avoids the old X/Y-only fallback, which could wedge the actor against
	# diagonal/isometric boundaries even when a clear tangent existed.
	var remaining := offset.length()
	var direction := offset / remaining
	var moved_any := false

	while remaining > NAVIGATION_MIN_MOTION:
		var step_length := minf(NAVIGATION_SUBSTEP, remaining)
		var requested_step := direction * step_length
		var resolved_step := _resolve_navigation_step(requested_step)
		if resolved_step.length_squared() <= MOTION_EPSILON_SQUARED:
			velocity = Vector2.ZERO
			break

		var before_step := global_position
		var physics_moved := _move_with_collision_sliding(resolved_step)
		var actual_motion := global_position - before_step
		if not physics_moved or actual_motion.length_squared() <= MOTION_EPSILON_SQUARED:
			velocity = Vector2.ZERO
			break

		moved_any = true
		# A navigation contact may intentionally return only part of the requested
		# substep. Consume only that distance so the rest can be resolved from the
		# actual contact point during this same physics frame.
		remaining = maxf(0.0, remaining - resolved_step.length())

	if not moved_any and remaining > NAVIGATION_MIN_MOTION:
		velocity = Vector2.ZERO
	world_position_changed.emit(global_position)


func _move_with_collision_sliding(motion: Vector2) -> bool:
	var remaining_motion := motion
	var moved_any := false

	# move_and_collide() stops at one contact. Resolve the remainder repeatedly,
	# mirroring CharacterBody2D's multi-contact slide behaviour while retaining
	# our authored-navigation validation after every physical move.
	for _slide_index in range(PHYSICS_MAX_SLIDES):
		if remaining_motion.length_squared() <= MOTION_EPSILON_SQUARED:
			break

		var before_motion := global_position
		var collision := move_and_collide(remaining_motion)
		if not _can_move_to(global_position):
			# Physics is secondary to authored navigation. A recovery/contact must
			# never place the actor inside a logical blocker.
			global_position = before_motion
			break

		if global_position.distance_squared_to(before_motion) > MOTION_EPSILON_SQUARED:
			moved_any = true

		if collision == null:
			break

		var remainder := collision.get_remainder()
		if remainder.length_squared() <= MOTION_EPSILON_SQUARED:
			break

		var slide := remainder.slide(collision.get_normal())
		if slide.length_squared() <= MOTION_EPSILON_SQUARED:
			break

		# Top-down movement should not lose all speed merely because the contact
		# normal removed one component. Keep the remaining travel budget while
		# rotating it onto the collision tangent, equivalent to floating motion.
		slide = slide.normalized() * remainder.length()
		var navigable_slide := _resolve_navigation_step(slide)
		if navigable_slide.length_squared() <= MOTION_EPSILON_SQUARED:
			break
		remaining_motion = navigable_slide

	return moved_any


func _resolve_navigation_step(step: Vector2) -> Vector2:
	if step.length_squared() <= MOTION_EPSILON_SQUARED:
		return Vector2.ZERO
	if _navigation_motion_is_valid(step):
		return step

	# First reach the actual boundary instead of steering away several pixels
	# early. The next loop iteration can then resolve the unused budget from the
	# contact point itself.
	var direct_contact := _largest_safe_motion(step)
	if direct_contact.length() >= NAVIGATION_MIN_MOTION:
		return direct_contact

	var step_length := step.length()
	var desired_direction := step / step_length

	# At the contact plane, find the smallest angular change that remains
	# navigable. Both sides are evaluated at each angle; a short look-ahead is
	# only used as a deterministic tie-breaker when both tangents are open.
	for angle_value in NAVIGATION_SLIDE_ANGLES:
		var angle := float(angle_value)
		var best_candidate := Vector2.ZERO
		var best_clearance_score := -1
		for sign_value in [-1.0, 1.0]:
			var candidate := desired_direction.rotated(angle * sign_value) * step_length
			if not _navigation_motion_is_valid(candidate):
				continue
			var clearance_score := 1 if _navigation_motion_is_valid(candidate * 1.5) else 0
			if clearance_score > best_clearance_score:
				best_candidate = candidate
				best_clearance_score = clearance_score
		if best_candidate.length_squared() > MOTION_EPSILON_SQUARED:
			return best_candidate

	return Vector2.ZERO


func _largest_safe_motion(step: Vector2) -> Vector2:
	var low := 0.0
	var high := 1.0
	for _iteration in range(NAVIGATION_CONTACT_SEARCH_ITERATIONS):
		var middle := (low + high) * 0.5
		if _navigation_motion_is_valid(step * middle):
			low = middle
		else:
			high = middle

	var safe_motion := step * low
	return safe_motion if safe_motion.length() >= NAVIGATION_MIN_MOTION else Vector2.ZERO


func _navigation_motion_is_valid(motion: Vector2) -> bool:
	if motion.length_squared() <= MOTION_EPSILON_SQUARED:
		return true

	# Validate the middle as well as the endpoint. Combined with the 4 px outer
	# substep this keeps navigation swept: a locally valid endpoint cannot jump
	# across a thin blocker or an invalid topology seam.
	if not _can_move_to(global_position + motion * 0.5):
		return false
	return _can_move_to(global_position + motion)


func _can_move_to(candidate: Vector2) -> bool:
	if _world_controller == null or not _world_controller.has_method("can_actor_move_to"):
		return true
	return bool(_world_controller.call("can_actor_move_to", candidate, self))
