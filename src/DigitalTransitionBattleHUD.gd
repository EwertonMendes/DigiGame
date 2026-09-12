extends "res://src/EscapeBattleHUD.gd"


func _build_escape_ui() -> void:
	super._build_escape_ui()
	# The shared BattleResultScreen is the single source of truth once a battle
	# ends. Keep the legacy retreat result node permanently hidden so it can never
	# stack another modal on top of the RETREATED result screen.
	if _escape_result != null:
		_escape_result.visible = false
		_escape_result.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_escape_result(_result: Dictionary) -> void:
	# EscapeBattleHUD historically rendered its own ESCAPED result panel. The
	# result domain now handles the escaped outcome properly, so showing a second
	# result here only duplicates UI and steals focus from the real result screen.
	if _escape_result != null:
		_escape_result.visible = false
	if _escape_announcement != null:
		_escape_announcement.visible = false


func _on_escape_combat_event(event: Dictionary) -> void:
	# Failed/blocked attempts still need immediate feedback. A successful flee is
	# communicated by the RETREATED battle-result screen instead of another
	# transient ESCAPED overlay.
	if String(event.get("type", "")) == "flee_success":
		if _escape_announcement_tween != null and _escape_announcement_tween.is_valid():
			_escape_announcement_tween.kill()
		if _escape_announcement != null:
			_escape_announcement.visible = false
		return
	super._on_escape_combat_event(event)


func _on_result_return_requested() -> void:
	_return_to_terminal_commons()


func _return_to_terminal_commons() -> void:
	if DigitalSceneTransition.is_transitioning():
		return
	DigitalSceneTransition.return_to_hub()
