extends Control
class_name HospitalScreen

signal close_requested

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const IconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")
const PortraitScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkScript = preload("res://src/ui/DigimonWalkPreview.gd")
const ConfirmationScript = preload("res://src/ui/components/DigiConfirmationModal.gd")
const BACKGROUND = preload("res://assets/ui/backgrounds/digi_hospital.png")
const BITS_ICON = preload("res://assets/ui/icons/bits.svg")
const CLOSE_ICON = preload("res://assets/ui/icons/cancel.svg")
const ARROW_ICON = preload("res://assets/ui/icons/hp_change_arrow.svg")
const PAGE_SIZE := 3

var _database: DigimonDatabase
var _selected_id := ""
var _tab := "party"
var _page := 0
var _compact_detail := false
var _pending_action := ""
var _notice := ""
var _notice_color := V2.CYAN
var _clock := 0.0

var _canvas: Control
var _shade: ColorRect
var _header: Panel
var _footer: Panel
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
var _hero_status: Label
var _hero_portrait: DigimonPortraitPreview
var _hero_notice: Label
var _health_value: Label
var _health_missing: Label
var _health_bar: ProgressBar
var _time_value: Label
var _cost_value: Label
var _confirmation: DigiConfirmationModal
var _close_button: Button
var _detail_back: Button
var _card_area: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	OverworldState.collection_changed.connect(_on_state_changed)
	OverworldState.account_rewards_changed.connect(_on_account_rewards_changed)
	OverworldState.hospital_state_changed.connect(_on_hospital_state_changed)
	get_viewport().size_changed.connect(_layout)
	visible = false
	set_process(false)


func open_screen() -> void:
	OverworldState.process_hospital_recoveries()
	visible = true
	set_process(true)
	_clock = 0.0
	_notice = ""
	_ensure_selection()
	_layout()
	_refresh()
	call_deferred("_focus_entry")


func close_view() -> void:
	if _confirmation.visible:
		_confirmation.close_dialog(false)
	_pending_action = ""
	visible = false
	set_process(false)
	close_requested.emit()


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.5:
		return
	_clock = 0.0
	OverworldState.process_hospital_recoveries()
	_refresh_live()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _confirmation.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		if _is_compact() and _compact_detail:
			_compact_detail = false
			_layout()
			call_deferred("_focus_entry")
		else:
			close_view()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_switch_tab("party")
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_switch_tab("hospital")
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_shade = ColorRect.new()
	_shade.color = Color(0.005, 0.019, 0.032, 0.36)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)

	_canvas = Control.new()
	_canvas.name = "HospitalCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	_header = _panel(_canvas, "HospitalHeader", V2.CYAN)
	_header.add_theme_stylebox_override("panel", V2.surface_style(Color(0.016, 0.037, 0.055, 0.94), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.40), 0))
	_icon(_header, "brand", V2.CYAN, Vector2(24, 12), Vector2(52, 52))
	_label(_header, "DIGI HOSPITAL", 30, V2.WHITE, true, Vector2(88, 12), Vector2(360, 38))
	_label(_header, "Recovery and Care", 16, V2.MUTED, false, Vector2(90, 49), Vector2(300, 25))
	var bits_badge := _panel(_header, "BitsBadge", V2.AMBER)
	bits_badge.name = "BitsBadge"
	bits_badge.set_meta("badge", true)
	_texture(bits_badge, BITS_ICON, V2.AMBER, Vector2(14, 13), Vector2(24, 24))
	_bits_label = _label(bits_badge, "0 BITS", 18, V2.WHITE, true, Vector2(47, 10), Vector2(105, 32))
	_close_button = _button(_header, "CloseHospital", "", V2.CYAN)
	_close_button.icon = CLOSE_ICON
	_close_button.expand_icon = true
	_close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_button.pressed.connect(close_view)

	_roster = _panel(_canvas, "HospitalRoster", V2.CYAN)
	for tab_id in ["party", "hospital"]:
		var tab := _button(_roster, "Tab_%s" % tab_id, tab_id.to_upper(), V2.CYAN)
		tab.pressed.connect(_switch_tab.bind(tab_id))
		_tab_buttons[tab_id] = tab
	_card_area = Control.new()
	_card_area.name = "PatientCards"
	_card_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster.add_child(_card_area)
	_page_back = _button(_roster, "PreviousPatients", "‹", V2.CYAN)
	_page_next = _button(_roster, "NextPatients", "›", V2.CYAN)
	_page_back.pressed.connect(_turn_page.bind(-1))
	_page_next.pressed.connect(_turn_page.bind(1))
	_page_label = _label(_roster, "", 16, V2.MUTED, true, Vector2.ZERO, Vector2.ZERO)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_hero = _panel(_canvas, "HospitalPatient", V2.CYAN)
	_hero_name = _label(_hero, "", 34, V2.WHITE, true, Vector2.ZERO, Vector2.ZERO)
	_hero_info = _label(_hero, "", 18, V2.TEXT, false, Vector2.ZERO, Vector2.ZERO)
	_hero_status = _label(_hero, "", 17, V2.RED, true, Vector2.ZERO, Vector2.ZERO)
	_hero_portrait = PortraitScript.new() as DigimonPortraitPreview
	_hero_portrait.name = "PatientPortrait"
	_hero.add_child(_hero_portrait)
	_hero_notice = _label(_hero, "", 16, V2.CYAN, true, Vector2.ZERO, Vector2.ZERO)
	_hero_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_overview = _panel(_canvas, "TreatmentOverview", V2.CYAN)
	_icon(_overview, "heart", V2.CYAN, Vector2(20, 14), Vector2(24, 24))
	_label(_overview, "TREATMENT OVERVIEW", 19, V2.WHITE, true, Vector2(53, 11), Vector2(370, 30))
	var health := _panel(_overview, "HealthRecovery", V2.GREEN)
	var time := _panel(_overview, "RecoveryTime", V2.CYAN)
	var cost := _panel(_overview, "InstantRecovery", V2.AMBER)
	for entry in [[health, "heart", "HEALTH RECOVERY", V2.GREEN], [time, "speed", "RECOVERY TIME", V2.CYAN], [cost, "bits", "INSTANT RECOVERY", V2.AMBER]]:
		_icon(entry[0], entry[1], entry[3], Vector2(15, 13), Vector2(25, 25))
		_label(entry[0], entry[2], 17, V2.TEXT, true, Vector2(47, 13), Vector2(350, 25))
	_health_value = _label(health, "", 25, V2.WHITE, true, Vector2(48, 41), Vector2(390, 34))
	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_theme_stylebox_override("background", V2.progress_track_style())
	_health_bar.add_theme_stylebox_override("fill", V2.progress_fill_style(V2.GREEN, true))
	_health_bar.custom_minimum_size.y = 10
	_health_bar.min_value = 0
	_health_bar.max_value = 1
	_health_bar.value = 0
	_health_bar.set_meta("health", true)
	_health_bar.name = "HealthBar"
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.visible = true
	_health_bar.set_meta("parent", health)
	_health_bar.position = Vector2(48, 80)
	health.add_child(_health_bar)
	_health_missing = _label(health, "", 15, V2.MUTED, false, Vector2(48, 98), Vector2(300, 23))
	_time_value = _label(time, "", 25, V2.CYAN, true, Vector2(48, 40), Vector2(380, 34))
	_cost_value = _label(cost, "", 25, V2.AMBER, true, Vector2(48, 40), Vector2(380, 34))
	for spec in [["admit", "ADMIT · FREE", "Move to Hospital for timed recovery", V2.CYAN, "brand"], ["recover", "RECOVER NOW", "Restore HP immediately", V2.WHITE, "speed"], ["discharge", "DISCHARGE", "Remove from Hospital", V2.GREEN, "move"]]:
		var button := _button(_overview, String(spec[0]).capitalize(), "", spec[3])
		_icon(button, spec[4], spec[3], Vector2(17, 13), Vector2(34, 34))
		_label(button, spec[1], 19, V2.WHITE, true, Vector2(68, 8), Vector2(350, 29))
		_label(button, spec[2], 15, V2.MUTED, false, Vector2(68, 37), Vector2(380, 23))
		button.pressed.connect(_request_action.bind(spec[0]))
		_actions[spec[0]] = button
	_detail_back = _button(_canvas, "BackToPatients", "‹  PATIENTS", V2.CYAN)
	_detail_back.pressed.connect(_show_roster)

	_footer = _panel(_canvas, "HospitalHints", V2.CYAN)
	_footer.add_theme_stylebox_override("panel", V2.surface_style(Color(0.016, 0.037, 0.055, 0.94), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.40), 0))
	_label(_footer, "DIGI HOSPITAL", 17, V2.WHITE, true, Vector2(24, 10), Vector2(240, 26))
	_label(_footer, "LB / RB  Tabs     D-Pad  Navigate     A  Select     B  Back", 15, V2.TEXT, true, Vector2(280, 10), Vector2(900, 26))

	_confirmation = ConfirmationScript.new() as DigiConfirmationModal
	_confirmation.name = "HospitalConfirmation"
	_confirmation.confirmed.connect(_confirm_action)
	_confirmation.cancelled.connect(func(): _pending_action = "")
	add_child(_confirmation)


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
	_place(_header, 0, 0, w, 86 if not compact else 72)
	var badge := _header.get_node("BitsBadge") as Panel
	_place(badge, w - (245 if not compact else 188), 17, 158 if not compact else 107, 46)
	_place(_close_button, w - 70, 16, 48, 48)
	_bits_label.text = "%d BITS" % OverworldState.get_bits()
	_place(_footer, 0, h - 52, w, 52)
	var footer_hint := _footer.get_child(1) as Label
	if footer_hint != null:
		footer_hint.visible = not compact
	var gap := 12.0
	var top := 102.0 if not compact else 84.0
	var bottom := h - 64.0
	var content_h := maxf(0.0, bottom - top)
	if compact:
		var pad := 10.0
		var full_w := w - pad * 2.0
		_place(_detail_back, pad, top, 148, 45)
		_detail_back.visible = _compact_detail
		_roster.visible = not _compact_detail
		_hero.visible = _compact_detail
		_overview.visible = _compact_detail
		if _compact_detail:
			var hero_h := minf(content_h * 0.32, 235.0)
			_place(_hero, pad, top + 52, full_w, hero_h)
			_place(_overview, pad, top + 58 + hero_h, full_w, content_h - hero_h - 58)
		else:
			_place(_roster, pad, top, full_w, content_h)
	else:
		_detail_back.visible = false
		_roster.visible = true
		_hero.visible = true
		_overview.visible = true
		var margin := 24.0
		var usable := w - margin * 2.0 - gap * 2.0
		var roster_w := usable * 0.264
		var hero_w := usable * 0.415
		var overview_w := usable - roster_w - hero_w
		_place(_roster, margin, top, roster_w, content_h)
		_place(_hero, margin + roster_w + gap, top, hero_w, content_h)
		_place(_overview, margin + roster_w + hero_w + gap * 2.0, top, overview_w, content_h)
	_layout_roster()
	_layout_hero()
	_layout_overview()
	_wire_focus()


func _layout_roster() -> void:
	var w := _roster.size.x
	var h := _roster.size.y
	var pad := 10.0
	var tab_w := (w - pad * 3.0) * 0.5
	_place(_tab_buttons["party"], pad, 10, tab_w, 56)
	_place(_tab_buttons["hospital"], pad * 2.0 + tab_w, 10, tab_w, 56)
	_place(_card_area, pad, 78, w - pad * 2.0, h - 139)
	var card_gap := 9.0
	var card_h := (_card_area.size.y - card_gap * 2.0) / 3.0
	for i in _card_order.size():
		var card := _card_order[i]
		_place(card, 0, i * (card_h + card_gap), _card_area.size.x, card_h)
		_layout_card(card)
	_place(_page_back, pad, h - 53, 52, 43)
	_place(_page_next, w - pad - 52, h - 53, 52, 43)
	_place(_page_label, 68, h - 50, w - 136, 32)


func _layout_card(card: Button) -> void:
	var h := card.size.y
	var icon_side := minf(100.0, h - 14.0)
	var portrait := card.get_node_or_null("Walk") as DigimonWalkPreview
	if portrait == null:
		return
	_place(portrait, 8, 7, icon_side, icon_side)
	var x := icon_side + 17.0
	for spec in [["Name", 9.0, 31.0], ["Level", 40.0, 23.0], ["Health", 64.0, 22.0], ["Status", h - 35.0, 28.0]]:
		var label := card.get_node(String(spec[0])) as Label
		_place(label, x, float(spec[1]), card.size.x - x - 9.0, float(spec[2]))
	var hp := card.get_node("HpBar") as ProgressBar
	_place(hp, x, h - 44.0, card.size.x - x - 13.0, 9)


func _layout_hero() -> void:
	var w := _hero.size.x
	var h := _hero.size.y
	var compact := _is_compact()
	var pad := 20.0
	_place(_hero_name, pad + 8, 17, w - pad * 2.0, 48)
	_place(_hero_info, pad + 8, 65, w - pad * 2.0, 30)
	_place(_hero_status, pad + 8, 99, w - pad * 2.0, 34)
	if compact:
		_place(_hero_info, pad + 8, 63, w * 0.50, 46)
		_place(_hero_status, pad + 8, 108, w * 0.50, 31)
		_place(_hero_portrait, w * 0.52, 68, w * 0.44, maxf(80, h - 76))
		_place(_hero_notice, pad + 8, h - 50, w * 0.52 - 30, 43)
	else:
		_place(_hero_portrait, w * 0.12, h * 0.20, w * 0.82, h * 0.72)
		_place(_hero_notice, pad + 8, h - 57, w - pad * 2.0, 42)


func _layout_overview() -> void:
	var w := _overview.size.x
	var h := _overview.size.y
	var compact := _is_compact()
	var pad := 11.0
	var body_top := 49.0
	var action_h := 69.0 if not compact else 58.0
	var gap := 8.0
	var health_h := 126.0 if not compact else 103.0
	var metric_h := 74.0 if not compact else 60.0
	var required := body_top + health_h + metric_h * 2.0 + action_h * 3.0 + gap * 5.0 + 11.0
	var fit := minf(1.0, (h - 10.0) / required)
	var y := body_top * fit
	var health := _overview.get_node("HealthRecovery") as Panel
	var time := _overview.get_node("RecoveryTime") as Panel
	var cost := _overview.get_node("InstantRecovery") as Panel
	_place(health, pad, y, w - pad * 2.0, health_h * fit)
	y += (health_h + gap) * fit
	_place(time, pad, y, w - pad * 2.0, metric_h * fit)
	y += (metric_h + gap) * fit
	_place(cost, pad, y, w - pad * 2.0, metric_h * fit)
	y += (metric_h + gap) * fit
	for key in ["admit", "recover", "discharge"]:
		_place(_actions[key], pad, y, w - pad * 2.0, action_h * fit)
		y += (action_h + gap) * fit
	_place(_health_value, 48, 36 if not compact else 31, health.size.x - 60, 27)
	_place(_health_bar, 48, health.size.y - 31, health.size.x - 62, 8)
	_place(_health_missing, 48, health.size.y - 22, health.size.x - 60, 19)
	_place(_time_value, 48, time.size.y - 36, time.size.x - 60, 27)
	_place(_cost_value, 48, cost.size.y - 36, cost.size.x - 60, 27)
	for key in _actions:
		var button := _actions[key] as Button
		var title := button.get_child(1) as Label
		var subtitle := button.get_child(2) as Label
		if title != null:
			_place(title, 63, 5, button.size.x - 70, 27)
		if subtitle != null:
			_place(subtitle, 63, 33, button.size.x - 70, 20)
			subtitle.visible = button.size.y >= 60.0


func _refresh() -> void:
	_bits_label.text = "%d BITS" % OverworldState.get_bits()
	_ensure_selection()
	_refresh_tabs()
	_refresh_cards()
	_refresh_detail()
	_layout()
	if visible and not _confirmation.visible:
		call_deferred("_focus_entry")


func _current_roster() -> Array[DigimonInstance]:
	return OverworldState.get_active_instances() if _tab == "party" else OverworldState.get_hospital_instances()


func _ensure_selection() -> void:
	var roster := _current_roster()
	for instance in roster:
		if instance.id == _selected_id:
			return
	_selected_id = roster[0].id if not roster.is_empty() else ""
	_page = 0


func _refresh_tabs() -> void:
	for key in ["party", "hospital"]:
		var button := _tab_buttons[key] as Button
		var count := OverworldState.get_active_instances().size() if key == "party" else OverworldState.get_hospital_instances().size()
		button.text = "%s  %d" % [key.to_upper(), count]
		var active: bool = String(key) == _tab
		button.add_theme_stylebox_override("normal", V2.hospital_button_style(V2.CYAN, "focus" if active else "normal"))
		button.add_theme_color_override("font_color", V2.WHITE if active else V2.MUTED)


func _refresh_cards() -> void:
	for child in _card_area.get_children():
		_card_area.remove_child(child)
		child.queue_free()
	_cards.clear()
	_card_order.clear()
	var roster := _current_roster()
	var total_pages := maxi(1, ceili(float(roster.size()) / PAGE_SIZE))
	_page = clampi(_page, 0, total_pages - 1)
	_page_back.disabled = _page == 0
	_page_next.disabled = _page >= total_pages - 1
	_page_label.text = "%d / %d" % [_page + 1, total_pages]
	if roster.is_empty():
		_label(_card_area, "No Digimon in %s." % _tab.capitalize(), 19, V2.MUTED, true, Vector2(12, 22), Vector2(_card_area.size.x - 24, 38))
		return
	for index in range(_page * PAGE_SIZE, mini(roster.size(), (_page + 1) * PAGE_SIZE)):
		var instance := roster[index]
		var species := _database.get_by_seed(instance.species_seed)
		var name := instance.get_display_name(String(species.get("name", instance.species_seed)))
		var preview := OverworldState.get_hospital_preview(instance.id)
		var accent := _status_color(String(preview.get("status", "healthy")))
		var card := _button(_card_area, "Patient_%s" % instance.id, "", V2.CYAN)
		card.add_theme_stylebox_override("normal", V2.hospital_panel_style(V2.CYAN, instance.id == _selected_id))
		card.pressed.connect(_select_instance.bind(instance.id))
		var walk := WalkScript.new() as DigimonWalkPreview
		walk.name = "Walk"
		walk.set_species(String(species.get("name", instance.species_seed)))
		walk.set_active(instance.id == _selected_id)
		card.add_child(walk)
		_label(card, name, 22, V2.WHITE, true, Vector2.ZERO, Vector2.ZERO).name = "Name"
		_label(card, "Lv. %d" % instance.level, 16, V2.TEXT, false, Vector2.ZERO, Vector2.ZERO).name = "Level"
		_label(card, "HP  %d / %d" % [int(preview.get("current_hp", 0)), int(preview.get("max_hp", 1))], 16, V2.TEXT, false, Vector2.ZERO, Vector2.ZERO).name = "Health"
		_label(card, _status_text(preview), 16, accent, true, Vector2.ZERO, Vector2.ZERO).name = "Status"
		var bar := _progress(card, "HpBar")
		bar.max_value = maxf(1.0, float(preview.get("max_hp", 1)))
		bar.value = float(preview.get("current_hp", 0))
		_cards[instance.id] = card
		_card_order.append(card)


func _refresh_detail() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		_hero_name.text = "NO PATIENT SELECTED"
		_hero_info.text = "Choose a Digimon from the roster."
		_hero_status.text = ""
		_hero_portrait.set_species("")
		_hero_notice.text = ""
		_health_value.text = "—"
		_health_missing.text = ""
		_time_value.text = "—"
		_cost_value.text = "—"
		for button in _actions.values():
			(button as Button).disabled = true
		return
	var species := _database.get_by_seed(instance.species_seed)
	var preview := OverworldState.get_hospital_preview(instance.id)
	var name := instance.get_display_name(String(species.get("name", instance.species_seed)))
	var location := String(preview.get("location", "")).to_upper()
	var current_hp := int(preview.get("current_hp", 0))
	var max_hp := int(preview.get("max_hp", 1))
	_hero_name.text = name
	_hero_info.text = "%s   |   Level %d   |   Tier %s   |   %s" % [String(species.get("rank", "")), instance.level, instance.tier, location]
	_hero_status.text = _status_text(preview)
	_hero_status.add_theme_color_override("font_color", _status_color(String(preview.get("status", "healthy"))))
	_hero_portrait.set_species(String(species.get("name", instance.species_seed)))
	_hero_notice.text = _notice
	_hero_notice.add_theme_color_override("font_color", _notice_color)
	_health_value.text = "%d / %d   →   %d / %d" % [current_hp, max_hp, max_hp, max_hp]
	_health_bar.max_value = maxf(1.0, float(max_hp))
	_health_bar.value = current_hp
	_health_missing.text = "%d%% HP missing" % int(round(float(preview.get("missing_hp_ratio", 0.0)) * 100.0))
	_time_value.text = _time_text(preview)
	_cost_value.text = "%d Bits" % int(preview.get("instant_cost", 0))
	(_actions["admit"] as Button).disabled = not bool(preview.get("can_admit", false))
	(_actions["recover"] as Button).disabled = not bool(preview.get("can_recover_now", false))
	(_actions["discharge"] as Button).disabled = not bool(preview.get("can_discharge", false))
	var recover_title := (_actions["recover"] as Button).get_child(1) as Label
	recover_title.text = "RECOVER NOW · %d BITS" % int(preview.get("instant_cost", 0))
	_wire_focus()


func _refresh_live() -> void:
	if not visible:
		return
	for id in _cards:
		var card := _cards[id] as Button
		var preview := OverworldState.get_hospital_preview(String(id))
		(card.get_node("Status") as Label).text = _status_text(preview)
	_refresh_detail()


func _switch_tab(next_tab: String) -> void:
	if next_tab == _tab:
		return
	_tab = next_tab
	_page = 0
	_compact_detail = false
	_notice = ""
	_refresh()
	call_deferred("_focus_entry")


func _turn_page(direction: int) -> void:
	var roster := _current_roster()
	var pages := maxi(1, ceili(float(roster.size()) / PAGE_SIZE))
	var next_page := clampi(_page + direction, 0, pages - 1)
	if next_page == _page:
		return
	_page = next_page
	_selected_id = roster[_page * PAGE_SIZE].id
	_refresh()
	call_deferred("_focus_entry")


func _select_instance(id: String) -> void:
	_selected_id = id
	_notice = ""
	for card_id in _cards:
		var card := _cards[card_id] as Button
		card.add_theme_stylebox_override("normal", V2.hospital_panel_style(V2.CYAN, card_id == id))
	_refresh_detail()
	if _is_compact():
		_compact_detail = true
		_layout()
		call_deferred("_focus_detail")


func _show_roster() -> void:
	_compact_detail = false
	_layout()
	call_deferred("_focus_entry")


func _request_action(action: String) -> void:
	var preview := OverworldState.get_hospital_preview(_selected_id)
	var allowed := bool(preview.get("can_admit" if action == "admit" else ("can_recover_now" if action == "recover" else "can_discharge"), false))
	if not allowed:
		return
	_pending_action = action
	if action == "admit":
		_confirmation.configure("ADMIT THIS DIGIMON?", "Timed recovery takes %s. This Digimon leaves the Party until discharged." % _format_duration(int(preview.get("recovery_seconds", 0))), "ADMIT", "CANCEL", V2.CYAN, "DIGI HOSPITAL")
	elif action == "recover":
		_confirmation.configure("RECOVER NOW?", "Spend %d Bits to fully restore HP? This Digimon remains in Hospital until discharged." % int(preview.get("instant_cost", 0)), "SPEND BITS", "CANCEL", V2.AMBER, "DIGI HOSPITAL")
	else:
		var destination := "Party" if OverworldState.get_active_instances().size() < OverworldState.get_max_active_party_size() else "Storage"
		_confirmation.configure("DISCHARGE THIS DIGIMON?", "Recovery is complete. Send this Digimon to %s?" % destination, "DISCHARGE", "CANCEL", V2.GREEN, "DIGI HOSPITAL")
	_confirmation.open_dialog(_actions[action])


func _confirm_action() -> void:
	var action := _pending_action
	_pending_action = ""
	var result: Dictionary = {}
	match action:
		"admit": result = OverworldState.admit_to_hospital(_selected_id)
		"recover": result = OverworldState.recover_from_hospital_now(_selected_id)
		"discharge": result = OverworldState.discharge_from_hospital(_selected_id)
	if bool(result.get("success", false)):
		_notice = "Treatment started." if action == "admit" else ("HP restored. Ready for discharge." if action == "recover" else "Discharged successfully.")
		_notice_color = V2.GREEN
	else:
		_notice = _failure_text(String(result.get("reason", "invalid")))
		_notice_color = V2.RED
	_refresh()


func _on_state_changed() -> void:
	if visible:
		_refresh()


func _on_account_rewards_changed(_bits: int, _data: Dictionary) -> void:
	if visible:
		_refresh()


func _on_hospital_state_changed(_id: String, _status: String) -> void:
	if visible:
		_refresh()


func _wire_focus() -> void:
	if _tab_buttons.is_empty():
		return
	var party := _tab_buttons["party"] as Button
	var hospital := _tab_buttons["hospital"] as Button
	party.focus_neighbor_right = hospital.get_path()
	hospital.focus_neighbor_left = party.get_path()
	var enabled: Array[Button] = []
	for key in ["admit", "recover", "discharge"]:
		var action := _actions[key] as Button
		if not action.disabled:
			enabled.append(action)
	for i in enabled.size():
		var action := enabled[i]
		action.focus_neighbor_top = (enabled[i - 1] if i > 0 else _card_order[0] if not _card_order.is_empty() else _detail_back).get_path()
		action.focus_neighbor_bottom = enabled[(i + 1) % enabled.size()].get_path()
		if not _card_order.is_empty():
			action.focus_neighbor_left = _card_order[0].get_path()
	for i in _card_order.size():
		var card := _card_order[i]
		card.focus_neighbor_top = (_card_order[i - 1] if i > 0 else _tab_buttons[_tab]).get_path()
		card.focus_neighbor_bottom = (_card_order[i + 1] if i + 1 < _card_order.size() else _page_next if not _page_next.disabled else _tab_buttons[_tab]).get_path()
		card.focus_neighbor_right = (enabled[0] if not enabled.is_empty() else _tab_buttons[_tab]).get_path()
		card.focus_neighbor_left = _tab_buttons[_tab].get_path()
	party.focus_neighbor_bottom = (_card_order[0] if not _card_order.is_empty() else _page_next).get_path()
	hospital.focus_neighbor_bottom = party.focus_neighbor_bottom
	_page_back.focus_neighbor_top = (_card_order.back() if not _card_order.is_empty() else party).get_path()
	_page_next.focus_neighbor_top = _page_back.focus_neighbor_top
	_page_back.focus_neighbor_right = _page_next.get_path()
	_page_next.focus_neighbor_left = _page_back.get_path()
	_detail_back.focus_neighbor_bottom = (enabled[0] if not enabled.is_empty() else _close_button).get_path()
	if not enabled.is_empty():
		enabled[0].focus_neighbor_top = _detail_back.get_path() if _is_compact() else enabled[0].focus_neighbor_top


func _focus_entry() -> void:
	if not visible or _confirmation.visible:
		return
	var card := _cards.get(_selected_id) as Button
	if card != null and card.is_visible_in_tree():
		card.grab_focus()
	else:
		(_tab_buttons[_tab] as Button).grab_focus()


func _focus_detail() -> void:
	if not visible or _confirmation.visible:
		return
	for key in ["admit", "recover", "discharge"]:
		var button := _actions[key] as Button
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return
	_detail_back.grab_focus()


func _is_compact() -> bool:
	var viewport_size := V2.physical_window_size(get_viewport())
	return viewport_size.x < 980.0 or viewport_size.y < 600.0


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


func _button(parent: Node, node_name: String, title: String, accent: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = title
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", V2.WHITE)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", V2.MUTED)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, V2.hospital_button_style(accent, state))
	V2.apply_heading(button)
	parent.add_child(button)
	return button


func _label(parent: Node, value: String, font_size: int, color: Color, heading: bool, pos: Vector2, dimensions: Vector2) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = dimensions
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


func _progress(parent: Node, node_name: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", V2.progress_track_style())
	bar.add_theme_stylebox_override("fill", V2.progress_fill_style(V2.GREEN, true))
	parent.add_child(bar)
	return bar


func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(maxf(0.0, w), maxf(0.0, h))
