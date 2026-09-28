extends "res://src/world/HubActor.gd"
class_name OverworldActor

const NAVIGATION_SUBSTEP := 4.0


func _try_move(offset: Vector2) -> void:
	if offset.length_squared() <= 0.000001:
		return

	# Navigation is authoritative; PhysicsServer collision is only a secondary
	# constraint for dynamic bodies such as NPCs. Resolve long/low-FPS motion in
	# small steps so neither the requested move nor a physics slide can jump from
	# one valid point to another through an invalid wall footprint.
	var remaining := offset.length()
	var direction := offset / remaining
	var moved_any := false

	while remaining > 0.001:
		var step_length := minf(NAVIGATION_SUBSTEP, remaining)
		var requested_step := direction * step_length
		var resolved_step := _resolve_navigation_step(requested_step)
		if resolved_step.length_squared() <= 0.000001:
			velocity = Vector2.ZERO
			break

		var before_step := global_position
		var collision := move_and_collide(resolved_step)
		if not _can_move_to(global_position):
			# A physical contact must never be allowed to move the body outside the
			# authored navigation contract. Roll back this substep completely.
			global_position = before_step
			velocity = Vector2.ZERO
			break

		if collision != null:
			var slide := collision.get_remainder().slide(collision.get_normal())
			if slide.length_squared() > 0.0001:
				var before_slide := global_position
				var slide_target := before_slide + slide
				if _can_move_to(slide_target):
					move_and_collide(slide)
					if not _can_move_to(global_position):
						global_position = before_slide

		if global_position.distance_squared_to(before_step) <= 0.000001:
			velocity = Vector2.ZERO
			break

		moved_any = true
		remaining -= step_length

	if not moved_any and remaining > 0.001:
		velocity = Vector2.ZERO
	world_position_changed.emit(global_position)


func _resolve_navigation_step(step: Vector2) -> Vector2:
	if _can_move_to(global_position + step):
		return step

	# Preserve the established screen-axis wall slide behaviour, but validate the
	# selected component through the same navigation source before physics sees it.
	var horizontal := Vector2(step.x, 0.0)
	if absf(horizontal.x) > 0.001 and _can_move_to(global_position + horizontal):
		return horizontal

	var vertical := Vector2(0.0, step.y)
	if absf(vertical.y) > 0.001 and _can_move_to(global_position + vertical):
		return vertical

	return Vector2.ZERO


func _can_move_to(candidate: Vector2) -> bool:
	if _world_controller == null or not _world_controller.has_method("can_actor_move_to"):
		return true
	return bool(_world_controller.call("can_actor_move_to", candidate, self))
