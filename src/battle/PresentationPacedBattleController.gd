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
	if presentation == null:
		return

	# Prefer a presentation-owned awaitable so the deadline can still grow while
	# multi-target/KO feedback is being scheduled. This is especially important for
	# enemy turns, which request handoff automatically in the same frame as their
	# attack finishes.
	if presentation.has_method("wait_for_current_resolution"):
		await presentation.call("wait_for_current_resolution")
		return

	# Compatibility fallback for presentation implementations that only expose a
	# snapshot budget.
	if not presentation.has_method("current_resolution_wait_seconds"):
		return
	var remaining := maxf(0.0, float(presentation.call("current_resolution_wait_seconds")))
	if remaining > 0.001:
		await get_tree().create_timer(remaining).timeout
