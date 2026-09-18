extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")
const GlassPanelScript = preload("res://src/ui/components/DigiGlassPanel.gd")
const InteractionPromptScript = preload("res://src/ui/components/DigiInteractionPrompt.gd")
const ConfirmationModalScript = preload("res://src/ui/components/DigiConfirmationModal.gd")
const AttributeChipScript = preload("res://src/ui/components/DigiAttributeChip.gd")
const SelectionCardScript = preload("res://src/ui/components/DigiSelectionCard.gd")
const SegmentedTabsScript = preload("res://src/ui/components/DigiSegmentedTabs.gd")


func _ready() -> void:
	# Keep this regression focused on player-facing contracts instead of exact
	# styling internals. Visual tuning such as shader parameters, border values or
	# focus-neighbor paths should be free to evolve without breaking CI.
	var glass := GlassPanelScript.new() as PanelContainer
	add_child(glass)
	glass.call("configure_glass", DigiUiTheme.CYAN, "floating", Vector4.ZERO, 10)
	await _frames(2)
	if not _check(glass.has_meta("digi_glass_surface") and glass.get_theme_stylebox("panel") != null, "Glass surface must instantiate as a reusable V2 component"):
		return

	# Classification chips may render either as styled text labels or as
	# icon-backed panels. Their outer height is a shared player-facing contract:
	# mixed rows must not look staggered just because one classification has an
	# icon. Also guard against normalizing the nested attribute label and thereby
	# applying the panel's vertical inset twice.
	var classification_row := HBoxContainer.new()
	add_child(classification_row)
	var text_chip := Label.new()
	text_chip.text = "ROOKIE"
	text_chip.add_theme_font_size_override("font_size", 9)
	text_chip.add_theme_color_override("font_color", DigiUiTheme.CYAN)
	text_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_chip.add_theme_stylebox_override("normal", DigiUiTheme.pill_style(DigiUiTheme.CYAN, true))
	DigiUiTheme.apply_heading(text_chip)
	classification_row.add_child(text_chip)
	var icon_chip := AttributeChipScript.build("Vaccine")
	classification_row.add_child(icon_chip)
	var text_attribute_chip := AttributeChipScript.build("Free")
	classification_row.add_child(text_attribute_chip)
	AttributeChipScript.normalize_text_pill_height(classification_row, "ROOKIE")
	await _frames(2)
	var icon_height_before := icon_chip.get_combined_minimum_size().y
	AttributeChipScript.normalize_text_pill_height(classification_row, "VACCINE")
	await _frames(1)
	var icon_height_after := icon_chip.get_combined_minimum_size().y
	if not _check(is_equal_approx(text_chip.get_combined_minimum_size().y, icon_height_after), "Text classification chips must match icon-backed chip height"):
		return
	if not _check(is_equal_approx(text_attribute_chip.get_combined_minimum_size().y, icon_height_after), "Classification chips without an icon must keep the shared chip height"):
		return
	if not _check(is_equal_approx(icon_height_before, icon_height_after), "Normalizing a classification row must not enlarge the nested attribute label"):
		return

	var selection_card := SelectionCardScript.new() as DigiSelectionCard
	selection_card.configure("BASIC BATTLE", "Persistent selection probe.", "MIXED", "sword", DigiUiTheme.CYAN)
	add_child(selection_card)
	await _frames(2)
	var selection_badge := selection_card.find_child("SelectionStatus", true, false) as Label
	var selection_surface := selection_card.find_child("SelectionCommittedSurface", true, false) as Panel
	if not _check(selection_surface != null and not selection_surface.visible, "Unselected card must keep committed-selection surface hidden"):
		return
	selection_card.call("_on_mouse_entered")
	var preview_style := selection_card.get_theme_stylebox("normal") as StyleBoxFlat
	selection_card.set_selected(true)
	var selected_surface_style := selection_surface.get_theme_stylebox("panel") as StyleBoxFlat
	var selection_pressed := selection_card.get_theme_stylebox("pressed") as StyleBoxFlat
	selection_card.call("_on_mouse_exited")
	var persistent_surface_style := selection_surface.get_theme_stylebox("panel") as StyleBoxFlat
	if not _check(selection_card.is_selected(), "Selection card must expose persistent committed selection independent from focus"):
		return
	if not _check(selection_badge != null and selection_badge.text == "MIXED", "Selection must never replace semantic card metadata with SELECTED text"):
		return
	if not _check(selection_surface.visible, "Committed selection must show a dedicated persistent visual surface"):
		return
	if not _check(selected_surface_style != null and persistent_surface_style != null, "Committed selection surface must expose a concrete workspace style"):
		return
	if not _check(
		selected_surface_style.border_width_left >= 2
		and selected_surface_style.border_color.a >= 0.9
		and selected_surface_style.shadow_size >= 10,
		"Committed selection must use the approved bright cyan border and glow"
	):
		return
	if not _check(
		selected_surface_style.border_color == persistent_surface_style.border_color
		and selected_surface_style.bg_color == persistent_surface_style.bg_color
		and selected_surface_style.shadow_size == persistent_surface_style.shadow_size,
		"Committed selection surface must remain visually identical after pointer/focus leaves"
	):
		return
	if not _check(preview_style != null and selection_pressed != null and preview_style.bg_color == selection_pressed.bg_color and preview_style.border_color == selection_pressed.border_color, "Pointer press must not flash through a third transient card surface"):
		return

	var segmented := SegmentedTabsScript.new() as DigiSegmentedTabs
	segmented.configure([
		{"id": "program", "label": "BATTLE PROGRAM", "compact_label": "PROGRAM"},
		{"id": "field", "label": "BATTLEFIELD", "compact_label": "FIELD"},
	], "program")
	add_child(segmented)
	await _frames(2)
	segmented.set_compact(true)
	var compact_program := segmented.get_button("program")
	var compact_field := segmented.get_button("field")
	if not _check(
		compact_program != null and compact_program.text == "PROGRAM"
		and compact_field != null and compact_field.text == "FIELD",
		"Segmented tabs must use authored compact labels without truncating workspace navigation"
	):
		return

	var prompt := InteractionPromptScript.new() as DigiInteractionPrompt
	add_child(prompt)
	await _frames(2)
	prompt.set_action("Open DigiLab")
	if not _check(prompt.get_action_label() != null and prompt.get_action_label().text == "OPEN DIGILAB", "Interaction prompt must expose the current action"):
		return
	if not _check(prompt.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET, "Interaction prompt must remain touch-safe"):
		return
	var joy := InputEventJoypadButton.new()
	joy.device = 0
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	prompt.call("_input", joy)
	if not _check(prompt.get_key_text() == "A", "Interaction prompt must adapt to gamepad input"):
		return

	var modal := ConfirmationModalScript.new() as DigiConfirmationModal
	add_child(modal)
	await _frames(2)
	modal.configure("DELETE SAVE?", "This is only a regression prompt.", "YES", "NO", DigiUiTheme.RED, "CONFIRM")
	modal.open_dialog()
	await _frames(2)
	var confirm := modal.get_confirm_button()
	var cancel := modal.get_cancel_button()
	if not _check(modal.visible and confirm != null and cancel != null, "Confirmation modal must open with both actions available"):
		return
	if not _check(get_viewport().gui_get_focus_owner() == cancel, "Confirmation modal must default to the safe cancel action"):
		return
	if not _check(confirm.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET and cancel.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET, "Confirmation actions must remain touch-safe"):
		return
	modal.close_dialog(false)

	var hub: Node = HUB_SCENE.instantiate()
	add_child(hub)
	await _frames(5)
	var hub_prompt := hub.find_child("InteractionPrompt", true, false)
	if not _check(hub_prompt is DigiInteractionPrompt, "Hub must use the shared Digi UI V2 interaction prompt"):
		return
	var player := hub.get("_player") as Node2D
	var operator := hub.get("_operator") as Node2D
	if not _check(player != null and operator != null, "Hub regression requires player and Battle Operator"):
		return
	player.position = operator.position + Vector2(18.0, 18.0)
	hub.call("_refresh_interaction")
	hub.call("open_test_battle_dialog")
	await _frames(3)
	var battle_dialog := hub.find_child("BattleDialog", true, false) as Control
	var operator_header := hub.find_child("OperatorHeader", true, false) as DigiModalHeader
	var hub_start := hub.find_child("StartBattle", true, false) as Button
	var program_buttons := hub.get("_battle_program_buttons") as Dictionary
	var basic_card := program_buttons.get("basic") as DigiSelectionCard
	if not _check(battle_dialog != null and battle_dialog.visible, "Battle Operator workspace must open"):
		return
	if not _check(operator_header != null and operator_header.is_workspace_mode(), "Battle Operator must reuse the shared V2 workspace header"):
		return
	if not _check(hub_start != null and basic_card != null, "Battle Operator must expose selected-program and start controls"):
		return
	if not _check(get_viewport().gui_get_focus_owner() == basic_card, "Battle Operator must focus the selected program while keeping selection persistent"):
		return

	hub.queue_free()
	modal.queue_free()
	prompt.queue_free()
	classification_row.queue_free()
	selection_card.queue_free()
	segmented.queue_free()
	glass.queue_free()
	await _frames(3)
	print("global ui v2 components regression passed")
	get_tree().quit()


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	print("[global-ui-v2] FAIL: %s" % message)
	get_tree().quit(1)
	return false


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
