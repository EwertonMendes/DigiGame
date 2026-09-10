extends Control
class_name CombatOverlayHUD

const UI = preload("res://src/ui/TacticalTheme.gd")

var _controller: Node = null
var _skill_panel: Panel = null
var _skill_list: VBoxContainer = null
var _preview_panel: Panel = null
var _preview_title: Label = null
var _preview_target: Label = null
var _preview_damage: Label = null
var _preview_meta: Label = null
var _preview_matchup: Label = null
var _result_panel: Panel = null
var _result_title: Label = null
var _result_body: Label = null
var _toast: Label = null
var _toast_tween: Tween = null
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


func toggle_skills() -> void:
	if _skill_panel.visible:
		hide_skills()
	else:
		show_skills()


func show_skills() -> void:
	if _controller == null or not _controller.has_method("get_available_skills"):
		return
	_rebuild_skill_list()
	_skill_panel.visible = _skill_list.get_child_count() > 0
	_layout()


func hide_skills() -> void:
	_skill_panel.visible = false
	if _controller != null and _controller.has_method("clear_action_recovery_preview"):
		_controller.call("clear_action_recovery_preview")


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
	if not bool(state.get("can_skill", false)) and not bool(state.get("is_targeting", false)):
		_skill_panel.visible = false
	_layout()


func _build_ui() -> void:
	_skill_panel = Panel.new()
	_skill_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_panel.visible = false
	_skill_panel.add_theme_stylebox_override("panel", UI.panel(UI.PURPLE, 0.97, 0.58, 12, 12))
	add_child(_skill_panel)

	var skill_title := Label.new()
	skill_title.name = "Title"
	skill_title.text = "TECHNIQUES"
	skill_title.add_theme_color_override("font_color", UI.PURPLE.lightened(0.28))
	UI.apply_heading_font(skill_title)
	_skill_panel.add_child(skill_title)

	_skill_list = VBoxContainer.new()
	_skill_list.name = "List"
	_skill_list.add_theme_constant_override("separation", 6)
	_skill_panel.add_child(_skill_list)

	_preview_panel = Panel.new()
	_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_panel.visible = false
	_preview_panel.add_theme_stylebox_override("panel", UI.panel(UI.GOLD, 0.97, 0.55, 12, 12))
	add_child(_preview_panel)
	_preview_title = _label("ACTION PREVIEW", 14, UI.GOLD)
	_preview_target = _label("", 20, UI.TEXT)
	_preview_damage = _label("", 24, Color.WHITE)
	_preview_meta = _label("", 13, UI.MUTED)
	_preview_matchup = _label("", 13, UI.CYAN)
	for label: Label in [_preview_title, _preview_target, _preview_damage, _preview_meta, _preview_matchup]:
		_preview_panel.add_child(label)

	_result_panel = Panel.new()
	_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_panel.visible = false
	_result_panel.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.985, 0.72, 14, 16))
	add_child(_result_panel)
	_result_title = _label("VICTORY", 34, UI.CYAN)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body = _label("", 16, UI.TEXT)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_panel.add_child(_result_title)
	_result_panel.add_child(_result_body)

	_toast = _label("", 18, Color.WHITE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.95))
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.visible = false
	add_child(_toast)


func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.apply_body_font(label)
	return label


func _rebuild_skill_list() -> void:
	for child in _skill_list.get_children():
		child.queue_free()
	var actions: Array[Dictionary] = _controller.call("get_available_skills")
	for action: Dictionary in actions:
		var button := Button.new()
		var action_id := String(action.get("id", ""))
		var action_name := String(action.get("name", action_id)).to_upper()
		var sp_cost := int(action.get("spCost", 0))
		var recovery := int(round(float(action.get("recoveryCost", 30.0))))
		var range_data = action.get("range", {})
		var max_range := int(range_data.get("max", 0)) if range_data is Dictionary else 0
		button.text = "%s    %d SP   R%d   REC %d" % [action_name, sp_cost, max_range, recovery]
		button.disabled = not bool(action.get("affordable", true))
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 14)
		UI.apply_heading_font(button)
		button.add_theme_color_override("font_color", UI.TEXT)
		button.add_theme_color_override("font_disabled_color", UI.MUTED.darkened(0.18))
		button.add_theme_stylebox_override("normal", UI.action_style(UI.PURPLE, "normal"))
		button.add_theme_stylebox_override("hover", UI.action_style(UI.PURPLE, "hover"))
		button.add_theme_stylebox_override("pressed", UI.action_style(UI.PURPLE, "pressed"))
		button.add_theme_stylebox_override("disabled", UI.action_style(UI.PURPLE, "disabled"))
		button.pressed.connect(Callable(self, "_on_skill_pressed").bind(action_id))
		button.mouse_entered.connect(Callable(self, "_on_skill_hover").bind(action_id))
		button.mouse_exited.connect(_on_skill_hover_exit)
		_skill_list.add_child(button)


func _on_skill_pressed(skill_id: String) -> void:
	hide_skills()
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
	_preview_title.text = "%s%s" % [String(preview.get("action_name", "ACTION")).to_upper(), "  •  LOCKED" if bool(preview.get("locked", false)) else "  •  PREVIEW"]
	_preview_target.text = String(preview.get("target_name", "TARGET")).to_upper()
	var damage := int(preview.get("damage", 0))
	if damage > 0:
		_preview_damage.text = "DMG  %d    HP %d → %d" % [damage, int(preview.get("target_hp", 0)), int(preview.get("target_hp_after", 0))]
	else:
		_preview_damage.text = "SUPPORT ACTION"
	_preview_meta.text = "HIT %d%%   •   CRIT %d%%   •   SP %d   •   TURN REC %d" % [
		int(round(float(preview.get("hit_chance", 100.0)))),
		int(round(float(preview.get("crit_chance", 0.0)))),
		int(preview.get("sp_cost", 0)),
		int(round(float(preview.get("turn_recovery", 0.0)))),
	]
	var type_mod := float(preview.get("type_modifier", 1.0))
	var element_mod := float(preview.get("element_modifier", 1.0))
	var matchup := "NEUTRAL"
	if type_mod * element_mod > 1.05:
		matchup = "EFFECTIVE  ×%.2f" % (type_mod * element_mod)
		_preview_matchup.add_theme_color_override("font_color", UI.GREEN)
	elif type_mod * element_mod < 0.95:
		matchup = "RESISTED  ×%.2f" % (type_mod * element_mod)
		_preview_matchup.add_theme_color_override("font_color", UI.RED.lightened(0.12))
	else:
		_preview_matchup.add_theme_color_override("font_color", UI.CYAN)
	_preview_matchup.text = "%s   •   %s" % [matchup, String(preview.get("element", "neutral")).to_upper()]


func _show_result(result: Dictionary) -> void:
	_result_panel.visible = true
	var victory := bool(result.get("victory", false))
	_result_title.text = "VICTORY" if victory else "DEFEAT"
	_result_title.add_theme_color_override("font_color", UI.CYAN if victory else UI.RED)
	var lines: Array[String] = []
	lines.append("BATTLE COMPLETE  •  %d ACTS" % int(result.get("acts", 0)))
	if victory:
		lines.append("BITS  +%d" % int(result.get("bits", 0)))
		var digi_data = result.get("digi_data", {})
		if digi_data is Dictionary and not digi_data.is_empty():
			var rewards: Array[String] = []
			for species_name in digi_data.keys():
				rewards.append("%s +%d" % [String(species_name).to_upper(), int(digi_data[species_name])])
			lines.append("DIGI DATA  •  %s" % "   ".join(rewards))
	_result_body.text = "\n".join(lines)


func _on_combat_event(event: Dictionary) -> void:
	var text := ""
	match String(event.get("type", "")):
		"damage_applied":
			text = "%s%d" % ["CRITICAL  -" if bool(event.get("critical", false)) else "-", int(event.get("damage", 0))]
		"action_missed": text = "MISS"
		"status_applied": text = String(event.get("status", "STATUS")).replace("_", " ").to_upper()
		"unit_knocked_out": text = "%s  KO" % String(event.get("target_name", "DIGIMON")).to_upper()
		"status_damage": text = "%s  -%d" % [String(event.get("status", "STATUS")).to_upper(), int(event.get("damage", 0))]
	if text.is_empty():
		return
	_show_toast(text)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_toast.position.y -= 5.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween().set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.75).set_delay(0.45)
	_toast_tween.tween_property(_toast, "position:y", _toast.position.y - 14.0, 1.2)
	_toast_tween.chain().tween_callback(func(): _toast.visible = false)


func _layout() -> void:
	var viewport_obj := get_viewport()
	var logical := viewport_obj.get_visible_rect().size
	var physical := UI.physical_window_size(viewport_obj)
	var ui_scale := UI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var compact := UI.is_compact(viewport_obj, 760.0)

	var skill_width := minf(430.0, physical.x - 24.0) if compact else 460.0
	var skill_height := minf(280.0, 64.0 + float(_skill_list.get_child_count()) * 48.0)
	_skill_panel.scale = Vector2.ONE * ui_scale
	_skill_panel.position = Vector2((physical.x - skill_width) * 0.5 * ui_scale, (physical.y - 138.0 - skill_height) * ui_scale)
	_skill_panel.size = Vector2(skill_width, skill_height)
	var skill_title := _skill_panel.get_node("Title") as Label
	skill_title.position = Vector2(14.0, 8.0)
	skill_title.size = Vector2(skill_width - 28.0, 28.0)
	skill_title.add_theme_font_size_override("font_size", 13 if compact else 15)
	_skill_list.position = Vector2(12.0, 40.0)
	_skill_list.size = Vector2(skill_width - 24.0, skill_height - 50.0)
	for child in _skill_list.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(0.0, 42.0 if compact else 46.0)
			child.add_theme_font_size_override("font_size", 12 if compact else 14)

	var preview_width := minf(430.0, physical.x - 24.0) if compact else 455.0
	var preview_height := 138.0 if compact else 150.0
	_preview_panel.scale = Vector2.ONE * ui_scale
	_preview_panel.position = Vector2((physical.x - preview_width) * 0.5 * ui_scale, (physical.y - 146.0 - preview_height) * ui_scale)
	_preview_panel.size = Vector2(preview_width, preview_height)
	_preview_title.position = Vector2(14.0, 8.0)
	_preview_title.size = Vector2(preview_width - 28.0, 20.0)
	_preview_target.position = Vector2(14.0, 30.0)
	_preview_target.size = Vector2(preview_width - 28.0, 28.0)
	_preview_damage.position = Vector2(14.0, 58.0)
	_preview_damage.size = Vector2(preview_width - 28.0, 30.0)
	_preview_meta.position = Vector2(14.0, 91.0)
	_preview_meta.size = Vector2(preview_width - 28.0, 20.0)
	_preview_matchup.position = Vector2(14.0, 114.0)
	_preview_matchup.size = Vector2(preview_width - 28.0, 20.0)
	_preview_title.add_theme_font_size_override("font_size", 12 if compact else 14)
	_preview_target.add_theme_font_size_override("font_size", 17 if compact else 20)
	_preview_damage.add_theme_font_size_override("font_size", 20 if compact else 24)
	_preview_meta.add_theme_font_size_override("font_size", 11 if compact else 13)
	_preview_matchup.add_theme_font_size_override("font_size", 11 if compact else 13)

	var result_width := minf(520.0, physical.x - 28.0)
	var result_height := 220.0
	_result_panel.scale = Vector2.ONE * ui_scale
	_result_panel.position = Vector2((physical.x - result_width) * 0.5 * ui_scale, (physical.y - result_height) * 0.5 * ui_scale)
	_result_panel.size = Vector2(result_width, result_height)
	_result_title.position = Vector2(18.0, 24.0)
	_result_title.size = Vector2(result_width - 36.0, 52.0)
	_result_body.position = Vector2(24.0, 78.0)
	_result_body.size = Vector2(result_width - 48.0, 112.0)

	_toast.scale = Vector2.ONE * ui_scale
	_toast.position = Vector2((physical.x - 320.0) * 0.5 * ui_scale, 112.0 * ui_scale)
	_toast.size = Vector2(320.0, 42.0)
