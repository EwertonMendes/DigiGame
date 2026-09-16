extends "res://src/battle/ReliableBattlePresentationFX.gd"

# Keep the battlefield framed on the resolved action long enough for the hit
# reaction, impact burst and damage number to become readable. The presentation
# layer owns this timeline; turn progression only waits for it to finish.
const DAMAGE_READABILITY_HOLD := 0.38
const MISS_READABILITY_HOLD := 0.34
const KNOCKOUT_PRESENTATION_DELAY := 0.20

var _resolution_deadline_msec: int = 0


func _on_combat_event(event: Dictionary) -> void:
	# Reserve the readability window synchronously when the combat result event is
	# received. This is important for AI turns: they can request turn handoff in
	# the same frame as damage resolution, before the scheduled impact callback has
	# actually rendered the number/reaction. The old implementation only started
	# the hold inside _present_damage(), which left exactly that race open.
	match String(event.get("type", "")):
		"damage_applied":
			_reserve_resolution_hold(DAMAGE_READABILITY_HOLD)
		"action_missed":
			_reserve_resolution_hold(MISS_READABILITY_HOLD)
		"unit_knocked_out":
			_reserve_resolution_hold(DAMAGE_READABILITY_HOLD, KNOCKOUT_PRESENTATION_DELAY)

	super._on_combat_event(event)


func _present_action_started(event: Dictionary) -> void:
	# Each action owns a fresh presentation deadline. An old action must never keep
	# a later turn blocked.
	_resolution_deadline_msec = 0
	super._present_action_started(event)


func _present_damage(event: Dictionary, profile: Dictionary) -> void:
	super._present_damage(event, profile)
	# Keep this as a safety net for direct presentation calls and for any future
	# event source that bypasses _on_combat_event(). max() semantics prevent double
	# charging the normal event path.
	_reserve_resolution_hold(DAMAGE_READABILITY_HOLD)


func _present_miss(event: Dictionary) -> void:
	super._present_miss(event)
	_reserve_resolution_hold(MISS_READABILITY_HOLD)


func _present_knockout(event: Dictionary) -> void:
	super._present_knockout(event)
	_reserve_resolution_hold(DAMAGE_READABILITY_HOLD)


func wait_for_current_impact() -> void:
	var remaining: float = maxf(
		0.0,
		float(_impact_deadline_msec - Time.get_ticks_msec()) / 1000.0
	)
	if remaining > 0.001:
		await get_tree().create_timer(remaining).timeout


func current_resolution_wait_seconds() -> float:
	if _resolution_deadline_msec <= 0:
		return 0.0
	return maxf(
		0.0,
		float(_resolution_deadline_msec - Time.get_ticks_msec()) / 1000.0
	)


func wait_for_current_resolution() -> void:
	# Re-read the deadline after every wait. Multi-target attacks and KO feedback
	# may extend the same action while presentation is still in flight; the caller
	# should wait for the complete visual result, not for a stale snapshot.
	while true:
		var remaining := current_resolution_wait_seconds()
		if remaining <= 0.001:
			return
		await get_tree().create_timer(remaining).timeout


func _reserve_resolution_hold(duration: float, extra_delay: float = 0.0) -> void:
	var hold := maxf(0.0, duration)
	if hold <= 0.001:
		return

	# Anchor the hold to whichever happens later: now or the already-scheduled
	# impact. This means an AI turn can query the budget immediately after combat
	# resolution and still preserve the upcoming damage feedback on screen.
	var now_msec := Time.get_ticks_msec()
	var anchor_msec := maxi(now_msec, _impact_deadline_msec)
	anchor_msec += int(round(maxf(0.0, extra_delay) * 1000.0))
	var requested_deadline := anchor_msec + int(round(hold * 1000.0))
	_resolution_deadline_msec = maxi(_resolution_deadline_msec, requested_deadline)
