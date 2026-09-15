extends "res://src/EscapeBattleHUD.gd"

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const ConfirmationModalScript = preload("res://src/ui/components/DigiConfirmationModal.gd")

var _v2_escape_modal: DigiConfirmationModal = null
var _legacy_escape_modal_layer: Control = null


func _build_escape_ui() -> void:
	super._build_escape_ui()
	# EscapeBattleHUD builds the legacy modal together with the announcement/result
	# surfaces. Keep that hidden modal intact during battle startup: removing it
	# here used to leave _escape_title/_escape_question pointing at queued-for-free
	# children while _layout_dock() still ran in the same _ready() sequence.
	# The V2 modal is materialized lazily when Flee is actually requested, after
	# the battle scene is stable.
	_legacy_escape_modal_layer = _escape_modal_layer

	# The shared BattleResultScreen is the single source of truth once a battle
	# ends. Keep the legacy retreat result node permanently hidden so it can never
	# stack another modal on top of the RETREATED result screen.
	if _escape_result != null:
		_escape_result.visible = false
		_escape_result.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ensure_v2_escape_modal() -> void:
	if _v2_escape_modal != null and is_instance_valid(_v2_escape_modal):
		return

	# Only retire the hidden legacy confirmation after startup has completed and
	# the player explicitly asks to flee. Clear every inherited pointer owned by
	# that subtree before it is freed so no later layout/input path can retain a
	# stale Object reference.
	if _legacy_escape_modal_layer != null and is_instance_valid(_legacy_escape_modal_layer):
		var legacy_parent := _legacy_escape_modal_layer.get_parent()
		if legacy_parent != null:
			legacy_parent.remove_child(_legacy_escape_modal_layer)
		_legacy_escape_modal_layer.queue_free()
	_legacy_escape_modal_layer = null
	_escape_modal_layer = null
	_escape_modal_panel = null
	_escape_title = null
	_escape_question = null
	_escape_confirm = null
	_escape_cancel = null

	_v2_escape_modal = ConfirmationModalScript.new() as DigiConfirmationModal
	_v2_escape_modal.name = "EscapeConfirmation"
	add_child(_v2_escape_modal)
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
	_escape_modal_layer = _v2_escape_modal
	_escape_modal_panel = _v2_escape_modal.get_panel()
	_escape_confirm = _v2_escape_modal.get_confirm_button()
	_escape_cancel = _v2_escape_modal.get_cancel_button()


func _open_escape_modal() -> void:
	_ensure_v2_escape_modal()
	if _v2_escape_modal == null:
		return
	_v2_escape_modal.open_dialog(_flee_button)


func _close_escape_modal() -> void:
	if _v2_escape_modal != null and is_instance_valid(_v2_escape_modal) and _v2_escape_modal.visible:
		_v2_escape_modal.close_dialog()
	elif _legacy_escape_modal_layer != null and is_instance_valid(_legacy_escape_modal_layer):
		_legacy_escape_modal_layer.visible = false
	_focus_flee_command()


func _focus_flee_command() -> void:
	if _flee_button != null and _flee_button.visible and not _flee_button.disabled:
		_flee_button.grab_focus()


func _layout_escape_ui() -> void:
	# DigiConfirmationModal owns its own responsive layout. This method only lays
	# out the announcement/result surfaces inherited from EscapeBattleHUD, so it
	# never dereferences controls that belonged to the retired legacy modal.
	var viewport_obj := get_viewport()
	if viewport_obj == null:
		return
	var physical := V2.physical_window_size(viewport_obj)
	var ui_scale := V2.ui_scale(viewport_obj)

	if _escape_announcement != null and is_instance_valid(_escape_announcement):
		var announce_w := minf(420.0, physical.x - 24.0)
		var announce_h := 104.0
		_escape_announcement.scale = Vector2.ONE * ui_scale
		_escape_announcement.position = Vector2((physical.x - announce_w) * 0.5, maxf(28.0, physical.y * 0.22)) * ui_scale
		_escape_announcement.size = Vector2(announce_w, announce_h)
		if _escape_announcement_title != null:
			_escape_announcement_title.position = Vector2(16.0, 14.0)
			_escape_announcement_title.size = Vector2(announce_w - 32.0, 40.0)
		if _escape_announcement_subtitle != null:
			_escape_announcement_subtitle.position = Vector2(16.0, 56.0)
			_escape_announcement_subtitle.size = Vector2(announce_w - 32.0, 28.0)

	if _escape_result != null and is_instance_valid(_escape_result):
		var result_w := minf(440.0, physical.x - 28.0)
		var result_h := minf(210.0, physical.y - 28.0)
		_escape_result.scale = Vector2.ONE * ui_scale
		_escape_result.position = Vector2((physical.x - result_w) * 0.5, (physical.y - result_h) * 0.5) * ui_scale
		_escape_result.size = Vector2(result_w, result_h)
		if _escape_result_title != null:
			_escape_result_title.position = Vector2(18.0, 20.0)
			_escape_result_title.size = Vector2(result_w - 36.0, 44.0)
		if _escape_result_body != null:
			_escape_result_body.position = Vector2(24.0, 68.0)
			_escape_result_body.size = Vector2(result_w - 48.0, 46.0)
		if _escape_result_return != null:
			_escape_result_return.position = Vector2(54.0, result_h - 60.0)
			_escape_result_return.size = Vector2(result_w - 108.0, 42.0)


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
