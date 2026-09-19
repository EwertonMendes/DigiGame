extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const V2 = preload("res://src/ui/components/DigiUiTheme.gd")


func _ready() -> void:
	GameInputBootstrap.configure_gamepad_actions()
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)
	_ensure_paged_fixture()

	var hub: Node = HUB_SCENE.instantiate()
	add_child(hub)
	await _frames(4)

	var training: TrainingCenterScreen = hub.get_node_or_null("TrainingCenterUI/TrainingCenter") as TrainingCenterScreen
	if not _check(training != null, "Hub must expose the Training Center"):
		return
	training.open_screen()
	await _frames(4)

	if not _check(training.visible, "Training Center must become visible"):
		return
	var header := training.get("_header") as DigiModalHeader
	var hints := training.get("_hint_bar") as DigiInputHintBar
	if not _check(header != null and header.is_workspace_mode(), "Training must use the shared workspace header"):
		return
	if not _check(hints != null, "Training must expose adaptive V2 input hints"):
		return
	if not _check(header.get_close_button() != null and header.get_close_button().focus_mode == Control.FOCUS_NONE, "Training close X must stay outside controller directional focus"):
		return

	var scrolls := _controls_of_type(training, "ScrollContainer")
	if not _check(scrolls.is_empty(), "Modern Training must not depend on ScrollContainer"):
		return

	var collection_header := training.get("_collection_header") as DigiSectionHeader
	var pager := training.get("_roster_pager") as DigiPager
	var buttons := training.get("_collection_buttons") as Array
	var ids := training.get("_collection_ids") as Array
	if not _check(collection_header != null and pager != null, "Training roster must use shared V2 section and pager components"):
		return
	if not _check(pager.get_page_count() >= 2, "Regression fixture must exercise paged Training roster"):
		return
	if not _check(buttons.size() == 3 and ids.size() == 3, "Training roster must render exactly three Digimon per full page"):
		return
	for raw_button in buttons:
		var card := raw_button as Button
		if not _check(card != null and card.custom_minimum_size.y >= V2.TOUCH_TARGET, "Training roster cards must remain touch-safe"):
			return

	var pager_previous := pager.get_node("PreviousPage") as Button
	var pager_next := pager.get_node("NextPage") as Button
	if not _check(pager_previous.focus_mode == Control.FOCUS_NONE and pager_next.focus_mode == Control.FOCUS_NONE, "Pager arrows must be pointer/touch controls outside the D-pad path"):
		return
	if not _check(pager_previous.custom_minimum_size == Vector2(52.0, 43.0) and pager_next.custom_minimum_size == Vector2(52.0, 43.0), "Training pager must reuse workspace pager dimensions"):
		return

	# D-pad/left-stick navigation stays page-local; only explicit pagination changes pages.
	training.call("_focus_first_collection")
	await _frames(1)
	var first_focus := get_viewport().gui_get_focus_owner()
	training.call("_move_roster_focus", 1)
	training.call("_move_roster_focus", 1)
	training.call("_move_roster_focus", 1)
	if not _check(int(training.get("_roster_page")) == 0, "Roster directional navigation must never auto-page"):
		return
	if not _check(get_viewport().gui_get_focus_owner() == first_focus, "Three downward moves must wrap inside the current three-card page"):
		return

	var analog := InputEventJoypadMotion.new()
	analog.axis = JOY_AXIS_LEFT_Y
	analog.axis_value = 0.9
	training.call("_input", analog)
	var analog_once := get_viewport().gui_get_focus_owner()
	training.call("_input", analog)
	if not _check(get_viewport().gui_get_focus_owner() == analog_once, "Held analog input must not race through the Training roster"):
		return
	analog.axis_value = 0.0
	training.call("_input", analog)
	analog.axis_value = 0.9
	training.call("_input", analog)
	if not _check(get_viewport().gui_get_focus_owner() != analog_once, "Analog navigation must re-arm after returning through its release threshold"):
		return

	training.call("_turn_roster_page", 1)
	await _frames(2)
	if not _check(int(training.get("_roster_page")) == 1, "Explicit Training pagination must move to the next roster page"):
		return
	training.call("_turn_roster_page", -1)
	await _frames(2)

	ids = training.get("_collection_ids") as Array
	if not _check(ids.size() >= 2, "First Training page must expose at least two selectable Digimon"):
		return
	var selected_id := String(ids[0])
	var alternate_id := String(ids[1])
	training.call("_activate_instance", selected_id)
	await _frames(3)
	if not _check(int(training.get("_interaction_mode")) == 1, "Confirming a Digimon must enter Training edit mode"):
		return

	var detail := training.get("_detail_panel") as Control
	var host := training.get("_presentation_host") as Control
	var attributes := training.get("_attributes_view") as Control
	var mobility := training.get("_mobility_view") as Control
	if not _check(detail != null and host != null and attributes != null and mobility != null, "Training must expose one stable detail workspace"):
		return
	if not _check(attributes.visible and not mobility.visible, "Attributes must be the initial Training presentation"):
		return
	var host_identity := host.get_instance_id()
	var host_size := host.size
	var attributes_header := training.get("_attributes_header") as DigiSectionHeader
	if not _check(_header_icon_is_centered(attributes_header), "Attribute Training icon must be vertically centered beside its title"):
		return

	var rows: Dictionary = training.get("_stat_rows") as Dictionary
	if not _check(rows.size() == 6, "Training must keep all six attribute rows alive"):
		return
	var target_key := ""
	var target_row: TrainingStatRow = null
	var target_plus: Button = null
	var host_rect := host.get_global_rect()
	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed"]:
		var row := rows.get(stat_key) as TrainingStatRow
		if row == null:
			continue
		if not _check(row.custom_minimum_size.y <= 54.0, "Training attribute cards must use the compact 54px row height without shrinking text"):
			return
		if not _check(row.get_global_rect().end.y <= host_rect.end.y + 1.0, "Every Training attribute row, including INT/SPD, must stay fully inside the presentation workspace"):
			return
		var row_buttons := row.get_focus_buttons()
		if not _check(row_buttons.size() == 2, "Each Training stat row must expose minus and plus controls"):
			return
		for control in row_buttons:
			if not _check((control as Button).custom_minimum_size.y >= V2.TOUCH_TARGET, "Training stat steppers must remain touch-safe"):
				return
		if not row_buttons[1].disabled:
			target_key = stat_key
			target_row = row
			target_plus = row_buttons[1]
			break
	if not _check(target_row != null and target_plus != null, "At least one stat must be trainable for the regression Digimon"):
		return

	target_plus.grab_focus()
	var stable_row_id := target_row.get_instance_id()
	target_plus.pressed.emit()
	await _frames(3)

	var pending := training.get("_pending_stats") as Dictionary
	rows = training.get("_stat_rows") as Dictionary
	var same_row := rows.get(target_key) as TrainingStatRow
	if not _check(int(pending.get(target_key, 0)) == 1, "Stat plus must add one pending training point"):
		return
	if not _check(same_row != null and same_row.get_instance_id() == stable_row_id, "Stat updates must refresh the existing row instead of rebuilding it"):
		return
	if not _check((training.get("_presentation_host") as Control).get_instance_id() == host_identity, "Training changes must preserve the presentation host"):
		return
	if not _check((training.get("_presentation_host") as Control).size.is_equal_approx(host_size), "Training changes must not resize the stable presentation host"):
		return
	var point_label := same_row.get_training_points_label()
	if not _check(point_label.text.contains("+1") and point_label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "Pending point totals must stay complete and visible"):
		return

	var attribute_plan_bar := training.get("_attribute_plan_bar") as PanelContainer
	var discard := training.get("_discard_button") as Button
	var apply := training.get("_apply_button") as Button
	if not _check(attribute_plan_bar != null and attributes.is_ancestor_of(attribute_plan_bar), "Attribute Apply/Discard must live inside the Attributes presentation"):
		return
	if not _check(attribute_plan_bar.get_global_rect().end.y <= host_rect.end.y + 1.0, "Compact attribute actions must stay fully inside the presentation workspace"):
		return
	for action in [discard, apply]:
		if not _check(action != null and action.custom_minimum_size.y >= V2.TOUCH_TARGET, "Attribute plan actions must remain touch-safe"):
			return
		if not _check(bool(action.get_meta("digi_command_button", false)) and bool(action.get_meta("compact_command_button", false)), "Attribute plan actions must use the compact Digi Hospital command language"):
			return
		var command_style := action.get_theme_stylebox("normal") as StyleBoxFlat
		if not _check(command_style != null and command_style.border_width_left >= 4, "Compact attribute commands must keep the Digi Hospital leading rail"):
			return
		var compact_icon := action.find_child("ActionIcon", true, false) as TextureRect
		if not _check(compact_icon != null and compact_icon.custom_minimum_size == Vector2(24.0, 24.0), "Compact attribute commands must keep a readable 24px action icon"):
			return

	# Apply remains guarded because attribute training is permanent.
	if not _check(not apply.disabled, "A valid attribute plan must enable Apply Training"):
		return
	apply.pressed.emit()
	await _frames(2)
	var confirmation := training.get("_confirmation") as DigiConfirmationModal
	if not _check(confirmation != null and confirmation.visible, "Attribute Apply must open the shared permanent-action confirmation"):
		return
	confirmation.get_cancel_button().pressed.emit()
	await _frames(2)
	if not _check(int((training.get("_pending_stats") as Dictionary).get(target_key, 0)) == 1, "Cancelling Apply must preserve the pending attribute plan"):
		return

	# Moving to another Digimon can never silently erase an unapplied attribute plan.
	var before_switch := String(training.get("_selected_id"))
	training.call("_activate_instance", alternate_id)
	await _frames(2)
	if not _check(confirmation.visible, "Switching Digimon with a pending attribute plan must ask before discarding it"):
		return
	if not _check(String(training.get("_selected_id")) == before_switch, "Pending attribute guard must keep the current Training target until confirmed"):
		return
	confirmation.get_cancel_button().pressed.emit()
	await _frames(2)

	# X/Square switches presentation only; geometry and component identity remain stable.
	var x_button := InputEventJoypadButton.new()
	x_button.button_index = JOY_BUTTON_X
	x_button.pressed = true
	training.call("_unhandled_input", x_button)
	await _frames(2)
	if not _check(int(training.get("_detail_view")) == 1 and mobility.visible and not attributes.visible, "X/Square must switch from Attributes to Mobility"):
		return
	if not _check((training.get("_presentation_host") as Control).get_instance_id() == host_identity, "Switching Training views must preserve the same presentation host"):
		return
	if not _check((training.get("_presentation_host") as Control).size.is_equal_approx(host_size), "Switching Training views must keep workspace geometry stable"):
		return

	var mobility_header := training.get("_mobility_header") as DigiSectionHeader
	if not _check(_header_icon_is_centered(mobility_header), "Tactical Mobility icon must be vertically centered beside its title"):
		return

	var mobility_plus := training.get("_mobility_plus") as Button
	if not _check(mobility_plus != null and mobility_plus.custom_minimum_size.y >= V2.TOUCH_TARGET, "Mobility command must remain touch-safe"):
		return
	if not _check(bool(mobility_plus.get_meta("digi_command_button", false)), "Mobility must use the shared Digi Hospital command-button language"):
		return
	var mobility_style := mobility_plus.get_theme_stylebox("normal") as StyleBoxFlat
	if not _check(mobility_style != null and mobility_style.border_width_left >= 4, "Mobility command must keep the Digi Hospital leading rail"):
		return
	var mobility_icon := mobility_plus.find_child("ActionIcon", true, false) as TextureRect
	if not _check(mobility_icon != null and mobility_icon.custom_minimum_size == Vector2(36.0, 36.0), "Mobility command icon must use the authored 36px Hospital scale"):
		return
	if not _check(mobility_plus.disabled, "Pending attribute changes must block independent MOV training until resolved"):
		return

	# Return to Attributes, discard the pending attribute plan, then prove MOV is self-sufficient.
	training.call("_toggle_detail_view")
	await _frames(2)
	discard.pressed.emit()
	await _frames(2)
	pending = training.get("_pending_stats") as Dictionary
	if not _check(pending.is_empty(), "Discard must clear only the pending attribute plan"):
		return
	if not _check((training.get("_stat_rows") as Dictionary).get(target_key) == same_row, "Discarding must update the same persistent stat components"):
		return

	var mobility_target_id := ""
	for candidate: DigimonInstance in OverworldState.get_collection_instances():
		if candidate.potential >= 20 and int(candidate.training.get("mov", 0)) < 2:
			mobility_target_id = candidate.id
			break
	if not _check(not mobility_target_id.is_empty(), "Mobility regression fixture must provide an eligible Digimon"):
		return

	training.call("_activate_instance", mobility_target_id)
	await _frames(3)
	training.call("_set_detail_view", 1, false)
	await _frames(2)
	var mobility_instance := OverworldState.get_instance_by_id(mobility_target_id)
	if not _check(mobility_instance != null and mobility_instance.potential >= 20, "Mobility regression target must satisfy the first MOV potential requirement"):
		return
	var mobility_before := int(mobility_instance.training.get("mov", 0))
	mobility_plus = training.get("_mobility_plus") as Button
	if not _check(not mobility_plus.disabled, "Eligible Digimon with no attribute plan must be able to train MOV independently"):
		return
	mobility_plus.pressed.emit()
	await _frames(2)
	if not _check(confirmation.visible, "Train MOV +1 must use its own permanent-action confirmation"):
		return
	if not _check((training.get("_pending_stats") as Dictionary).is_empty(), "MOV confirmation must not create or reuse an attribute plan"):
		return
	confirmation.get_confirm_button().pressed.emit()
	await _frames(4)
	mobility_instance = OverworldState.get_instance_by_id(mobility_target_id)
	if not _check(int(mobility_instance.training.get("mov", 0)) == mobility_before + 1, "Confirmed MOV training must apply exactly one mobility level immediately"):
		return
	if not _check((training.get("_pending_stats") as Dictionary).is_empty(), "Committed MOV training must leave the attribute plan empty"):
		return

	training.call("_return_to_roster")
	await _frames(2)
	if not _check(int(training.get("_interaction_mode")) == 0, "Back from Training editing must return to the roster before closing the service"):
		return

	training.close_view()
	hub.queue_free()
	await _frames(3)
	OverworldState.set_persistence_enabled(true)
	print("training ui v2 regression passed")
	get_tree().quit()


func _ensure_paged_fixture() -> void:
	var database: DigimonDatabase = OverworldState.get_database() as DigimonDatabase
	var factory = FactoryScript.new(database)
	var candidates := ["guilmon", "patamon", "veemon", "gabumon"]
	var cursor := 0
	while OverworldState.get_collection_instances().size() < 5 and cursor < candidates.size():
		var instance: DigimonInstance = factory.create_player_by_name(candidates[cursor], 3, 100)
		cursor += 1
		if instance != null:
			# The factory argument is scan percent, not Potential. Give regression
			# fixtures enough Potential to exercise independent MOV training.
			instance.potential = 100
			OverworldState.add_collection_instance(instance)


func _header_icon_is_centered(header: DigiSectionHeader) -> bool:
	if header == null:
		return false
	var icon := header.get_icon_view()
	var slot := header.get_node_or_null("MarginContainer/HBoxContainer/SectionIconSlot") as CenterContainer
	if slot == null:
		slot = header.find_child("SectionIconSlot", true, false) as CenterContainer
	if icon == null or slot == null or not icon.visible:
		return false
	var icon_center := icon.get_global_rect().get_center()
	var slot_center := slot.get_global_rect().get_center()
	return absf(icon_center.y - slot_center.y) <= 0.5


func _controls_of_type(root: Node, type_name: String) -> Array[Node]:
	var result: Array[Node] = []
	if root.get_class() == type_name:
		result.append(root)
	for child: Node in root.get_children():
		result.append_array(_controls_of_type(child, type_name))
	return result


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	print("[training-ui-v2] FAIL: %s" % message)
	get_tree().quit(1)
	return false


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
