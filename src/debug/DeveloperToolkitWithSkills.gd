extends "res://src/debug/DeveloperToolkit.gd"

const TechniqueToolsScript = preload("res://src/debug/DebugTechniqueTools.gd")
const TECHNIQUE_PAGE_SIZE := 24

var _techniques: DebugTechniqueTools
var _skill_catalog: Array[Dictionary] = []
var _selected_skill_id := ""
var _skill_page := 0

var _skill_target_summary: Label
var _skill_search: LineEdit
var _skill_role_filter: OptionButton
var _skill_element_filter: OptionButton
var _skill_state_filter: OptionButton
var _skill_availability_filter: OptionButton
var _skill_results_summary: Label
var _skill_list: VBoxContainer
var _skill_details: Label
var _skill_form_learnset: Label
var _skill_learn_button: Button
var _skill_favorite_button: Button
var _skill_archive_button: Button
var _skill_mastery: SpinBox
var _skill_mastery_apply: Button


func _ready() -> void:
	super._ready()
	if not _available:
		return
	_techniques = TechniqueToolsScript.new() as DebugTechniqueTools
	_skill_catalog = _techniques.catalog(true)
	_build_skills_tab(_tabs)
	_refresh_skill_lab()


func _refresh_all() -> void:
	super._refresh_all()
	_refresh_skill_lab()


func _refresh_selected() -> void:
	super._refresh_selected()
	_refresh_skill_lab()


func _build_skills_tab(tabs: TabContainer) -> void:
	var page := _page(tabs, "SKILLS")
	page.add_child(_section_label("TECHNIQUE TEST LAB", UI.PURPLE))
	var intro := _label("Assign any catalog technique to the selected owned Digimon, change its organization/mastery state, then launch the normal battle sandbox. Debug mutations are real collection state and therefore exercise the same battle/save paths as gameplay.", 10, UI.SUBTLE)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(intro)

	_skill_target_summary = _label("Select an owned Digimon.", 11, UI.TEXT, true)
	_skill_target_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_skill_target_summary)

	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 7)
	filters.add_theme_constant_override("v_separation", 7)
	page.add_child(filters)

	_skill_search = LineEdit.new()
	_skill_search.placeholder_text = "Search name or id"
	_skill_search.custom_minimum_size = Vector2(230, 38)
	_skill_search.clear_button_enabled = true
	_style_field(_skill_search)
	_skill_search.text_changed.connect(func(_text: String) -> void: _reset_skill_results())
	filters.add_child(_skill_search)

	_skill_role_filter = _skill_filter(["ALL ROLES", "DAMAGE", "HEALING", "SUPPORT", "CONTROL", "MOBILITY"])
	_skill_element_filter = _skill_filter(["ALL ELEMENTS", "NEUTRAL", "FIRE", "PLANT", "WATER", "ELECTRIC", "WIND", "EARTH", "LIGHT", "DARK"])
	_skill_state_filter = _skill_filter(["ALL STATES", "LEARNED", "UNLEARNED", "FAVORITES", "ARCHIVED"])
	_skill_availability_filter = _skill_filter(["ALL AVAILABILITY", "READY", "LOCKED MECHANIC"])
	for option: OptionButton in [_skill_role_filter, _skill_element_filter, _skill_state_filter, _skill_availability_filter]:
		option.custom_minimum_size = Vector2(150, 38)
		option.item_selected.connect(func(_index: int) -> void: _reset_skill_results())
		filters.add_child(option)
	filters.add_child(_action("RESET FILTERS", _reset_skill_filters, UI.MUTED, 38))

	var catalog_header := HBoxContainer.new()
	catalog_header.add_theme_constant_override("separation", 8)
	page.add_child(catalog_header)
	catalog_header.add_child(_section_label("CATALOG", UI.CYAN))
	_skill_results_summary = _label("", 9, UI.SUBTLE, true)
	_skill_results_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_results_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	catalog_header.add_child(_skill_results_summary)

	var list_surface := PanelContainer.new()
	list_surface.custom_minimum_size.y = 250
	list_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_surface.add_theme_stylebox_override("panel", UI.glass_panel(UI.CYAN, 0.76, 9))
	page.add_child(list_surface)
	var list_margin := _margin(7, 7, 7, 7)
	list_surface.add_child(list_margin)
	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list_scroll.follow_focus = true
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_margin.add_child(list_scroll)
	_skill_list = VBoxContainer.new()
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_list.add_theme_constant_override("separation", 4)
	list_scroll.add_child(_skill_list)

	page.add_child(_section_label("SELECTED TECHNIQUE", UI.GOLD))
	var detail_surface := PanelContainer.new()
	detail_surface.add_theme_stylebox_override("panel", UI.glass_panel(UI.GOLD, 0.76, 9))
	page.add_child(detail_surface)
	var detail_margin := _margin(10, 9, 10, 9)
	detail_surface.add_child(detail_margin)
	_skill_details = _label("Select a technique from the catalog.", 10, UI.TEXT)
	_skill_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_details.custom_minimum_size.y = 92
	detail_margin.add_child(_skill_details)

	_skill_learn_button = _action("LEARN", _toggle_selected_skill_learned, UI.GREEN)
	_skill_favorite_button = _action("FAVORITE", _toggle_selected_skill_favorite, UI.GOLD)
	_skill_archive_button = _action("ARCHIVE", _toggle_selected_skill_archived, UI.PURPLE)
	page.add_child(_button_row([_skill_learn_button, _skill_favorite_button, _skill_archive_button, _action("REFILL HP / SP", _heal, UI.CYAN), _action("TEST IN BATTLE", _start_debug_battle, UI.RED)]))

	_skill_mastery = _spin(0, DigimonInstance.MAX_SKILL_MASTERY_POINTS, 1)
	_skill_mastery.custom_minimum_size.x = 110
	_skill_mastery_apply = _action("APPLY", _apply_selected_skill_mastery, UI.CYAN)
	page.add_child(_field_row("MASTERY POINTS", _skill_mastery, [_skill_mastery_apply, _action("LEARNED · 0", _set_selected_skill_mastery.bind(0), UI.MUTED), _action("EXPERIENCED · 8", _set_selected_skill_mastery.bind(DigimonInstance.EXPERIENCED_SKILL_MASTERY_POINTS), UI.CYAN), _action("MASTERED · 24", _set_selected_skill_mastery.bind(DigimonInstance.MAX_SKILL_MASTERY_POINTS), UI.GOLD)]))

	page.add_child(_section_label("CURRENT FORM LEARNSET", UI.GREEN))
	_skill_form_learnset = _label("", 9, UI.SUBTLE)
	_skill_form_learnset.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_skill_form_learnset)


func _skill_filter(labels: Array[String]) -> OptionButton:
	var option := OptionButton.new()
	for text: String in labels:
		option.add_item(text)
	_style_field(option)
	return option


func _reset_skill_filters() -> void:
	_skill_search.clear()
	_skill_role_filter.select(0)
	_skill_element_filter.select(0)
	_skill_state_filter.select(0)
	_skill_availability_filter.select(0)
	_reset_skill_results()


func _reset_skill_results() -> void:
	_skill_page = 0
	_refresh_skill_lab()


func _refresh_skill_lab() -> void:
	if _techniques == null or _skill_list == null:
		return
	var value := _selected_instance()
	if value == null:
		_skill_target_summary.text = "No owned Digimon selected."
		_skill_results_summary.text = "0 results"
		_clear_skill_list()
		_selected_skill_id = ""
		_refresh_skill_details()
		_refresh_form_learnset()
		return

	var species := _roster.database.get_by_seed(value.species_seed)
	var party_state := "PARTY" if OverworldState.get_active_party_ids().has(value.id) else "STORAGE"
	_skill_target_summary.text = "%s · LV %d · %s · %d learned · %d favorites · %d archived" % [
		_progression.display_name(value).to_upper(), value.level, party_state,
		value.learned_skills.size(), value.favorite_skills.size(), value.archived_skills.size()
	]

	var filtered := _filtered_skills(value)
	var page_count := maxi(1, ceili(float(filtered.size()) / float(TECHNIQUE_PAGE_SIZE)))
	_skill_page = clampi(_skill_page, 0, page_count - 1)
	var start := _skill_page * TECHNIQUE_PAGE_SIZE
	var finish := mini(filtered.size(), start + TECHNIQUE_PAGE_SIZE)
	_skill_results_summary.text = "%d matching · page %d / %d" % [filtered.size(), _skill_page + 1, page_count]

	if not _selected_skill_id.is_empty() and not filtered.any(func(action: Dictionary) -> bool: return String(action.get("id", "")) == _selected_skill_id):
		_selected_skill_id = ""
	if _selected_skill_id.is_empty() and not filtered.is_empty():
		_selected_skill_id = String(filtered[0].get("id", ""))

	_clear_skill_list()
	if filtered.is_empty():
		_skill_list.add_child(_label("No techniques match the current filters.", 10, UI.MUTED))
	else:
		for action: Dictionary in filtered.slice(start, finish):
			_skill_list.add_child(_skill_result_button(action, value))
		if page_count > 1:
			var pager := HBoxContainer.new()
			pager.alignment = BoxContainer.ALIGNMENT_CENTER
			pager.add_theme_constant_override("separation", 8)
			var previous := _action("← PREVIOUS", _change_skill_page.bind(-1), UI.MUTED, 34)
			previous.disabled = _skill_page <= 0
			pager.add_child(previous)
			var page_label := _label("%d / %d" % [_skill_page + 1, page_count], 10, UI.SUBTLE, true)
			page_label.custom_minimum_size.x = 60
			page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pager.add_child(page_label)
			var next := _action("NEXT →", _change_skill_page.bind(1), UI.MUTED, 34)
			next.disabled = _skill_page >= page_count - 1
			pager.add_child(next)
			_skill_list.add_child(pager)
	_refresh_skill_details()
	_refresh_form_learnset()


func _filtered_skills(value: DigimonInstance) -> Array[Dictionary]:
	var query := _skill_search.text.strip_edges().to_lower()
	var role_filter := _skill_role_filter.get_item_text(_skill_role_filter.selected).to_lower()
	var element_filter := _skill_element_filter.get_item_text(_skill_element_filter.selected).to_lower()
	var state_filter := _skill_state_filter.get_item_text(_skill_state_filter.selected).to_lower()
	var availability_filter := _skill_availability_filter.get_item_text(_skill_availability_filter.selected).to_lower()
	var result: Array[Dictionary] = []
	for action: Dictionary in _skill_catalog:
		var skill_id := String(action.get("id", ""))
		var name := String(action.get("name", skill_id))
		var haystack := "%s %s %s" % [name, skill_id, String(action.get("namePtBr", ""))]
		if not query.is_empty() and not haystack.to_lower().contains(query):
			continue
		var role := String(action.get("category", action.get("tacticalRole", ""))).to_lower()
		if role_filter != "all roles" and role != role_filter:
			continue
		var element := String(action.get("element", "neutral")).to_lower()
		if element_filter != "all elements" and element != element_filter:
			continue
		var learned := value.learned_skills.has(skill_id)
		match state_filter:
			"learned":
				if not learned: continue
			"unlearned":
				if learned: continue
			"favorites":
				if not value.favorite_skills.has(skill_id): continue
			"archived":
				if not value.archived_skills.has(skill_id): continue
		var availability := String(action.get("availability", "ready"))
		if availability_filter == "ready" and availability != "ready":
			continue
		if availability_filter == "locked mechanic" and availability == "ready":
			continue
		result.append(action)
	return result


func _skill_result_button(action: Dictionary, value: DigimonInstance) -> Button:
	var skill_id := String(action.get("id", ""))
	var learned := value.learned_skills.has(skill_id)
	var favorite := value.favorite_skills.has(skill_id)
	var archived := value.archived_skills.has(skill_id)
	var available := String(action.get("availability", "ready")) == "ready"
	var state := "UNLEARNED"
	if archived:
		state = "ARCHIVED"
	elif favorite:
		state = "FAVORITE"
	elif learned:
		state = value.get_skill_mastery_grade(skill_id).to_upper()
	var area = action.get("area", {})
	var shape := String((area as Dictionary).get("shape", "single")).to_upper() if area is Dictionary else "SINGLE"
	var role := String(action.get("category", action.get("tacticalRole", "unknown"))).to_upper()
	var lock_text := "" if available else " · LOCKED"
	var button := Button.new()
	button.text = "%s   ·   %s · %s · %d SP · %s · %s%s" % [
		String(action.get("name", skill_id)), String(action.get("element", "neutral")).to_upper(), role,
		int(action.get("spCost", 0)), shape, state, lock_text
	]
	button.tooltip_text = "%s\n%s" % [skill_id, String(action.get("description", ""))]
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.clip_text = true
	button.focus_mode = Control.FOCUS_ALL
	var accent := UI.MUTED if not available else (UI.GOLD if favorite else (UI.PURPLE if archived else (UI.GREEN if learned else UI.CYAN)))
	_style_button(button, accent, skill_id == _selected_skill_id)
	button.pressed.connect(_select_skill.bind(skill_id))
	button.focus_entered.connect(_select_skill.bind(skill_id))
	return button


func _clear_skill_list() -> void:
	for child in _skill_list.get_children():
		_skill_list.remove_child(child)
		child.queue_free()


func _select_skill(skill_id: String) -> void:
	if skill_id == _selected_skill_id:
		_refresh_skill_details()
		return
	_selected_skill_id = skill_id
	_refresh_skill_lab()


func _change_skill_page(delta: int) -> void:
	_skill_page += delta
	_refresh_skill_lab()
	call_deferred("_focus_selected_skill")


func _focus_selected_skill() -> void:
	if _skill_list == null:
		return
	for child in _skill_list.get_children():
		if child is Button and String((child as Button).tooltip_text).begins_with(_selected_skill_id):
			(child as Button).grab_focus()
			return
	for child in _skill_list.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return


func _refresh_skill_details() -> void:
	if _skill_details == null:
		return
	var value := _selected_instance()
	var action := _techniques.action(_selected_skill_id, _selected_id) if _techniques != null and not _selected_skill_id.is_empty() else {}
	if value == null or action.is_empty():
		_skill_details.text = "Select a technique from the catalog."
		_set_skill_controls_enabled(false)
		return
	var skill_id := String(action.get("id", _selected_skill_id))
	var learned := value.learned_skills.has(skill_id)
	var favorite := value.favorite_skills.has(skill_id)
	var archived := value.archived_skills.has(skill_id)
	var area = action.get("area", {})
	var shape := String((area as Dictionary).get("shape", "single")).capitalize() if area is Dictionary else "Single"
	var range_data = action.get("range", {})
	var max_range := int((range_data as Dictionary).get("max", 0)) if range_data is Dictionary else 0
	var availability := String(action.get("availability", "ready"))
	var learned_state := "UNLEARNED"
	if learned:
		learned_state = "%s · %d/%d mastery" % [value.get_skill_mastery_grade(skill_id).to_upper(), value.get_skill_mastery_points(skill_id), DigimonInstance.MAX_SKILL_MASTERY_POINTS]
		if favorite: learned_state += " · FAVORITE"
		if archived: learned_state += " · ARCHIVED"
	_skill_details.text = "%s\n%s\n%s · %s · %d SP · Range %d · %s · Recovery %d · Accuracy %d%%\nMastery profile: %s · Availability: %s\nState on %s: %s\n%s" % [
		String(action.get("name", skill_id)).to_upper(), skill_id,
		String(action.get("element", "neutral")).capitalize(), String(action.get("category", action.get("tacticalRole", "unknown"))).capitalize(),
		int(action.get("spCost", 0)), max_range, shape, int(round(float(action.get("recoveryCost", 0.0)))), int(round(float(action.get("accuracy", 100.0)))),
		String(action.get("masteryProfile", "swift")).replace("_", " ").capitalize(), availability.replace("_", " ").capitalize(),
		_progression.display_name(value), learned_state, String(action.get("description", ""))
	]
	_skill_learn_button.text = "FORGET" if learned else "LEARN"
	_skill_learn_button.add_theme_color_override("font_color", UI.RED if learned else UI.TEXT)
	_skill_favorite_button.text = "UNFAVORITE" if favorite else "FAVORITE"
	_skill_archive_button.text = "RESTORE" if archived else "ARCHIVE"
	_skill_favorite_button.disabled = not learned
	_skill_archive_button.disabled = not learned
	_skill_mastery.editable = learned
	_skill_mastery.value = value.get_skill_mastery_points(skill_id) if learned else 0
	_skill_mastery_apply.disabled = not learned


func _set_skill_controls_enabled(enabled: bool) -> void:
	if _skill_learn_button != null: _skill_learn_button.disabled = not enabled
	if _skill_favorite_button != null: _skill_favorite_button.disabled = not enabled
	if _skill_archive_button != null: _skill_archive_button.disabled = not enabled
	if _skill_mastery != null: _skill_mastery.editable = enabled
	if _skill_mastery_apply != null: _skill_mastery_apply.disabled = not enabled


func _refresh_form_learnset() -> void:
	if _skill_form_learnset == null or _techniques == null:
		return
	var value := _selected_instance()
	if value == null:
		_skill_form_learnset.text = "No Digimon selected."
		return
	var entries := _techniques.current_form_learnset(value.id)
	if entries.is_empty():
		_skill_form_learnset.text = "No learnset entries for the current form."
		return
	var lines: Array[String] = []
	for entry: Dictionary in entries:
		var mark := "LEARNED" if bool(entry.get("learned", false)) else "NOT LEARNED"
		lines.append("%s · Lv.%d · %s · %s" % [String(entry.get("name", entry.get("skill", "Technique"))), int(entry.get("level", 1)), String(entry.get("acquisition", "level")).to_upper(), mark])
	_skill_form_learnset.text = "\n".join(lines)


func _toggle_selected_skill_learned() -> void:
	var value := _selected_instance()
	if value == null or _selected_skill_id.is_empty():
		return
	var was_learned := value.learned_skills.has(_selected_skill_id)
	var changed := _techniques.forget(value.id, _selected_skill_id) if was_learned else _techniques.learn(value.id, _selected_skill_id, false)
	if changed:
		var action := _techniques.action(_selected_skill_id, value.id)
		var name := String(action.get("name", _selected_skill_id))
		_status.text = "%s %s %s." % [_progression.display_name(value), "forgot" if was_learned else "learned", name]
		_state.log_action("Forget technique" if was_learned else "Learn technique", "%s · %s" % [_progression.display_name(value), name])
	_refresh_skill_lab()


func _toggle_selected_skill_favorite() -> void:
	var value := _selected_instance()
	if value == null or not value.learned_skills.has(_selected_skill_id):
		return
	var enabling := not value.favorite_skills.has(_selected_skill_id)
	var changed := _techniques.set_favorite(value.id, _selected_skill_id, enabling)
	if not changed and enabling and value.favorite_skills.size() >= DigimonInstance.MAX_FAVORITE_SKILLS:
		_status.text = "Favorite limit reached (%d)." % DigimonInstance.MAX_FAVORITE_SKILLS
	elif changed:
		_status.text = "%s %s favorite." % [_selected_name(), "added to" if enabling else "removed from"]
		_state.log_action("Favorite technique", "%s · %s · %s" % [_selected_name(), _selected_skill_id, "on" if enabling else "off"])
	_refresh_skill_lab()


func _toggle_selected_skill_archived() -> void:
	var value := _selected_instance()
	if value == null or not value.learned_skills.has(_selected_skill_id):
		return
	var enabling := not value.archived_skills.has(_selected_skill_id)
	if _techniques.set_archived(value.id, _selected_skill_id, enabling):
		_status.text = "%s %s technique %s." % [_selected_name(), "archived" if enabling else "restored", _selected_skill_id]
		_state.log_action("Archive technique", "%s · %s · %s" % [_selected_name(), _selected_skill_id, "on" if enabling else "off"])
	_refresh_skill_lab()


func _apply_selected_skill_mastery() -> void:
	_set_selected_skill_mastery(int(_skill_mastery.value))


func _set_selected_skill_mastery(points: int) -> void:
	var value := _selected_instance()
	if value == null or not value.learned_skills.has(_selected_skill_id):
		return
	if _techniques.set_mastery(value.id, _selected_skill_id, points):
		_status.text = "%s mastery set to %d/%d." % [_selected_skill_id, clampi(points, 0, DigimonInstance.MAX_SKILL_MASTERY_POINTS), DigimonInstance.MAX_SKILL_MASTERY_POINTS]
		_state.log_action("Set technique mastery", "%s · %s · %d" % [_selected_name(), _selected_skill_id, points])
	_refresh_skill_lab()
