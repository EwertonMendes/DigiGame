extends SceneTree

const PresentationScript = preload("res://src/battle/SequencedBattlePresentationFX.gd")
const HOLD_SECONDS := 0.10
const MIN_EXPECTED_WAIT_MSEC := 65
const MAX_EXPECTED_WAIT_MSEC := 500
const MAX_EXPIRED_WAIT_MSEC := 60

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PresentationScript.new()
	root.add_child(presentation)
	await process_frame

	var started := Time.get_ticks_msec()
	presentation.call("_extend_resolution_deadline", HOLD_SECONDS)
	await presentation.call("wait_for_current_resolution")
	var elapsed := Time.get_ticks_msec() - started
	_expect(
		elapsed >= MIN_EXPECTED_WAIT_MSEC and elapsed <= MAX_EXPECTED_WAIT_MSEC,
		"Resolution gate must wait for the active readability window (elapsed=%dms)." % elapsed
	)

	started = Time.get_ticks_msec()
	await presentation.call("wait_for_current_resolution")
	elapsed = Time.get_ticks_msec() - started
	_expect(
		elapsed <= MAX_EXPIRED_WAIT_MSEC,
		"An expired presentation deadline must not add a stale delay (elapsed=%dms)." % elapsed
	)

	presentation.queue_free()
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
