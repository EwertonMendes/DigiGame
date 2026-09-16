extends "res://src/battle/StableSequencedBattleController.gd"

# Turn progression and camera focus must not outrun combat presentation. This
# controller keeps the scheduler on the resolved action until the presentation
# layer says the impact has been readable long enough. It does not invent a
# gameplay delay of its own; attacks without a presentation deadline continue
# immediately.
var _turn_resolution_gate_active := false


func _end_turn() -> void:
	if _turn_resolution_gate_active or _battle_over or current_actor == null:
		return

	_turn_resolution_gate_active = true
	_input_locked = true
	await _wait_for_resolution_presentation()

	# The wait can overlap battle-ending events. Never advance the scheduler after
	# victory/defeat or after the actor has been invalidated.
	if _battle_over or current_actor == null or not is_instance_valid(current_actor):
		_turn_resolution_gate_active = false
		return

	super._end_turn()
	_turn_resolution_gate_active = false


func _wait_for_resolution_presentation() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var presentation := main.get_node_or_null("BattlePresentationFX")
	if presentation == null or not presentation.has_method("current_resolution_wait_seconds"):
		return

	# The presentation layer owns the deadline; this controller owns suspension
	# of the turn scheduler. Keeping those responsibilities separate prevents the
	# camera/HUD/current-actor state from advancing while the result is still being
	# shown, without hiding a gameplay timer in the camera itself.
	var remaining := maxf(0.0, float(presentation.call("current_resolution_wait_seconds")))
	if remaining > 0.001:
		await get_tree().create_timer(remaining).timeout
