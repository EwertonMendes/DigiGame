extends Control
class_name HospitalScreen

signal close_requested

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")
const PortraitScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkScript = preload("res://src/ui/DigimonWalkPreview.gd")
const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")
const HintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const ConfirmationScript = preload("res://src/ui/components/DigiConfirmationModal.gd")
const TransitionSurfaceScript = preload("res://src/ui/components/DigiUiTransitionSurface.gd")
const BACKGROUND = preload("res://assets/ui/backgrounds/digi_hospital.png")
const BITS_ICON = preload("res://assets/ui/icons/bits.png")
const CLOSE_ICON = preload("res://assets/ui/icons/cancel.svg")
const ARROW_ICON = preload("res://assets/ui/icons/hp_change_arrow.svg")
const PAGE_SIZE := 3

enum InteractionMode {
	EXPLORE,
	ACTIONS,
}

var _database: DigimonDatabase
var _preview_id := ""
var _confirmed_id := ""
var _tab := "party"
var _page := 0
var _compact_detail := false
var _interaction_mode := InteractionMode.EXPLORE
var _pending_action := ""
var _notice := ""
var _notice_color := V2.CYAN
var _clock := 0.0
var _card_roster_signature := ""

var _canvas: Control
var _transition_surface: DigiUiTransitionSurface = null
var _close_lifecycle_managed := false
var _shade: ColorRect
var _header: Panel
var _footer: DigiInputHintBar
var _roster: Panel
var _hero: Panel
var _overview: Panel
var _tab_buttons: Dictionary = {}
var _cards: Dictionary = {}
var _card_order: Array[Button] = []
var _actions: Dictionary = {}
var _page_back: Button
var _page_next: Button
var _page_label: Label
var _bits_label: Label
var _hero_name: Label
var _hero_info: Label
var _hero_location: Label
var _hero_tier_icon: DigiTierIcon
var _hero_status: Label
var _hero_portrait: DigimonPortraitPreview
var _hero_notice: Label
var _health_before: Label
var _health_after: Label
var _health_arrow: TextureRect
var _health_missing: Label
var _health_bar: ProgressBar
var _sp_before: Label
var _sp_after: Label
var _sp_arrow: TextureRect
var _sp_progress: Label
var _sp_bar: ProgressBar
var _time_value: Label
var _cost_value: Label
var _confirmation: DigiConfirmationModal
var _close_button: Button
var _detail_back: Button
var _card_area: VBoxContainer
var _overview_stack: VBoxContainer
var _health_panel: PanelContainer
var _sp_panel: PanelContainer
var _recovery_meta_row: HBoxContainer
var _time_panel: PanelContainer
var _cost_panel: PanelContainer
var _overview_header: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	OverworldState.collection_changed.connect(_on_state_changed)
	OverworldState.account_rewards_changed.connect(_on_account_rewards_changed)
	OverworldState.hospital_state_changed.connect(_on_hospital_state_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	visible = false
	set_process(false)


func get_transition_surface() -> DigiUiTransitionSurface:
	return _transition_surface


func set_close_lifecycle_managed(value: bool) -> void:
	_close_lifecycle_managed = value


func open_screen() -> void:
	OverworldState.process_hospital_recoveries()
	visible = true
	set_process(true)
	_clock = 0.0
	_notice = ""
	_interaction_mode = InteractionMode.EXPLORE
	_confirmed_id = ""
	_compact_detail = false
	_ensure_preview()
	_refresh_structure(false)
	call_deferred("_focus_preview_card")


func _request_close() -> void:
	if _close_lifecycle_managed:
		close_requested.emit()
	else:
		close_view()


func finish_close() -> void:
	if _confirmation.visible:
		_confirmation.close_dialog(false)
	_pending_action = ""
	_interaction_mode = InteractionMode.EXPLORE
	_confirmed_id = ""
	_compact_detail = false
	visible = false
	set_process(false)


func close_view() -> void:
	# Preserve immediate programmatic close behavior; player input emits a request
	# so the Hub can run the reversible digital transition first.
	finish_close()
	close_requested.emit()


func is_open() -> bool:
	return visible


func is_action_mode_active() -> bool:
	return _interaction_mode == InteractionMode.ACTIONS


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.5:
		return
	_clock = 0.0
	OverworldState.process_hospital_recoveries()
	_refresh_live()


func _input(event: InputEvent) -> void:
	if not visible or _confirmation.visible:
		return

	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_switch_tab("party")
			get_viewport().set_input_as_handled()
			return
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_switch_tab("hospital")
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_switch_tab("hospital" if _tab == "party" else "party")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		if _interaction_mode == InteractionMode.ACTIONS:
			_exit_action_mode()
		else:
			_request_close()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		if _interaction_mode == InteractionMode.ACTIONS:
			_move_action_focus(-1)
		else:
			_move_preview(-1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		if _interaction_mode == InteractionMode.ACTIONS:
			_move_action_focus(1)
		else:
			_move_preview(1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		if _interaction_mode == InteractionMode.ACTIONS:
			_activate_focused_action()
		elif not _preview_id.is_empty():
			_confirm_instance(_preview_id)
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_transition_surface = TransitionSurfaceScript.new() as DigiUiTransitionSurface
	_transition_surface.name = "HospitalTransition"
	add_child(_transition_surface)

	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_surface.add_transition_child(background)

	_shade = ColorRect.new()
	_shade.color = Color(0.005, 0.019, 0.032, 0.36)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_surface.add_transition_child(_shade)

	_canvas = Control.new()
	_canvas.name = "HospitalCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_surface.add_transition_child(_canvas)

	_build_header()
	_build_roster()
	_build_hero()
	_build_overview()
	_build_footer()

	_confirmation = ConfirmationScript.new() as DigiConfirmationModal
	_confirmation.name = "HospitalConfirmation"
	_confirmation.confirmed.connect(_confirm_action)
	_confirmation.cancelled.connect(func(): _pending_action = "")
	add_child(_confirmation)


func _build_header() -> void:
	_header = _panel(_canvas, "HospitalHeader", V2.CYAN)
	_header.add_theme_stylebox_override("panel", V2.surface_style(Color(0.016, 0.037, 0.055, 0.94), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.40), 0))
	_icon(_header, "brand", V2.CYAN, Vector2(24, 12), Vector2(52, 52))
	_label(_header, "DIGI HOSPITAL", 30, V2.WHITE, true, Vector2(88, 12), Vector2(360, 38))
	_label(_header, "Recovery and Care", 16, V2.MUTED, false, Vector2(90, 49), Vector2(300, 25))

	var bits_badge := _panel(_header, "BitsBadge", V2.AMBER)
	bits_badge.set_meta("badge", true)
	var bits_icon := _texture(bits_badge, BITS_ICON, Color.WHITE, Vector2(13, 9), Vector2(30, 30))
	bits_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bits_label = _label(bits_badge, "0 BITS", 18, V2.WHITE, true, Vector2(49, 7), Vector2(105, 32))

	_close_button = _button(_header, "CloseHospital", "", V2.CYAN)
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.icon = CLOSE_ICON
	_close_button.expand_icon = true
	_close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_button.pressed.connect(_request_close)


func _build_roster() -> void:
	_roster = _panel(_canvas, "HospitalRoster", V2.CYAN)
	var margin := _full_margin(_roster, 10, 10, 10, 10)
	var stack := VBoxContainer.new()
	stack.name = "RosterStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 10)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)

	var tabs_row := HBoxContainer.new()
	tabs_row.name = "Tabs"
	tabs_row.custom_minimum_size.y = 56
	tabs_row.add_theme_constant_override("separation", 10)
	tabs_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(tabs_row)
	for tab_id in ["party", "hospital"]:
		var tab := _button(tabs_row, "Tab_%s" % tab_id, tab_id.to_upper(), V2.CYAN)
		tab.focus_mode = Control.FOCUS_NONE
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_switch_tab.bind(tab_id))
		_tab_buttons[tab_id] = tab

	_card_area = VBoxContainer.new()
	_card_area.name = "PatientCards"
	_card_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_area.add_theme_constant_override("separation", 9)
	_card_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_card_area)

	var pager := HBoxContainer.new()
	pager.name = "PatientPager"
	pager.custom_minimum_size.y = 43
	pager.add_theme_constant_override("separation", 10)
	pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(pager)
	_page_back = _button(pager, "PreviousPatients", "‹", V2.CYAN)
	_page_back.focus_mode = Control.FOCUS_NONE
	_page_back.custom_minimum_size = Vector2(52, 43)
	_page_back.pressed.connect(_turn_page.bind(-1))
	_page_label = _flow_label(pager, "", 16, V2.MUTED, true)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_next = _button(pager, "NextPatients", "›", V2.CYAN)
	_page_next.focus_mode = Control.FOCUS_NONE
	_page_next.custom_minimum_size = Vector2(52, 43)
	_page_next.pressed.connect(_turn_page.bind(1))


func _build_hero() -> void:
	_hero = _panel(_canvas, "HospitalPatient", V2.CYAN)
	var margin := _full_margin(_hero, 24, 18, 24, 14)
	var stack := VBoxContainer.new()
	stack.name = "PatientStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 7)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)

	_hero_name = _flow_label(stack, "", 34, V2.WHITE, true)
	_hero_name.custom_minimum_size.y = 44

	var meta := HBoxContainer.new()
	meta.name = "PatientMeta"
	meta.custom_minimum_size.y = 30
	meta.add_theme_constant_override("separation", 8)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(meta)
	_hero_info = _flow_label(meta, "", 18, V2.TEXT, false)
	_hero_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tier_caption := _flow_label(meta, "Tier", 16, V2.MUTED, true)
	tier_caption.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hero_tier_icon = TierIconScript.new() as DigiTierIcon
	_hero_tier_icon.name = "TierIcon"
	_hero_tier_icon.configure("E", Vector2(34, 24))
	_hero_tier_icon.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hero_tier_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_child(_hero_tier_icon)
	_hero_location = _flow_label(meta, "", 17, V2.TEXT, true)
	_hero_location.size_flags_horizontal = Control.SIZE_SHRINK_END

	_hero_status = _flow_label(stack, "", 15, V2.RED, true)
	_hero_status.custom_minimum_size = Vector2(0, 30)
	_hero_status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var portrait_slot := Control.new()
	portrait_slot.name = "PortraitSlot"
	portrait_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(portrait_slot)
	_hero_portrait = PortraitScript.new() as DigimonPortraitPreview
	_hero_portrait.name = "PatientPortrait"
	_hero_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_slot.add_child(_hero_portrait)

	_hero_notice = _flow_label(stack, "", 15, V2.CYAN, true)
	_hero_notice.custom_minimum_size.y = 38
	_hero_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_notice.max_lines_visible = 2


func _build_overview() -> void:
	_overview = _panel(_canvas, "TreatmentOverview", V2.CYAN)
	_overview.gui_input.connect(_on_overview_gui_input)
	var margin := _full_margin(_overview, 12, 11, 12, 11)
	_overview_stack = VBoxContainer.new()
	_overview_stack.name = "OverviewStack"
	_overview_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overview_stack.add_theme_constant_override("separation", 8)
	_overview_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_overview_stack)

	_overview_header = HBoxContainer.new()
	_overview_header.name = "OverviewHeader"
	_overview_header.custom_minimum_size.y = 34
	_overview_header.add_theme_constant_override("separation", 9)
	_overview_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview_stack.add_child(_overview_header)
	var heart := IconScript.new() as DigiProceduralIcon
	heart.custom_minimum_size = Vector2(25, 25)
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart.configure("heart", V2.CYAN)
	_overview_header.add_child(heart)
	var overview_title := _flow_label(_overview_header, "TREATMENT OVERVIEW", 19, V2.WHITE, true)
	overview_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_health_panel = _information_panel(_overview_stack, "HealthRecovery", V2.GREEN, 104)
	var hp_controls := _build_recovery_resource_content(_health_panel, "HP RECOVERY", "heart", V2.GREEN, "Hp")
	_health_before = hp_controls["before"] as Label
	_health_after = hp_controls["after"] as Label
	_health_arrow = hp_controls["arrow"] as TextureRect
	_health_bar = hp_controls["bar"] as ProgressBar
	_health_missing = hp_controls["progress"] as Label

	_sp_panel = _information_panel(_overview_stack, "SpRecovery", V2.BLUE, 104)
	var sp_controls := _build_recovery_resource_content(_sp_panel, "SP RECOVERY", "bolt", V2.BLUE, "Sp")
	_sp_before = sp_controls["before"] as Label
	_sp_after = sp_controls["after"] as Label
	_sp_arrow = sp_controls["arrow"] as TextureRect
	_sp_bar = sp_controls["bar"] as ProgressBar
	_sp_progress = sp_controls["progress"] as Label

	_recovery_meta_row = HBoxContainer.new()
	_recovery_meta_row.name = "RecoveryMetaRow"
	_recovery_meta_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recovery_meta_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_recovery_meta_row.add_theme_constant_override("separation", 8)
	_recovery_meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview_stack.add_child(_recovery_meta_row)

	_time_panel = _information_panel(_recovery_meta_row, "RecoveryTime", V2.CYAN, 58)
	_time_panel.size_flags_stretch_ratio = 1.0
	_time_value = _build_metric_content(_time_panel, "speed", null, "RECOVERY TIME", V2.CYAN)
	_cost_panel = _information_panel(_recovery_meta_row, "InstantRecovery", V2.AMBER, 58)
	_cost_panel.size_flags_stretch_ratio = 1.0
	_cost_value = _build_metric_content(_cost_panel, "", BITS_ICON, "INSTANT RECOVERY", V2.AMBER)

	for spec in [
		["admit", "ADMIT · FREE", "Move to Hospital for timed recovery", V2.CYAN, "brand"],
		["recover", "RECOVER NOW", "Restore HP and SP immediately", V2.WHITE, "speed"],
		["discharge", "DISCHARGE", "Remove from Hospital", V2.GREEN, "move"],
	]:
		var button := _create_action_button(String(spec[0]), String(spec[1]), String(spec[2]), spec[3] as Color, String(spec[4]))
		_overview_stack.add_child(button)
		_actions[spec[0]] = button

	_detail_back = _button(_canvas, "BackToPatients", "‹  PATIENTS", V2.CYAN)
	_detail_back.focus_mode = Control.FOCUS_NONE
	_detail_back.pressed.connect(_exit_action_mode)


func _build_recovery_resource_content(panel: PanelContainer, title_text: String, icon_kind: String, accent: Color, prefix: String) -> Dictionary:
	var margin := _full_margin(panel, 14, 8, 14, 8)
	var stack := VBoxContainer.new()
	stack.name = "%sRecoveryContent" % prefix
	stack.add_theme_constant_override("separation", 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)

	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size.y = 22
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title_row)
	var icon := IconScript.new() as DigiProceduralIcon
	icon.custom_minimum_size = Vector2(23, 23)
	icon.configure(icon_kind, accent)
	title_row.add_child(icon)
	var title := _flow_label(title_row, title_text, 16, V2.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var values := HBoxContainer.new()
	values.custom_minimum_size.y = 29
	values.alignment = BoxContainer.ALIGNMENT_CENTER
	values.add_theme_constant_override("separation", 10)
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(values)

	var before := _flow_label(values, "—", 23, V2.WHITE, true)
	before.name = "%sBefore" % prefix
	before.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	before.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var arrow := TextureRect.new()
	arrow.name = "%sChangeArrow" % prefix
	arrow.texture = ARROW_ICON
	arrow.custom_minimum_size = Vector2(28, 24)
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.modulate = accent
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_child(arrow)

	var after := _flow_label(values, "—", 23, V2.WHITE, true)
	after.name = "%sAfter" % prefix
	after.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bar := _progress(stack, "%sBar" % prefix, accent)
	bar.custom_minimum_size.y = 9
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var progress := _flow_label(stack, "", 13, V2.MUTED, false)
	progress.name = "%sProgress" % prefix
	progress.custom_minimum_size.y = 17

	return {
		"before": before,
		"after": after,
		"arrow": arrow,
		"bar": bar,
		"progress": progress,
	}


func _build_metric_content(panel: PanelContainer, icon_kind: String, texture: Texture2D, title_text: String, accent: Color) -> Label:
	var margin := _full_margin(panel, 14, 7, 14, 7)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.custom_minimum_size = Vector2(27, 27)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
	else:
		var icon := IconScript.new() as DigiProceduralIcon
		icon.custom_minimum_size = Vector2(27, 27)
		icon.configure(icon_kind, accent)
		row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 0)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	_flow_label(copy, title_text, 14, V2.TEXT, true)
	var value := _flow_label(copy, "—", 22, accent, true)
	return value


func _build_footer() -> void:
	_footer = HintBarScript.new() as DigiInputHintBar
	_footer.name = "HospitalHints"
	_footer.set_description("DIGI HOSPITAL")
	_footer.set_primary_tabs_enabled(true)
	_footer.set_scroll_hint_enabled(false)
	_footer.set_hide_hints_on_touch(true)
	_canvas.add_child(_footer)


func _layout() -> void:
	if _canvas == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var factor := V2.ui_scale(get_viewport())
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = Vector2.ZERO
	_canvas.size = physical
	var w := physical.x
	var h := physical.y
	var compact := _is_compact()

	var header_h := 86.0 if not compact else 72.0
	var footer_h := 54.0
	_place(_header, 0, 0, w, header_h)
	var badge := _header.get_node("BitsBadge") as Panel
	var badge_w := 166.0 if not compact else 126.0
	_place(badge, w - badge_w - 82.0, 17, badge_w, 46)
	_place(_close_button, w - 70, 16, 48, 48)
	_bits_label.text = "%d BITS" % OverworldState.get_bits()
	_place(_footer, 0, h - footer_h, w, footer_h)

	var gap := 12.0
	var top := header_h + (16.0 if not compact else 12.0)
	var bottom := h - footer_h - 12.0
	var content_h := maxf(0.0, bottom - top)

	if compact:
		var pad := 10.0
		var full_w := w - pad * 2.0
		var detail_open := _compact_detail and _interaction_mode == InteractionMode.ACTIONS
		_detail_back.visible = detail_open
		_roster.visible = not detail_open
		_hero.visible = detail_open
		_overview.visible = detail_open
		if not detail_open:
			_place(_roster, pad, top, full_w, content_h)
		else:
			_place(_detail_back, pad, top, 148, 44)
			var detail_top := top + 52.0
			var detail_h := maxf(0.0, content_h - 52.0)
			if w >= 720.0:
				var hero_w := (full_w - gap) * 0.43
				_place(_hero, pad, detail_top, hero_w, detail_h)
				_place(_overview, pad + hero_w + gap, detail_top, full_w - hero_w - gap, detail_h)
			else:
				var hero_h := clampf(detail_h * 0.32, 132.0, 205.0)
				_place(_hero, pad, detail_top, full_w, hero_h)
				_place(_overview, pad, detail_top + hero_h + gap, full_w, maxf(0.0, detail_h - hero_h - gap))
	else:
		_detail_back.visible = false
		_roster.visible = true
		_hero.visible = true
		_overview.visible = true
		var margin := 24.0
		var usable := w - margin * 2.0 - gap * 2.0
		var roster_w := clampf(usable * 0.255, 290.0, 430.0)
		var overview_w := clampf(usable * 0.315, 340.0, 500.0)
		var hero_w := usable - roster_w - overview_w
		_place(_roster, margin, top, roster_w, content_h)
		_place(_hero, margin + roster_w + gap, top, hero_w, content_h)
		_place(_overview, margin + roster_w + hero_w + gap * 2.0, top, overview_w, content_h)

	_apply_density(compact)
	_apply_interaction_visuals()


func _apply_density(compact: bool) -> void:
	if _health_panel == null:
		return
	_health_panel.custom_minimum_size.y = 110 if compact else 120
	_sp_panel.custom_minimum_size.y = _health_panel.custom_minimum_size.y
	_time_panel.custom_minimum_size.y = 52 if compact else 62
	_cost_panel.custom_minimum_size.y = 52 if compact else 62
	_overview_header.custom_minimum_size.y = 29 if compact else 34
	for button in _actions.values():
		(button as Button).custom_minimum_size.y = 56 if compact else 72


func _refresh_structure(restore_focus: bool = true) -> void:
	var focus_token := _capture_focus_token() if restore_focus else ""
	_bits_label.text = "%d BITS" % OverworldState.get_bits()
	_ensure_preview()
	_refresh_tabs()
	_rebuild_cards()
	_refresh_detail()
	_layout()
	if visible and not _confirmation.visible:
		if restore_focus:
			call_deferred("_restore_focus", focus_token)
		else:
			call_deferred("_focus_preview_card")


func _current_roster() -> Array[DigimonInstance]:
	return OverworldState.get_squad_instances() if _tab == "party" else OverworldState.get_hospital_instances()


func _roster_signature() -> String:
	var ids: Array[String] = []
	for instance: DigimonInstance in _current_roster():
		ids.append(instance.id)
	return "%s:%s" % [_tab, ",".join(ids)]


func _ensure_preview() -> void:
	var roster := _current_roster()
	if roster.is_empty():
		_preview_id = ""
		_confirmed_id = ""
		_interaction_mode = InteractionMode.EXPLORE
		_compact_detail = false
		_page = 0
		return

	var ids: Array[String] = []
	for instance: DigimonInstance in roster:
		ids.append(instance.id)
	if not ids.has(_preview_id):
		_preview_id = roster[0].id
	if _interaction_mode == InteractionMode.ACTIONS:
		if not ids.has(_confirmed_id):
			_confirmed_id = ""
			_interaction_mode = InteractionMode.EXPLORE
			_compact_detail = false
		else:
			_preview_id = _confirmed_id
	var index := ids.find(_preview_id)
	_page = maxi(0, index) / _page_capacity()


func _refresh_tabs() -> void:
	for key in ["party", "hospital"]:
		var button := _tab_buttons[key] as Button
		var count := OverworldState.get_squad_instances().size() if key == "party" else OverworldState.get_hospital_instances().size()
		var label := "SQUAD" if key == "party" else "HOSPITAL"
		button.text = "%s  %d" % [label, count]
		var active := String(key) == _tab
		button.add_theme_stylebox_override("normal", V2.hospital_button_style(V2.CYAN, "focus" if active else "normal"))
		button.add_theme_color_override("font_color", V2.WHITE if active else V2.MUTED)


func _rebuild_cards() -> void:
	for child in _card_area.get_children():
		_card_area.remove_child(child)
		child.queue_free()
	_cards.clear()
	_card_order.clear()

	var roster := _current_roster()
	var capacity := _page_capacity()
	var total_pages := maxi(1, ceili(float(roster.size()) / float(capacity)))
	_page = clampi(_page, 0, total_pages - 1)
	_page_back.disabled = _page == 0
	_page_next.disabled = _page >= total_pages - 1
	_page_label.text = "%d / %d" % [_page + 1, total_pages]
	_card_roster_signature = _roster_signature()

	if roster.is_empty():
		var empty_label := "Squad" if _tab == "party" else "Hospital"
		var empty := _flow_label(_card_area, "No Digimon in %s." % empty_label, 18, V2.MUTED, true)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		return

	var start := _page * capacity
	var finish := mini(roster.size(), start + capacity)
	for index in range(start, finish):
		var instance := roster[index]
		var card := _create_patient_card(instance)
		_card_area.add_child(card)
		_cards[instance.id] = card
		_card_order.append(card)
	_refresh_card_highlights()


func _create_patient_card(instance: DigimonInstance) -> Button:
	var species := _database.get_by_seed(instance.species_seed)
	var preview := OverworldState.get_hospital_preview(instance.id)
	var name := instance.get_display_name(String(species.get("name", instance.species_seed)))
	var card := _button(_card_area, "Patient_%s" % instance.id, "", V2.CYAN, false)
	card.set_meta("instance_id", instance.id)
	card.custom_minimum_size.y = 116
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.pressed.connect(_confirm_instance.bind(instance.id))
	card.mouse_entered.connect(_preview_instance.bind(instance.id))
	card.focus_entered.connect(_preview_instance.bind(instance.id))

	var margin := _full_margin(card, 10, 8, 10, 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var walk := WalkScript.new() as DigimonWalkPreview
	walk.custom_minimum_size = Vector2(92, 92)
	walk.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	walk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	walk.set_species(String(species.get("name", instance.species_seed)))
	row.add_child(walk)

	var info := VBoxContainer.new()
	info.name = "CardInfo"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_label := _flow_label(info, name, 20, V2.WHITE, true)
	name_label.name = "Name"
	name_label.custom_minimum_size.y = 24
	var level := _flow_label(info, "Lv. %d" % instance.level, 14, V2.TEXT, false)
	level.name = "Level"
	level.custom_minimum_size.y = 18
	var health := _flow_label(info, "HP %d / %d  ·  SP %d / %d" % [int(preview.get("current_hp", 0)), int(preview.get("max_hp", 1)), int(preview.get("current_sp", 0)), int(preview.get("max_sp", 0))], 12, V2.TEXT, false)
	health.name = "Health"
	health.custom_minimum_size.y = 18
	var bar := _progress(info, "HpBar")
	bar.custom_minimum_size.y = 8
	bar.max_value = maxf(1.0, float(preview.get("max_hp", 1)))
	bar.value = float(preview.get("current_hp", 0))
	var status := _flow_label(info, _status_text(preview), 12, _status_color(String(preview.get("status", "healthy"))), true)
	status.name = "Status"
	status.custom_minimum_size.y = 25
	status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_apply_status_chip(status, preview)
	return card


func _refresh_card_highlights() -> void:
	for raw_id in _cards:
		var id := String(raw_id)
		var card := _cards[id] as Button
		var highlighted := id == _preview_id
		card.add_theme_stylebox_override("normal", V2.hospital_panel_style(V2.CYAN, highlighted))
		var walk := card.find_child("WalkPreview", true, false) as DigimonWalkPreview
		if walk != null:
			walk.set_active(highlighted)


func _refresh_card_values() -> void:
	for raw_id in _cards:
		var id := String(raw_id)
		var card := _cards[id] as Button
		var preview := OverworldState.get_hospital_preview(id)
		var health := card.find_child("Health", true, false) as Label
		if health != null:
			health.text = "HP %d / %d  ·  SP %d / %d" % [int(preview.get("current_hp", 0)), int(preview.get("max_hp", 1)), int(preview.get("current_sp", 0)), int(preview.get("max_sp", 0))]
		var bar := card.find_child("HpBar", true, false) as ProgressBar
		if bar != null:
			bar.max_value = maxf(1.0, float(preview.get("max_hp", 1)))
			bar.value = float(preview.get("current_hp", 0))
		var status := card.find_child("Status", true, false) as Label
		if status != null:
			status.text = _status_text(preview)
			_apply_status_chip(status, preview)
	_refresh_card_highlights()


func _refresh_detail() -> void:
	var instance := OverworldState.get_instance_by_id(_preview_id)
	if instance == null:
		_hero_name.text = "NO PATIENT SELECTED"
		_hero_info.text = "Choose a Digimon from the roster."
		_hero_location.text = ""
		_hero_tier_icon.visible = false
		_hero_status.visible = false
		_hero_portrait.set_species("")
		_hero_notice.text = ""
		_health_before.text = "—"
		_health_after.text = "—"
		_health_arrow.visible = false
		_health_missing.text = ""
		_health_bar.max_value = 1.0
		_health_bar.value = 0.0
		_sp_before.text = "—"
		_sp_after.text = "—"
		_sp_arrow.visible = false
		_sp_progress.text = ""
		_sp_bar.max_value = 1.0
		_sp_bar.value = 0.0
		_time_value.text = "—"
		_cost_value.text = "—"
		for button in _actions.values():
			var action := button as Button
			action.visible = false
			action.disabled = true
			action.focus_mode = Control.FOCUS_NONE
		_apply_interaction_visuals()
		return

	var species := _database.get_by_seed(instance.species_seed)
	var preview := OverworldState.get_hospital_preview(instance.id)
	var name := instance.get_display_name(String(species.get("name", instance.species_seed)))
	var location := String(preview.get("location", "")).to_upper()
	if location == PlayerCollection.LOCATION_PARTY.to_upper():
		var role := OverworldState.get_squad_role(instance.id)
		location = role.to_upper() if not role.is_empty() else "SQUAD"
	var current_hp := int(preview.get("current_hp", 0))
	var max_hp := int(preview.get("max_hp", 1))
	var current_sp := int(preview.get("current_sp", 0))
	var max_sp := int(preview.get("max_sp", 0))
	var recovery_progress := clampf(float(preview.get("recovery_progress", 0.0)), 0.0, 1.0)

	_hero_name.text = name
	_hero_info.text = "%s   |   Level %d   |" % [String(species.get("rank", "")), instance.level]
	_hero_tier_icon.visible = true
	_hero_tier_icon.set_tier(instance.tier)
	_hero_location.text = "|   %s" % location
	_hero_status.visible = true
	_hero_status.text = _status_text(preview)
	_apply_status_chip(_hero_status, preview)
	_hero_portrait.set_species(String(species.get("name", instance.species_seed)))
	_hero_notice.text = _notice
	_hero_notice.add_theme_color_override("font_color", _notice_color)

	_health_before.text = "%d / %d" % [current_hp, max_hp]
	_health_after.text = "%d / %d" % [max_hp, max_hp]
	_health_arrow.visible = true
	_health_bar.max_value = maxf(1.0, float(max_hp))
	_health_bar.value = current_hp

	_sp_before.text = "%d / %d" % [current_sp, max_sp]
	_sp_after.text = "%d / %d" % [max_sp, max_sp]
	_sp_arrow.visible = true
	_sp_bar.max_value = maxf(1.0, float(max_sp))
	_sp_bar.value = current_sp

	var hospitalized := String(preview.get("location", "")) == PlayerCollection.LOCATION_HOSPITAL
	if hospitalized:
		var progress_percent := int(round(recovery_progress * 100.0))
		_health_missing.text = "RECOVERY %d%%" % progress_percent
		_sp_progress.text = "RECOVERY %d%%" % progress_percent
	else:
		_health_missing.text = "%d%% HP missing" % int(round(float(preview.get("missing_hp_ratio", 0.0)) * 100.0))
		_sp_progress.text = "%d%% SP missing" % int(round(float(preview.get("missing_sp_ratio", 0.0)) * 100.0))
	_time_value.text = _time_text(preview)
	_cost_value.text = "%d Bits" % int(preview.get("instant_cost", 0))

	_update_action_visibility(preview)
	var recover_title := (_actions["recover"] as Button).find_child("Title", true, false) as Label
	if recover_title != null:
		recover_title.text = "RECOVER NOW · %d BITS" % int(preview.get("instant_cost", 0))
	_apply_interaction_visuals()


func _update_action_visibility(preview: Dictionary) -> void:
	var status := String(preview.get("status", "unavailable"))
	var location := String(preview.get("location", ""))
	var party := _tab == "party" and location == PlayerCollection.LOCATION_PARTY
	var hospital := _tab == "hospital" and location == PlayerCollection.LOCATION_HOSPITAL
	var show_admit := party and bool(preview.get("can_admit", false))
	var show_recover := party and status in ["injured", "critical"] and int(preview.get("instant_cost", 0)) > 0
	var show_discharge := hospital and bool(preview.get("can_discharge", false))
	var visibility := {
		"admit": show_admit,
		"recover": show_recover,
		"discharge": show_discharge,
	}
	for key in ["admit", "recover", "discharge"]:
		var button := _actions[key] as Button
		button.visible = bool(visibility[key])
		var allowed := bool(preview.get("can_admit" if key == "admit" else ("can_recover_now" if key == "recover" else "can_discharge"), false))
		var action_mode := _interaction_mode == InteractionMode.ACTIONS and _confirmed_id == _preview_id
		button.disabled = not action_mode or not allowed
		button.focus_mode = Control.FOCUS_ALL if button.visible and not button.disabled else Control.FOCUS_NONE


func _apply_interaction_visuals() -> void:
	if _overview == null:
		return
	var active := _interaction_mode == InteractionMode.ACTIONS and not _confirmed_id.is_empty()
	_overview.modulate = Color(1.0, 1.0, 1.0, 1.0 if active else 0.70)
	_overview.mouse_filter = Control.MOUSE_FILTER_PASS if active else Control.MOUSE_FILTER_IGNORE


func _refresh_live() -> void:
	if not visible:
		return
	_bits_label.text = "%d BITS" % OverworldState.get_bits()
	if _roster_signature() != _card_roster_signature:
		_refresh_structure(true)
		return
	_refresh_card_values()
	_refresh_detail()


func _switch_tab(next_tab: String) -> void:
	if next_tab == _tab:
		return
	_tab = next_tab
	_page = 0
	_preview_id = ""
	_confirmed_id = ""
	_interaction_mode = InteractionMode.EXPLORE
	_compact_detail = false
	_notice = ""
	_ensure_preview()
	_refresh_structure(false)
	call_deferred("_focus_preview_card")


func _turn_page(direction: int) -> void:
	if _interaction_mode == InteractionMode.ACTIONS:
		_exit_action_mode(false)
	var roster := _current_roster()
	var capacity := _page_capacity()
	var pages := maxi(1, ceili(float(roster.size()) / float(capacity)))
	var next_page := clampi(_page + direction, 0, pages - 1)
	if next_page == _page or roster.is_empty():
		return
	_page = next_page
	_preview_id = roster[_page * capacity].id
	_rebuild_cards()
	_refresh_detail()
	_layout()
	call_deferred("_focus_preview_card")


func _preview_instance(id: String) -> void:
	if _interaction_mode == InteractionMode.ACTIONS or id == _preview_id:
		return
	if not _cards.has(id):
		return
	_preview_id = id
	_notice = ""
	_refresh_card_highlights()
	_refresh_detail()


func _confirm_instance(id: String) -> void:
	if _interaction_mode == InteractionMode.ACTIONS:
		return
	_preview_id = id
	_notice = ""
	_refresh_card_highlights()
	_refresh_detail()
	if _visible_action_keys().is_empty():
		return
	_confirmed_id = id
	_interaction_mode = InteractionMode.ACTIONS
	_compact_detail = _is_compact()
	_refresh_detail()
	_layout()
	call_deferred("_focus_first_action")


func _exit_action_mode(focus_list: bool = true) -> void:
	if _interaction_mode != InteractionMode.ACTIONS:
		return
	_interaction_mode = InteractionMode.EXPLORE
	_confirmed_id = ""
	_compact_detail = false
	_refresh_detail()
	_layout()
	if focus_list:
		call_deferred("_focus_preview_card")


func _request_action(action: String) -> void:
	if _interaction_mode != InteractionMode.ACTIONS or _confirmed_id.is_empty() or _confirmed_id != _preview_id:
		return
	var button := _actions.get(action) as Button
	if button == null or not button.visible or button.disabled:
		return
	var preview := OverworldState.get_hospital_preview(_confirmed_id)
	var allowed := bool(preview.get("can_admit" if action == "admit" else ("can_recover_now" if action == "recover" else "can_discharge"), false))
	if not allowed:
		return
	_pending_action = action
	if action == "admit":
		_confirmation.configure("ADMIT THIS DIGIMON?", "Timed recovery takes %s. This Digimon leaves the Squad until discharged." % _format_duration(int(preview.get("recovery_seconds", 0))), "ADMIT", "CANCEL", V2.CYAN, "DIGI HOSPITAL")
	elif action == "recover":
		_confirmation.configure("RECOVER NOW?", "Spend %d Bits to fully restore HP and SP? This Digimon remains in Hospital until discharged." % int(preview.get("instant_cost", 0)), "SPEND BITS", "CANCEL", V2.AMBER, "DIGI HOSPITAL")
	else:
		_confirmation.configure(
			"DISCHARGE THIS DIGIMON?",
			"Recovery is complete. Return this Digimon to its Squad role when possible? If the Squad is full, it will move to Storage.",
			"DISCHARGE",
			"CANCEL",
			V2.GREEN,
			"DIGI HOSPITAL"
		)
	_confirmation.open_dialog(button)


func _confirm_action() -> void:
	var action := _pending_action
	var target_id := _confirmed_id
	_pending_action = ""
	if action.is_empty() or target_id.is_empty():
		return
	var result: Dictionary = {}
	match action:
		"admit": result = OverworldState.admit_to_hospital(target_id)
		"recover": result = OverworldState.recover_from_hospital_now(target_id)
		"discharge": result = OverworldState.discharge_from_hospital(target_id)
	if bool(result.get("success", false)):
		_notice = "Treatment started." if action == "admit" else ("HP and SP restored. Ready for discharge." if action == "recover" else "Discharged successfully.")
		_notice_color = V2.GREEN
		_interaction_mode = InteractionMode.EXPLORE
		_confirmed_id = ""
		_compact_detail = false
	else:
		_notice = _failure_text(String(result.get("reason", "invalid")))
		_notice_color = V2.RED
	_refresh_structure(true)


func _move_preview(direction: int) -> void:
	var roster := _current_roster()
	if roster.is_empty():
		return
	var ids: Array[String] = []
	for instance: DigimonInstance in roster:
		ids.append(instance.id)
	var current := ids.find(_preview_id)
	if current < 0:
		current = 0
	var next := clampi(current + direction, 0, ids.size() - 1)
	if next == current:
		return
	_preview_id = ids[next]
	_notice = ""
	var next_page := next / _page_capacity()
	if next_page != _page:
		_page = next_page
		_rebuild_cards()
	else:
		_refresh_card_highlights()
	_refresh_detail()
	call_deferred("_focus_preview_card")


func _move_action_focus(direction: int) -> void:
	var keys := _available_action_keys()
	if keys.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var current := -1
	for i in keys.size():
		if _actions[keys[i]] == owner:
			current = i
			break
	var next := 0 if current < 0 else clampi(current + direction, 0, keys.size() - 1)
	(_actions[keys[next]] as Button).grab_focus()


func _activate_focused_action() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	for key in _available_action_keys():
		if _actions[key] == owner:
			_request_action(key)
			return
	if not _available_action_keys().is_empty():
		_request_action(_available_action_keys()[0])


func _visible_action_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in ["admit", "recover", "discharge"]:
		var button := _actions[key] as Button
		if button.visible:
			keys.append(key)
	return keys


func _available_action_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in ["admit", "recover", "discharge"]:
		var button := _actions[key] as Button
		if button.visible and not button.disabled:
			keys.append(key)
	return keys


func _focus_preview_card() -> void:
	if not visible or _confirmation.visible or _interaction_mode != InteractionMode.EXPLORE:
		return
	var card := _cards.get(_preview_id) as Button
	if card != null and card.is_visible_in_tree():
		card.grab_focus()


func _focus_first_action() -> void:
	if not visible or _confirmation.visible or _interaction_mode != InteractionMode.ACTIONS:
		return
	var keys := _available_action_keys()
	if not keys.is_empty():
		(_actions[keys[0]] as Button).grab_focus()


func _capture_focus_token() -> String:
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null:
		return ""
	for raw_id in _cards:
		if _cards[raw_id] == owner:
			return "card:%s" % String(raw_id)
	for key in _actions:
		if _actions[key] == owner:
			return "action:%s" % String(key)
	return ""


func _restore_focus(token: String) -> void:
	if not visible or _confirmation.visible:
		return
	if _interaction_mode == InteractionMode.ACTIONS:
		if token.begins_with("action:"):
			var key := token.trim_prefix("action:")
			var button := _actions.get(key) as Button
			if button != null and button.visible and not button.disabled:
				button.grab_focus()
				return
		_focus_first_action()
	else:
		_focus_preview_card()


func _on_overview_gui_input(event: InputEvent) -> void:
	if _interaction_mode != InteractionMode.ACTIONS:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_exit_action_mode()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_exit_action_mode()
		accept_event()


func _on_state_changed() -> void:
	if not visible:
		return
	if _roster_signature() != _card_roster_signature:
		_refresh_structure(true)
	else:
		_refresh_live()


func _on_viewport_resized() -> void:
	if visible:
		_refresh_structure(true)
	else:
		_layout()


func _on_account_rewards_changed(_bits: int, _data: Dictionary) -> void:
	if visible:
		_refresh_live()


func _on_hospital_state_changed(_id: String, _status: String) -> void:
	if visible:
		_refresh_live()


func _is_compact() -> bool:
	var viewport_size := V2.physical_window_size(get_viewport())
	return viewport_size.x < 980.0 or viewport_size.y < 600.0


func _page_capacity() -> int:
	var viewport_size := V2.physical_window_size(get_viewport())
	if viewport_size.y < 560.0:
		return 1
	if viewport_size.y < 680.0:
		return 2
	return PAGE_SIZE


func _status_text(preview: Dictionary) -> String:
	match String(preview.get("status", "healthy")):
		"injured": return "INJURED"
		"critical": return "CRITICAL"
		"recovering": return "RECOVERING · %s" % _format_duration(int(preview.get("remaining_seconds", 0)))
		"ready": return "READY FOR DISCHARGE"
		"unavailable": return "UNAVAILABLE"
		_: return "HEALTHY"


func _status_color(status: String) -> Color:
	match status:
		"injured", "critical": return V2.RED
		"recovering": return V2.CYAN
		"ready", "healthy": return V2.GREEN
		_: return V2.MUTED


func _apply_status_chip(label: Label, preview: Dictionary) -> void:
	var accent := _status_color(String(preview.get("status", "healthy")))
	label.add_theme_color_override("font_color", accent)
	label.add_theme_stylebox_override("normal", V2.pill_style(accent, true))


func _time_text(preview: Dictionary) -> String:
	match String(preview.get("status", "")):
		"recovering": return _format_duration(int(preview.get("remaining_seconds", 0))) + " remaining"
		"ready": return "Complete"
		_:
			var seconds := int(preview.get("recovery_seconds", 0))
			return _format_duration(seconds) if seconds > 0 else "Not required"


func _format_duration(value: int) -> String:
	var total := maxi(0, value)
	var hours := int(total / 3600)
	var minutes := int((total % 3600) / 60)
	var seconds := total % 60
	return "%d:%02d:%02d" % [hours, minutes, seconds] if hours > 0 else "%02d:%02d" % [minutes, seconds]


func _failure_text(reason: String) -> String:
	match reason:
		"insufficient_bits": return "Not enough Bits for instant recovery."
		"still_recovering": return "Treatment is still in progress."
		"healthy": return "This Digimon is already healthy."
		_: return "Hospital action could not be completed."


func _panel(parent: Node, node_name: String, accent: Color) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", V2.hospital_panel_style(accent))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _information_panel(parent: Node, node_name: String, accent: Color, minimum_height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size.y = minimum_height
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.hospital_panel_style(accent))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _button(parent: Node, node_name: String, title: String, accent: Color, attach: bool = true) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = title
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", V2.WHITE)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", V2.MUTED)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, V2.hospital_button_style(accent, state))
	V2.apply_heading(button)
	if attach:
		parent.add_child(button)
	return button


func _create_action_button(key: String, title_text: String, subtitle_text: String, accent: Color, icon_kind: String) -> Button:
	var button := Button.new()
	button.name = key.capitalize()
	button.text = ""
	button.custom_minimum_size.y = 72
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = false
	button.add_theme_stylebox_override("normal", _action_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", _action_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", _action_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", _action_style(accent, "pressed"))
	button.add_theme_stylebox_override("hover_pressed", _action_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", _action_style(accent, "disabled"))
	button.pressed.connect(_request_action.bind(key))

	var margin := _full_margin(button, 16, 8, 16, 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var icon := IconScript.new() as DigiProceduralIcon
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(icon_kind, accent, 2.2)
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var title := _flow_label(copy, title_text, 18, V2.WHITE, true)
	title.name = "Title"
	var subtitle := _flow_label(copy, subtitle_text, 13, V2.MUTED, false)
	subtitle.name = "Subtitle"
	return button


func _action_style(accent: Color, state: String) -> StyleBoxFlat:
	var fill := Color(0.025, 0.075, 0.103, 0.98)
	var border := Color(accent.r, accent.g, accent.b, 0.72)
	var width := 2
	var shadow_alpha := 0.14
	var shadow_size := 8
	match state:
		"hover":
			fill = Color(accent.r * 0.15 + 0.025, accent.g * 0.15 + 0.065, accent.b * 0.15 + 0.085, 0.99)
			border = Color(accent.r, accent.g, accent.b, 0.96)
			shadow_alpha = 0.30
			shadow_size = 12
		"focus":
			fill = Color(accent.r * 0.20 + 0.025, accent.g * 0.20 + 0.060, accent.b * 0.20 + 0.080, 1.0)
			border = Color(accent.r, accent.g, accent.b, 1.0)
			width = 3
			shadow_alpha = 0.46
			shadow_size = 16
		"pressed":
			fill = Color(accent.r * 0.27 + 0.020, accent.g * 0.27 + 0.050, accent.b * 0.27 + 0.070, 1.0)
			border = Color(accent.r, accent.g, accent.b, 1.0)
			width = 3
			shadow_alpha = 0.24
			shadow_size = 8
		"disabled":
			fill = Color(0.020, 0.038, 0.052, 0.76)
			border = Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.34)
			width = 1
			shadow_alpha = 0.0
			shadow_size = 0
	var style := V2.surface_style(fill, border, 10)
	style.set_border_width_all(width)
	style.border_blend = true
	style.shadow_color = Color(accent.r, accent.g, accent.b, shadow_alpha)
	style.shadow_size = shadow_size
	return style


func _label(parent: Node, value: String, font_size: int, color: Color, heading: bool, pos: Vector2, dimensions: Vector2) -> Label:
	var label := _flow_label(parent, value, font_size, color, heading)
	label.position = pos
	label.size = dimensions
	return label


func _flow_label(parent: Node, value: String, font_size: int, color: Color, heading: bool) -> Label:
	var label := Label.new()
	label.text = value
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if heading:
		V2.apply_heading(label)
	else:
		V2.apply_reading(label)
	parent.add_child(label)
	return label


func _icon(parent: Node, kind: String, color: Color, pos: Vector2, dimensions: Vector2) -> DigiProceduralIcon:
	var icon := IconScript.new() as DigiProceduralIcon
	icon.position = pos
	icon.size = dimensions
	icon.configure(kind, color)
	parent.add_child(icon)
	return icon


func _texture(parent: Node, texture: Texture2D, tint: Color, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.position = pos
	image.size = dimensions
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = tint
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image


func _progress(parent: Node, node_name: String, accent: Color = V2.GREEN) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", V2.progress_track_style())
	bar.add_theme_stylebox_override("fill", V2.progress_fill_style(accent, true))
	parent.add_child(bar)
	return bar


func _full_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(margin)
	return margin


func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(maxf(0.0, w), maxf(0.0, h))
