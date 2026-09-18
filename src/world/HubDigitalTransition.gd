extends "res://src/world/HubHospitalGameplay.gd"

const BattleOperatorCatalogScript = preload("res://src/world/BattleOperatorEncounterCatalog.gd")
const EncounterDefinitionScript = preload("res://src/world/BattleEncounterDefinition.gd")
const BattlefieldCatalogScript = preload("res://src/world/BattlefieldCatalog.gd")
const AnalogGateScript = preload("res://src/ui/components/DigiAnalogNavigationGate.gd")
const CommandButtonScript = preload("res://src/ui/components/DigiCommandButton.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

const PROGRAM_IDS: Array[String] = [
	"basic",
	"random_fresh",
	"random_baby",
	"random_rookie",
	"random_champion",
	"random_ultimate",
	"random_mega",
]
const PROGRAM_ORDER: Array[String] = [
	"basic",
	"random_fresh",
	"random_baby",
	"random_rookie",
	"random_champion",
	"random_ultimate",
	"random_mega",
	"cancel",
]
const SECTION_PROGRAM := "program"
const SECTION_FIELD := "field"

var _battle_catalog := BattleOperatorCatalogScript.new() as BattleOperatorEncounterCatalog
var _field_catalog := BattlefieldCatalogScript.new() as BattlefieldCatalog
var _battle_program_rng := RandomNumberGenerator.new()
var _battle_program_buttons: Dictionary = {}
var _battlefield_buttons: Dictionary = {}
var _field_order: Array[String] = []
var _selected_program_id := "basic"
var _selected_battlefield_id := ""
var _operator_section := SECTION_PROGRAM
var _battle_program_hint: Label = null
var _program_heading: Label = null
var _field_heading: Label = null
var _program_container: Control = null
var _field_container: Control = null
var _program_tab: Button = null
var _field_tab: Button = null
var _selection_panel: PanelContainer = null
var _selection_summary: Label = null
var _input_hint_bar: DigiInputHintBar = null
var _battle_program_columns := 2
var _battlefield_columns := 2
var _compact_operator_layout := false
var _left_analog_gate: DigiAnalogNavigationGate = AnalogGateScript.new() as DigiAnalogNavigationGate
var _right_analog_gate: DigiAnalogNavigationGate = AnalogGateScript.new() as DigiAnalogNavigationGate


func _ready() -> void:
	_battle_program_rng.randomize()
	_field_catalog.load_default()
	super._ready()
	MusicDirector.play_zone_1()


func _build_dialog() -> void:
	super._build_dialog()
	if _mobile_dialog_content == null or _start_battle_button == null or _mobile_dialog_cancel == null:
		return

	if not _field_catalog.load_default():
		for error in _field_catalog.validation_errors():
			push_error("Battle Operator battlefield catalog: %s" % error)

	_dialog_panel.call("configure_glass", HUB_V2.CYAN, "modal", Vector4.ZERO, 14)
	_mobile_dialog_title.text = "BATTLE OPERATOR"
	_mobile_dialog_body.text = "CONFIGURE TEST BATTLE"
	_start_battle_button.text = "START BATTLE"
	_start_battle_button.tooltip_text = "Launch the selected battle program on the selected battlefield."
	_start_battle_button.set_meta("operator_kind", "action")
	_start_battle_button.set_meta("operator_id", "launch")
	_apply_v2_dialog_button(_start_battle_button, HUB_V2.AMBER)

	_mobile_dialog_cancel.text = "CLOSE"
	_mobile_dialog_cancel.tooltip_text = "Close the Battle Operator without starting combat."
	_mobile_dialog_cancel.set_meta("battle_program_id", "cancel")
	_mobile_dialog_cancel.set_meta("operator_kind", "action")
	_mobile_dialog_cancel.set_meta("operator_id", "cancel")
	_apply_v2_dialog_button(_mobile_dialog_cancel, HUB_V2.MUTED)
	_battle_program_buttons["cancel"] = _mobile_dialog_cancel

	_battle_program_hint = _label(
		"Choose an opponent program and an authored battlefield. This build is intended for mechanics testing.",
		11,
		HUB_V2.MUTED
	)
	_battle_program_hint.name = "OperatorHint"
	_battle_program_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_battle_program_hint.max_lines_visible = 2
	_mobile_dialog_content.add_child(_battle_program_hint)

	_build_section_tabs()
	_build_program_workspace()
	_build_battlefield_workspace()
	_build_selection_summary()
	_build_input_hints()
	_refresh_operator_state()
	_wire_operator_focus()


func _build_section_tabs() -> void:
	_program_tab = _dialog_button("PROGRAM", HUB_V2.AMBER)
	_program_tab.name = "ProgramTab"
	_program_tab.set_meta("operator_kind", "tab")
	_program_tab.set_meta("operator_id", SECTION_PROGRAM)
	_program_tab.pressed.connect(_set_operator_section.bind(SECTION_PROGRAM, false))
	_mobile_dialog_content.add_child(_program_tab)

	_field_tab = _dialog_button("FIELD", HUB_V2.CYAN)
	_field_tab.name = "FieldTab"
	_field_tab.set_meta("operator_kind", "tab")
	_field_tab.set_meta("operator_id", SECTION_FIELD)
	_field_tab.pressed.connect(_set_operator_section.bind(SECTION_FIELD, false))
	_mobile_dialog_content.add_child(_field_tab)


func _build_program_workspace() -> void:
	_program_heading = _label("BATTLE PROGRAM", 11, HUB_V2.CYAN)
	_program_heading.name = "ProgramHeading"
	HUB_V2.apply_heading(_program_heading)
	_mobile_dialog_content.add_child(_program_heading)

	_program_container = Control.new()
	_program_container.name = "ProgramWorkspace"
	_program_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_dialog_content.add_child(_program_container)

	_add_program_card(
		"basic",
		"BASIC BATTLE",
		"Koromon, Tanemon and Veemon. Fixed low-level baseline encounter.",
		"MIXED",
		"sword",
		HUB_V2.CYAN
	)
	_add_program_card("random_fresh", "RANDOM FRESH", "Three verified Fresh Digimon scaled to your squad.", "FRESH", "spark", HUB_V2.CYAN)
	_add_program_card("random_baby", "RANDOM BABY", "Three verified In-Training Digimon scaled to your squad.", "IN-TRAINING", "spark", HUB_V2.BLUE)
	_add_program_card("random_rookie", "RANDOM ROOKIE", "Three verified Rookie Digimon scaled to your squad.", "ROOKIE", "sword", HUB_V2.GREEN)
	_add_program_card("random_champion", "RANDOM CHAMPION", "Three verified Champion Digimon scaled to your squad.", "CHAMPION", "shield", HUB_V2.AMBER)
	_add_program_card("random_ultimate", "RANDOM ULTIMATE", "Three verified Ultimate Digimon scaled to your squad.", "ULTIMATE", "bolt", HUB_V2.RED)
	_add_program_card("random_mega", "RANDOM MEGA", "Three verified Mega Digimon scaled to your squad.", "MEGA", "evolution", HUB_V2.PURPLE)


func _add_program_card(
	program_id: String,
	title: String,
	subtitle: String,
	status: String,
	icon_kind: String,
	accent: Color
) -> void:
	var button := CommandButtonScript.new() as DigiCommandButton
	button.name = _program_button_name(program_id)
	button.configure(title, subtitle, status, icon_kind, accent)
	button.set_meta("battle_program_id", program_id)
	button.set_meta("operator_kind", "program")
	button.set_meta("operator_id", program_id)
	button.pressed.connect(_select_battle_program.bind(program_id))
	_program_container.add_child(button)
	_battle_program_buttons[program_id] = button


func _build_battlefield_workspace() -> void:
	_field_heading = _label("BATTLEFIELD", 11, HUB_V2.CYAN)
	_field_heading.name = "FieldHeading"
	HUB_V2.apply_heading(_field_heading)
	_mobile_dialog_content.add_child(_field_heading)

	_field_container = Control.new()
	_field_container.name = "FieldWorkspace"
	_field_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_dialog_content.add_child(_field_container)

	_field_order.clear()
	for definition: BattlefieldDefinition in _field_catalog.all_definitions():
		_field_order.append(definition.battlefield_id)
		var button := CommandButtonScript.new() as DigiCommandButton
		button.name = "Field_%s" % definition.battlefield_id
		button.configure(
			definition.display_name.to_upper(),
			definition.description,
			_field_card_status(definition, false),
			"move",
			_field_accent(definition)
		)
		button.set_meta("operator_kind", "field")
		button.set_meta("operator_id", definition.battlefield_id)
		button.pressed.connect(_select_battlefield.bind(definition.battlefield_id))
		_field_container.add_child(button)
		_battlefield_buttons[definition.battlefield_id] = button

	var default_field := _field_catalog.default_definition()
	if default_field != null:
		_selected_battlefield_id = default_field.battlefield_id
	elif not _field_order.is_empty():
		_selected_battlefield_id = _field_order[0]


func _build_selection_summary() -> void:
	_selection_panel = GlassPanelScript.new() as PanelContainer
	_selection_panel.name = "SelectionSummary"
	_selection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_panel.call("configure_glass", HUB_V2.CYAN, "subtle", Vector4(16, 8, 16, 8), 10)
	_mobile_dialog_content.add_child(_selection_panel)

	_selection_summary = _label("", 11, HUB_V2.TEXT)
	_selection_summary.name = "SelectionSummaryText"
	_selection_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selection_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_panel.add_child(_selection_summary)


func _build_input_hints() -> void:
	_input_hint_bar = InputHintBarScript.new() as DigiInputHintBar
	_input_hint_bar.name = "OperatorInputHints"
	_input_hint_bar.set_description("Choose a program and battlefield, then start the simulation.")
	_input_hint_bar.set_scroll_hint_enabled(false)
	_input_hint_bar.set_secondary_tabs_enabled(false)
	_input_hint_bar.set_pagination_enabled(false)
	_mobile_dialog_content.add_child(_input_hint_bar)


func _open_dialog() -> void:
	_left_analog_gate.reset()
	_right_analog_gate.reset()
	super._open_dialog()
	if not _dialog_open:
		return
	_refresh_operator_state()
	if _mobile_dialog_cancel != null and not _mobile_dialog_cancel.disabled:
		_mobile_dialog_cancel.grab_focus()


func _refresh_operator_state() -> void:
	var party_error := OverworldState.battle_party_validation_error()
	_refresh_battle_program_availability()
	_refresh_battlefield_availability()
	_refresh_program_cards()
	_refresh_field_cards()
	_refresh_selection_summary()
	_refresh_launch_state(party_error)


func _refresh_battle_program_availability() -> void:
	var database: DigimonDatabase = OverworldState.get_database() as DigimonDatabase
	_battle_catalog.prepare(database)
	for program_id: String in PROGRAM_IDS:
		var button := _battle_program_buttons.get(program_id) as DigiCommandButton
		if button == null:
			continue
		if program_id == "basic":
			button.set_interactive(true)
			continue
		var rank := _rank_for_program(program_id)
		var available := _battle_catalog.ready_count(rank, database)
		button.set_interactive(available >= BattleOperatorEncounterCatalog.ENEMY_COUNT)


func _refresh_battlefield_availability() -> void:
	var player_footprints := _player_footprints()
	var enemy_footprints: Array = [FootprintScript.SINGLE, FootprintScript.SINGLE, FootprintScript.SINGLE]
	var first_compatible := ""
	for battlefield_id: String in _field_order:
		var definition := _field_catalog.get_by_id(battlefield_id)
		var button := _battlefield_buttons.get(battlefield_id) as DigiCommandButton
		if definition == null or button == null:
			continue
		var compatible := definition.supports_teams(player_footprints, enemy_footprints)
		button.set_interactive(compatible)
		if compatible and first_compatible.is_empty():
			first_compatible = battlefield_id

	var selected_button := _battlefield_buttons.get(_selected_battlefield_id) as DigiCommandButton
	if selected_button != null and selected_button.disabled and not first_compatible.is_empty():
		_selected_battlefield_id = first_compatible


func _refresh_program_cards() -> void:
	for program_id: String in PROGRAM_IDS:
		var button := _battle_program_buttons.get(program_id) as DigiCommandButton
		if button == null:
			continue
		var selected := program_id == _selected_program_id
		var spec := _program_spec(program_id)
		var status := "SELECTED" if selected else String(spec.get("status", ""))
		if button.disabled:
			status = "UNAVAILABLE"
		button.configure(
			String(spec.get("title", program_id.to_upper())),
			String(spec.get("subtitle", "")),
			status,
			String(spec.get("icon", "info")),
			HUB_V2.AMBER if selected else (spec.get("accent", HUB_V2.CYAN) as Color)
		)


func _refresh_field_cards() -> void:
	for battlefield_id: String in _field_order:
		var definition := _field_catalog.get_by_id(battlefield_id)
		var button := _battlefield_buttons.get(battlefield_id) as DigiCommandButton
		if definition == null or button == null:
			continue
		var selected := battlefield_id == _selected_battlefield_id
		var status := "INCOMPATIBLE" if button.disabled else _field_card_status(definition, selected)
		button.configure(
			definition.display_name.to_upper(),
			definition.description,
			status,
			"move",
			HUB_V2.AMBER if selected else _field_accent(definition)
		)


func _refresh_selection_summary() -> void:
	if _selection_summary == null:
		return
	var definition := _field_catalog.get_by_id(_selected_battlefield_id)
	var program_spec := _program_spec(_selected_program_id)
	var field_text := "No field selected"
	if definition != null:
		field_text = "%s · %dx%d · max %s" % [
			definition.display_name,
			definition.grid_size.x,
			definition.grid_size.y,
			FootprintScript.display_label(definition.max_supported_footprint_id()),
		]
	_selection_summary.text = "PROGRAM  %s     FIELD  %s" % [
		String(program_spec.get("title", _selected_program_id)).to_upper(),
		field_text.to_upper(),
	]


func _refresh_launch_state(party_error: String) -> void:
	if _start_battle_button == null:
		return
	var message := ""
	var program_button := _battle_program_buttons.get(_selected_program_id) as Button
	var field_button := _battlefield_buttons.get(_selected_battlefield_id) as Button
	if not party_error.is_empty():
		message = party_error
	elif program_button == null or program_button.disabled:
		message = "The selected battle program is not currently available."
	elif field_button == null or field_button.disabled:
		message = "The selected battlefield cannot safely deploy the current party."
	elif _selected_battlefield_id.is_empty():
		message = "Select a battlefield before starting the simulation."

	_start_battle_button.disabled = not message.is_empty()
	if _mobile_dialog_body != null:
		_mobile_dialog_body.text = "PARTY NOT READY" if not party_error.is_empty() else "CONFIGURE TEST BATTLE"
	if _battle_program_hint != null:
		if not message.is_empty():
			_battle_program_hint.text = message
		else:
			var definition := _field_catalog.get_by_id(_selected_battlefield_id)
			_battle_program_hint.text = (
				definition.description
				if definition != null
				else "Choose an opponent program and an authored battlefield."
			)


func _select_battle_program(program_id: String) -> void:
	var button := _battle_program_buttons.get(program_id) as Button
	if button == null or button.disabled:
		return
	_selected_program_id = program_id
	_refresh_program_cards()
	_refresh_selection_summary()
	_refresh_launch_state(OverworldState.battle_party_validation_error())


func _select_battlefield(battlefield_id: String) -> void:
	var button := _battlefield_buttons.get(battlefield_id) as Button
	if button == null or button.disabled:
		return
	_selected_battlefield_id = battlefield_id
	_refresh_field_cards()
	_refresh_selection_summary()
	_refresh_launch_state(OverworldState.battle_party_validation_error())


func _start_test_battle() -> void:
	_launch_selected_battle()


func _launch_selected_battle() -> void:
	if _start_battle_button == null or _start_battle_button.disabled:
		return
	_start_battle_program(_selected_program_id)


func _start_battle_program(program_id: String) -> void:
	if _transitioning or DigitalSceneTransition.is_transitioning():
		return
	var party_error := OverworldState.battle_party_validation_error()
	if not party_error.is_empty():
		_show_battle_program_error(party_error)
		return

	var result := _build_selected_battle_encounter(program_id)
	if not bool(result.get("ok", false)):
		_show_battle_program_error(String(result.get("error", "Could not prepare this battle program.")))
		return

	var config := result.get("config", {}) as Dictionary
	var definition := EncounterDefinitionScript.from_dict(config) as BattleEncounterDefinition
	var errors := definition.validate(OverworldState.get_database())
	if not errors.is_empty():
		_show_battle_program_error("Could not prepare a safe encounter: %s" % "; ".join(errors))
		return

	var battlefield := _field_catalog.get_by_id(_selected_battlefield_id)
	var enemy_footprints: Array = []
	for descriptor: Dictionary in definition.enemy_party:
		enemy_footprints.append(String(descriptor.get("footprint", FootprintScript.SINGLE)))
	if battlefield == null or not battlefield.supports_teams(_player_footprints(), enemy_footprints):
		_show_battle_program_error("The selected battlefield cannot safely deploy this encounter.")
		return

	if not BattleEncounterSession.stage_encounter(config):
		_show_battle_program_error("Could not stage the selected encounter.")
		return

	var selected_names: Array[String] = []
	for raw_name in Array(result.get("names", [])):
		selected_names.append(String(raw_name))
	_begin_battle_transition(program_id, selected_names)


func _build_selected_battle_encounter(program_id: String) -> Dictionary:
	if _selected_battlefield_id.is_empty():
		return {"ok": false, "error": "Select a battlefield first."}
	if program_id == "basic":
		return _battle_catalog.build_basic_encounter(_selected_battlefield_id)

	var rank := _rank_for_program(program_id)
	if rank.is_empty():
		return {"ok": false, "error": "This battle program is not available."}
	return _battle_catalog.build_rank_encounter(
		rank,
		OverworldState.get_database(),
		_active_party_level(),
		_battle_program_rng,
		_selected_battlefield_id
	)


func _begin_battle_transition(program_id: String, selected_names: Array[String]) -> void:
	_transitioning = true
	_dialog_open = false
	_dialog_panel.visible = false
	if _player != null:
		_player.movement_enabled = false
	_mobile_controls.visible = false
	_set_operator_controls_disabled(true)
	var roster_suffix := "" if selected_names.is_empty() else " · %s" % ", ".join(selected_names)
	print(
		"[Hub] START_BATTLE_PROGRAM program=%s field=%s%s"
		% [program_id, _selected_battlefield_id, roster_suffix]
	)
	if not DigitalSceneTransition.enter_battle(BATTLE_SCENE_PATH):
		BattleEncounterSession.clear_pending_encounter()
		_transitioning = false
		if _player != null:
			_player.movement_enabled = true
		_set_operator_controls_disabled(false)
		_refresh_operator_state()
		_layout_ui()


func _show_battle_program_error(message: String) -> void:
	if _mobile_dialog_body != null:
		_mobile_dialog_body.text = "SIMULATION UNAVAILABLE"
	if _battle_program_hint != null:
		_battle_program_hint.text = message
	if _mobile_dialog_cancel != null:
		_mobile_dialog_cancel.grab_focus()


func _set_operator_controls_disabled(disabled: bool) -> void:
	for program_id: String in PROGRAM_IDS:
		var button := _battle_program_buttons.get(program_id) as Button
		if button != null:
			button.disabled = disabled
	for battlefield_id: String in _field_order:
		var button := _battlefield_buttons.get(battlefield_id) as Button
		if button != null:
			button.disabled = disabled
	if _start_battle_button != null:
		_start_battle_button.disabled = disabled


func _active_party_level() -> int:
	var party: Array[DigimonInstance] = OverworldState.get_battle_ready_active_instances()
	if party.is_empty():
		return 1
	var total := 0
	for instance: DigimonInstance in party:
		total += maxi(1, instance.level)
	return maxi(1, int(round(float(total) / float(party.size()))))


func _player_footprints() -> Array:
	var result: Array = []
	for instance: DigimonInstance in OverworldState.get_battle_ready_active_instances():
		if instance != null:
			result.append(instance.battle_footprint_id)
	return result


func _rank_for_program(program_id: String) -> String:
	match program_id:
		"random_fresh": return "Fresh"
		"random_baby": return "In-Training"
		"random_rookie": return "Rookie"
		"random_champion": return "Champion"
		"random_ultimate": return "Ultimate"
		"random_mega": return "Mega"
	return ""


func _program_spec(program_id: String) -> Dictionary:
	match program_id:
		"basic":
			return {"title": "Basic Battle", "subtitle": "Koromon, Tanemon and Veemon. Fixed low-level baseline encounter.", "status": "MIXED", "icon": "sword", "accent": HUB_V2.CYAN}
		"random_fresh":
			return {"title": "Random Fresh", "subtitle": "Three verified Fresh Digimon scaled to your squad.", "status": "FRESH", "icon": "spark", "accent": HUB_V2.CYAN}
		"random_baby":
			return {"title": "Random Baby", "subtitle": "Three verified In-Training Digimon scaled to your squad.", "status": "IN-TRAINING", "icon": "spark", "accent": HUB_V2.BLUE}
		"random_rookie":
			return {"title": "Random Rookie", "subtitle": "Three verified Rookie Digimon scaled to your squad.", "status": "ROOKIE", "icon": "sword", "accent": HUB_V2.GREEN}
		"random_champion":
			return {"title": "Random Champion", "subtitle": "Three verified Champion Digimon scaled to your squad.", "status": "CHAMPION", "icon": "shield", "accent": HUB_V2.AMBER}
		"random_ultimate":
			return {"title": "Random Ultimate", "subtitle": "Three verified Ultimate Digimon scaled to your squad.", "status": "ULTIMATE", "icon": "bolt", "accent": HUB_V2.RED}
		"random_mega":
			return {"title": "Random Mega", "subtitle": "Three verified Mega Digimon scaled to your squad.", "status": "MEGA", "icon": "evolution", "accent": HUB_V2.PURPLE}
	return {}


func _program_button_name(program_id: String) -> String:
	match program_id:
		"basic": return "BasicBattle"
		"random_fresh": return "RandomFreshBattle"
		"random_baby": return "RandomBabyBattle"
		"random_rookie": return "RandomRookieBattle"
		"random_champion": return "RandomChampionBattle"
		"random_ultimate": return "RandomUltimateBattle"
		"random_mega": return "RandomMegaBattle"
	return "BattleProgram"


func _field_card_status(definition: BattlefieldDefinition, selected: bool) -> String:
	if selected:
		return "SELECTED"
	return "%s · %dx%d · MAX %s" % [
		definition.size_class.to_upper(),
		definition.grid_size.x,
		definition.grid_size.y,
		FootprintScript.display_label(definition.max_supported_footprint_id()),
	]


func _field_accent(definition: BattlefieldDefinition) -> Color:
	match definition.size_class:
		"compact": return HUB_V2.GREEN
		"large": return HUB_V2.BLUE
		"colossal": return HUB_V2.PURPLE
	return HUB_V2.CYAN


func _input(event: InputEvent) -> void:
	if not _dialog_open or _transitioning:
		super._input(event)
		return

	if event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if joy.pressed and (joy.button_index == JOY_BUTTON_LEFT_SHOULDER or joy.button_index == JOY_BUTTON_RIGHT_SHOULDER):
			if _compact_operator_layout:
				_switch_operator_section(-1 if joy.button_index == JOY_BUTTON_LEFT_SHOULDER else 1, true)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var gate := _right_analog_gate if motion.axis == JOY_AXIS_RIGHT_X or motion.axis == JOY_AXIS_RIGHT_Y else _left_analog_gate
		var step := 0
		if motion.axis == JOY_AXIS_LEFT_X or motion.axis == JOY_AXIS_RIGHT_X:
			step = gate.horizontal_step(motion.axis_value)
			if step != 0:
				_focus_operator_neighbor("right" if step > 0 else "left")
		elif motion.axis == JOY_AXIS_LEFT_Y or motion.axis == JOY_AXIS_RIGHT_Y:
			step = gate.vertical_step(motion.axis_value)
			if step != 0:
				_focus_operator_neighbor("down" if step > 0 else "up")
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		_close_dialog()
		get_viewport().set_input_as_handled()
		return
	if _compact_operator_layout and event.is_action_pressed("ui_focus_next"):
		_switch_operator_section(1, true)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_focus_operator_neighbor("left")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_focus_operator_neighbor("right")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_focus_operator_neighbor("up")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_focus_operator_neighbor("down")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_activate_focused_operator_control()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		_handle_operator_touch(event as InputEventScreenTouch)


func _activate_focused_operator_control() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner() as Button
	if focus_owner == null or focus_owner.disabled:
		return
	var kind := String(focus_owner.get_meta("operator_kind", ""))
	var control_id := String(focus_owner.get_meta("operator_id", ""))
	match kind:
		"program":
			_select_battle_program(control_id)
		"field":
			_select_battlefield(control_id)
		"tab":
			_set_operator_section(control_id, false)
		"action":
			if control_id == "launch":
				_launch_selected_battle()
			elif control_id == "cancel":
				_close_dialog()


func _handle_operator_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _fallback_action_touch != -1:
			return
		for program_id: String in PROGRAM_IDS:
			var program_button := _battle_program_buttons.get(program_id) as Button
			if program_button != null and not program_button.disabled and program_button.visible:
				if _control_contains_viewport_point(program_button, touch.position, 6.0):
					_fallback_action_touch = touch.index
					_select_battle_program(program_id)
					get_viewport().set_input_as_handled()
					return
		for battlefield_id: String in _field_order:
			var field_button := _battlefield_buttons.get(battlefield_id) as Button
			if field_button != null and not field_button.disabled and field_button.visible:
				if _control_contains_viewport_point(field_button, touch.position, 6.0):
					_fallback_action_touch = touch.index
					_select_battlefield(battlefield_id)
					get_viewport().set_input_as_handled()
					return
		for tab in [_program_tab, _field_tab]:
			if tab != null and tab.visible and _control_contains_viewport_point(tab, touch.position, 6.0):
				_fallback_action_touch = touch.index
				_set_operator_section(String(tab.get_meta("operator_id", SECTION_PROGRAM)), false)
				get_viewport().set_input_as_handled()
				return
		if _start_battle_button != null and not _start_battle_button.disabled and _control_contains_viewport_point(_start_battle_button, touch.position, 8.0):
			_fallback_action_touch = touch.index
			_launch_selected_battle()
			get_viewport().set_input_as_handled()
			return
		if _mobile_dialog_cancel != null and _control_contains_viewport_point(_mobile_dialog_cancel, touch.position, 8.0):
			_fallback_action_touch = touch.index
			_close_dialog()
			get_viewport().set_input_as_handled()
			return
	elif touch.index == _fallback_action_touch:
		_fallback_action_touch = -1
		get_viewport().set_input_as_handled()


func _layout_mobile_dialog(physical: Vector2, ui_scale: float, landscape: bool, edge: float) -> void:
	if _dialog_panel == null or _mobile_dialog_content == null or _program_container == null or _field_container == null:
		super._layout_mobile_dialog(physical, ui_scale, landscape, edge)
		return

	var compact_landscape := landscape and physical.y < 520.0
	_compact_operator_layout = physical.x < 900.0 or physical.y < 620.0
	var outer_edge := 12.0 if compact_landscape else edge
	var dialog_width := minf(1120.0, physical.x - outer_edge * 2.0)
	var dialog_height := minf(720.0, physical.y - outer_edge * 2.0)
	var side_pad := 16.0 if compact_landscape else 24.0
	var top_pad := 8.0 if compact_landscape else 18.0
	var hint_bar_height := 0.0 if compact_landscape else 48.0
	var action_height := HUB_V2.TOUCH_TARGET
	var summary_height := 44.0 if compact_landscape else 58.0
	var bottom_pad := 10.0 if compact_landscape else 16.0
	var action_gap := 10.0

	_dialog_panel.scale = Vector2.ONE * ui_scale
	_dialog_panel.position = Vector2(
		(physical.x - dialog_width) * 0.5 * ui_scale,
		(physical.y - dialog_height) * 0.5 * ui_scale
	)
	_dialog_panel.size = Vector2(dialog_width, dialog_height)
	_mobile_dialog_content.position = Vector2.ZERO
	_mobile_dialog_content.size = Vector2(dialog_width, dialog_height)

	_mobile_dialog_title.position = Vector2(side_pad, top_pad)
	_mobile_dialog_title.size = Vector2(dialog_width - side_pad * 2.0, 18.0)
	_mobile_dialog_title.add_theme_font_size_override("font_size", 10 if compact_landscape else 12)
	_mobile_dialog_body.position = Vector2(side_pad, top_pad + (18.0 if compact_landscape else 22.0))
	_mobile_dialog_body.size = Vector2(dialog_width - side_pad * 2.0, 22.0 if compact_landscape else 26.0)
	_mobile_dialog_body.add_theme_font_size_override("font_size", 14 if compact_landscape else 19)
	_battle_program_hint.visible = not compact_landscape
	_battle_program_hint.position = Vector2(side_pad, top_pad + 52.0)
	_battle_program_hint.size = Vector2(dialog_width - side_pad * 2.0, 40.0)
	_battle_program_hint.add_theme_font_size_override("font_size", 10)

	var tabs_y := top_pad + (44.0 if compact_landscape else 96.0)
	var tabs_height := 36.0 if compact_landscape else 38.0
	var tabs_gap := 8.0
	var tabs_width := minf(360.0, dialog_width - side_pad * 2.0)
	var tab_width := (tabs_width - tabs_gap) * 0.5
	_program_tab.position = Vector2(side_pad, tabs_y)
	_program_tab.size = Vector2(tab_width, tabs_height)
	_field_tab.position = Vector2(side_pad + tab_width + tabs_gap, tabs_y)
	_field_tab.size = Vector2(tab_width, tabs_height)

	var actions_y := dialog_height - bottom_pad - hint_bar_height - action_height
	var summary_y := actions_y - action_gap - summary_height
	var content_top := tabs_y + (tabs_height + (8.0 if compact_landscape else 10.0) if _compact_operator_layout else 0.0)
	if not _compact_operator_layout:
		content_top = top_pad + 102.0
	var content_bottom := summary_y - (4.0 if compact_landscape else 10.0)
	var content_height := maxf(80.0, content_bottom - content_top)

	var action_group_width := minf(520.0, dialog_width - side_pad * 2.0)
	var action_width := (action_group_width - action_gap) * 0.5
	var actions_x := dialog_width - side_pad - action_group_width
	_mobile_dialog_cancel.position = Vector2(actions_x, actions_y)
	_mobile_dialog_cancel.size = Vector2(action_width, action_height)
	_start_battle_button.position = Vector2(actions_x + action_width + action_gap, actions_y)
	_start_battle_button.size = Vector2(action_width, action_height)
	_mobile_dialog_cancel.custom_minimum_size.y = HUB_V2.TOUCH_TARGET
	_start_battle_button.custom_minimum_size.y = HUB_V2.TOUCH_TARGET

	_selection_panel.position = Vector2(side_pad, summary_y)
	_selection_panel.size = Vector2(dialog_width - side_pad * 2.0, summary_height)
	_selection_summary.add_theme_font_size_override("font_size", 9 if compact_landscape else 10)

	_input_hint_bar.visible = hint_bar_height > 0.0
	if _input_hint_bar.visible:
		_input_hint_bar.position = Vector2(0.0, dialog_height - hint_bar_height)
		_input_hint_bar.size = Vector2(dialog_width, hint_bar_height)
		_input_hint_bar.set_primary_tabs_enabled(_compact_operator_layout)

	if _compact_operator_layout:
		_program_tab.visible = true
		_field_tab.visible = true
		_layout_compact_operator_workspace(
			Rect2(side_pad, content_top, dialog_width - side_pad * 2.0, content_height),
			compact_landscape
		)
	else:
		_program_tab.visible = false
		_field_tab.visible = false
		_layout_desktop_operator_workspace(
			Rect2(side_pad, content_top, dialog_width - side_pad * 2.0, content_height)
		)

	_refresh_section_visibility()
	_wire_operator_focus()


func _layout_desktop_operator_workspace(rect: Rect2) -> void:
	var pane_gap := 16.0
	var pane_width := (rect.size.x - pane_gap) * 0.5
	var heading_height := 20.0
	var cards_top := 28.0

	_program_heading.visible = true
	_field_heading.visible = true
	_program_heading.position = rect.position
	_program_heading.size = Vector2(pane_width, heading_height)
	_field_heading.position = Vector2(rect.position.x + pane_width + pane_gap, rect.position.y)
	_field_heading.size = Vector2(pane_width, heading_height)

	_program_container.position = Vector2(rect.position.x, rect.position.y + cards_top)
	_program_container.size = Vector2(pane_width, rect.size.y - cards_top)
	_field_container.position = Vector2(rect.position.x + pane_width + pane_gap, rect.position.y + cards_top)
	_field_container.size = Vector2(pane_width, rect.size.y - cards_top)

	_battle_program_columns = 2
	_battlefield_columns = 2
	_layout_card_grid(PROGRAM_IDS, _battle_program_buttons, _program_container.size, _battle_program_columns, false)
	_layout_card_grid(_field_order, _battlefield_buttons, _field_container.size, _battlefield_columns, false)


func _layout_compact_operator_workspace(rect: Rect2, compact_landscape: bool) -> void:
	_program_heading.visible = false
	_field_heading.visible = false
	_program_container.position = rect.position
	_program_container.size = rect.size
	_field_container.position = rect.position
	_field_container.size = rect.size

	_battle_program_columns = 4 if compact_landscape else 2
	_battlefield_columns = 3 if compact_landscape else 2
	_layout_card_grid(PROGRAM_IDS, _battle_program_buttons, rect.size, _battle_program_columns, compact_landscape)
	_layout_card_grid(_field_order, _battlefield_buttons, rect.size, _battlefield_columns, compact_landscape)


func _layout_card_grid(
	ids: Array[String],
	buttons: Dictionary,
	available_size: Vector2,
	columns: int,
	dense: bool
) -> void:
	if ids.is_empty():
		return
	var safe_columns := maxi(1, columns)
	var rows := int(ceil(float(ids.size()) / float(safe_columns)))
	var gap := 6.0 if dense else 9.0
	var button_width := (available_size.x - gap * float(safe_columns - 1)) / float(safe_columns)
	var button_height := minf(
		82.0,
		(available_size.y - gap * float(maxi(0, rows - 1))) / float(maxi(1, rows))
	)
	button_height = maxf(56.0 if dense else 64.0, button_height)
	for index in range(ids.size()):
		var button := buttons.get(ids[index]) as DigiCommandButton
		if button == null:
			continue
		var row := int(index / safe_columns)
		var column := index % safe_columns
		button.set_compact(button_height < 78.0)
		button.custom_minimum_size = Vector2.ZERO
		button.position = Vector2(
			float(column) * (button_width + gap),
			float(row) * (button_height + gap)
		)
		button.size = Vector2(button_width, button_height)


func _set_operator_section(section: String, focus_selected: bool = true) -> void:
	if section != SECTION_PROGRAM and section != SECTION_FIELD:
		return
	_operator_section = section
	_refresh_section_visibility()
	_wire_operator_focus()
	if focus_selected:
		_focus_selected_in_active_section()


func _switch_operator_section(direction: int, focus_selected: bool = true) -> void:
	if direction == 0:
		return
	var next_section := SECTION_FIELD if _operator_section == SECTION_PROGRAM else SECTION_PROGRAM
	_set_operator_section(next_section, focus_selected)


func _refresh_section_visibility() -> void:
	if _program_container == null or _field_container == null:
		return
	if _compact_operator_layout:
		_program_container.visible = _operator_section == SECTION_PROGRAM
		_field_container.visible = _operator_section == SECTION_FIELD
		_program_tab.focus_mode = Control.FOCUS_ALL
		_field_tab.focus_mode = Control.FOCUS_ALL
	else:
		_program_container.visible = true
		_field_container.visible = true
		_program_tab.focus_mode = Control.FOCUS_NONE
		_field_tab.focus_mode = Control.FOCUS_NONE

	_apply_v2_dialog_button(_program_tab, HUB_V2.AMBER if _operator_section == SECTION_PROGRAM else HUB_V2.CYAN)
	_apply_v2_dialog_button(_field_tab, HUB_V2.AMBER if _operator_section == SECTION_FIELD else HUB_V2.CYAN)


func _wire_operator_focus() -> void:
	if _mobile_dialog_cancel == null or _start_battle_button == null:
		return
	_wire_grid_neighbors(PROGRAM_IDS, _battle_program_buttons, _battle_program_columns)
	_wire_grid_neighbors(_field_order, _battlefield_buttons, _battlefield_columns)

	_mobile_dialog_cancel.focus_neighbor_left = _mobile_dialog_cancel.get_path()
	_mobile_dialog_cancel.focus_neighbor_right = _start_battle_button.get_path()
	_start_battle_button.focus_neighbor_left = _mobile_dialog_cancel.get_path()
	_start_battle_button.focus_neighbor_right = _start_battle_button.get_path()

	if _compact_operator_layout:
		_program_tab.focus_neighbor_left = _program_tab.get_path()
		_program_tab.focus_neighbor_right = _field_tab.get_path()
		_field_tab.focus_neighbor_left = _program_tab.get_path()
		_field_tab.focus_neighbor_right = _field_tab.get_path()
		var active_ids := PROGRAM_IDS if _operator_section == SECTION_PROGRAM else _field_order
		var active_buttons := _battle_program_buttons if _operator_section == SECTION_PROGRAM else _battlefield_buttons
		var columns := _battle_program_columns if _operator_section == SECTION_PROGRAM else _battlefield_columns
		var active_tab := _program_tab if _operator_section == SECTION_PROGRAM else _field_tab
		_wire_compact_edges(active_ids, active_buttons, columns, active_tab)
	else:
		_wire_desktop_cross_edges()

	var cancel_up := _selected_program_button()
	var launch_up := _selected_field_button()
	if _compact_operator_layout:
		cancel_up = _selected_active_button()
		launch_up = _selected_active_button()
	if cancel_up != null:
		_mobile_dialog_cancel.focus_neighbor_top = cancel_up.get_path()
	if launch_up != null:
		_start_battle_button.focus_neighbor_top = launch_up.get_path()


func _wire_grid_neighbors(ids: Array[String], buttons: Dictionary, columns: int) -> void:
	if ids.is_empty():
		return
	var safe_columns := maxi(1, columns)
	for index in range(ids.size()):
		var button := buttons.get(ids[index]) as Button
		if button == null:
			continue
		var row := int(index / safe_columns)
		var column := index % safe_columns
		var left_index := row * safe_columns + maxi(0, column - 1)
		var right_index := mini(row * safe_columns + mini(safe_columns - 1, column + 1), ids.size() - 1)
		var up_index := maxi(0, index - safe_columns)
		var down_index := mini(ids.size() - 1, index + safe_columns)
		var left := buttons.get(ids[left_index]) as Button
		var right := buttons.get(ids[right_index]) as Button
		var up := buttons.get(ids[up_index]) as Button
		var down := buttons.get(ids[down_index]) as Button
		if left != null:
			button.focus_neighbor_left = left.get_path()
		if right != null:
			button.focus_neighbor_right = right.get_path()
		if up != null:
			button.focus_neighbor_top = up.get_path()
		if down != null:
			button.focus_neighbor_bottom = down.get_path()


func _wire_compact_edges(ids: Array[String], buttons: Dictionary, columns: int, active_tab: Button) -> void:
	if ids.is_empty():
		return
	var safe_columns := maxi(1, columns)
	var rows := int(ceil(float(ids.size()) / float(safe_columns)))
	for index in range(ids.size()):
		var button := buttons.get(ids[index]) as Button
		if button == null:
			continue
		var row := int(index / safe_columns)
		if row == 0 and active_tab != null:
			button.focus_neighbor_top = active_tab.get_path()
		if row == rows - 1 or index + safe_columns >= ids.size():
			button.focus_neighbor_bottom = (
				_mobile_dialog_cancel.get_path()
				if index % safe_columns < int(ceil(float(safe_columns) * 0.5))
				else _start_battle_button.get_path()
			)
	if active_tab != null:
		var selected := _selected_active_button()
		if selected != null:
			active_tab.focus_neighbor_bottom = selected.get_path()


func _wire_desktop_cross_edges() -> void:
	if PROGRAM_IDS.is_empty() or _field_order.is_empty():
		return
	for index in range(PROGRAM_IDS.size()):
		var program_button := _battle_program_buttons.get(PROGRAM_IDS[index]) as Button
		if program_button == null:
			continue
		var column := index % _battle_program_columns
		if column == _battle_program_columns - 1 or index == PROGRAM_IDS.size() - 1:
			var target_index := mini(
				int(index / _battle_program_columns) * _battlefield_columns,
				_field_order.size() - 1
			)
			var target := _battlefield_buttons.get(_field_order[target_index]) as Button
			if target != null:
				program_button.focus_neighbor_right = target.get_path()
		if index + _battle_program_columns >= PROGRAM_IDS.size():
			program_button.focus_neighbor_bottom = _mobile_dialog_cancel.get_path()

	for index in range(_field_order.size()):
		var field_button := _battlefield_buttons.get(_field_order[index]) as Button
		if field_button == null:
			continue
		var column := index % _battlefield_columns
		if column == 0:
			var target_index := mini(
				int(index / _battlefield_columns) * _battle_program_columns + (_battle_program_columns - 1),
				PROGRAM_IDS.size() - 1
			)
			var target := _battle_program_buttons.get(PROGRAM_IDS[target_index]) as Button
			if target != null:
				field_button.focus_neighbor_left = target.get_path()
		if index + _battlefield_columns >= _field_order.size():
			field_button.focus_neighbor_bottom = _start_battle_button.get_path()


func _focus_operator_neighbor(direction: String) -> void:
	var focus := get_viewport().gui_get_focus_owner() as Control
	if focus == null:
		_mobile_dialog_cancel.grab_focus()
		return
	var current := focus
	for _attempt in range(16):
		var path := NodePath()
		match direction:
			"left": path = current.focus_neighbor_left
			"right": path = current.focus_neighbor_right
			"up": path = current.focus_neighbor_top
			"down": path = current.focus_neighbor_bottom
		if path.is_empty():
			return
		var target := current.get_node_or_null(path) as Control
		if target == null or target == current:
			return
		if target.visible and target.focus_mode != Control.FOCUS_NONE and (not (target is Button) or not (target as Button).disabled):
			target.grab_focus()
			return
		current = target


func _focus_selected_in_active_section() -> void:
	var button := _selected_active_button()
	if button != null and not button.disabled:
		button.grab_focus()


func _selected_active_button() -> Button:
	return _selected_program_button() if _operator_section == SECTION_PROGRAM else _selected_field_button()


func _selected_program_button() -> Button:
	return _battle_program_buttons.get(_selected_program_id) as Button


func _selected_field_button() -> Button:
	return _battlefield_buttons.get(_selected_battlefield_id) as Button
