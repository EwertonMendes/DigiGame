extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")


func _ready() -> void:
	OverworldState.reset_active_party()
	var hub: Node = HUB_SCENE.instantiate()
	add_child(hub)
	await _frames(3)

	var training: TrainingCenterScreen = hub.get_node_or_null("TrainingCenterUI/TrainingCenter") as TrainingCenterScreen
	if not _check(training != null, "Hub must expose the Training Center"):
		return
	training.open_screen()
	await _frames(4)

	if not _check(training.visible, "Training Center must become visible"):
		return
	if not _check(training.get("_header") is DigiModalHeader, "Training Center must use the shared Digi UI V2 modal header"):
		return
	if not _check(training.get("_hint_bar") is DigiInputHintBar, "Training Center must expose adaptive V2 input hints"):
		return
	if not _check(training.get("_collection_header") is DigiSectionHeader, "Training roster must use the shared V2 section header"):
		return
	if not _check((training.get("_collection_ids") as Array).size() > 0, "Training Center must expose at least one owned Digimon"):
		return

	var detail: Control = training.get("_detail") as Control
	if not _check(detail != null and _layout_text_is_usable(detail), "Training detail contains collapsed or vertical text"):
		return
	if not _check(_find_label_containing(detail, "ATTRIBUTE TRAINING") != null, "Training Center must expose attribute training"):
		return
	if not _check(_find_label_containing(detail, "TACTICAL MOBILITY") != null, "Training Center must expose tactical mobility"):
		return
	if not _check(_find_label_containing(detail, "TRAINING PLAN") != null, "Training Center must expose the plan summary"):
		return

	var detail_scroll := training.get("_detail_scroll") as ScrollContainer
	if not _check(detail_scroll != null, "Training detail must expose its scroll viewport"):
		return
	var rows: Dictionary = training.get("_stat_rows") as Dictionary
	if not _check(rows.size() == 6, "Training Center must build all six trainable stat rows"):
		return
	var selected_id := String(training.get("_selected_id"))
	var selected: DigimonInstance = OverworldState.get_instance_by_id(selected_id)
	if not _check(selected != null, "Training Center must keep a valid selected Digimon"):
		return

	var target_key := ""
	var target_plus: Button = null
	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed"]:
		var row := rows.get(stat_key) as TrainingStatRow
		if row == null:
			continue
		var buttons := row.get_focus_buttons()
		if buttons.size() >= 2 and not buttons[1].disabled:
			target_key = stat_key
			target_plus = buttons[1]
			break
	if not _check(not target_key.is_empty() and target_plus != null, "At least one attribute must be trainable for the default individual"):
		return

	# Focus the same control a mouse/gamepad interaction would leave active and
	# capture the viewport after Godot has made that row visible. Rebuilding the
	# detail must not append a second pending tree and drag focus/scroll downward.
	target_plus.grab_focus()
	await _frames(2)
	var scroll_before := detail_scroll.scroll_vertical
	target_plus.pressed.emit()
	await _frames(3)

	var pending: Dictionary = training.get("_pending_stats") as Dictionary
	if not _check(int(pending.get(target_key, 0)) == 1, "Attribute stepper must add a point to the pending plan"):
		return
	if not _check(abs(detail_scroll.scroll_vertical - scroll_before) <= 2, "Attribute refresh must preserve the user's training scroll position"):
		return
	rows = training.get("_stat_rows") as Dictionary
	var refreshed_row := rows.get(target_key) as TrainingStatRow
	if not _check(refreshed_row != null, "Dynamic refresh must recreate the edited stat row"):
		return
	var refreshed_buttons := refreshed_row.get_focus_buttons()
	if not _check(refreshed_buttons.size() >= 2, "Refreshed stat row must preserve both step controls"):
		return
	var expected_focus: Control = refreshed_buttons[1] if not refreshed_buttons[1].disabled else refreshed_buttons[0]
	var focus_owner := get_viewport().gui_get_focus_owner()
	if not _check(focus_owner == expected_focus, "Dynamic stat refresh must restore focus to the equivalent available control"):
		return
	var points_label := refreshed_row.get_training_points_label()
	if not _check(points_label != null and points_label.text.contains("+1"), "Edited stat row must expose its pending training amount"):
		return
	if not _check(points_label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "Training point totals must never render with ellipsis"):
		return
	if not _check(points_label.size.x >= 103.0, "Training point totals must reserve enough width for the complete value"):
		return
	if not _check(_find_label_containing(detail, "%s +1" % _stat_label(target_key)) != null, "Training plan must summarize the pending attribute change"):
		return

	training.call("_discard_plan")
	await _frames(2)
	pending = training.get("_pending_stats") as Dictionary
	if not _check(pending.is_empty() and int(training.get("_pending_mobility")) == 0, "Discard must clear the complete pending plan"):
		return

	training.close_view()
	hub.queue_free()
	await _frames(2)
	print("training ui v2 regression passed")
	get_tree().quit()


func _stat_label(stat_key: String) -> String:
	match stat_key:
		"mp":
			return "SP"
		"speed":
			return "SPD"
		_:
			return stat_key.to_upper()


func _layout_text_is_usable(root: Control) -> bool:
	for label: Label in _labels_under(root):
		if not label.is_visible_in_tree():
			continue
		var text := label.text.strip_edges()
		if text.length() < 3:
			continue
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var width_floor := 8.0 if text.length() <= 4 else 18.0
			if label.size.x < width_floor:
				print("[training-ui-v2] collapsed single-line label: %s (%.1f px)" % [text, label.size.x])
				return false
		elif label.size.x < 42.0:
			print("[training-ui-v2] collapsed wrapped label: %s (%.1f px)" % [text, label.size.x])
			return false
	return true


func _find_label_containing(root: Node, target: String) -> Label:
	if root is Label and (root as Label).text.contains(target):
		return root as Label
	for child: Node in root.get_children():
		var found := _find_label_containing(child, target)
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
	print("[training-ui-v2] FAIL: %s" % message)
	get_tree().quit(1)
	return false


func _frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
