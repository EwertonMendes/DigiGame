extends "res://src/battle/ReliableBattlePresentationFX.gd"

# Keep the battlefield framed on the resolved action long enough for the hit
# reaction, impact burst and damage number to become readable. The presentation
# layer owns this countdown; turn progression only reads the remaining budget.
const DAMAGE_READABILITY_HOLD := 0.38
const MISS_READABILITY_HOLD := 0.34

var _resolution_timer: SceneTreeTimer = null


func _present_action_started(event: Dictionary) -> void:
	# A new action owns a new presentation window. Dropping our reference is
	# enough; SceneTreeTimer is one-shot and any previous timer can expire without
	# affecting the new action.
	_resolution_timer = null
	super._present_action_started(event)


func _present_damage(event: Dictionary, profile: Dictionary) -> void:
	super._present_damage(event, profile)
	_extend_resolution_hold(DAMAGE_READABILITY_HOLD)


func _present_miss(event: Dictionary) -> void:
	super._present_miss(event)
	_extend_resolution_hold(MISS_READABILITY_HOLD)


func _present_knockout(event: Dictionary) -> void:
	super._present_knockout(event)
	_extend_resolution_hold(DAMAGE_READABILITY_HOLD)


func wait_for_current_impact() -> void:
	var remaining: float = maxf(
		0.0,
		float(_impact_deadline_msec - Time.get_ticks_msec()) / 1000.0
	)
	if remaining > 0.001:
		await get_tree().create_timer(remaining).timeout


func current_resolution_wait_seconds() -> float:
	# SceneTreeTimer gives us engine-time remaining instead of manually comparing
	# wall-clock ticks. This means time naturally consumed by hit/KO presentation
	# is not charged again when the controller finally reaches turn handoff.
	if _resolution_timer == null:
		return 0.0
	return maxf(0.0, _resolution_timer.time_left)


func _extend_resolution_hold(duration: float) -> void:
	var requested := maxf(0.0, duration)
	if requested <= 0.001:
		return

	# Multiple impacted targets can report within one action. Preserve the longest
	# remaining readability window rather than stacking per-target sleeps.
	if _resolution_timer != null and _resolution_timer.time_left >= requested:
		return
	_resolution_timer = get_tree().create_timer(requested)
