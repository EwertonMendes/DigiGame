extends Control
class_name HospitalScreen

signal close_requested

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const ModalHeaderScript = preload("res://src/ui/components/DigiModalHeader.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const ConfirmationModalScript = preload("res://src/ui/components/DigiConfirmationModal.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const SmoothScrollScript = preload("res://src/ui/SmoothScrollBehavior.gd")
const CHANGE_ICON := preload("res://assets/ui/icons/hp_change_arrow.svg")

const FRAME_MAX_WIDTH := 1380.0
const FRAME_MAX_HEIGHT := 850.0
const HEADER_HEIGHT := 60.0
const HINT_HEIGHT := 50.0

var _database: DigimonDatabase
var _selected_id := ""
var _pending_action := ""
var _notice_text := "Select a Digimon to review its condition."
var _notice_color := V2.CYAN
var _clock_accumulator := 0.0

var _frame: PanelContainer
var _content_root: Control
var _header: DigiModalHeader
var _hint_bar: DigiInputHintBar
var _collection_panel: PanelContainer
var _collection_scroll: ScrollContainer
var _collection_list: GridContainer
var _collection_header: DigiSectionHeader
var _detail_panel: PanelContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _confirmation: DigiConfirmationModal
var _collection_buttons: Dictionary = {}
var _status_labels: Dictionary = {}
var _countdown_labels: Dictionary = {}
var _detail_countdown: Label
var _admit_button: Button
var _recover_button: Button
var _discharge_button: Button


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
	_ensure_visible_selection()
	_notice_text = "Select a Party member to admit, or a Hospital patient to review."
	_notice_color = V2.CYAN
	visible = true
	set_process(true)
	_clock_accumulator = 0.0
	_header.set_bits(OverworldState.get_bits())
	_layout()
	_refresh()
	call_deferred("_layout")
	call_deferred("_focus_selected")


func close_view() -> void:
	if _confirmation != null and _confirmation.visible:
		_confirmation.close_dialog(false)
	_pending_action = ""
	visible = false
	set_process(false)
	close_requested.emit()


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		return
	_clock_accumulator += delta
	if _clock_accumulator < 0.25:
		return
	_clock_accumulator = 0.0
	OverworldState.process_hospital_recoveries()
	_refresh_live_status()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (_confirmation != null and _confirmation.visible):
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		close_view()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = V2.BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_frame = PanelContainer.new()
	_frame.name = "HospitalV2"
	_frame.clip_contents = true
	_frame.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.BACKDROP.r, V2.BACKDROP.g, V2.BACKDROP.b, 1.0), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.52), 10, Vector4.ZERO, 0.18))
	add_child(_frame)

	_content_root = Control.new()
	_content_root.name = "HospitalContent"
	_content_root.clip_contents = true
	_frame.add_child(_content_root)

	_header = ModalHeaderScript.new() as DigiModalHeader
	_header.name = "HospitalHeader"
	_header.configure("DIGI HOSPITAL", "Recovery and Care", OverworldState.get_bits(), true)
	_header.configure_tabs([], "")
	_header.close_requested.connect(close_view)
	_content_root.add_child(_header)

	_build_collection_panel()
	_build_detail_panel()

	_hint_bar = InputHintBarScript.new() as DigiInputHintBar
	_hint_bar.name = "HospitalInputHints"
	_hint_bar.set_description("Party members can be admitted. Recovered patients stay in Hospital until you discharge them.")
	_content_root.add_child(_hint_bar)

	_confirmation = ConfirmationModalScript.new() as DigiConfirmationModal
	_confirmation.name = "HospitalConfirmation"
	_confirmation.confirmed.connect(_confirm_pending_action)
	_confirmation.cancelled.connect(_cancel_pending_action)
	add_child(_confirmation)


func _build_collection_panel() -> void:
	_collection_panel = PanelContainer.new()
	_collection_panel.name = "HospitalRoster"
	_collection_panel.clip_contents = true
	_collection_panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.72), 8))
	_content_root.add_child(_collection_panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	_collection_panel.add_child(root)

	_collection_header = SectionHeaderScript.new() as DigiSectionHeader
	_collection_header.configure("PARTY & HOSPITAL", "", V2.CYAN, "heart")
	root.add_child(_collection_header)

	var intro_margin := _margin(12, 9, 12, 7)
	root.add_child(intro_margin)
	var intro := _label("Only current Party members can be admitted. Storage Digimon are not shown.", 10, V2.MUTED, false)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_margin.add_child(intro)

	var scroll_margin := _margin(8, 2, 5, 8)
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll_margin)

	_collection_scroll = ScrollContainer.new()
	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_collection_scroll.follow_focus = true
	_collection_scroll.scroll_deadzone = 8
	_collection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_collection_scroll)
	SmoothScrollScript.attach(_collection_scroll)

	_collection_list = GridContainer.new()
	_collection_list.columns = 1
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("h_separation", 8)
	_collection_list.add_theme_constant_override("v_separation", 8)
	_collection_scroll.add_child(_collection_list)


func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "HospitalDetails"
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.BORDER.r, V2.BORDER.g, V2.BORDER.b, 0.68), 8))
	_content_root.add_child(_detail_panel)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 0)
	_detail_panel.add_child(outer)

	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure("TREATMENT", "INDIVIDUAL CARE", V2.GREEN, "heart")
	outer.add_child(header)

	var scroll_margin := _margin(12, 10, 8, 10)
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll_margin)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_detail_scroll.follow_focus = true
	_detail_scroll.scroll_deadzone = 8
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_detail_scroll)
	SmoothScrollScript.attach(_detail_scroll)

	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	_detail_scroll.add_child(_detail)


func _refresh() -> void:
	_header.set_bits(OverworldState.get_bits())
	_ensure_visible_selection()
	_refresh_collection()
	_refresh_detail()


func _visible_roster() -> Array[DigimonInstance]:
	var result: Array[DigimonInstance] = []
	for instance: DigimonInstance in OverworldState.get_active_instances():
		result.append(instance)
	for instance: DigimonInstance in OverworldState.get_hospital_instances():
		result.append(instance)
	return result


func _ensure_visible_selection() -> void:
	var roster := _visible_roster()
	var still_visible := false
	for instance: DigimonInstance in roster:
		if instance.id == _selected_id:
			still_visible = true
			break
	if still_visible:
		return
	_selected_id = roster[0].id if not roster.is_empty() else ""


func _refresh_collection() -> void:
	for child in _collection_list.get_children():
		child.queue_free()
	_collection_buttons.clear()
	_status_labels.clear()
	_countdown_labels.clear()
	var party := OverworldState.get_active_instances()
	var hospital := OverworldState.get_hospital_instances()
	_collection_header.set_trailing("%d PARTY · %d HOSPITAL" % [party.size(), hospital.size()])
	_add_roster_group("PARTY", party, "No Digimon are currently in your Party.")
	_add_roster_group("HOSPITAL", hospital, "No Digimon are currently admitted.")


func _add_roster_group(title: String, instances: Array[DigimonInstance], empty_text: String) -> void:
	var heading := _label(title, 10, V2.CYAN if title == "PARTY" else V2.GREEN, true)
	heading.custom_minimum_size.y = 24.0
	_collection_list.add_child(heading)
	if instances.is_empty():
		var empty := _label(empty_text, 10, V2.MUTED, false)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size.y = 32.0
		_collection_list.add_child(empty)
		return
	for instance: DigimonInstance in instances:
		_add_patient_card(instance)


func _add_patient_card(instance: DigimonInstance) -> void:
	var species := _database.get_by_seed(instance.species_seed)
	var species_name := String(species.get("name", instance.species_seed))
	var display_name := instance.get_display_name(species_name)
	var preview := OverworldState.get_hospital_preview(instance.id)
	var accent := _status_color(String(preview.get("status", "healthy")))
	var location := String(preview.get("location", ""))

	var card := Button.new()
	card.name = "Patient_%s" % instance.id
	card.custom_minimum_size = Vector2(0.0, 92.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.pressed.connect(_select_instance.bind(instance.id))
	_style_patient_button(card, instance.id == _selected_id, accent)
	_collection_list.add_child(card)
	_collection_buttons[instance.id] = card

	var margin := _margin(10, 8, 10, 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview_box := PanelContainer.new()
	preview_box.custom_minimum_size = Vector2(72.0, 72.0)
	preview_box.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.9), Color(accent.r, accent.g, accent.b, 0.32), 7))
	preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview_box)
	var walk := WalkPreviewScript.new() as DigimonWalkPreview
	walk.name = "DigimonWalkPreview"
	walk.custom_minimum_size = Vector2(68.0, 68.0)
	walk.set_species(species_name)
	walk.set_active(instance.id == _selected_id)
	preview_box.add_child(walk)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name_label := _label(display_name, 13, V2.TEXT, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(name_label)
	copy.add_child(_label("Lv. %d  ·  HP %d / %d" % [instance.level, int(preview.get("current_hp", 0)), int(preview.get("max_hp", 1))], 10, V2.MUTED, false))
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 7)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(status_row)
	status_row.add_child(_label(location.to_upper(), 9, V2.SUBTLE, true))
	var status := _label(_status_text(preview), 10, accent, true)
	status_row.add_child(status)
	_status_labels[instance.id] = status
	var countdown := _label(_countdown_text(preview), 10, V2.MUTED, false)
	status_row.add_child(countdown)
	_countdown_labels[instance.id] = countdown


func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	_detail_countdown = null
	_admit_button = null
	_recover_button = null
	_discharge_button = null
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null or not _collection_buttons.has(_selected_id):
		_detail.add_child(_empty_state("No Party or Hospital Digimon are available."))
		return
	var species := _database.get_by_seed(instance.species_seed)
	var species_name := String(species.get("name", instance.species_seed))
	var display_name := instance.get_display_name(species_name)
	var preview := OverworldState.get_hospital_preview(instance.id)
	var status_key := String(preview.get("status", "healthy"))
	var location := String(preview.get("location", ""))
	var accent := _status_color(status_key)

	var notice := PanelContainer.new()
	notice.add_theme_stylebox_override("panel", V2.surface_style(Color(_notice_color.r, _notice_color.g, _notice_color.b, 0.08), Color(_notice_color.r, _notice_color.g, _notice_color.b, 0.38), 7, Vector4(12, 8, 12, 8)))
	var notice_label := _label(_notice_text, 10, _notice_color, false)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_child(notice_label)
	_detail.add_child(notice)

	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", V2.surface_style(Color(V2.SURFACE.r, V2.SURFACE.g, V2.SURFACE.b, 0.86), Color(accent.r, accent.g, accent.b, 0.42), 8, Vector4(14, 12, 14, 12), 0.08))
	_detail.add_child(hero)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 18)
	hero.add_child(hero_row)
	var portrait := PortraitPreviewScript.new() as DigimonPortraitPreview
	portrait.custom_minimum_size = Vector2(150.0, 142.0)
	portrait.set_species(species_name)
	hero_row.add_child(portrait)
	var hero_copy := VBoxContainer.new()
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_copy.add_theme_constant_override("separation", 5)
	hero_row.add_child(hero_copy)
	hero_copy.add_child(_label(display_name, 24, V2.WHITE, true))
	hero_copy.add_child(_label("%s  ·  Level %d  ·  Tier %s  ·  %s" % [String(species.get("rank", "Unknown")), instance.level, instance.tier, location.to_upper()], 11, V2.MUTED, false))
	hero_copy.add_child(_status_pill(_status_text(preview), accent))

	var health_section := _section("HEALTH", V2.GREEN, "heart")
	_detail.add_child(health_section)
	var health_body := health_section.get_meta("body") as VBoxContainer
	var hp_transition := HBoxContainer.new()
	hp_transition.add_theme_constant_override("separation", 8)
	hp_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_body.add_child(hp_transition)
	hp_transition.add_child(_label("%d / %d" % [int(preview.get("current_hp", 0)), int(preview.get("max_hp", 1))], 18, V2.TEXT, true))
	var hp_arrow := TextureRect.new()
	hp_arrow.texture = CHANGE_ICON
	hp_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hp_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hp_arrow.custom_minimum_size = Vector2(18.0, 18.0)
	hp_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_arrow.modulate = V2.CYAN
	hp_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_transition.add_child(hp_arrow)
	hp_transition.add_child(_label("%d / %d" % [int(preview.get("max_hp", 1)), int(preview.get("max_hp", 1))], 18, V2.TEXT, true))
	health_body.add_child(_progress(V2.GREEN, int(preview.get("max_hp", 1)), int(preview.get("current_hp", 0))))
	health_body.add_child(_label("%d%% HP missing" % int(round(float(preview.get("missing_hp_ratio", 0.0)) * 100.0)), 10, V2.MUTED, false))

	var treatment_section := _section("RECOVERY OPTIONS", V2.CYAN, "spark")
	_detail.add_child(treatment_section)
	var treatment_body := treatment_section.get_meta("body") as VBoxContainer
	var comparison := GridContainer.new()
	comparison.columns = 2
	comparison.add_theme_constant_override("h_separation", 12)
	comparison.add_theme_constant_override("v_separation", 6)
	treatment_body.add_child(comparison)
	comparison.add_child(_label("RECOVERY TIME", 10, V2.MUTED, true))
	comparison.add_child(_label("INSTANT RECOVERY", 10, V2.MUTED, true))
	_detail_countdown = _label(_detail_time_text(preview), 18, V2.CYAN, true)
	comparison.add_child(_detail_countdown)
	comparison.add_child(_label("%d Bits" % int(preview.get("instant_cost", 0)), 18, V2.AMBER, true))

	var actions := GridContainer.new()
	actions.columns = 1 if _frame.size.x < 760.0 else 3
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	treatment_body.add_child(actions)
	_admit_button = _action_button("ADMIT · FREE", V2.CYAN)
	_admit_button.disabled = not bool(preview.get("can_admit", false))
	if location == PlayerCollection.LOCATION_HOSPITAL:
		_admit_button.text = "IN HOSPITAL"
	_admit_button.pressed.connect(_request_admission)
	actions.add_child(_admit_button)
	_recover_button = _action_button("RECOVER NOW · %d BITS" % int(preview.get("instant_cost", 0)), V2.AMBER)
	_recover_button.disabled = not bool(preview.get("can_recover_now", false))
	_recover_button.pressed.connect(_request_instant_recovery)
	actions.add_child(_recover_button)
	_discharge_button = _action_button("DISCHARGE", V2.GREEN)
	_discharge_button.disabled = not bool(preview.get("can_discharge", false))
	_discharge_button.pressed.connect(_request_discharge)
	actions.add_child(_discharge_button)

	var rule_copy := "Party Digimon can be admitted for free timed recovery or moved into Hospital for immediate paid recovery."
	if location == PlayerCollection.LOCATION_HOSPITAL and status_key == "recovering":
		rule_copy = "This Digimon is recovering from persistent timestamps, including while the game is closed. It stays out of the Party until discharged."
	elif location == PlayerCollection.LOCATION_HOSPITAL and status_key == "ready":
		rule_copy = "Recovery is complete. This Digimon remains in Hospital until you discharge it. It will return to Party if there is room, otherwise to Storage."
	elif status_key == "healthy":
		rule_copy = "This Party Digimon is already at full HP and does not need treatment."
	elif int(preview.get("instant_cost", 0)) > OverworldState.get_bits():
		rule_copy += " You need more Bits for immediate recovery."
	var rule := _label(rule_copy, 10, V2.MUTED, false)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	treatment_body.add_child(rule)


func _refresh_live_status() -> void:
	for raw_id in _status_labels.keys():
		var instance_id := String(raw_id)
		var preview := OverworldState.get_hospital_preview(instance_id)
		var status := _status_labels.get(instance_id) as Label
		var countdown := _countdown_labels.get(instance_id) as Label
		if status != null:
			status.text = _status_text(preview)
			status.add_theme_color_override("font_color", _status_color(String(preview.get("status", "healthy"))))
		if countdown != null:
			countdown.text = _countdown_text(preview)
	if _detail_countdown != null:
		_detail_countdown.text = _detail_time_text(OverworldState.get_hospital_preview(_selected_id))


func _select_instance(instance_id: String) -> void:
	if _selected_id == instance_id:
		return
	_selected_id = instance_id
	_notice_text = "Review the available treatment options."
	_notice_color = V2.CYAN
	_refresh()
	call_deferred("_focus_selected")


func _request_admission() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	var preview := OverworldState.get_hospital_preview(_selected_id)
	if instance == null or not bool(preview.get("can_admit", false)):
		return
	_pending_action = "admit"
	_confirmation.configure(
		"ADMIT THIS DIGIMON?",
		"Recovery will take %s. This Digimon will leave the Party immediately and remain in Hospital until you discharge it after recovery." % _format_duration(int(preview.get("recovery_seconds", 0))),
		"ADMIT",
		"NOT NOW",
		V2.CYAN,
		"DIGI HOSPITAL"
	)
	_confirmation.open_dialog(_admit_button)


func _request_instant_recovery() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	var preview := OverworldState.get_hospital_preview(_selected_id)
	if instance == null or not bool(preview.get("can_recover_now", false)):
		return
	_pending_action = "recover_now"
	_confirmation.configure(
		"RECOVER NOW?",
		"Spend %d Bits to restore this Digimon from %d / %d HP to full health immediately? It will remain in Hospital until discharged." % [int(preview.get("instant_cost", 0)), int(preview.get("current_hp", 0)), int(preview.get("max_hp", 1))],
		"SPEND BITS",
		"NOT NOW",
		V2.AMBER,
		"CONFIRM TREATMENT"
	)
	_confirmation.open_dialog(_recover_button)


func _request_discharge() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	var preview := OverworldState.get_hospital_preview(_selected_id)
	if instance == null or not bool(preview.get("can_discharge", false)):
		return
	var destination := "Party" if OverworldState.get_active_instances().size() < OverworldState.get_max_active_party_size() else "Storage"
	_pending_action = "discharge"
	_confirmation.configure(
		"DISCHARGE THIS DIGIMON?",
		"Recovery is complete. This Digimon will be sent to %s." % destination,
		"DISCHARGE",
		"NOT NOW",
		V2.GREEN,
		"DIGI HOSPITAL"
	)
	_confirmation.open_dialog(_discharge_button)


func _confirm_pending_action() -> void:
	var action := _pending_action
	_pending_action = ""
	var result: Dictionary = {}
	if action == "admit":
		result = OverworldState.admit_to_hospital(_selected_id)
	elif action == "recover_now":
		result = OverworldState.recover_from_hospital_now(_selected_id)
	elif action == "discharge":
		result = OverworldState.discharge_from_hospital(_selected_id)
	if bool(result.get("success", false)):
		if action == "admit":
			_notice_text = "Treatment started. The Digimon has left the Party and is now in Hospital."
		elif action == "recover_now":
			_notice_text = "Recovery complete. HP restored; the Digimon is ready for discharge."
		else:
			var destination := String(result.get("destination", "storage"))
			_notice_text = "Discharged successfully to %s." % ("Party" if destination == PlayerCollection.LOCATION_PARTY else "Storage")
		_notice_color = V2.GREEN
	else:
		_notice_text = _failure_text(String(result.get("reason", "invalid")))
		_notice_color = V2.RED
	_refresh()


func _cancel_pending_action() -> void:
	_pending_action = ""


func _on_state_changed() -> void:
	if visible:
		_refresh()


func _on_account_rewards_changed(_bits: int, _digi_data: Dictionary) -> void:
	if visible:
		_refresh()


func _on_hospital_state_changed(_instance_id: String, _status: String) -> void:
	if visible:
		_refresh()


func _layout() -> void:
	if _frame == null:
		return
	var physical := V2.physical_window_size(get_viewport())
	var scale_factor := V2.ui_scale(get_viewport())
	var compact := V2.is_compact(get_viewport(), 900.0)
	var margin := 12.0 if compact else 18.0
	var width := minf(FRAME_MAX_WIDTH, physical.x - margin * 2.0)
	var height := minf(FRAME_MAX_HEIGHT, physical.y - margin * 2.0)
	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = Vector2((physical.x - width) * 0.5, (physical.y - height) * 0.5) * scale_factor
	_frame.size = Vector2(width, height)
	_content_root.position = Vector2.ZERO
	_content_root.size = Vector2(width, height)
	_header.position = Vector2.ZERO
	_header.size = Vector2(width, HEADER_HEIGHT)
	_hint_bar.position = Vector2(0.0, height - HINT_HEIGHT)
	_hint_bar.size = Vector2(width, HINT_HEIGHT)

	var content_y := HEADER_HEIGHT + 10.0
	var content_h := height - content_y - HINT_HEIGHT - 10.0
	var stacked := compact or width < 920.0
	if stacked:
		var list_h := clampf(content_h * 0.38, 190.0, 300.0)
		_collection_panel.position = Vector2(10.0, content_y)
		_collection_panel.size = Vector2(width - 20.0, list_h)
		_detail_panel.position = Vector2(10.0, content_y + list_h + 10.0)
		_detail_panel.size = Vector2(width - 20.0, content_h - list_h - 10.0)
	else:
		var list_w := clampf(width * 0.30, 330.0, 410.0)
		_collection_panel.position = Vector2(12.0, content_y)
		_collection_panel.size = Vector2(list_w, content_h)
		_detail_panel.position = Vector2(24.0 + list_w, content_y)
		_detail_panel.size = Vector2(width - list_w - 36.0, content_h)
	_collection_list.columns = 1


func _section(title: String, accent: Color, icon: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(accent.r, accent.g, accent.b, 0.30), 8))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)
	var header := SectionHeaderScript.new() as DigiSectionHeader
	header.configure(title, "", accent, icon)
	stack.add_child(header)
	var margin := _margin(12, 10, 12, 12)
	stack.add_child(margin)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	panel.set_meta("body", body)
	return panel


func _status_pill(text_value: String, accent: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_theme_stylebox_override("panel", V2.pill_style(accent, true))
	var label := _label(text_value, 10, accent, true)
	label.custom_minimum_size = Vector2(104.0, 30.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(label)
	return pill


func _progress(accent: Color, maximum: int, value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxf(1, maximum)
	bar.value = clampi(value, 0, maxi(1, maximum))
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", V2.progress_track_style())
	bar.add_theme_stylebox_override("fill", V2.progress_fill_style(accent, true))
	return bar


func _action_button(text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = V2.TOUCH_TARGET
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_pressed_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", V2.SUBTLE)
	button.add_theme_stylebox_override("normal", V2.button_style(accent, "normal", 7))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 7))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus", 7))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 7))
	button.add_theme_stylebox_override("disabled", V2.button_style(accent, "disabled", 7))
	V2.apply_heading(button)
	return button


func _style_patient_button(button: Button, selected: bool, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", V2.outlined_surface(accent, selected, 7))
	button.add_theme_stylebox_override("hover", V2.button_style(accent, "hover", 7))
	button.add_theme_stylebox_override("focus", V2.button_style(accent, "focus", 7))
	button.add_theme_stylebox_override("pressed", V2.button_style(accent, "pressed", 7))


func _status_text(preview: Dictionary) -> String:
	var status := String(preview.get("status", "healthy"))
	match status:
		"injured": return "INJURED"
		"critical": return "CRITICAL"
		"recovering": return "RECOVERING"
		"ready": return "READY FOR DISCHARGE"
		"unavailable": return "UNAVAILABLE"
		_: return "HEALTHY"


func _status_color(status: String) -> Color:
	match status:
		"injured": return V2.AMBER
		"critical": return V2.RED
		"recovering": return V2.CYAN
		"ready": return V2.GREEN
		"unavailable": return V2.MUTED
		_: return V2.GREEN


func _countdown_text(preview: Dictionary) -> String:
	return _format_duration(int(preview.get("remaining_seconds", 0))) if String(preview.get("status", "")) == "recovering" else ""


func _detail_time_text(preview: Dictionary) -> String:
	var status := String(preview.get("status", ""))
	if status == "recovering":
		return _format_duration(int(preview.get("remaining_seconds", 0))) + " remaining"
	if status == "ready":
		return "Complete"
	var seconds := int(preview.get("recovery_seconds", 0))
	return _format_duration(seconds) if seconds > 0 else "Not required"


func _format_duration(total_seconds: int) -> String:
	var normalized := maxi(0, total_seconds)
	var hours := int(normalized / 3600)
	var minutes := int((normalized % 3600) / 60)
	var seconds := normalized % 60
	return "%d:%02d:%02d" % [hours, minutes, seconds] if hours > 0 else "%02d:%02d" % [minutes, seconds]


func _failure_text(reason: String) -> String:
	match reason:
		"healthy": return "This Digimon is already healthy."
		"already_recovering": return "This Digimon is already recovering."
		"already_ready": return "This Digimon is already recovered and ready for discharge."
		"insufficient_bits": return "You do not have enough Bits for immediate recovery."
		"not_in_party": return "Only Digimon currently in your Party can be admitted."
		"not_in_party_or_hospital": return "This Digimon is not available for Hospital treatment."
		"still_recovering": return "This Digimon is still recovering and cannot be discharged yet."
		_: return "The Hospital operation could not be completed."


func _focus_selected() -> void:
	var button := _collection_buttons.get(_selected_id) as Button
	if button != null and button.visible and not button.disabled:
		button.grab_focus()


func _empty_state(text_value: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 120.0
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(V2.MUTED.r, V2.MUTED.g, V2.MUTED.b, 0.30), 8))
	var label := _label(text_value, 12, V2.MUTED, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel


func _label(text_value: String, font_size: int, color: Color, heading: bool) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading:
		V2.apply_heading(label)
	else:
		V2.apply_reading(label)
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin