extends "res://src/world/HubActor.gd"
class_name OverworldActor

const INTERIOR_LOGICAL_STEP_MAX := 2.0


func _try_move(offset: Vector2) -> void:
	if offset.length_squared() <= 0.000001:
		return

	# Mobile/Web can deliver a larger delta on a slow frame. Interior walls are
	# thin ground-plane boundaries, so checking only the final candidate leaves
	# the actor one whole frame away from the wall (or can skip a narrow corner).
	# Substep ONLY the authored interior navigation path; the exterior keeps its
	# existing cost/profile.
	var step_count := 1
	if (
		_world_controller != null
		and _world_controller.has_method("is_precise_interior_navigation_active")
		and bool(_world_controller.call("is_precise_interior_navigation_active"))
	):
		step_count = maxi(1, ceili(offset.length() / INTERIOR_LOGICAL_STEP_MAX))

	var step := offset / float(step_count)
	for _index in range(step_count):
		if not _try_move_step(step):
			break
	world_position_changed.emit(global_position)


func _try_move_step(offset: Vector2) -> bool:
	var candidate := global_position + offset
	if _world_controller != null and _world_controller.has_method("can_actor_move_to"):
		if not bool(_world_controller.call("can_actor_move_to", candidate, self)):
			var horizontal_offset := Vector2(offset.x, 0.0)
			var vertical_offset := Vector2(0.0, offset.y)
			var horizontal_ok := (
				absf(offset.x) > 0.001
				and bool(_world_controller.call(
					"can_actor_move_to",
					global_position + horizontal_offset,
					self
				))
			)
			var vertical_ok := (
				absf(offset.y) > 0.001
				and bool(_world_controller.call(
					"can_actor_move_to",
					global_position + vertical_offset,
					self
				))
			)
			if horizontal_ok:
				offset = horizontal_offset
				velocity.y = 0.0
			elif vertical_ok:
				offset = vertical_offset
				velocity.x = 0.0
			else:
				velocity = Vector2.ZERO
				return false

	var collision := move_and_collide(offset)
	if collision != null:
		var slide := collision.get_remainder().slide(collision.get_normal())
		if slide.length_squared() > 0.0001:
			move_and_collide(slide)
	return true
