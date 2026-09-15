extends "res://src/EscapeBattleHUD.gd"

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const ConfirmationModalScript = preload("res://src/ui/components/DigiConfirmationModal.gd")

var _v2_escape_modal: DigiConfirmationModal = null


func _build_escape_ui() -> void:
	super._build_escape_ui()
	# Replace the legacy flee prompt with the shared V2 confirmation component.
	# Announcements and result handling remain owned by EscapeBattleHUD.
	if _escape_modal_layer != null:
		var old_parent := _escape_modal_layer.get_parent()
		if old_parent != null:
			old_parent.remove_child(_escape_modal_layer)
		_escape_modal_layer.queue_free()

	_v2_escape_modal = ConfirmationModalScript.new() as DigiConfirmationModal
	_v2_escape_modal.name = "EscapeConfirmation"
	_v2_escape_modal.configure(
		"FLEE FROM BATTLE?",
		"Are you sure you want to flee? If the attempt succeeds, the battle ends immediately.",
		"YES, FLEE",
		"NO, STAY",
		V2.RED,
		"RETREAT"
	)
	_v2_escape_modal.confirmed.connect(_on_escape_confirmed)
	_v2_escape_modal.cancelled.connect(_focus_flee_command)
	add_child(_v2_escape_modal)
	_escape_modal_layer = _v2_escape_modal
	_escape_modal_panel = _v2_escape_modal.get_panel()
	_escape_confirm = _v2_escape_modal.get_confirm_button()
	_escape_cancel = _v2_escape_modal.get_cancel_button()

	# The shared BattleResultScreen is the single source of truth once a battle
	# ends. Keep the legacy retreat result node permanently hidden so it can never
	# stack another modal on top of the RETREATED result screen.
	if _escape_result != null:
		_escape_result.visible = false
		_escape_result.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open_escape_modal() -> void:
	if _v2_escape_modal == null:
		return
	_v2_escape_modal.open_dialog(_flee_button)


func _close_escape_modal() -> void:
	if _v2_escape_modal != null and _v2_escape_modal.visible:
		_v2_escape_modal.close_dialog()
	_focus_flee_command()


func _focus_flee_command() -> void:
	if _flee_button != null and _flee_button.visible and not _flee_button.disabled:
		_flee_button.grab_focus()


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
