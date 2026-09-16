extends SceneTree

const PresentationScript = preload("res://src/battle/SequencedBattlePresentationFX.gd")
const HOLD_SECONDS := 0.16
const MIN_INITIAL_BUDGET := 0.09
const MAX_INITIAL_BUDGET := 0.17
const MAX_EXPIRED_BUDGET := 0.01

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PresentationScript.new()
	root.add_child(presentation)
	await process_frame

	presentation.call("_extend_resolution_hold", HOLD_SECONDS)
	var remaining := float(presentation.call("current_resolution_wait_seconds"))
	_expect(
		remaining >= MIN_INITIAL_BUDGET and remaining <= MAX_INITIAL_BUDGET,
		"Active readability hold must expose its remaining presentation budget (remaining=%.3fs)." % remaining
	)

	if remaining > 0.0:
		await create_timer(remaining + 0.04).timeout
	var expired := float(presentation.call("current_resolution_wait_seconds"))
	_expect(
		expired <= MAX_EXPIRED_BUDGET,
		"Expired presentation hold must not leak a stale delay (remaining=%.3fs)." % expired
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
