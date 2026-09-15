extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")


func _ready() -> void:
	OverworldState.reset_active_party()
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	await _frames(3)

	var digilab := hub.get_node_or_null("DigiLabUI/DigiLab") as Control
	assert(digilab != null, "Hub must expose DigiLab")
	digilab.call("open_lab")
	await _frames(4)

	var create_screen := digilab.get("_create_screen") as Control
	var party_screen := digilab.get("_party_screen") as Control
	var ascension_screen := digilab.get("_ascension_screen") as Control
	assert(create_screen != null and create_screen.visible, "DigiLab must open on Convert Digi Data")
	assert(party_screen != null and not party_screen.visible, "Party / Storage must initially stay hidden")
	assert(ascension_screen != null and not ascension_screen.visible, "Ascension / Expansion must stay hidden until requested")

	var create_detail := create_screen.get("_detail_body") as Control
	assert(create_detail != null, "Convert Digi Data must expose its detail body")
	await _frames(2)
	_assert_semantic_labels(create_detail, 4, "Convert Digi Data")
	_assert_no_vertical_text(create_detail, "Convert Digi Data")
	_assert_subsection_copy(create_detail)
	_assert_hint_bar_bounds(create_screen.get("_hint_bar") as Control, "Convert Digi Data")
	await _assert_create_selection_resets_scroll(create_screen)

	digilab.call("_switch_tab", "party")
	await _frames(4)
	assert(not create_screen.visible and party_screen.visible, "Primary tab switch must show Party / Storage")
	var party_detail := party_screen.get("_detail") as Control
	assert(party_detail != null, "Party / Storage must expose its detail body")
	_assert_semantic_labels(party_detail, 6, "Party / Storage")
	_assert_no_vertical_text(party_detail, "Party / Storage")
	_assert_hint_bar_bounds(party_screen.get("_hint_bar") as Control, "Party / Storage")
	await _assert_party_selection_resets_scroll(party_screen)

	var ascension_button := _find_button_by_text(party_detail, "ASCENSION / EXPANSION")
	assert(ascension_button != null, "Party / Storage must keep Ascension / Expansion reachable after the V2 migration")
	assert(ascension_button.focus_mode == Control.FOCUS_ALL, "Ascension / Expansion action must be controller focusable")
	ascension_button.pressed.emit()
	await _frames(3)
	assert(ascension_screen.visible and not party_screen.visible, "Ascension / Expansion must open from Party / Storage")
	ascension_screen.call("close_view")
	await _frames(3)
	assert(party_screen.visible and not ascension_screen.visible, "Closing Ascension / Expansion must return to Party / Storage")

	digilab.call("close_view")
	hub.queue_free()
	await _frames(2)
	print("digilab layout regression passed")
	get_tree().quit()


func _assert_create_selection_resets_scroll(screen: Control) -> void:
	var buttons: Array = screen.get("_data_buttons")
	var scroll := screen.get("_detail_scroll") as ScrollContainer
	assert(scroll != null, "Convert Digi Data must expose detail scrolling")
	if buttons.size() < 2:
		return
	var max_scroll := int(scroll.get_v_scroll_bar().max_value)
	if max_scroll > 0:
		scroll.scroll_vertical = max_scroll
		await _frames(1)
	var second := buttons[1] as Button
	assert(second != null, "Digi Data entry must be a button")
	var species_name := String(second.get_meta("species_name", ""))
	assert(not species_name.is_empty(), "Digi Data entry must expose its species name")
	screen.call("_select_species", species_name)
	await _frames(2)
	assert(scroll.scroll_vertical <= 1, "Selecting another species must reset the reconstructed detail viewport to the top")
	_assert_no_vertical_text(screen.get("_detail_body") as Control, "Convert Digi Data after selection")


func _assert_party_selection_resets_scroll(screen: Control) -> void:
	var ids: Array = screen.get("_list_ids")
	var scroll := screen.get("_detail_scroll") as ScrollContainer
	assert(scroll != null, "Party / Storage must expose detail scrolling")
	if ids.size() < 2:
		return
	var max_scroll := int(scroll.get_v_scroll_bar().max_value)
	if max_scroll > 0:
		scroll.scroll_vertical = max_scroll
		await _frames(1)
	screen.call("_select", String(ids[1]))
	await _frames(2)
	assert(scroll.scroll_vertical <= 1, "Selecting another collection member must reset Party / Storage details to the top")
	_assert_no_vertical_text(screen.get("_detail") as Control, "Party / Storage after selection")


func _assert_semantic_labels(root: Control, minimum_count: int, label_name: String) -> void:
	var semantic_count := 0
	for label: Label in _labels_under(root):
		var text := label.text.strip_edges()
		if not label.is_visible_in_tree() or text.is_empty():
			continue
		# Semantic chips/status values are deliberately single-line, unclipped and
		# non-trimming. Wrapped prose may also use NO_TRIMMING in the base theme,
		# so it must not be classified as a semantic label here.
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			continue
		if label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or label.clip_text:
			continue
		semantic_count += 1
		var minimum := label.get_combined_minimum_size()
		var width_floor := 8.0 if text.length() <= 4 else 18.0
		assert(minimum.x >= width_floor, "%s semantic label '%s' must keep an intrinsic horizontal minimum" % [label_name, text])
		assert(label.size.x >= width_floor, "%s semantic label '%s' collapsed horizontally" % [label_name, text])
	assert(semantic_count >= minimum_count, "%s must use non-collapsing semantic labels for chips and status values" % label_name)


func _assert_no_vertical_text(root: Control, label_name: String) -> void:
	for label: Label in _labels_under(root):
		var text := label.text.strip_edges()
		if not label.is_visible_in_tree() or text.length() < 3:
			continue
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var width_floor := 8.0 if text.length() <= 4 else 18.0
			assert(label.size.x >= width_floor, "%s has collapsed horizontal text '%s'" % [label_name, text])
			continue
		# Wrapped prose is valid, but a one-character column is never an intended layout.
		assert(label.size.x >= 42.0, "%s wrapped '%s' into an unreadable vertical column" % [label_name, text])


func _assert_subsection_copy(root: Control) -> void:
	var copy: Label = null
	for label: Label in _labels_under(root):
		if label.text.begins_with("Data is consumed"):
			copy = label
			break
	assert(copy != null, "Reconstruction subsection explanatory copy must be present")
	assert(copy.autowrap_mode == TextServer.AUTOWRAP_OFF, "Reconstruction subsection copy must stay horizontal")
	assert(copy.size.x >= 100.0, "Reconstruction subsection copy must not collapse into a vertical column")


func _assert_hint_bar_bounds(hint_bar: Control, label_name: String) -> void:
	assert(hint_bar != null, "%s must expose its input hint bar" % label_name)
	var bounds := hint_bar.get_global_rect()
	for control: Control in _controls_under(hint_bar):
		if not control.is_visible_in_tree() or control == hint_bar:
			continue
		var rect := control.get_global_rect()
		assert(rect.position.x >= bounds.position.x - 1.0, "%s footer content leaked through the left edge" % label_name)
		assert(rect.end.x <= bounds.end.x + 1.0, "%s footer content leaked through the right edge" % label_name)


func _find_button_by_text(root: Node, target: String) -> Button:
	if root is Button and (root as Button).text == target:
		return root as Button
	for child in root.get_children():
		var found := _find_button_by_text(child, target)
		if found != null:
			return found
	return null


func _labels_under(root: Node) -> Array[Label]:
	var result: Array[Label] = []
	if root is Label:
		result.append(root as Label)
	for child in root.get_children():
		result.append_array(_labels_under(child))
	return result


func _controls_under(root: Node) -> Array[Control]:
	var result: Array[Control] = []
	if root is Control:
		result.append(root as Control)
	for child in root.get_children():
		result.append_array(_controls_under(child))
	return result


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
