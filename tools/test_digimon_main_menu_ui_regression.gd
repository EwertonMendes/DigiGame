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
	# The shared test reset now seeds the normal three-member gameplay Party.
	# Collapse it through the public Party API before building the five-member UI
	# fixture so this regression stays valid as the production starter roster evolves.
	assert(OverworldState.set_active_party([starter[0].id]), "Regression fixture must start from one active Digimon")

	# Build a five-member Party through public collection/party APIs so pagination
	# is exercised without reaching into production state internals.
	for species_name in ["gabumon", "veemon", "guilmon", "patamon"]:
		var instance: DigimonInstance = factory.create_player_by_name(species_name, 3, 100)
		assert(instance != null, "Regression species must resolve: %s" % species_name)
		assert(not OverworldState.add_collection_instance(instance).is_empty(), "Regression Digimon must be added to the collection")
		assert(OverworldState.add_to_active_party(instance.id), "Regression Digimon must be added to the active Party")

	var party := OverworldState.get_active_instances()
	assert(party.size() == 5, "Regression setup must expose five active Digimon")

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
	assert(pager.get_page_count() == 2 and pager.get_page() == 0, "Five active Digimon must produce two roster pages")
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
	assert(int(menu.get("_roster_page")) == 1 and int(menu.get("_selected_index")) == 3, "Explicit pagination must move to the next Party page and select its first Digimon")
	assert(not pager_previous.disabled and pager_next.disabled, "Last workspace roster page must expose a disabled next arrow instead of wrapping")
	buttons = menu.get("_buttons") as Array
	assert(buttons.size() == 2, "Final Party page must show only its actual Digimon and leave unused space empty")

	# Confirming a Digimon activates only the command surface. Header chrome,
	# pager arrows and overview tabs remain pointer/touch targets, not D-pad stops.
	menu.call("_confirm_index", 3)
	await _frames(3)
	assert(int(menu.get("_mode")) == 1, "Confirming a roster card must enter command mode")
	var commands := menu.get("_command_buttons") as Array
	assert(commands.size() == 2, "Main Digimon command area must expose Techniques and Evolution")
	for raw_command in commands:
		var command := raw_command as Button
		assert(command != null and not command.disabled and command.focus_mode == Control.FOCUS_ALL, "Commands must become interactive only after Digimon confirmation")
		_assert_command_copy_fits(command)
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


func _assert_command_copy_fits(command: Button) -> void:
	var title := command.find_child("CommandTitle", true, false) as Label
	var subtitle := command.find_child("CommandSubtitle", true, false) as Label
	var status := command.find_child("CommandStatus", true, false) as Label
	assert(title != null and subtitle != null and status != null, "Every populated Digimon command must expose title, subtitle and status labels")
	assert(_single_line_text_width(title) <= title.size.x + 1.0, "%s title should fit without default ellipsis" % title.text)
	assert(_single_line_text_width(status) <= status.size.x + 1.0, "%s status should fit without default ellipsis" % title.text)
	assert(subtitle.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and subtitle.max_lines_visible == 2, "%s subtitle must use bounded two-line wrapping before ellipsis" % title.text)
	assert(_wrapped_line_count(subtitle) <= subtitle.max_lines_visible, "%s standard subtitle should fit without ellipsis" % title.text)


func _single_line_text_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _wrapped_line_count(label: Label) -> int:
	var words := label.text.split(" ", false)
	if words.is_empty():
		return 0
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var available := maxf(1.0, label.size.x)
	var space_width := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var lines := 1
	var line_width := 0.0
	for word in words:
		var word_width := font.get_string_size(String(word), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if line_width > 0.0 and line_width + space_width + word_width > available:
			lines += 1
			line_width = word_width
		else:
			line_width += word_width if line_width <= 0.0 else space_width + word_width
	return lines


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
