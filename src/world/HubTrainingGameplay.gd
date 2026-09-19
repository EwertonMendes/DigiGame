extends "res://src/world/HubProgressionGameplay.gd"

const TrainingCenterScreenScript = preload("res://src/ui/TrainingCenterScreen.gd")
const TrainerActorScript = preload("res://src/world/HubActor.gd")
const TRAINER_TEXTURE = preload("res://assets/characters/world/battle_operator_purple.png")
const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const InteractionPromptScript = preload("res://src/ui/components/DigiInteractionPrompt.gd")

var _trainer: HubActor = null
var _training_screen: TrainingCenterScreen = null
var _training_transition_surface: DigiUiTransitionSurface = null
var _training_open := false
var _v2_interaction_prompt: DigiInteractionPrompt = null


func _ready() -> void:
	super._ready()
	_install_v2_hub_chrome()
	_build_training_specialist()
	_build_training_ui()
	call_deferred("_layout_ui")
	call_deferred("_refresh_interaction")


func _unhandled_input(event: InputEvent) -> void:
	if _training_open:
		return
	if not _digilab_open and not _menu_open and not _dialog_open and not _transitioning and _is_interact_event(event) and _trainer_has_interaction_priority():
		_open_training()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _build_training_specialist() -> void:
	var actors := get_node_or_null("Actors") as Node2D
	if actors == null:
		return
	_trainer = TrainerActorScript.new() as HubActor
	_trainer.name = "TrainingSpecialist"
	_trainer.configure(TRAINER_TEXTURE, false, self, "southwest")
	# Put the specialist close to the upper-left rim, clearly separated from both
	# DigiLab and the central Battle Operator. Vertical separation also keeps the
	# long TRAINING SPECIALIST label from ever touching the operator label.
	_trainer.position = _grid_to_world(Vector2(-5, -3))
	actors.add_child(_trainer)
	_blockers.append({"position": _trainer.position, "radius": 28.0})
	var sprite := _trainer.get_node_or_null("CharacterSprite") as Sprite2D
	if sprite != null:
		sprite.modulate = Color(0.74, 1.0, 0.88, 1.0)
	var label := Label.new()
	label.name = "RoleLabel"
	label.position = Vector2(-82, -86)
	label.size = Vector2(164, 24)
	label.text = "TRAINING SPECIALIST"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", V2.GREEN)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	V2.apply_heading(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trainer.add_child(label)
	var glow := PointLight2D.new()
	glow.name = "TrainingGlow"
	glow.energy = 0.36
	glow.texture_scale = 1.1
	glow.color = V2.GREEN
	glow.position = Vector2(0, -38)
	_trainer.add_child(glow)


func _build_training_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrainingCenterUI"
	layer.layer = 94
	add_child(layer)
	_training_screen = TrainingCenterScreenScript.new() as TrainingCenterScreen
	_training_screen.name = "TrainingCenter"
	_training_screen.visible = false
	_training_screen.set_close_lifecycle_managed(true)
	_training_screen.close_requested.connect(_close_training)
	layer.add_child(_training_screen)
	_training_transition_surface = _training_screen.get_transition_surface()


func _open_training() -> void:
	if _training_open or _digilab_open or _menu_open or _dialog_open or _transitioning or _training_screen == null or _training_transition_surface == null:
		return
	if not DigiUiTransitionDirector.begin_open(_training_transition_surface, "training"):
		return
	_training_open = true
	_release_touch_movement()
	if _player != null:
		_player.movement_enabled = false
		_player.velocity = Vector2.ZERO
		_player.set_facing("northwest")
	if _trainer != null:
		_trainer.set_facing("southeast")
	_training_screen.open_screen()
	UiSfxDirector.play_open()
	_layout_ui()
	await DigiUiTransitionDirector.reveal_open()
	if OS.is_debug_build():
		print("[Hub] TRAINING_CENTER open")


func _close_training() -> void:
	if not _training_open or _training_transition_surface == null:
		return
	if not DigiUiTransitionDirector.begin_close(_training_transition_surface, "training"):
		return
	UiSfxDirector.play_back()
	await DigiUiTransitionDirector.conceal_close()
	_training_open = false
	if _training_screen != null:
		_training_screen.finish_close()
	if _player != null:
		_player.movement_enabled = true
	_layout_ui()
	_refresh_interaction()
	DigiUiTransitionDirector.complete_close()
	if OS.is_debug_build():
		print("[Hub] TRAINING_CENTER close")


func _refresh_interaction() -> void:
	if _interaction_prompt == null:
		return
	if _training_open:
		_interaction_prompt.visible = false
		if _mobile_talk_button != null:
			_mobile_talk_button.disabled = true
		return
	if not _digilab_open and not _menu_open and not _dialog_open and _trainer_has_interaction_priority():
		var compact := UI.is_compact(get_viewport(), 760.0)
		_interaction_prompt.visible = not compact and not _transitioning
		_set_v2_interaction_action("TRAIN DIGIMON", "TRAIN")
		_objective_label.text = "SERVICE  -  Training Center"
		if _mobile_talk_button != null:
			_mobile_talk_button.disabled = _transitioning
		return

	super._refresh_interaction()
	# Parent interaction code still owns distance/priority logic. This top-level
	# adapter only supplies concise V2 copy so the key badge and action never
	# duplicate strings such as "E / ENTER" inside the prompt itself.
	if _is_operator_nearby():
		_set_v2_interaction_action("TALK", "TALK")
	elif _is_digilab_nearby():
		_set_v2_interaction_action("OPEN DIGILAB", "DIGILAB")


func _on_mobile_interact() -> void:
	if _training_open:
		return
	if _trainer_has_interaction_priority():
		_open_training()
		return
	super._on_mobile_interact()


func _trainer_has_interaction_priority() -> bool:
	if not _is_trainer_nearby():
		return false
	var trainer_distance := _player.position.distance_to(_trainer.position)
	var operator_distance := INF
	if _operator != null:
		operator_distance = _player.position.distance_to(_operator.position)
	var digilab_distance := INF
	if _digilab_terminal != null:
		digilab_distance = _player.position.distance_to(_digilab_terminal.position)
	return trainer_distance <= operator_distance and trainer_distance <= digilab_distance


func _is_trainer_nearby() -> bool:
	if _player == null or _trainer == null:
		return false
	return _player.position.distance_to(_trainer.position) <= _interaction_distance_for_current_device()


func _layout_ui() -> void:
	super._layout_ui()
	_enforce_v2_touch_targets()
	if not _training_open:
		return
	if _touch_menu_button != null:
		_touch_menu_button.visible = false
	if _touch_digilab_button != null:
		_touch_digilab_button.visible = false
	if _mobile_controls != null:
		_mobile_controls.visible = false


func _open_dialog() -> void:
	super._open_dialog()
	# Conversation prompts are reversible. Keep the safe "not now" choice as
	# the default for keyboard/controller instead of making Enter/A start combat.
	if _dialog_panel != null and _dialog_panel.visible:
		var cancel := _dialog_panel.find_child("CancelBattleDialog", true, false) as Button
		if (
			cancel != null
			and not cancel.disabled
			and cancel.is_visible_in_tree()
			and cancel.focus_mode != Control.FOCUS_NONE
		):
			cancel.grab_focus()


func _install_v2_hub_chrome() -> void:
	_replace_interaction_prompt()
	if _location_panel != null:
		_location_panel.set_meta("digi_ui_v2_component", true)
		_location_panel.add_theme_stylebox_override(
			"panel",
			V2.surface_style(
				Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.94),
				Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.34),
				V2.CARD_RADIUS,
				Vector4.ZERO,
				0.10
			)
		)
	if _objective_label != null:
		_objective_label.add_theme_color_override("font_color", V2.AMBER)
		V2.apply_body(_objective_label)
	for button: Button in [_mobile_talk_button, _touch_menu_button, _touch_digilab_button]:
		_apply_v2_action_button(button)


func _replace_interaction_prompt() -> void:
	if _interaction_prompt == null or _interaction_prompt is DigiInteractionPrompt:
		_v2_interaction_prompt = _interaction_prompt as DigiInteractionPrompt
		if _v2_interaction_prompt != null:
			_prompt_label = _v2_interaction_prompt.get_action_label()
		return
	var old_prompt := _interaction_prompt
	var parent := old_prompt.get_parent()
	if parent == null:
		return
	var old_index := old_prompt.get_index()
	var old_visible := old_prompt.visible
	var old_position := old_prompt.position
	var old_size := old_prompt.size
	var old_scale := old_prompt.scale
	parent.remove_child(old_prompt)
	old_prompt.queue_free()

	_v2_interaction_prompt = InteractionPromptScript.new() as DigiInteractionPrompt
	_v2_interaction_prompt.name = "InteractionPrompt"
	parent.add_child(_v2_interaction_prompt)
	parent.move_child(_v2_interaction_prompt, mini(old_index, parent.get_child_count() - 1))
	_v2_interaction_prompt.visible = old_visible
	_v2_interaction_prompt.position = old_position
	_v2_interaction_prompt.size = old_size
	_v2_interaction_prompt.scale = old_scale
	_interaction_prompt = _v2_interaction_prompt
	_prompt_label = _v2_interaction_prompt.get_action_label()
	_set_v2_interaction_action("TALK", "TALK")


func _set_v2_interaction_action(action_text: String, mobile_text: String) -> void:
	if _v2_interaction_prompt != null:
		_v2_interaction_prompt.set_action(action_text)
	elif _prompt_label != null:
		_prompt_label.text = action_text
	if _mobile_talk_button != null:
		_mobile_talk_button.text = mobile_text


func _apply_v2_action_button(button: Button) -> void:
	if button == null:
		return
	button.set_meta("digi_ui_v2_component", true)
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_pressed_color", V2.WHITE)
	button.add_theme_stylebox_override("normal", V2.button_style(V2.AMBER, "normal"))
	button.add_theme_stylebox_override("hover", V2.button_style(V2.AMBER, "hover"))
	button.add_theme_stylebox_override("focus", V2.button_style(V2.AMBER, "focus"))
	button.add_theme_stylebox_override("pressed", V2.button_style(V2.AMBER, "pressed"))
	button.add_theme_stylebox_override("disabled", V2.button_style(V2.AMBER, "disabled"))
	V2.apply_heading(button)


func _enforce_v2_touch_targets() -> void:
	for button: Button in [_touch_menu_button, _touch_digilab_button]:
		if button != null and button.visible:
			button.size.y = maxf(button.size.y, V2.TOUCH_TARGET)
			button.custom_minimum_size.y = V2.TOUCH_TARGET
