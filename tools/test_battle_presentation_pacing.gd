extends SceneTree

const PresentationScript = preload("res://src/battle/SequencedBattlePresentationFX.gd")
const FUTURE_IMPACT_SECONDS := 0.08
const DAMAGE_HOLD_SECONDS := 0.38
const MIN_ENEMY_HANDOFF_BUDGET := 0.40
const MAX_ENEMY_HANDOFF_BUDGET := 0.52
const MIN_WAIT_ELAPSED := 0.34
const MAX_WAIT_ELAPSED := 0.62
const MAX_EXPIRED_BUDGET := 0.02

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Build the smallest real presentation tree needed for a damage event. The
	# important regression is the enemy-style handoff: combat resolution emits
	# damage and can request the next turn immediately, before the scheduled impact
	# callback has rendered its feedback.
	var main := Node2D.new()
	main.name = "Main"
	root.add_child(main)

	var digimon_controller := Node2D.new()
	digimon_controller.name = "DigimonController"
	main.add_child(digimon_controller)

	var attacker := CharacterBody2D.new()
	attacker.name = "EnemyActor"
	digimon_controller.add_child(attacker)
	var target := CharacterBody2D.new()
	target.name = "PlayerTarget"
	digimon_controller.add_child(target)

	var presentation := PresentationScript.new()
	presentation.name = "BattlePresentationFX"
	main.add_child(presentation)
	await process_frame

	presentation.set(
		"_impact_deadline_msec",
		Time.get_ticks_msec() + int(round(FUTURE_IMPACT_SECONDS * 1000.0))
	)
	presentation.call("_on_combat_event", {
		"type": "damage_applied",
		"actor_id": str(attacker.get_instance_id()),
		"target_id": str(target.get_instance_id()),
		"action_id": "basic_attack",
		"damage": 12,
		"critical": false,
	})

	# This query happens at the same point where an AI turn can auto-end. It must
	# already include both the pending impact and the post-impact readability hold;
	# waiting until _present_damage() runs is too late for enemy turns.
	var immediate_budget := float(presentation.call("current_resolution_wait_seconds"))
	_expect(
		immediate_budget >= MIN_ENEMY_HANDOFF_BUDGET and immediate_budget <= MAX_ENEMY_HANDOFF_BUDGET,
		"Enemy damage must reserve its camera hold before automatic turn handoff (remaining=%.3fs)." % immediate_budget
	)

	var wait_started := Time.get_ticks_msec()
	await presentation.call("wait_for_current_resolution")
	var wait_elapsed := float(Time.get_ticks_msec() - wait_started) / 1000.0
	_expect(
		wait_elapsed >= MIN_WAIT_ELAPSED and wait_elapsed <= MAX_WAIT_ELAPSED,
		"Resolution awaitable must keep the enemy result readable until presentation completes (elapsed=%.3fs)." % wait_elapsed
	)

	var expired := float(presentation.call("current_resolution_wait_seconds"))
	_expect(
		expired <= MAX_EXPIRED_BUDGET,
		"Completed presentation must not leak a stale turn delay (remaining=%.3fs)." % expired
	)

	main.queue_free()
	await process_frame

	if _failures.is_empty():
		print("[BattlePresentationPacingTest] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[BattlePresentationPacingTest] %s" % failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
