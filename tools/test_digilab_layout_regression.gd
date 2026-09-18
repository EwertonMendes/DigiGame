extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")


func _ready() -> void:
	OverworldState.set_persistence_enabled(false)
	OverworldState.reset_progress_for_tests()
	var factory: DigimonFactory = FactoryScript.new(OverworldState.get_database())
	var reserve_fixture := factory.create_player_by_name("agumon", 1, 100)
	var storage_fixture := factory.create_player_by_name("gabumon", 1, 100)
	if not _check(reserve_fixture != null and storage_fixture != null, "Party / Storage regression fixtures must be creatable"):
		return
	if not _check(not OverworldState.add_collection_instance(reserve_fixture).is_empty(), "Reserve fixture must enter the collection"):
		return
	if not _check(not OverworldState.add_collection_instance(storage_fixture).is_empty(), "Storage fixture must enter the collection"):
		return
	if not _check(OverworldState.add_to_reserve_party(reserve_fixture.id), "Reserve fixture must occupy Reserve slot 1"):
		return

	var hub: Node = HUB_SCENE.instantiate()
	add_child(hub)
	await _frames(3)
	print("[digilab-layout] hub ready")

	var digilab: Control = hub.get_node_or_null("DigiLabUI/DigiLab") as Control
	if not _check(digilab != null, "Hub must expose DigiLab"):
		return
	digilab.call("open_lab")
	await _frames(4)

	var convert: Control = digilab.get("_create_screen") as Control
	var party: Control = digilab.get("_party_screen") as Control
	var ascension: Control = digilab.get("_ascension_screen") as Control
	if not _check(convert != null and party != null and ascension != null, "DigiLab must build all three primary workspaces"):
		return
	if not _check(convert.visible and not party.visible and not ascension.visible, "DigiLab must open on Convert Digi Data"):
		return
	var lab_background := convert.find_child("DigiLabBackgroundImage", true, false) as TextureRect
	if not _check(lab_background != null and lab_background.texture != null and lab_background.texture.resource_path.ends_with("digi_lab.webp"), "DigiLab must use its dedicated laboratory background"):
		return
	if not _check(_workspace_background_is_visible(convert), "Convert Digi Data must render the laboratory background above the legacy backdrop and below transparent workspace chrome"):
		return
	if not _check(_primary_tabs_are_valid(convert, "convert"), "Convert Digi Data must expose the three primary tabs"):
		return
	if not _check(_workspace_contract_is_valid(convert, "_list_scroll", "_detail_scroll", "_roster_pager"), "Convert Digi Data must use the paged no-scroll workspace contract"):
		return
	if not _check(convert.get("_mode_segments") is DigiSegmentedTabs, "Convert Digi Data must use the shared segmented control"):
		return
	if not _check(_find_label_containing(convert.get("_detail_body") as Control, "NEW INDIVIDUAL") == null, "Convert Digi Data must not keep the legacy New Individual strip"):
		return
	if not _check(_layout_text_is_usable(convert.get("_detail_body") as Control), "Convert Digi Data contains collapsed or vertical text"):
		return
	if not _check(_content_fits_disabled_scroll(convert, "_list_scroll", "_list_box"), "Convert Digi Data archive page must fit without scrolling"):
		return
	if not _check(_content_fits_disabled_scroll(convert, "_detail_scroll", "_detail_body"), "Convert Digi Data detail must fit without scrolling"):
		return
	print("[digilab-layout] convert ok")

	digilab.call("_switch_tab", "party")
	await _frames(4)
	if not _check(party.visible and not convert.visible and not ascension.visible, "Party / Storage primary tab must open"):
		return
	if not _check(_workspace_background_is_visible(party), "Party / Storage must keep the laboratory background visible"):
		return
	if not _check(_primary_tabs_are_valid(party, "party"), "Party / Storage must expose the three primary tabs"):
		return
	if not _check(_workspace_contract_is_valid(party, "_list_scroll", "_detail_scroll", "_workspace_pager"), "Party / Storage must use the paged no-scroll workspace contract"):
		return
	if not _check(party.get("_roster_segments") is DigiSegmentedTabs, "Party / Storage must expose separate Party and Storage segments"):
		return
	var party_detail: Control = party.get("_detail") as Control
	if not _check(party_detail != null and _layout_text_is_usable(party_detail), "Party / Storage contains collapsed or vertical text"):
		return
	if not _check(_content_fits_disabled_scroll(party, "_list_scroll", "_list"), "Party / Storage roster page must fit without scrolling"):
		return
	if not _check(_content_fits_disabled_scroll(party, "_detail_scroll", "_detail"), "Party / Storage stats and actions must fit without scrolling"):
		return
	if not _check(_content_uses_available_height(party, "_detail_scroll", "_detail"), "Party / Storage detail must compose itself across the available height"):
		return
	if not _check(_squad_actions_are_bounded(party, party_detail, 3), "Active Squad Actions must remain compact and fully above the footer"):
		return
	if not _check(_stats_are_bounded(party, party_detail), "Active Stats must keep all seven rows inside the visible detail area"):
		return

	party.call("_set_roster_mode", "reserve")
	await _frames(3)
	var reserve_detail := party.get("_detail") as Control
	if not _check(reserve_detail != null and _squad_actions_are_bounded(party, reserve_detail, 3), "Reserve Squad Actions must remain compact and fully above the footer"):
		return
	if not _check(_stats_are_bounded(party, reserve_detail), "Reserve Stats must keep all seven rows inside the visible detail area"):
		return

	party.call("_set_roster_mode", "storage")
	await _frames(3)
	var storage_detail := party.get("_detail") as Control
	if not _check(storage_detail != null and _squad_actions_are_bounded(party, storage_detail, 2), "Storage Squad Actions must remain compact and fully above the footer"):
		return
	if not _check(_stats_are_bounded(party, storage_detail), "Storage Stats must keep all seven rows inside the visible detail area"):
		return

	party.call("_set_roster_mode", "active")
	await _frames(3)
	party_detail = party.get("_detail") as Control
	var selected_id: String = String(party.call("get_selected_instance_id"))
	if not _check(not selected_id.is_empty(), "Party / Storage must expose the selected individual"):
		return
	var ascension_action: Button = _find_button_by_text(party_detail, "ASCENSION / EXPANSION")
	if not _check(ascension_action != null, "Party Actions must expose Ascension / Expansion"):
		return
	if not _check(ascension_action.focus_mode == Control.FOCUS_ALL and not ascension_action.disabled, "Ascension / Expansion action must be controller-focusable"):
		return
	print("[digilab-layout] party ok; opening ascension for %s" % selected_id)

	ascension_action.pressed.emit()
	await _frames(4)
	if not _check(ascension.visible and not party.visible, "Party Actions must open the Ascension / Expansion primary tab"):
		return
	if not _check(_workspace_background_is_visible(ascension), "Ascension / Expansion must keep the laboratory background visible"):
		return
	if not _check(String(digilab.get("_active_tab")) == "ascension", "Opening Ascension from Party Actions must update the active primary tab"):
		return
	if not _check(String(ascension.call("get_selected_instance_id")) == selected_id, "Ascension / Expansion must open on the Digimon selected in Party / Storage"):
		return
	if not _check(_primary_tabs_are_valid(ascension, "ascension"), "Ascension / Expansion must expose the three primary tabs"):
		return
	if not _check(_workspace_contract_is_valid(ascension, "_list_scroll", "_detail_scroll", "_workspace_pager"), "Ascension / Expansion must use the paged no-scroll workspace contract"):
		return
	if not _check(ascension.get("_section_segments") is DigiSegmentedTabs, "Ascension / Expansion must use the shared segmented control"):
		return
	var ascension_detail: Control = ascension.get("_detail") as Control
	if not _check(ascension_detail != null and _layout_text_is_usable(ascension_detail), "Ascension / Expansion contains collapsed or vertical text"):
		return
	if not _check(_find_button_by_text(ascension_detail, "TIER ASCENSION") != null, "Ascension / Expansion must expose the Tier Ascension secondary workspace"):
		return
	if not _check(_find_button_by_text(ascension_detail, "EXPANSION") != null, "Ascension / Expansion must expose the Expansion secondary workspace"):
		return
	var tier_arrow := ascension_detail.find_child("TierTransitionArrow", true, false) as TextureRect
	if not _check(tier_arrow != null and tier_arrow.texture != null, "Tier Ascension must use the packaged transition arrow icon instead of a font glyph"):
		return
	if not _check(_content_fits_disabled_scroll(ascension, "_list_scroll", "_list"), "Ascension roster page must fit without scrolling"):
		return
	if not _check(_content_fits_disabled_scroll(ascension, "_detail_scroll", "_detail"), "Ascension / Expansion detail must fit without scrolling"):
		return
	if not _check(_content_uses_available_height(ascension, "_detail_scroll", "_detail"), "Ascension / Expansion detail must compose itself across the available height"):
		return
	var tier_compare := ascension_detail.find_child("TierComparison", true, false) as Control
	var tier_actions := ascension_detail.find_child("TierActions", true, false) as Control
	if not _check(tier_compare != null and tier_compare.size_flags_vertical == Control.SIZE_EXPAND_FILL, "Tier comparison must expand into available vertical room"):
		return
	if not _check(tier_actions != null and tier_actions.size_flags_vertical == Control.SIZE_EXPAND_FILL, "Tier actions must expand into available vertical room"):
		return
	print("[digilab-layout] ascension deep-link ok")

	ascension.call("_set_section_mode", "expansion")
	await _frames(4)
	ascension_detail = ascension.get("_detail") as Control
	if not _check(_content_fits_disabled_scroll(ascension, "_detail_scroll", "_detail"), "Expansion detail must fit without scrolling"):
		return
	if not _check(_expansion_content_is_bounded(ascension, ascension_detail), "Expansion footprint and actions must remain fully above the footer"):
		return
	print("[digilab-layout] expansion bounds ok")

	# DigiModalHeader uses the same adjacent-tab method for LB/RB and L1/R1.
	# Moving left from Ascension must therefore return to Party / Storage.
	var ascension_header: DigiModalHeader = ascension.get("_header") as DigiModalHeader
	if not _check(ascension_header != null and ascension_header.select_adjacent_tab(-1), "Previous shoulder tab navigation must work from Ascension"):
		return
	await _frames(4)
	if not _check(party.visible and not ascension.visible, "LB/L1-equivalent navigation must move from Ascension to Party / Storage"):
		return

	var party_header: DigiModalHeader = party.get("_header") as DigiModalHeader
	if not _check(party_header != null and party_header.select_adjacent_tab(1), "Next shoulder tab navigation must work from Party / Storage"):
		return
	await _frames(4)
	if not _check(ascension.visible and not party.visible, "RB/R1-equivalent navigation must move from Party / Storage to Ascension"):
		return
	if not _check(String(ascension.call("get_selected_instance_id")) == selected_id, "Shoulder navigation from Party / Storage must preserve the selected Digimon context"):
		return
	print("[digilab-layout] shoulder tabs ok")

	digilab.call("close_view")
	# queue_free() is deferred. Wait for the Hub to actually leave the tree before
	# ending the process so every child-owned Resource is released deterministically.
	# This avoids racing Godot's shutdown cleanup as the Hub grows new services.
	hub.queue_free()
	await hub.tree_exited
	await get_tree().process_frame
	print("digilab layout regression passed")
	get_tree().quit()



func _workspace_background_is_visible(screen: Control) -> bool:
	var legacy_backdrop := screen.get("_backdrop") as ColorRect
	var frame := screen.get("_frame") as PanelContainer
	var layer := screen.find_child("DigiLabWorkspaceBackdrop", true, false) as Control
	var image := screen.find_child("DigiLabBackgroundImage", true, false) as TextureRect
	if legacy_backdrop == null or frame == null or layer == null or image == null:
		return false
	if layer.get_parent() != screen:
		return false
	if not image.visible or image.texture == null or image.modulate.a < 0.8:
		return false
	# The image must sit above the opaque legacy backdrop but below the full-screen
	# workspace frame. The frame itself must not paint an opaque surface.
	if not (legacy_backdrop.get_index() < layer.get_index() and layer.get_index() < frame.get_index()):
		print("[digilab-layout] background layer order is invalid: legacy=%d image=%d frame=%d" % [legacy_backdrop.get_index(), layer.get_index(), frame.get_index()])
		return false
	var frame_style := frame.get_theme_stylebox("panel") as StyleBoxFlat
	if frame_style == null or frame_style.bg_color.a > 0.05:
		print("[digilab-layout] workspace frame still hides the background")
		return false
	return true


func _primary_tabs_are_valid(screen: Control, active_id: String) -> bool:
	var header: DigiModalHeader = screen.get("_header") as DigiModalHeader
	if header == null or not header.is_workspace_mode():
		return false
	var tabs_root := header.get_node_or_null("HeaderTabs") as Control
	if tabs_root == null:
		return false
	var uniform_width := -1.0
	for tab_id: String in ["convert", "party", "ascension"]:
		var button: Button = header.get_tab_button(tab_id)
		if button == null or button.disabled or button.focus_mode != Control.FOCUS_NONE:
			return false
		var label := button.get_meta("tab_label") as Label
		if label == null or not label.visible or label.text.strip_edges().is_empty():
			print("[digilab-layout] missing visible name for primary tab %s" % tab_id)
			return false
		if label.size.x < 24.0:
			print("[digilab-layout] primary tab label has no usable rendered width: %s (%.1f px)" % [tab_id, label.size.x])
			return false
		if label.size.x > button.size.x:
			print("[digilab-layout] primary tab label exceeds tab bounds: %s" % tab_id)
			return false
		if uniform_width < 0.0:
			uniform_width = button.size.x
		elif not is_equal_approx(button.size.x, uniform_width):
			print("[digilab-layout] primary tabs must share one content-driven width")
			return false
		if button.position.x + button.size.x > tabs_root.size.x + 1.0:
			print("[digilab-layout] primary tab escaped behind header controls: %s" % tab_id)
			return false
	return uniform_width >= 170.0 and header.get_tab_button(active_id) != null


func _workspace_contract_is_valid(screen: Control, list_scroll_key: String, detail_scroll_key: String, pager_key: String) -> bool:
	var list_scroll := screen.get(list_scroll_key) as ScrollContainer
	var detail_scroll := screen.get(detail_scroll_key) as ScrollContainer
	var pager := screen.get(pager_key) as DigiPager
	if list_scroll == null or detail_scroll == null or pager == null:
		return false
	if list_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	if detail_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var previous := pager.get_node_or_null("PreviousPage") as Button
	var next := pager.get_node_or_null("NextPage") as Button
	if previous == null or next == null:
		return false
	if previous.focus_mode != Control.FOCUS_NONE or next.focus_mode != Control.FOCUS_NONE:
		return false
	return true


func _content_fits_disabled_scroll(screen: Control, scroll_key: String, content_key: String) -> bool:
	var scroll := screen.get(scroll_key) as ScrollContainer
	var content := screen.get(content_key) as Control
	if scroll == null or content == null:
		return false
	var required := content.get_combined_minimum_size().y
	var available := scroll.size.y
	if required > available + 2.0:
		print("[digilab-layout] content overflow: %s requires %.1f px but only %.1f px are available" % [content_key, required, available])
		return false
	return true


func _content_uses_available_height(screen: Control, scroll_key: String, content_key: String) -> bool:
	var scroll := screen.get(scroll_key) as ScrollContainer
	var content := screen.get(content_key) as Control
	if scroll == null or content == null:
		return false
	if not scroll.is_visible_in_tree() or scroll.size.y <= 1.0:
		return true
	if content.size.y + 2.0 < scroll.size.y:
		print("[digilab-layout] unused vertical space: %s uses %.1f px of %.1f px" % [content_key, content.size.y, scroll.size.y])
		return false
	return true


func _squad_actions_are_bounded(screen: Control, root: Control, expected_command_count: int) -> bool:
	if screen == null or root == null:
		return false
	var panel := root.find_child("SquadActionsPanel", true, false) as Control
	var commands := root.find_child("SquadActionsCommands", true, false) as VBoxContainer
	var footer := screen.get("_hint_bar") as Control
	var detail_panel := screen.get("_detail_panel") as Control
	if panel == null or commands == null or footer == null or detail_panel == null:
		print("[digilab-layout] missing Squad Actions layout nodes")
		return false

	var command_count := 0
	for child: Node in commands.get_children():
		if not child is DigiCommandButton:
			continue
		var command := child as DigiCommandButton
		command_count += 1
		if command.size.y > 90.0:
			print("[digilab-layout] Squad command expanded vertically: %s = %.1f px" % [command.name, command.size.y])
			return false
		var command_rect := command.get_global_rect()
		var panel_rect := panel.get_global_rect()
		if command_rect.position.y < panel_rect.position.y - 1.0 or command_rect.end.y > panel_rect.end.y + 1.0:
			print("[digilab-layout] Squad command escaped panel bounds: %s" % command.name)
			return false

	if command_count != expected_command_count:
		print("[digilab-layout] expected %d Squad commands but found %d" % [expected_command_count, command_count])
		return false

	var panel_rect := panel.get_global_rect()
	var footer_rect := footer.get_global_rect()
	var detail_rect := detail_panel.get_global_rect()
	if panel_rect.end.y > footer_rect.position.y - 2.0:
		print("[digilab-layout] Squad Actions overlaps footer: panel bottom %.1f footer top %.1f" % [panel_rect.end.y, footer_rect.position.y])
		return false
	if panel_rect.end.y > detail_rect.end.y + 1.0:
		print("[digilab-layout] Squad Actions escaped detail panel")
		return false

	var minimum_h := panel.get_combined_minimum_size().y
	if panel.size.y > minimum_h + 6.0:
		print("[digilab-layout] Squad Actions stretched beyond content: %.1f px vs minimum %.1f px" % [panel.size.y, minimum_h])
		return false
	return true


func _stats_are_bounded(screen: Control, root: Control) -> bool:
	if screen == null or root == null:
		return false
	var stats := root.find_child("PartyWorkspaceStats", true, false) as Control
	var detail_panel := screen.get("_detail_panel") as Control
	var footer := screen.get("_hint_bar") as Control
	if stats == null or detail_panel == null or footer == null:
		print("[digilab-layout] missing bounded Stats layout nodes")
		return false

	var rows: Array[Control] = []
	for child: Node in stats.find_children("*", "DigiStatRow", true, false):
		if child is Control:
			rows.append(child as Control)
	if rows.size() != 7:
		print("[digilab-layout] expected 7 Stats rows but found %d" % rows.size())
		return false

	var detail_rect := detail_panel.get_global_rect()
	var footer_rect := footer.get_global_rect()
	for row: Control in rows:
		var rect := row.get_global_rect()
		if rect.position.y < detail_rect.position.y - 1.0 or rect.end.y > detail_rect.end.y + 1.0:
			print("[digilab-layout] Stats row escaped detail panel: %s" % row.name)
			return false
		if rect.end.y > footer_rect.position.y - 2.0:
			print("[digilab-layout] Stats row overlaps footer: %s" % row.name)
			return false
		if row.size.y > 44.0:
			print("[digilab-layout] bounded Stats row stretched vertically: %s = %.1f px" % [row.name, row.size.y])
			return false
	return true


func _expansion_content_is_bounded(screen: Control, root: Control) -> bool:
	if screen == null or root == null:
		return false
	var footprint := root.find_child("ExpansionFootprint", true, false) as Control
	var actions := root.find_child("ExpansionActions", true, false) as Control
	var detail_panel := screen.get("_detail_panel") as Control
	var footer := screen.get("_hint_bar") as Control
	if footprint == null or actions == null or detail_panel == null or footer == null:
		print("[digilab-layout] missing Expansion layout nodes")
		return false

	var detail_rect := detail_panel.get_global_rect()
	var footer_rect := footer.get_global_rect()
	for control: Control in [footprint, actions]:
		var rect := control.get_global_rect()
		if rect.end.y > detail_rect.end.y + 1.0 or rect.end.y > footer_rect.position.y - 2.0:
			print("[digilab-layout] Expansion control escaped visible workspace: %s" % control.name)
			return false

	var command_count := 0
	for child: Node in actions.get_children():
		if not child is DigiCommandButton:
			continue
		command_count += 1
		var button := child as DigiCommandButton
		if button.size.y > 90.0:
			print("[digilab-layout] Expansion command stretched vertically: %s = %.1f px" % [button.name, button.size.y])
			return false
		var rect := button.get_global_rect()
		if rect.end.y > detail_rect.end.y + 1.0 or rect.end.y > footer_rect.position.y - 2.0:
			print("[digilab-layout] Expansion command escaped visible workspace: %s" % button.name)
			return false
	if command_count != 2:
		print("[digilab-layout] Expansion must expose exactly two command cards; found %d" % command_count)
		return false
	return true


func _layout_text_is_usable(root: Control) -> bool:
	if root == null:
		return false
	for label: Label in _labels_under(root):
		if not label.is_visible_in_tree():
			continue
		var text: String = label.text.strip_edges()
		if text.length() < 3:
			continue
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			# Very short semantic values such as 1×1, 2×2 and Lv 1 are legitimately
			# compact. The failure we care about is a label collapsing to a one-character
			# column, so use a smaller floor for short values and a stricter floor for
			# normal words/status labels.
			var width_floor := 8.0 if text.length() <= 4 else 18.0
			if label.size.x < width_floor:
				print("[digilab-layout] collapsed single-line label: %s (%.1f px)" % [text, label.size.x])
				return false
		elif label.size.x < 42.0:
			print("[digilab-layout] collapsed wrapped label: %s (%.1f px)" % [text, label.size.x])
			return false
	return true


func _find_button_by_text(root: Node, target: String) -> Button:
	if root is Button:
		var button := root as Button
		if button.text == target:
			return button
		var command_title := button.find_child("CommandTitle", true, false) as Label
		if command_title != null and command_title.text == target:
			return button
	for child: Node in root.get_children():
		var found: Button = _find_button_by_text(child, target)
		if found != null:
			return found
	return null


func _find_label_containing(root: Node, target: String) -> Label:
	if root is Label and (root as Label).text.contains(target):
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_containing(child, target)
		if found != null:
			return found
	return null


func _labels_under(root: Node) -> Array[Label]:
	var result: Array[Label] = []
	if root is Label:
		result.append(root as Label)
	for child: Node in root.get_children():
		result.append_array(_labels_under(child))
	return result


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	print("[digilab-layout] FAIL: %s" % message)
	get_tree().quit(1)
	return false


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
