extends RefCounted
class_name DigiTweenGuard

## Event-driven fallback for presentation tweens.
##
## Web renderers can occasionally fail to deliver Tween.finished even though
## gameplay must keep progressing. This guard races Tween.finished against a
## SceneTreeTimer without polling Tween state every frame. Callers own the final
## visual state and should apply it explicitly after this method returns.

signal settled

var _resolved := false
var _timed_out := false


func await_tween(tree: SceneTree, tween: Tween, timeout_seconds: float) -> bool:
	if tree == null or tween == null:
		return false

	_resolved = false
	_timed_out = false
	tween.finished.connect(_resolve.bind(false), CONNECT_ONE_SHOT)
	var timer := tree.create_timer(maxf(timeout_seconds, 0.05), true, false, true)
	timer.timeout.connect(_resolve.bind(true), CONNECT_ONE_SHOT)
	await settled
	return _timed_out


func _resolve(timed_out: bool) -> void:
	if _resolved:
		return
	_resolved = true
	_timed_out = timed_out
	settled.emit()
