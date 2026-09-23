extends Control
class_name CombatOverlayHUD

const UI = preload("res://src/ui/TacticalTheme.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const TECHNIQUE_PAGE_SIZE := 40

var _controller: Node = null
var _skill_panel: Panel = null
var _skill_filter_panel: Panel = null
var _skill_filter_grid: GridContainer = null
var _skill_filter_caption: Label = null
var _skill_count: Label = null
var _skill_scroll: ScrollContainer = null
var _skill_list: VBoxContainer = null
var _skill_view: OptionButton = null
var _skill_role: OptionButton = null
var _skill_element: OptionButton = null
var _skill_pattern: OptionButton = null
var _skill_sort: OptionButton = null
var _skill_affordable: CheckButton = null
var _skill_archived: CheckButton = null
var _skill_reset: Button = null
var _skill_filter_controls: Array[Control] = []
var _skill_entry_buttons: Array[Button] = []
var _preview_panel: Panel = null
var _preview_title: Label = null
var _preview_target: Label = null
var _preview_damage: Label = null
var _preview_meta: Label = null
var _preview_matchup: Label = null
var _result_panel: Panel = null
var _result_title: Label = null
var _result_body: Label = null
var _result_return: Button = null
var _toast: Label = null
var _toast_tween: Tween = null
var _skill_panel_tween: Tween = null
var _skill_page := 0
var _previous_focus: Control = null
var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	set_process(true)
	call_deferred("_layout")


func setup(controller: Node) -> void:
	_controller = controller
	if _controller != null and _controller.has_signal("combat_event"):
		_controller.connect("combat_event", _on_combat_event)
	refresh()


func _process(_delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := DisplayServer.window_get_size()
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		_layout()


# Horizontal input from an actual technique card returns to the parent Skill
# command. Filter controls and page controls keep their horizontal input so
# keyboard/controller users can operate the complete menu instead of having the
# overlay close underneath them.
func _input(event: InputEvent) -> void:
	if not _skill_panel.visible:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var owner := get_viewport().gui_get_focus_owner()
		if _is_technique_entry_focus(owner):
			hide_skills()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _skill_panel.visible:
		return
	# Keep cancel here rather than in _input(). Popups (especially OptionButton)
	# get the first chance to consume B/Escape and close themselves cleanly.
	if event.is_action_pressed("ui_cancel"):
		hide_skills()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var owner := get_viewport().gui_get_focus_owner()
		if not _is_skill_focus(owner):
			_focus_first_skill()
			get_viewport().set_input_as_handled()


func toggle_skills() -> void:
	if _skill_panel.visible:
		hide_skills()
	else:
		show_skills()


func show_skills() -> void:
	if _controller == null or not _controller.has_method("get_available_skills"):
		return

	# Techniques is a child of the Skill command, so keyboard/controller users
	# should always return to Skill when leaving it, even if it was opened by the
	# numeric shortcut while another command happened to own focus.
	var parent_focus := _skill_parent_focus()
	_previous_focus = parent_focus if parent_focus != null else get_viewport().gui_get_focus_owner()
	_skill_page = 0
	var available: Array[Dictionary] = _controller.call("get_available_skills")
	if _skill_view.selected == 0 and not available.any(func(action: Dictionary): return bool(action.get("favorite", false))):
		_skill_view.select(1)
	_rebuild_skill_list()
	_skill_panel.visible = not available.is_empty()
	_layout()
	if _skill_panel.visible:
		_animate_skill_panel_in()
		# Grab focus immediately and again after the frame. The second pass covers
		# Godot layout/focus reconciliation after rebuilding dynamic children.
		_focus_first_skill()
		call_deferred("_focus_first_skill")


func hide_skills(restore_parent_focus: bool = true) -> void:
	if _skill_panel_tween != null and _skill_panel_tween.is_valid():
		_skill_panel_tween.kill()
	_skill_panel.visible = false
	_skill_panel.modulate.a = 1.0
	if _controller != null and _controller.has_method("clear_action_recovery_preview"):
		_controller.call("clear_action_recovery_preview")
	if restore_parent_focus and _previous_focus != null and is_instance_valid(_previous_focus) and _previous_focus.visible:
		_previous_focus.grab_focus()
	_previous_focus = null


func refresh() -> void:
	if _controller == null or not _controller.has_method("get_hud_state"):
		return
	var state: Dictionary = _controller.call("get_hud_state")
	if bool(state.get("battle_over", false)):
		_show_result(state.get("battle_result", {}) as Dictionary)
	else:
		_result_panel.visible = false
	var preview: Dictionary = _controller.call("get_combat_preview") if _controller.has_method("get_combat_preview") else {}
	_refresh_preview(preview)
	if not bool(state.get("can_skill", false)) and not bool(state.get("is_targeting", false)) and _skill_panel.visible:
		hide_skills(false)
	_layout()


func _build_ui() -> void:
	_skill_panel = Panel.new()
	_skill_panel.name = "TechniqueMenu"
	_skill_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_panel.visible = false
	_skill_panel.z_index = 20
	_skill_panel.clip_contents = true
	_skill_panel.add_theme_stylebox_override("panel", UI.glass_panel(UI.GOLD, 0.92, 8))
	add_child(_skill_panel)

	var skill_title := Label.new()
	skill_title.name = "Title"
	skill_title.text = "TECHNIQUES"
	skill_title.add_theme_color_override("font_color", UI.GOLD)
	UI.apply_heading_font(skill_title)
	_skill_panel.add_child(skill_title)

	var skill_hint := Label.new()
	skill_hint.name = "Hint"
	skill_hint.text = "D-pad / Arrows Navigate   •   A / Enter Select   •   B / Esc Back   •   Tap / Click supported"
	skill_hint.add_theme_color_override("font_color", UI.SUBTLE)
	skill_hint.clip_text = true
	UI.apply_body_font(skill_hint)
	_skill_panel.add_child(skill_hint)

	_skill_filter_panel = Panel.new()
	_skill_filter_panel.name = "FilterPanel"
	_skill_filter_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_filter_panel.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.54, 0.30, 6))
	_skill_panel.add_child(_skill_filter_panel)

	_skill_filter_caption = _label("FILTER & SORT", 10, UI.CYAN)
	UI.apply_heading_font(_skill_filter_caption)
	_skill_filter_panel.add_child(_skill_filter_caption)
	_skill_count = _label("", 10, UI.SUBTLE)
	_skill_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skill_filter_panel.add_child(_skill_count)

	_skill_filter_grid = GridContainer.new()
	_skill_filter_grid.name = "FilterGrid"
	_skill_filter_grid.columns = 4
	_skill_filter_grid.add_theme_constant_override("h_separation", 6)
	_skill_filter_grid.add_theme_constant_override("v_separation", 6)
	_skill_filter_panel.add_child(_skill_filter_grid)

	_skill_view = _filter_option(["Favorites", "All Techniques"])
	_skill_role = _filter_option(["All Roles", "Damage", "Healing", "Support", "Control", "Mobility"])
	_skill_element = _filter_option(["All Elements", "Neutral", "Fire", "Plant", "Water", "Electric", "Wind", "Earth", "Light", "Dark"])
	_skill_pattern = _filter_option(["All Patterns", "Single", "Line", "Cone", "Cross", "Diamond", "Ring", "Self"])
	_skill_sort = _filter_option(["Default", "Recent", "Name", "SP Cost"])
	_skill_affordable = CheckButton.new()
	_skill_affordable.text = "Affordable"
	_skill_affordable.focus_mode = Control.FOCUS_ALL
	_skill_archived = CheckButton.new()
	_skill_archived.text = "Show archived"
	_skill_archived.focus_mode = Control.FOCUS_ALL
	_style_filter_toggle(_skill_affordable)
	_style_filter_toggle(_skill_archived)
	_skill_reset = Button.new()
	_skill_reset.text = "RESET"
	_skill_reset.focus_mode = Control.FOCUS_ALL
	_style_filter_button(_skill_reset, UI.MUTED)

	_skill_filter_controls = [
		_skill_view,
		_skill_role,
		_skill_element,
		_skill_pattern,
		_skill_sort,
		_skill_affordable,
		_skill_archived,
		_skill_reset,
	]
	for control: Control in _skill_filter_controls:
		control.custom_minimum_size = Vector2(0.0, 38.0)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_skill_filter_grid.add_child(control)

	_skill_view.item_selected.connect(func(_index: int): _reset_skill_page())
	_skill_role.item_selected.connect(func(_index: int): _reset_skill_page())
	_skill_element.item_selected.connect(func(_index: int): _reset_skill_page())
	_skill_pattern.item_selected.connect(func(_index: int): _reset_skill_page())
	_skill_sort.item_selected.connect(func(_index: int): _reset_skill_page())
	_skill_affordable.toggled.connect(func(_pressed: bool): _reset_skill_page())
	_skill_archived.toggled.connect(func(_pressed: bool): _reset_skill_page())
	_skill_reset.pressed.connect(_reset_skill_filters)

	_skill_scroll = ScrollContainer.new()
	_skill_scroll.name = "TechniqueScroll"
	_skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_skill_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_skill_scroll.follow_focus = true
	_skill_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_panel.add_child(_skill_scroll)
	SmoothScrollScript.attach(_skill_scroll)

	_skill_list = VBoxContainer.new()
	_skill_list.name = "List"
	_skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_list.add_theme_constant_override("separation", 6)
	_skill_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_scroll.add_child(_skill_list)

	_preview_panel = Panel.new()
	_preview_panel.name = "ActionPreview"
	_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_panel.visible = false
	_preview_panel.add_theme_stylebox_override("panel", UI.glass_panel(UI.GOLD, 0.78, 7))
	add_child(_preview_panel)
	_preview_title = _label("Preview", 14, UI.GOLD)
	_preview_target = _label("", 18, UI.TEXT)
	_preview_damage = _label("", 20, Color.WHITE)
	_preview_meta = _label("", 13, UI.MUTED)
	_preview_matchup = _label("", 13, UI.GOLD)
	for label: Label in [_preview_title, _preview_target, _preview_damage, _preview_meta, _preview_matchup]:
		_preview_panel.add_child(label)

	_result_panel = Panel.new()
	_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_panel.visible = false
	_result_panel.add_theme_stylebox_override("panel", UI.panel_strong(UI.GOLD, 10))
	add_child(_result_panel)
	_result_title = _label("Victory", 30, UI.GOLD)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body = _label("", 16, UI.TEXT)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_return = Button.new()
	_result_return.name = "ReturnToHub"
	_result_return.text = "RETURN TO TERMINAL COMMONS"
	_result_return.focus_mode = Control.FOCUS_ALL
	_result_return.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_result_return.add_theme_font_size_override("font_size", 14)
	_result_return.add_theme_color_override("font_color", UI.TEXT)
	_result_return.add_theme_color_override("font_hover_color", Color.WHITE)
	_result_return.add_theme_color_override("font_focus_color", Color.WHITE)
	_result_return.add_theme_stylebox_override("normal", UI.action_style(UI.GOLD, "normal"))
	_result_return.add_theme_stylebox_override("hover", UI.action_style(UI.GOLD, "hover"))
	_result_return.add_theme_stylebox_override("pressed", UI.action_style(UI.GOLD, "pressed"))
	_result_return.add_theme_stylebox_override("focus", UI.focus_outline(UI.GOLD, 8))
	_result_return.pressed.connect(_return_to_hub)
	_result_panel.add_child(_result_title)
	_result_panel.add_child(_result_body)
	_result_panel.add_child(_result_return)

	_toast = _label("", 18, Color.WHITE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.clip_text = false
	_toast.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.05, 0.94))
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.visible = false
	add_child(_toast)


func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	UI.apply_body_font(label)
	return label


func _filter_option(labels: Array[String]) -> OptionButton:
	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_ALL
	option.fit_to_longest_item = false
	option.clip_text = true
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for label_text: String in labels:
		option.add_item(label_text)
	_style_filter_button(option, UI.CYAN)
	return option


func _style_filter_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_stylebox_override("focus", UI.focus_outline(accent, 6))
	UI.apply_body_font(button)


func _style_filter_toggle(toggle: CheckButton) -> void:
	toggle.add_theme_font_size_override("font_size", 11)
	toggle.add_theme_color_override("font_color", UI.TEXT)
	toggle.add_theme_color_override("font_hover_color", Color.WHITE)
	toggle.add_theme_color_override("font_pressed_color", Color.WHITE)
	toggle.add_theme_color_override("font_focus_color", Color.WHITE)
	toggle.add_theme_stylebox_override("normal", UI.action_style(UI.CYAN, "normal"))
	toggle.add_theme_stylebox_override("hover", UI.action_style(UI.CYAN, "hover"))
	toggle.add_theme_stylebox_override("pressed", UI.action_style(UI.CYAN, "pressed"))
	toggle.add_theme_stylebox_override("focus", UI.focus_outline(UI.CYAN, 6))
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UI.apply_body_font(toggle)


func _reset_skill_filters() -> void:
	_skill_view.select(0)
	_skill_role.select(0)
	_skill_element.select(0)
	_skill_pattern.select(0)
	_skill_sort.select(0)
	_skill_affordable.button_pressed = false
	_skill_archived.button_pressed = false
	_skill_page = 0
	_rebuild_skill_list()
	_skill_view.grab_focus()


func _reset_skill_page() -> void:
	_skill_page = 0
	_rebuild_skill_list()


func _rebuild_skill_list() -> void:
	# Remove stale buttons from the container immediately. queue_free() alone
	# keeps them in get_children() until the frame ends, which could make the old
	# first button steal focus just as the rebuilt submenu opened.
	for child in _skill_list.get_children():
		_skill_list.remove_child(child)
		child.queue_free()
	_skill_entry_buttons.clear()

	var actions: Array[Dictionary] = _controller.call("get_available_skills")
	match _skill_sort.selected:
		1: actions.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("recentIndex", 999999)) < int(b.get("recentIndex", 999999)))
		2: actions.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.get("name", "")) < String(b.get("name", "")))
		3: actions.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("spCost", 0)) < int(b.get("spCost", 0)))
	var filtered: Array[Dictionary] = []
	for action: Dictionary in actions:
		if _skill_view.selected == 0 and not bool(action.get("favorite", false)):
			continue
		if bool(action.get("archived", false)) and not _skill_archived.button_pressed:
			continue
		if _skill_affordable.button_pressed and not bool(action.get("affordable", false)):
			continue
		var selected_role := _skill_role.get_item_text(_skill_role.selected).to_lower()
		if selected_role != "all roles" and String(action.get("category", "")).to_lower() != selected_role:
			continue
		var selected_element := _skill_element.get_item_text(_skill_element.selected).to_lower()
		if selected_element != "all elements" and String(action.get("element", "neutral")).to_lower() != selected_element:
			continue
		var selected_pattern := _skill_pattern.get_item_text(_skill_pattern.selected).to_lower()
		var area_data = action.get("area", {})
		if selected_pattern != "all patterns" and (not area_data is Dictionary or String(area_data.get("shape", "single")).to_lower() != selected_pattern):
			continue
		filtered.append(action)

	_skill_count.text = "%d shown · %d known" % [filtered.size(), actions.size()]
	var page_count := maxi(1, ceili(float(filtered.size()) / float(TECHNIQUE_PAGE_SIZE)))
	_skill_page = clampi(_skill_page, 0, page_count - 1)
	var page_start := _skill_page * TECHNIQUE_PAGE_SIZE
	var page_end := mini(filtered.size(), page_start + TECHNIQUE_PAGE_SIZE)
	for action: Dictionary in filtered.slice(page_start, page_end):
		var button := _technique_button(action)
		_skill_list.add_child(button)
		_skill_entry_buttons.append(button)

	if filtered.is_empty():
		var empty := _label("No techniques match these filters.", 12, UI.MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0.0, 74.0)
		_skill_list.add_child(empty)

	if page_count > 1:
		var pager := HBoxContainer.new()
		pager.alignment = BoxContainer.ALIGNMENT_CENTER
		pager.add_theme_constant_override("separation", 8)
		var previous := _pager_button("← PREVIOUS")
		previous.disabled = _skill_page <= 0
		previous.pressed.connect(_change_skill_page.bind(-1))
		pager.add_child(previous)
		var page_label := _label("%d / %d" % [_skill_page + 1, page_count], 11, UI.MUTED)
		page_label.custom_minimum_size.x = 58
		page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pager.add_child(page_label)
		var next := _pager_button("NEXT →")
		next.disabled = _skill_page >= page_count - 1
		next.pressed.connect(_change_skill_page.bind(1))
		pager.add_child(next)
		_skill_list.add_child(pager)

	call_deferred("_layout")
	call_deferred("_wire_skill_focus_navigation")


func _technique_button(action: Dictionary) -> Button:
	var button := Button.new()
	var action_id := String(action.get("id", ""))
	var action_name := String(action.get("name", action_id))
	var sp_cost := int(action.get("spCost", 0))
	var recovery := int(round(float(action.get("recoveryCost", 30.0))))
	var range_data = action.get("range", {})
	var max_range := int(range_data.get("max", 0)) if range_data is Dictionary else 0
	var area_data = action.get("area", {})
	var mastery := String(action.get("masteryGrade", "learned")).capitalize()
	var element := String(action.get("element", "neutral")).capitalize()
	var area := String(area_data.get("shape", "single")).capitalize() if area_data is Dictionary else "Single"
	var affordable := bool(action.get("affordable", true))
	var available := bool(action.get("available", true))
	var usable := affordable and available

	button.name = "Technique_%s" % action_id.replace("-", "_").replace(" ", "_")
	button.text = ""
	button.clip_contents = true
	button.custom_minimum_size = Vector2(0.0, 68.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not usable
	button.tooltip_text = String(action.get("unavailableReason", "")) if not available else ("Not enough SP" if not affordable else action_name)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("technique_entry", true)
	button.set_meta("skill_id", action_id)
	button.add_theme_stylebox_override("normal", UI.action_style(UI.GOLD, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(UI.GOLD, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(UI.GOLD, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.action_style(UI.GOLD, "disabled"))
	button.add_theme_stylebox_override("focus", UI.focus_outline(UI.GOLD, 7))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(heading)
	var name_label := _label(action_name, 14, UI.TEXT if usable else UI.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI.apply_heading_font(name_label)
	heading.add_child(name_label)
	var cost_color := UI.CYAN if affordable and available else UI.RED
	var cost_label := _label("%d SP" % sp_cost, 11, cost_color)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.custom_minimum_size = Vector2(58.0, 24.0)
	cost_label.add_theme_stylebox_override("normal", UI.pill(cost_color, 0.08))
	heading.add_child(cost_label)

	var meta_parts: Array[String] = []
	if bool(action.get("favorite", false)):
		meta_parts.append("Favorite")
	if bool(action.get("archived", false)):
		meta_parts.append("Archived")
	meta_parts.append(element)
	meta_parts.append(area)
	meta_parts.append(mastery)
	meta_parts.append("Range %d" % max_range)
	meta_parts.append("Recovery %d" % recovery)
	var meta := _label("  •  ".join(meta_parts), 11, UI.MUTED if usable else UI.SUBTLE)
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(meta)

	button.pressed.connect(Callable(self, "_on_skill_pressed").bind(action_id))
	button.mouse_entered.connect(Callable(self, "_on_skill_hover").bind(action_id))
	button.mouse_exited.connect(_on_skill_hover_exit)
	button.focus_entered.connect(Callable(self, "_on_skill_hover").bind(action_id))
	button.focus_exited.connect(_on_skill_hover_exit)
	return button


func _pager_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(112.0, 42.0)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", UI.DISABLED)
	button.add_theme_stylebox_override("normal", UI.action_style(UI.CYAN, "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(UI.CYAN, "hover"))
	button.add_theme_stylebox_override("pressed", UI.action_style(UI.CYAN, "pressed"))
	button.add_theme_stylebox_override("disabled", UI.action_style(UI.CYAN, "disabled"))
	button.add_theme_stylebox_override("focus", UI.focus_outline(UI.CYAN, 6))
	UI.apply_body_font(button)
	return button


func _change_skill_page(delta: int) -> void:
	_skill_page += delta
	_rebuild_skill_list()
	_focus_first_skill()


func _enabled_skill_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button: Button in _skill_entry_buttons:
		if is_instance_valid(button) and button.visible and not button.disabled:
			result.append(button)
	return result


func _wire_skill_focus_navigation() -> void:
	if _skill_filter_grid == null:
		return
	var entries := _enabled_skill_buttons()
	var filter_count := _skill_filter_controls.size()
	if filter_count == 0:
		return

	# Deterministic Tab / shoulder-key order across filters and the actual
	# techniques. Spatial D-pad navigation remains native and follows the grid.
	var chain: Array[Control] = []
	for control: Control in _skill_filter_controls:
		if is_instance_valid(control) and control.visible:
			chain.append(control)
	for button: Button in entries:
		chain.append(button)
	if chain.size() > 1:
		for index in range(chain.size()):
			var current := chain[index]
			var next := chain[(index + 1) % chain.size()]
			var previous := chain[(index - 1 + chain.size()) % chain.size()]
			current.focus_next = current.get_path_to(next)
			current.focus_previous = current.get_path_to(previous)

	if entries.is_empty():
		return
	var first := entries[0]
	var columns := maxi(1, _skill_filter_grid.columns)
	var last_row_start := maxi(0, filter_count - columns)
	var top_target := _skill_filter_controls[last_row_start]
	first.focus_neighbor_top = first.get_path_to(top_target)
	for index in range(last_row_start, filter_count):
		var control := _skill_filter_controls[index]
		control.focus_neighbor_bottom = control.get_path_to(first)
	for index in range(entries.size()):
		var button := entries[index]
		if index > 0:
			button.focus_neighbor_top = button.get_path_to(entries[index - 1])
		if index < entries.size() - 1:
			button.focus_neighbor_bottom = button.get_path_to(entries[index + 1])


func _focus_first_skill() -> void:
	if not _skill_panel.visible:
		return
	var entries := _enabled_skill_buttons()
	if not entries.is_empty():
		entries[0].grab_focus()
		return
	if _skill_view != null and _skill_view.visible:
		_skill_view.grab_focus()


func _is_skill_focus(owner: Control) -> bool:
	return owner != null and _skill_panel != null and _skill_panel.is_ancestor_of(owner)


func _is_technique_entry_focus(owner: Control) -> bool:
	return owner is Button and bool(owner.get_meta("technique_entry", false))


func _skill_parent_focus() -> Control:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("CommandRail/PrimaryActions/SkillAction") as Control


func _animate_skill_panel_in() -> void:
	if _skill_panel_tween != null and _skill_panel_tween.is_valid():
		_skill_panel_tween.kill()
	_skill_panel.pivot_offset = _skill_panel.size * 0.5
	var target_scale := _skill_panel.scale
	_skill_panel.modulate.a = 0.0
	_skill_panel.scale = target_scale * 0.985
	_skill_panel_tween = create_tween().set_parallel(true)
	_skill_panel_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_skill_panel_tween.tween_property(_skill_panel, "modulate:a", 1.0, 0.14)
	_skill_panel_tween.tween_property(_skill_panel, "scale", target_scale, 0.14)


func _on_skill_pressed(skill_id: String) -> void:
	# Do not bounce focus back to Skill while transitioning from the submenu to
	# battlefield targeting; the battle navigation layer takes over immediately.
	hide_skills(false)
	if _controller != null and _controller.has_method("begin_skill"):
		_controller.call("begin_skill", skill_id)


func _on_skill_hover(skill_id: String) -> void:
	if _controller != null and _controller.has_method("preview_skill_recovery"):
		_controller.call("preview_skill_recovery", skill_id)


func _on_skill_hover_exit() -> void:
	if _controller != null and _controller.has_method("clear_action_recovery_preview"):
		_controller.call("clear_action_recovery_preview")


func _refresh_preview(preview: Dictionary) -> void:
	if preview.is_empty() or not bool(preview.get("valid", false)):
		_preview_panel.visible = false
		return
	_preview_panel.visible = true
	var action_name := String(preview.get("action_name", "Action"))
	_preview_title.text = "%s   •   %s" % [action_name, "Locked" if bool(preview.get("locked", false)) else "Preview"]
	_preview_target.text = String(preview.get("target_name", "Target"))
	var damage := int(preview.get("damage", 0))
	if damage > 0:
		_preview_damage.text = "%d damage   •   HP %d → %d" % [damage, int(preview.get("target_hp", 0)), int(preview.get("target_hp_after", 0))]
	else:
		_preview_damage.text = "Support action"
	_preview_meta.text = "%d%% hit   •   %d%% crit   •   %d SP   •   Rec %d" % [
		int(round(float(preview.get("hit_chance", 100.0)))),
		int(round(float(preview.get("crit_chance", 0.0)))),
		int(preview.get("sp_cost", 0)),
		int(round(float(preview.get("turn_recovery", 0.0)))),
	]
	var type_mod := float(preview.get("type_modifier", 1.0))
	var element_mod := float(preview.get("element_modifier", 1.0))
	var modifier := type_mod * element_mod
	var matchup := "Neutral"
	if modifier > 1.05:
		matchup = "Effective ×%.2f" % modifier
		_preview_matchup.add_theme_color_override("font_color", UI.GREEN)
	elif modifier < 0.95:
		matchup = "Resisted ×%.2f" % modifier
		_preview_matchup.add_theme_color_override("font_color", UI.RED)
	else:
		_preview_matchup.add_theme_color_override("font_color", UI.GOLD)
	_preview_matchup.text = "%s   •   %s" % [matchup, String(preview.get("element", "neutral")).capitalize()]


func _show_result(result: Dictionary) -> void:
	var result_was_hidden := not _result_panel.visible
	_result_panel.visible = true
	var victory := bool(result.get("victory", false))
	_result_title.text = "Victory" if victory else "Defeat"
	_result_title.add_theme_color_override("font_color", UI.GOLD if victory else UI.RED)
	var lines: Array[String] = []
	lines.append("Battle complete · %d turns" % int(result.get("acts", 0)))
	if victory:
		lines.append("Bits +%d" % int(result.get("bits", 0)))
		var digi_data = result.get("digi_data", {})
		if digi_data is Dictionary and not digi_data.is_empty():
			var rewards: Array[String] = []
			for species_name in digi_data.keys():
				rewards.append("%s +%d" % [String(species_name), int(digi_data[species_name])])
			lines.append("Digi Data · %s" % "   ".join(rewards))
	_result_body.text = "\n".join(lines)
	if result_was_hidden:
		call_deferred("_focus_result_return")


func _focus_result_return() -> void:
	if _result_return != null and _result_return.visible:
		_result_return.grab_focus()


func _return_to_hub() -> void:
	DigitalSceneTransition.return_to_world()


func _on_combat_event(event: Dictionary) -> void:
	var text := ""
	match String(event.get("type", "")):
		"damage_applied":
			text = "%s%d" % ["Critical  −" if bool(event.get("critical", false)) else "−", int(event.get("damage", 0))]
		"action_missed": text = "Miss"
		"status_applied": text = String(event.get("status", "Status")).replace("_", " ").capitalize()
		"unit_knocked_out": text = "%s  KO" % String(event.get("target_name", "Digimon"))
		"status_damage": text = "%s  −%d" % [String(event.get("status", "Status")).replace("_", " ").capitalize(), int(event.get("damage", 0))]
		"unit_switched":
			var incoming_name := String(event.get("incoming_name", "Digimon"))
			if bool(event.get("forced", false)):
				_show_toast("RESERVE DEPLOYED  ·  %s" % incoming_name, UI.CYAN, 0.70)
			else:
				var outgoing_name := String(event.get("outgoing_name", "Digimon"))
				_show_toast("SWITCH  ·  %s  →  %s\nTURN CONSUMED" % [outgoing_name, incoming_name], UI.GOLD, 0.90)
			return
	if text.is_empty():
		return
	_show_toast(text)


func _show_toast(text: String, color: Color = Color.WHITE, hold_seconds: float = 0.42) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_toast.position.y -= 5.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween().set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.70).set_delay(maxf(0.10, hold_seconds))
	_toast_tween.tween_property(_toast, "position:y", _toast.position.y - 12.0, 1.1)
	_toast_tween.chain().tween_callback(func(): _toast.visible = false)


func _layout() -> void:
	var viewport_obj := get_viewport()
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	_last_viewport_size = viewport_obj.get_visible_rect().size
	_last_window_size = DisplayServer.window_get_size()
	var compact := UI.is_compact(viewport_obj, 820.0)
	var portrait_mobile := compact and physical.y > physical.x
	var short_landscape := compact and physical.x > physical.y

	var skill_width := 520.0
	if portrait_mobile:
		skill_width = minf(physical.x - 20.0, 440.0)
	elif short_landscape:
		skill_width = minf(470.0, physical.x - 300.0)
	else:
		skill_width = minf(520.0, physical.x - 290.0)
	skill_width = maxf(300.0, skill_width)

	var filter_columns := 2 if portrait_mobile or skill_width < 440.0 else 4
	_skill_filter_grid.columns = filter_columns
	var filter_rows := ceili(float(_skill_filter_controls.size()) / float(filter_columns))
	var filter_height := 42.0 + float(filter_rows) * 38.0 + float(maxi(0, filter_rows - 1)) * 6.0
	var header_height := 56.0
	var list_content_height := clampf(float(maxi(1, _skill_list.get_child_count())) * 74.0, 86.0, 290.0)
	var desired_height := header_height + filter_height + 10.0 + list_content_height + 10.0

	var skill_x := 270.0
	var skill_y := 190.0
	if portrait_mobile:
		skill_x = (physical.x - skill_width) * 0.5
		skill_y = 228.0
	elif short_landscape:
		skill_x = minf(316.0, physical.x - skill_width - 8.0)
		skill_y = 54.0
	var max_height := maxf(230.0, physical.y - skill_y - 14.0)
	var skill_height := minf(desired_height, max_height)

	_skill_panel.scale = Vector2.ONE * ui_scale
	_skill_panel.position = Vector2(skill_x, skill_y) * ui_scale
	_skill_panel.size = Vector2(skill_width, skill_height)
	var skill_title := _skill_panel.get_node("Title") as Label
	skill_title.position = Vector2(14.0, 8.0)
	skill_title.size = Vector2(skill_width - 28.0, 22.0)
	skill_title.add_theme_font_size_override("font_size", 14 if compact else 15)
	var skill_hint := _skill_panel.get_node("Hint") as Label
	skill_hint.position = Vector2(14.0, 30.0)
	skill_hint.size = Vector2(skill_width - 28.0, 20.0)
	skill_hint.add_theme_font_size_override("font_size", 9 if compact else 10)

	_skill_filter_panel.position = Vector2(10.0, header_height)
	_skill_filter_panel.size = Vector2(skill_width - 20.0, filter_height)
	_skill_filter_caption.position = Vector2(10.0, 7.0)
	_skill_filter_caption.size = Vector2(150.0, 20.0)
	_skill_count.position = Vector2(skill_width - 236.0, 7.0)
	_skill_count.size = Vector2(206.0, 20.0)
	_skill_filter_grid.position = Vector2(8.0, 32.0)
	_skill_filter_grid.size = Vector2(skill_width - 36.0, filter_height - 40.0)
	for control: Control in _skill_filter_controls:
		control.custom_minimum_size.y = 38.0 if not portrait_mobile else 40.0
		control.add_theme_font_size_override("font_size", 10 if compact else 11)

	var scroll_top := header_height + filter_height + 8.0
	_skill_scroll.position = Vector2(10.0, scroll_top)
	_skill_scroll.size = Vector2(skill_width - 20.0, maxf(60.0, skill_height - scroll_top - 10.0))
	_skill_list.custom_minimum_size.x = skill_width - 36.0
	for button: Button in _skill_entry_buttons:
		if is_instance_valid(button):
			button.custom_minimum_size.y = 64.0 if compact else 68.0

	_wire_skill_focus_navigation()

	var preview_width := minf(430.0, physical.x - 20.0)
	var preview_height := 140.0
	_preview_panel.scale = Vector2.ONE * ui_scale
	if portrait_mobile:
		_preview_panel.position = Vector2((physical.x - preview_width) * 0.5 * ui_scale, maxf(205.0, physical.y - 344.0) * ui_scale)
	elif short_landscape:
		_preview_panel.position = Vector2(262.0 * ui_scale, maxf(58.0, physical.y - preview_height - 16.0) * ui_scale)
	else:
		_preview_panel.position = Vector2(276.0 * ui_scale, maxf(360.0, physical.y - preview_height - 28.0) * ui_scale)
	_preview_panel.size = Vector2(preview_width, preview_height)
	_preview_title.position = Vector2(14.0, 8.0)
	_preview_title.size = Vector2(preview_width - 28.0, 21.0)
	_preview_target.position = Vector2(14.0, 31.0)
	_preview_target.size = Vector2(preview_width - 28.0, 25.0)
	_preview_damage.position = Vector2(14.0, 57.0)
	_preview_damage.size = Vector2(preview_width - 28.0, 28.0)
	_preview_meta.position = Vector2(14.0, 88.0)
	_preview_meta.size = Vector2(preview_width - 28.0, 20.0)
	_preview_matchup.position = Vector2(14.0, 111.0)
	_preview_matchup.size = Vector2(preview_width - 28.0, 20.0)

	var result_width := minf(520.0, physical.x - 28.0)
	var result_height := 256.0
	_result_panel.scale = Vector2.ONE * ui_scale
	_result_panel.position = Vector2((physical.x - result_width) * 0.5 * ui_scale, (physical.y - result_height) * 0.5 * ui_scale)
	_result_panel.size = Vector2(result_width, result_height)
	_result_title.position = Vector2(18.0, 22.0)
	_result_title.size = Vector2(result_width - 36.0, 50.0)
	_result_body.position = Vector2(24.0, 74.0)
	_result_body.size = Vector2(result_width - 48.0, 90.0)
	_result_return.position = Vector2(74.0, 184.0)
	_result_return.size = Vector2(result_width - 148.0, 48.0)

	var toast_width := minf(520.0, physical.x - 40.0)
	_toast.scale = Vector2.ONE * ui_scale
	_toast.position = Vector2((physical.x - toast_width) * 0.5 * ui_scale, 88.0 * ui_scale)
	_toast.size = Vector2(toast_width, 58.0)
