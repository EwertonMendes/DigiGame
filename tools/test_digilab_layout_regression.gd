extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")


func _ready() -> void:
	OverworldState.reset_active_party()
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
	if not _check(_primary_tabs_are_valid(convert, "convert"), "Convert Digi Data must expose the three primary tabs"):
		return
	if not _check(_layout_text_is_usable(convert.get("_detail_body") as Control), "Convert Digi Data contains collapsed or vertical text"):
		return
	print("[digilab-layout] convert ok")

	digilab.call("_switch_tab", "party")
	await _frames(4)
	if not _check(party.visible and not convert.visible and not ascension.visible, "Party / Storage primary tab must open"):
		return
	if not _check(_primary_tabs_are_valid(party, "party"), "Party / Storage must expose the three primary tabs"):
		return
	var party_detail: Control = party.get("_detail") as Control
	if not _check(party_detail != null and _layout_text_is_usable(party_detail), "Party / Storage contains collapsed or vertical text"):
		return

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
	if not _check(String(digilab.get("_active_tab")) == "ascension", "Opening Ascension from Party Actions must update the active primary tab"):
		return
	if not _check(String(ascension.call("get_selected_instance_id")) == selected_id, "Ascension / Expansion must open on the Digimon selected in Party / Storage"):
		return
	if not _check(_primary_tabs_are_valid(ascension, "ascension"), "Ascension / Expansion must expose the three primary tabs"):
		return
	var ascension_detail: Control = ascension.get("_detail") as Control
	if not _check(ascension_detail != null and _layout_text_is_usable(ascension_detail), "Ascension / Expansion contains collapsed or vertical text"):
		return
	if not _check(_find_label_containing(ascension_detail, "TIER ASCENSION") != null, "Ascension / Expansion must expose Tier Ascension"):
		return
	if not _check(_find_label_containing(ascension_detail, "EXPANSION") != null, "Ascension / Expansion must expose Expansion controls"):
		return
	print("[digilab-layout] ascension deep-link ok")

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
	hub.queue_free()
	await _frames(2)
	print("digilab layout regression passed")
	get_tree().quit()


func _primary_tabs_are_valid(screen: Control, active_id: String) -> bool:
	var header: DigiModalHeader = screen.get("_header") as DigiModalHeader
	if header == null:
		return false
	for tab_id: String in ["convert", "party", "ascension"]:
		var button: Button = header.get_tab_button(tab_id)
		if button == null or button.disabled:
			return false
	return header.get_tab_button(active_id) != null


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
	if root is Button and (root as Button).text == target:
		return root as Button
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
