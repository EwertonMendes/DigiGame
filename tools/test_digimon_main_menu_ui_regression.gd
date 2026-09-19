extends Node

const MenuScript = preload("res://src/ui/DigiWorkspaceProgressionMenu.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
const AnalogGateScript = preload("res://src/ui/components/DigiAnalogNavigationGate.gd")
const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const TacticalTheme = preload("res://src/ui/TacticalTheme.gd")


func _ready() -> void:
	GameInputBootstrap.configure_gamepad_actions()
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests(false)

	var database: DigimonDatabase = OverworldState.get_database() as DigimonDatabase
	var factory: DigimonFactory = FactoryScript.new(database)
	var starter := OverworldState.get_active_instances()
	assert(not starter.is_empty(), "Digimon menu regression requires the starter Party")
	# Build a five-member Squad as 3 Active + 2 Reserve. The menu must keep its
	# existing three-card geometry while page 1 and page 2 have explicit roles.
	var created: Array[DigimonInstance] = []
	for species_name in ["guilmon", "patamon"]:
		var instance: DigimonInstance = factory.create_player_by_name(species_name, 3, 100)
		assert(instance != null, "Regression species must resolve: %s" % species_name)
		assert(not OverworldState.add_collection_instance(instance).is_empty(), "Regression Digimon must be added to the collection")
		created.append(instance)
	assert(OverworldState.add_to_reserve_party(created[0].id), "First regression Digimon must join Reserve")
	assert(OverworldState.add_to_reserve_party(created[1].id), "Second regression Digimon must join Reserve")

	var squad := OverworldState.get_squad_instances()
	assert(OverworldState.get_active_instances().size() == 3, "Regression setup must keep exactly three Active Digimon")
	assert(OverworldState.get_reserve_party_instances().size() == 2, "Regression setup must expose two Reserve Digimon")
	assert(squad.size() == 5, "Regression setup must expose five Squad Digimon")

	var menu := MenuScript.new() as DigiWorkspaceProgressionMenu
	add_child(menu)
	menu.open_menu()
	await _frames(4)

	var collection_scroll := menu.get("_collection_scroll") as ScrollContainer
	var detail_scroll := menu.get("_detail_scroll") as ScrollContainer
	assert(collection_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Main Digimon roster must use pagination instead of vertical scrolling")
	assert(collection_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Main Digimon roster must not depend on horizontal scrolling")
	assert(detail_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Main Digimon detail workspace must be scroll-free")
	assert(detail_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Main Digimon detail workspace must remain horizontally contained")

	# The main menu must use the exact workspace chrome language established by
	# DigiLab/Hospital instead of a visually similar but independently sized shell.
	var header := menu.get("_header") as DigiModalHeader
	var footer := menu.get("_hint_bar") as DigiInputHintBar
	var collection_panel := menu.get("_collection_panel") as Control
	var physical := V2.physical_window_size(get_viewport())
	var compact := physical.x < 980.0 or physical.y < 600.0
	var expected_header := 72.0 if compact else 86.0
	var expected_edge := 10.0 if compact else 24.0
	var expected_top_gap := 12.0 if compact else 16.0
	assert(header != null and header.is_workspace_mode(), "Main Digimon header must use the shared workspace header variant")
	assert(header.get_tab_button("party") != null and header.get_tab_button("digipedia") != null and header.get_tab_button("system") != null, "Main header must expose Party, Digipedia and System tabs")
	var main_tab_width := -1.0
	for tab_id in ["party", "digipedia", "system"]:
		var main_tab := header.get_tab_button(tab_id)
		assert(main_tab is DigiAngledTab, "Main header tabs must use the angled game tab shape")
		var main_label := main_tab.get_meta("tab_label") as Label
		assert(main_label != null and main_label.visible and not main_label.text.strip_edges().is_empty(), "Main Digimon tabs must keep their icon and text label visible")
		assert(main_label.size.x >= 24.0, "Main Digimon tab labels must receive real rendered width, not just exist in metadata")
		if main_tab_width < 0.0:
			main_tab_width = main_tab.size.x
		else:
			assert(is_equal_approx(main_tab.size.x, main_tab_width), "Main Digimon tabs must use one uniform width based on their largest label")
	assert(main_tab_width >= 150.0, "Main Digimon tabs must retain comfortable label padding instead of collapsing to icon-only buttons")
	assert(menu.get("_collection_header") == null, "Party cards must not have an Active Party banner")
	assert(menu.find_child("DigimonMenuBackground", true, false) != null, "Main menu must display its supplied background")
	assert(is_equal_approx(header.size.y, expected_header), "Main Digimon header height must match the DigiLab/Hospital workspace chrome")
	assert(is_equal_approx(footer.size.y, 54.0), "Main Digimon footer height must match the shared workspace footer")
	assert(is_equal_approx(collection_panel.position.x, expected_edge), "Main Digimon content edge must match the shared workspace gutter")
	assert(is_equal_approx(collection_panel.position.y, expected_header + expected_top_gap), "Main Digimon body must align with the shared workspace header spacing")

	var buttons := menu.get("_buttons") as Array
	var pager := menu.get("_roster_pager") as DigiPager
	assert(buttons.size() == 3, "Roster page must render exactly three cards when at least three Digimon are available")
	assert(pager.get_page_count() == 2 and pager.get_page() == 0, "Five Squad Digimon must produce Active and Reserve roster pages")
	var pager_previous := pager.get_node("PreviousPage") as Button
	var pager_next := pager.get_node("NextPage") as Button
	var pager_label := pager.get_node("PageIndicator") as Label
	assert(pager_previous.visible and pager_next.visible and pager_label.visible, "Workspace pager must keep its arrows and page indicator visible")
	assert(pager_previous.disabled and not pager_next.disabled, "Workspace pager must disable only the unavailable page direction")
	assert(pager_previous.custom_minimum_size == Vector2(52.0, 43.0), "Workspace pager arrows must use the DigiLab/Hospital dimensions")
	for raw_button in buttons:
		var card := raw_button as Button
		assert(card != null and card.custom_minimum_size.y >= 100.0, "Paged Digimon cards must retain a readable authored height")
		assert(card.find_child("FieldSprite", true, false) != null, "Each roster card must reuse the packaged DS field sprite system")

	# Vertical roster navigation is page-local. It wraps inside page 1 instead of
	# silently changing pages, leaving LT/RT as the explicit pagination control.
	menu.call("_move_roster_focus", 1)
	menu.call("_move_roster_focus", 1)
	menu.call("_move_roster_focus", 1)
	await _frames(2)
	assert(int(menu.get("_roster_page")) == 0, "D-pad roster navigation must never auto-page")
	assert(int(menu.get("_selected_index")) < 3, "End-of-page roster navigation must wrap within the current page")
	var before_horizontal := int(menu.get("_selected_index"))
	menu.call("_move_horizontal", 1)
	assert(int(menu.get("_selected_index")) == before_horizontal, "Horizontal direction must not alias vertical roster navigation")

	menu.call("_turn_roster_page", 1)
	await _frames(3)
	assert(int(menu.get("_roster_page")) == 1 and int(menu.get("_selected_index")) == 3, "Explicit pagination must move to the Reserve page and select its first Digimon")
	assert(not pager_previous.disabled and pager_next.disabled, "Last workspace roster page must expose a disabled next arrow instead of wrapping")
	buttons = menu.get("_buttons") as Array
	assert(buttons.size() == 2, "Reserve page must show only its actual Digimon and leave unused space empty")

	# Confirming a Digimon activates only the command surface. Header chrome,
	# pager arrows and overview tabs remain pointer/touch targets, not D-pad stops.
	menu.call("_confirm_index", 3)
	await _frames(3)
	assert(int(menu.get("_mode")) == 1, "Confirming a roster card must enter command mode")
	var commands := menu.get("_command_buttons") as Array
	assert(commands.size() == 3, "Main Digimon command area must expose Techniques, Evolution and Squad role management")
	var command_row := menu.find_child("CommandRow", true, false) as HBoxContainer
	assert(command_row != null and command_row.get_child_count() == 3, "All three Digimon commands must share one horizontal row")
	var first_command_y := -1.0
	var first_command_height := -1.0
	for command_index in range(commands.size()):
		var command := commands[command_index] as DigiCommandButton
		assert(command != null and not command.disabled and command.focus_mode == Control.FOCUS_ALL, "Commands must become interactive only after Digimon confirmation")
		assert(command.find_child("CommandIcon", true, false) != null, "Compact Digimon commands must retain their icon")
		assert(command.find_child("CommandTitle", true, false) != null, "Compact Digimon commands must retain their name")
		assert(command.find_child("CommandSubtitle", true, false) == null, "Compact Digimon commands must not render descriptions")
		assert(command.find_child("CommandStatus", true, false) == null, "Compact Digimon commands must not render learned/ready/status labels")
		assert(command.custom_minimum_size.y >= V2.TOUCH_TARGET and command.custom_minimum_size.y <= 60.0, "Compact Digimon commands must stay touch-safe without consuming a second row")
		if command_index == 0:
			first_command_y = command.position.y
			first_command_height = command.size.y
		else:
			assert(is_equal_approx(command.position.y, first_command_y), "All Digimon commands must stay on the same visual row")
			assert(is_equal_approx(command.size.y, first_command_height), "All Digimon commands must use the same compact height")
	var squad_role_command := commands[2] as DigiCommandButton
	assert(squad_role_command.name == "SquadRoleCommand", "Third command must own Active/Reserve role management")
	assert(_command_title(squad_role_command) == "SWAP WITH ACTIVE", "Reserve member must offer an Active swap when all Active slots are full")
	menu.call("_focus_action", 0)
	menu.call("_move_horizontal", 1)
	assert(get_viewport().gui_get_focus_owner() == commands[1], "Controller Right must move to Evolution in the single command row")
	menu.call("_move_horizontal", 1)
	assert(get_viewport().gui_get_focus_owner() == squad_role_command, "Controller Right must reach Squad role management in the same row")
	menu.call("_move_horizontal", 1)
	assert(get_viewport().gui_get_focus_owner() == commands[0], "Single-row command navigation must wrap without escaping into chrome")
	menu.call("_move_vertical", 1)
	assert(get_viewport().gui_get_focus_owner() == commands[1], "Controller vertical input must remain forgiving within the single command row")
	menu.call("_focus_action", 0)
	var close_button := header.get_close_button()
	assert(close_button != null and close_button.focus_mode == Control.FOCUS_NONE, "Header close X must stay out of controller directional focus")
	assert(close_button.custom_minimum_size == Vector2(48.0, 48.0), "Header close button must match the DigiLab/Hospital workspace target size")
	var overview_tabs := menu.get("_overview_tab_buttons") as Dictionary
	for raw_tab in overview_tabs.values():
		assert((raw_tab as Button).focus_mode == Control.FOCUS_NONE, "Overview tabs must be changed by X, not D-pad focus")
	var stats_panel := menu.get("_stats_panel") as DigiStatsPanel
	var development_panel := menu.get("_development_panel") as DigiDevelopmentPanel
	assert(stats_panel != null and development_panel != null, "Overview must keep both presentation panels available inside one stable host")
	assert(stats_panel.visible and not development_panel.visible, "Stats must be the initial Overview presentation")
	var stat_row: DigiStatRow = null
	for descendant in stats_panel.find_children("*", "PanelContainer", true, false):
		assert(not (descendant is DigiSectionHeader), "Overview must not nest a second Combat Stats header")
		if descendant is DigiStatRow:
			stat_row = descendant as DigiStatRow
	assert(stat_row != null and stat_row.custom_minimum_size.y >= 50.0, "Overview stats need readable row height")
	for child in pager.get_children():
		if child is Button:
			assert((child as Button).focus_mode == Control.FOCUS_NONE, "Pager arrows must remain pointer/touch controls outside the D-pad focus path")

	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	menu.call("_unhandled_input", rb)
	await _frames(2)
	assert(String(menu.get("_main_tab")) == "digipedia", "RB must switch to Digipedia")
	assert((menu.get("_soon_label") as Label).visible, "Digipedia must display its Soon placeholder")
	assert((menu.get("_soon_label") as Label).get_theme_font("font") == TacticalTheme.heading_font(), "Soon placeholder must use the Digimon display font")
	menu.call("_unhandled_input", rb)
	await _frames(2)
	assert(String(menu.get("_main_tab")) == "system", "RB must switch to System")
	var lb := InputEventJoypadButton.new()
	lb.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb.pressed = true
	menu.call("_unhandled_input", lb)
	menu.call("_unhandled_input", lb)
	await _frames(2)
	assert(String(menu.get("_main_tab")) == "party", "LB must return to Party")
	assert(not (menu.get("_soon_label") as Label).visible, "Party must restore its roster and detail panels")

	# X/Square must swap only the presentation state. The complete workspace
	# geometry is captured after layout settles and compared across repeated
	# real input events so a one-time or first-toggle-only fix cannot pass.
	var detail_panel := menu.get("_detail_panel") as Control
	var body_grid := menu.get("_body_grid") as Control
	var primary_column := menu.get("_primary_column") as Control
	var sidebar_column := menu.get("_sidebar_column") as Control
	var overview_panel := sidebar_column.get_node_or_null("OverviewPanel") as Control
	var overview_content := menu.get("_overview_content") as Control
	var presentation_host := menu.get("_overview_presentation_host") as Control
	assert(detail_panel != null and body_grid != null and primary_column != null and sidebar_column != null, "Stable Overview regression requires the complete workspace geometry")
	assert(overview_panel != null and overview_content != null and presentation_host != null, "Overview must expose a stable presentation host")
	var stable_controls := {
		"header": header,
		"roster": collection_panel,
		"detail": detail_panel,
		"workspace": body_grid,
		"primary": primary_column,
		"sidebar": sidebar_column,
		"overview": overview_panel,
		"overview_content": overview_content,
		"footer": footer,
	}
	var stable_geometry := _capture_geometry(stable_controls)
	var x_button := InputEventJoypadButton.new()
	x_button.button_index = JOY_BUTTON_X
	x_button.pressed = true
	for expected_tab in ["development", "stats", "development", "stats"]:
		menu.call("_unhandled_input", x_button)
		await _frames(3)
		assert(String(menu.get("_overview_tab")) == expected_tab, "X must alternate Stats and Development on every press")
		_assert_geometry_unchanged(stable_geometry, stable_controls, "Overview tab %s" % expected_tab)
		assert(menu.get("_body_grid") == body_grid, "Overview switching must not rebuild the workspace grid")
		assert(menu.get("_primary_column") == primary_column and menu.get("_sidebar_column") == sidebar_column, "Overview switching must preserve both workspace columns")
		assert(menu.get("_overview_content") == overview_content, "Overview switching must preserve the presentation area")
		assert(stats_panel.size.is_equal_approx(presentation_host.size), "Stats must fill the stable Overview presentation rectangle")
		assert(development_panel.size.is_equal_approx(presentation_host.size), "Development must fill the stable Overview presentation rectangle")
		assert(stats_panel.visible == (expected_tab == "stats"), "Stats visibility must match the selected Overview tab")
		assert(development_panel.visible == (expected_tab == "development"), "Development visibility must match the selected Overview tab")
	assert(stats_panel.get_combined_minimum_size().y <= presentation_host.size.y + 0.01, "Stats minimum height must fit inside the stable Overview presentation area")
	assert(development_panel.get_combined_minimum_size().y <= presentation_host.size.y + 0.01, "Development minimum height must fit inside the stable Overview presentation area")

	menu.call("_open_techniques")
	await _frames(3)
	assert(int(menu.get("_mode")) == 2, "Techniques command must open the dedicated no-scroll library view")
	assert(detail_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Technique Library must remain paged instead of scrollable")
	var technique_panel := menu.get("_technique_panel") as Control
	assert(technique_panel != null and technique_panel.visible, "Technique Library must own a dedicated contained workspace")
	var technique_back := technique_panel.find_child("TechniqueBack", true, false) as Button
	assert(technique_back != null and technique_back.visible and technique_back.focus_mode == Control.FOCUS_ALL, "Technique Library must expose a visible touch/controller Back button")
	technique_back.pressed.emit()
	await _frames(2)
	assert(int(menu.get("_mode")) == 1 and menu.visible, "Visible Technique Back button must return to Digimon details/commands")

	# ESC/B must retain the same nested back semantics as the visible affordance.
	menu.call("_open_techniques")
	await _frames(2)
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	menu.call("_unhandled_input", back)
	await _frames(2)
	assert(int(menu.get("_mode")) == 1 and menu.visible, "Back from Technique Library must return to Digimon commands")
	menu.call("_unhandled_input", back)
	await _frames(2)
	assert(int(menu.get("_mode")) == 0 and menu.visible, "Back from commands must return to the Party roster without closing")

	# The shared hint bar tracks the last input family. Touch hides legends while
	# controller mode advertises shoulder tabs and trigger pagination.
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	footer.call("_input", touch)
	assert(footer.is_touch_mode(), "Touch must become the active menu input mode")
	assert((footer.call("_menu_hints") as Array).is_empty(), "Touch mode must hide control legends")
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_A
	controller.pressed = true
	footer.call("_input", controller)
	var hint_keys := _hint_keys(footer.call("_menu_hints") as Array)
	assert(hint_keys.has("LB/RB") and hint_keys.has("X") and hint_keys.has("LT/RT") and hint_keys.has("D-PAD") and hint_keys.has("A") and hint_keys.has("B"), "Controller hints must expose main tabs, overview toggle, pages, navigation, select and back")
	assert(not hint_keys.has("RS"), "Scroll hints must never appear on the redesigned main Digimon menu")

	# Reusable analog hysteresis accepts one intentional movement per deflection.
	var gate := AnalogGateScript.new() as DigiAnalogNavigationGate
	assert(gate.vertical_step(0.90) == 1, "Analog gate must register an intentional downward press")
	assert(gate.vertical_step(0.95) == 0, "Held analog direction must not race through multiple Digimon")
	assert(gate.vertical_step(0.0) == 0 and gate.vertical_step(0.90) == 1, "Analog gate must re-arm after returning to neutral")
	assert(gate.trigger_step(JOY_AXIS_TRIGGER_RIGHT, 0.90) == 1, "Right trigger must request the next page once")
	assert(gate.trigger_step(JOY_AXIS_TRIGGER_RIGHT, 0.95) == 0, "Held trigger must not skip multiple pages")

	# Active/Reserve management belongs in the main Digimon menu. With three
	# Active slots occupied, a Reserve member enters a lightweight swap-pick mode:
	# controller/touch select a target card, while a visible touch-safe Cancel
	# affordance and B/ESC both leave roles untouched.
	var reserve_source_id := created[0].id
	var active_target_id := OverworldState.get_active_instances()[0].id
	var source_index := -1
	for index in range(OverworldState.get_squad_instances().size()):
		if OverworldState.get_squad_instances()[index].id == reserve_source_id:
			source_index = index
			break
	assert(source_index >= 0, "Reserve swap source must remain in the Squad")
	menu.call("_turn_roster_page", 1 if int(menu.get("_roster_page")) == 0 else 0)
	await _frames(2)
	menu.call("_confirm_index", source_index)
	await _frames(2)
	commands = menu.get("_command_buttons") as Array
	squad_role_command = commands[2] as DigiCommandButton
	assert(_command_title(squad_role_command) == "SWAP WITH ACTIVE", "Full Active team must route Reserve promotion through an explicit swap")
	squad_role_command.pressed.emit()
	await _frames(3)
	assert(String(menu.get("_squad_swap_source_id")) == reserve_source_id and int(menu.get("_roster_page")) == 0, "Squad swap must move directly to the opposite role page")
	var cancel_swap := menu.find_child("CancelSquadSwap", true, false) as Button
	assert(cancel_swap != null and cancel_swap.custom_minimum_size.y >= V2.TOUCH_TARGET, "Swap picker must expose a visible touch-safe cancel action")
	cancel_swap.pressed.emit()
	await _frames(2)
	assert(String(menu.get("_squad_swap_source_id")).is_empty(), "Touch cancel must leave Squad swap mode")
	assert(OverworldState.get_squad_role(reserve_source_id) == PlayerCollection.SQUAD_ROLE_RESERVE, "Cancelling must keep Reserve role unchanged")
	assert(OverworldState.get_squad_role(active_target_id) == PlayerCollection.SQUAD_ROLE_ACTIVE, "Cancelling must keep Active target unchanged")

	# Repeat and complete the same flow through roster confirmation, matching the
	# controller A/Enter path. Slot counts must stay valid and the roles exchange.
	menu.call("_confirm_index", source_index)
	await _frames(2)
	commands = menu.get("_command_buttons") as Array
	(commands[2] as Button).pressed.emit()
	await _frames(2)
	menu.call("_confirm_index", 0)
	await _frames(3)
	assert(OverworldState.get_squad_role(reserve_source_id) == PlayerCollection.SQUAD_ROLE_ACTIVE, "Confirmed Reserve source must become Active")
	assert(OverworldState.get_squad_role(active_target_id) == PlayerCollection.SQUAD_ROLE_RESERVE, "Confirmed Active target must become Reserve")
	assert(OverworldState.get_active_instances().size() == 3 and OverworldState.get_reserve_party_instances().size() == 2, "Role swap must preserve three Active and two Reserve slots")
	# Restore the fixture so the direct-move path starts from the original 3+2
	# shape. The state signal owns the menu refresh; no second same-frame rebuild.
	assert(OverworldState.swap_party_with_reserve(reserve_source_id, active_target_id), "Regression fixture must restore original Squad roles")
	await _frames(2)

	# An open destination slot should require no picker or confirmation modal.
	# Move one Active directly to Reserve, then promote the same Digimon back.
	var active_target_index := -1
	var restored_squad := OverworldState.get_squad_instances()
	for index in range(restored_squad.size()):
		if restored_squad[index].id == active_target_id:
			active_target_index = index
			break
	assert(active_target_index >= 0, "Direct-move fixture must locate its Active member")
	menu.call("_confirm_index", active_target_index)
	await _frames(2)
	commands = menu.get("_command_buttons") as Array
	assert(_command_title(commands[2] as Button) == "MOVE TO RESERVE", "Active member must offer a direct Reserve move when a slot is open")
	(commands[2] as Button).pressed.emit()
	await _frames(3)
	assert(OverworldState.get_active_instances().size() == 2 and OverworldState.get_reserve_party_instances().size() == 3, "Direct Reserve move must update Squad counts without a picker")
	assert(String(menu.get("_squad_swap_source_id")).is_empty(), "Direct role move must never enter swap-pick mode")

	var moved_squad := OverworldState.get_squad_instances()
	var moved_target_index := -1
	for index in range(moved_squad.size()):
		if moved_squad[index].id == active_target_id:
			moved_target_index = index
			break
	menu.call("_confirm_index", moved_target_index)
	await _frames(2)
	commands = menu.get("_command_buttons") as Array
	assert(_command_title(commands[2] as Button) == "MOVE TO ACTIVE", "Reserve member must offer a direct Active move when a slot is open")
	(commands[2] as Button).pressed.emit()
	await _frames(3)
	assert(OverworldState.get_active_instances().size() == 3 and OverworldState.get_reserve_party_instances().size() == 2, "Direct Active move must restore the original Squad counts")

	var closed := [false]
	menu.close_requested.connect(func(): closed[0] = true)
	menu.call("_unhandled_input", back)
	await _frames(2)
	assert(bool(closed[0]), "Back from roster exploration must close the main Digimon menu")

	menu.queue_free()
	await _frames(4)
	OverworldState.set_persistence_enabled(true)
	print("digimon main menu ui regression passed")
	get_tree().quit()


func _command_title(command: Button) -> String:
	if command == null:
		return ""
	var title := command.find_child("CommandTitle", true, false) as Label
	return title.text if title != null else command.text

func _capture_geometry(controls: Dictionary) -> Dictionary:
	var result := {}
	for key in controls:
		var control := controls[key] as Control
		assert(control != null, "Geometry capture requires a valid Control for %s" % String(key))
		result[key] = Rect2(control.global_position, control.size)
	return result


func _assert_geometry_unchanged(expected: Dictionary, controls: Dictionary, context: String) -> void:
	var actual := _capture_geometry(controls)
	for key in expected:
		var before: Rect2 = expected[key]
		var after: Rect2 = actual[key]
		assert(before.position.is_equal_approx(after.position), "%s must not move %s" % [context, String(key)])
		assert(before.size.is_equal_approx(after.size), "%s must not resize %s" % [context, String(key)])


func _hint_keys(hints: Array) -> Array[String]:
	var result: Array[String] = []
	for hint in hints:
		result.append(String((hint as Dictionary).get("key", "")))
	return result


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
