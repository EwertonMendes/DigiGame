extends "res://src/battle/ReliableBattlePresentationFX.gd"

# Keep the battlefield framed on the resolved action long enough for the hit
# reaction, impact burst and damage number to become readable. This is a
# presentation deadline, not a turn timer: the battle controller only waits
# when an actual damage/miss/KO presentation extends it.
const DAMAGE_READABILITY_HOLD := 0.38
const MISS_READABILITY_HOLD := 0.34

var _resolution_deadline_msec: int = 0


func _present_action_started(event: Dictionary) -> void:
	# A new action owns a new presentation window. Clearing the previous deadline
	# prevents an unrelated turn (Defend/Wait/status skip) from inheriting stale
	# pacing state from an earlier attack.
	_resolution_deadline_msec = 0
	super._present_action_started(event)


func _present_damage(event: Dictionary, profile: Dictionary) -> void:
	super._present_damage(event, profile)
	_extend_resolution_deadline(DAMAGE_READABILITY_HOLD)


func _present_miss(event: Dictionary) -> void:
	super._present_miss(event)
	_extend_resolution_deadline(MISS_READABILITY_HOLD)


func _present_knockout(event: Dictionary) -> void:
	super._present_knockout(event)
	_extend_resolution_deadline(DAMAGE_READABILITY_HOLD)


func wait_for_current_impact() -> void:
	var remaining: float = maxf(
		0.0,
		float(_impact_deadline_msec - Time.get_ticks_msec()) / 1000.0
	)
	if remaining > 0.001:
		await get_tree().create_timer(remaining).timeout


func current_resolution_wait_seconds() -> float:
	# Keep coroutine ownership in the battle controller. Dynamic `Node.call()` is
	# intentionally used only for this synchronous query; awaiting a dynamically
	# invoked coroutine does not propagate its suspension reliably in Godot 4.
	# Returning the remaining presentation budget gives the controller one clear
	# value to await without duplicating presentation timing rules.
	return maxf(
		0.0,
		float(_resolution_deadline_msec - Time.get_ticks_msec()) / 1000.0
	)


func _extend_resolution_deadline(duration: float) -> void:
	var requested_deadline := Time.get_ticks_msec() + int(ceil(maxf(0.0, duration) * 1000.0))
	_resolution_deadline_msec = maxi(_resolution_deadline_msec, requested_deadline)
