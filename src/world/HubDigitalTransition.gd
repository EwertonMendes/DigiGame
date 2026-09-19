extends "res://src/world/HubHospitalGameplay.gd"

const BattleOperatorCatalogScript = preload("res://src/world/BattleOperatorEncounterCatalog.gd")
const EncounterDefinitionScript = preload("res://src/world/BattleEncounterDefinition.gd")
const BattlefieldCatalogScript = preload("res://src/world/BattlefieldCatalog.gd")
const AnalogGateScript = preload("res://src/ui/components/DigiAnalogNavigationGate.gd")
const SelectionCardScript = preload("res://src/ui/components/DigiSelectionCard.gd")
const ModalHeaderScript = preload("res://src/ui/components/DigiModalHeader.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const PagerScript = preload("res://src/ui/components/DigiPager.gd")
const SegmentScript = preload("res://src/ui/components/DigiSegmentedTabs.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const WorkspaceChrome = preload("res://src/ui/components/DigiLabWorkspaceChrome.gd")
const OperatorIcons = preload("res://src/ui/battle_operator/BattleOperatorIconCatalog.gd")
const IconViewScript = preload("res://src/ui/components/DigiIconView.gd")
const OPERATOR_BACKGROUND = preload("res://assets/ui/backgrounds/digimon_menu.png")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")
const OperatorTransitionSurfaceScript = preload("res://src/ui/components/DigiUiTransitionSurface.gd")

const PROGRAM_IDS: Array[String] = [
	"basic",
	"random_fresh",
	"random_baby",
	"random_rookie",
	"random_champion",
	"random_ultimate",
	"random_mega",
]
const SECTION_PROGRAM := "program"
const SECTION_FIELD := "field"
const OPERATOR_UI_LAYER := 90

var _battle_catalog := BattleOperatorCatalogScript.new() as BattleOperatorEncounterCatalog
var _field_catalog := BattlefieldCatalogScript.new() as BattlefieldCatalog
var _battle_program_rng := RandomNumberGenerator.new()
var _battle_program_buttons: Dictionary = {}
var _battlefield_buttons: Dictionary = {}
var _field_order: Array[String] = []
var _selected_program_id := "basic"
var _selected_battlefield_id := ""
var _operator_section := SECTION_PROGRAM
var _operator_ui_layer: CanvasLayer = null
var _operator_transition_surface: CanvasGroup = null
var _operator_header: DigiModalHeader = null
var _operator_header_rule: ColorRect = null
var _operator_footer: DigiInputHintBar = null
var _section_tabs: DigiSegmentedTabs = null
var _program_panel: PanelContainer = null
var _field_panel: PanelContainer = null
var _summary_panel: PanelContainer = null
var _program_list: VBoxContainer = null
var _field_list: VBoxContainer = null
var _program_header: DigiSectionHeader = null
var _field_header: DigiSectionHeader = null
var _summary_header: DigiSectionHeader = null
var _program_pager: DigiPager = null
var _field_pager: DigiPager = null
var _summary_program: Label = null
var _summary_field: Label = null
var _summary_description: Label = null
var _summary_meta: Label = null
var _summary_state: Label = null

var _program_page := 0
var _field_page := 0
var _program_page_capacity := PROGRAM_IDS.size()
var _field_page_capacity := 5
var _compact_operator_layout := false
var _analog_gate: DigiAnalogNavigationGate = AnalogGateScript.new() as DigiAnalogNavigationGate

func _ready() -> void:
	_battle_program_rng.randomize()
	_field_catalog.load_default()
	super._ready()
	MusicDirector.play_zone_1()


func _build_dialog() -> void:
	# Battle Operator follows the same full-screen service-layer contract as the
	# Digimon menu, DigiLab and Hospital. Keeping it on its own CanvasLayer also
	# guarantees closed debug launchers (layers 60/80) never cover workspace UI.
	_operator_ui_layer = CanvasLayer.new()
	_operator_ui_layer.name = "BattleOperatorUI"
	_operator_ui_layer.layer = OPERATOR_UI_LAYER
	add_child(_operator_ui_layer)

	_dialog_panel = PanelContainer.new()
	_dialog_panel.name = "BattleDialog"
	_dialog_panel.visible = false
	_dialog_panel.clip_contents = true
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_panel.add_theme_stylebox_override(
		"panel",
		HUB_V2.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0)
	)
	_operator_ui_layer.add_child(_dialog_panel)

	_operator_transition_surface = OperatorTransitionSurfaceScript.new() as CanvasGroup
	_operator_transition_surface.name = "BattleOperatorTransition"
	_dialog_panel.add_child(_operator_transition_surface)

	var background := TextureRect.new()
	background.name = "BattleOperatorBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = OPERATOR_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_operator_transition_surface.add_transition_child(background)

	var shade := ColorRect.new()
	shade.name = "BattleOperatorBackgroundShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.019, 0.032, 0.40)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_operator_transition_surface.add_transition_child(shade)

	_mobile_dialog_content = Control.new()
	_mobile_dialog_content.name = "Content"
	_mobile_dialog_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_dialog_content.clip_contents = true
	_operator_transition_surface.add_transition_child(_mobile_dialog_content)

	_start_battle_button = _dialog_button("", HUB_V2.AMBER)
	_start_battle_button.name = "StartBattle"
	_start_battle_button.custom_minimum_size.y = HUB_V2.TOUCH_TARGET
	_start_battle_button.pressed.connect(_start_test_battle)
	_start_battle_button.set_meta("operator_kind", "action")
	_start_battle_button.set_meta("operator_id", "launch")
	_apply_v2_dialog_button(_start_battle_button, HUB_V2.AMBER)
	_build_start_battle_content()
	_mobile_dialog_content.add_child(_start_battle_button)

	if not _field_catalog.load_default():
		for error in _field_catalog.validation_errors():
			push_error("Battle Operator battlefield catalog: %s" % error)

	_operator_header = ModalHeaderScript.new() as DigiModalHeader
	_operator_header.name = "OperatorHeader"
	_operator_header.set_workspace_mode(true)
	_operator_header.configure("BATTLE OPERATOR", "Battle Simulation", 0, false)
	_operator_header.close_requested.connect(_close_dialog)
	_mobile_dialog_content.add_child(_operator_header)
	var close_button := _operator_header.get_close_button()
	if close_button != null:
		# Same navigation contract as Digimon/Hospital: close chrome is pointer /
		# Back driven and never steals D-pad or analog focus from workspace content.
		close_button.focus_mode = Control.FOCUS_NONE

	_operator_header_rule = ColorRect.new()
	_operator_header_rule.name = "OperatorHeaderRule"
	_operator_header_rule.color = Color(HUB_V2.BORDER.r, HUB_V2.BORDER.g, HUB_V2.BORDER.b, 0.62)
	_operator_header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_dialog_content.add_child(_operator_header_rule)

	_section_tabs = SegmentScript.new() as DigiSegmentedTabs
	_section_tabs.name = "OperatorSections"
	_section_tabs.configure([
		{"id": SECTION_PROGRAM, "label": "BATTLE PROGRAM", "compact_label": "PROGRAM", "accent": HUB_V2.CYAN},
		{"id": SECTION_FIELD, "label": "BATTLEFIELD", "compact_label": "FIELD", "accent": HUB_V2.CYAN},
	], _operator_section)
	_section_tabs.tab_selected.connect(_set_operator_section)
	_mobile_dialog_content.add_child(_section_tabs)

	_build_program_workspace()
	_build_battlefield_workspace()
	_build_selection_summary()

	_operator_footer = InputHintBarScript.new() as DigiInputHintBar
	_operator_footer.name = "BattleOperatorHints"
	WorkspaceChrome.configure_hints(
		_operator_footer,
		"Configure the test battle. Select a program and battlefield, then start the simulation."
	)
	_mobile_dialog_content.add_child(_operator_footer)

	_refresh_operator_state()
	call_deferred("_enforce_operator_header_focus_contract")
	call_deferred("_wire_operator_focus")


func _build_start_battle_content() -> void:
	if _start_battle_button == null:
		return

	# Do not use Button.icon here. Godot aligns native button icons separately
	# from centered text, which makes a small SVG sit against the left edge.
	# A single centered content row keeps the action icon and label together
	# across desktop, compact and touch layouts without hard-coded offsets.
	var center := CenterContainer.new()
	center.name = "StartBattleContent"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_battle_button.add_child(center)

	var row := HBoxContainer.new()
	row.name = "StartBattleRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)

	var icon := IconViewScript.new() as DigiIconView
	icon.name = "StartBattleIcon"
	icon.custom_minimum_size = Vector2(22.0, 22.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure_texture(OperatorIcons.action_icon("start_simulation"), HUB_V2.AMBER)
	row.add_child(icon)

	var label := Label.new()
	label.name = "StartBattleLabel"
	label.text = "START BATTLE"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", HUB_V2.TEXT)
	HUB_V2.apply_heading(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)


func _refresh_start_battle_content() -> void:
	if _start_battle_button == null:
		return
	var icon := _start_battle_button.find_child("StartBattleIcon", true, false) as DigiIconView
	var label := _start_battle_button.find_child("StartBattleLabel", true, false) as Label
	var content_color := HUB_V2.SUBTLE if _start_battle_button.disabled else HUB_V2.AMBER
	if icon != null:
		icon.configure_texture(OperatorIcons.action_icon("start_simulation"), content_color)
	if label != null:
		label.add_theme_color_override(
			"font_color",
			HUB_V2.SUBTLE if _start_battle_button.disabled else HUB_V2.TEXT
		)


func _build_program_workspace() -> void:
	_program_panel = PanelContainer.new()
	_program_panel.name = "ProgramPanel"
	WorkspaceChrome.style_workspace_panel(_program_panel, HUB_V2.CYAN)
	_mobile_dialog_content.add_child(_program_panel)

	var stack := VBoxContainer.new()
	stack.name = "ProgramStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	_program_panel.add_child(stack)

	_program_header = SectionHeaderScript.new() as DigiSectionHeader
	_program_header.name = "ProgramHeader"
	_program_header.configure("BATTLE PROGRAM", "7 PROGRAMS", HUB_V2.CYAN)
	_program_header.set_icon_texture(OperatorIcons.section_icon("program"))
	_program_header.set_workspace_mode(true)
	stack.add_child(_program_header)

	var margin := MarginContainer.new()
	margin.name = "ProgramListMargin"
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	stack.add_child(margin)

	_program_list = VBoxContainer.new()
	_program_list.name = "ProgramList"
	_program_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_program_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_program_list.add_theme_constant_override("separation", 7)
	margin.add_child(_program_list)

	for program_id: String in PROGRAM_IDS:
		var spec := _program_spec(program_id)
		var button := SelectionCardScript.new() as DigiSelectionCard
		button.name = _program_button_name(program_id)
		button.configure(
			String(spec.get("title", program_id.to_upper())),
			String(spec.get("subtitle", "")),
			String(spec.get("status", "")),
			"",
			spec.get("accent", HUB_V2.CYAN) as Color
		)
		button.set_icon_texture(OperatorIcons.program_icon(program_id))
		button.set_meta("operator_kind", "program")
		button.set_meta("operator_id", program_id)
		button.pressed.connect(_select_battle_program.bind(program_id))
		_program_list.add_child(button)
		_battle_program_buttons[program_id] = button

	_program_pager = PagerScript.new() as DigiPager
	_program_pager.name = "ProgramPager"
	_program_pager.set_workspace_mode(true)
	_program_pager.page_delta_requested.connect(_turn_program_page)
	stack.add_child(_program_pager)


func _build_battlefield_workspace() -> void:
	_field_panel = PanelContainer.new()
	_field_panel.name = "BattlefieldPanel"
	WorkspaceChrome.style_workspace_panel(_field_panel, HUB_V2.CYAN)
	_mobile_dialog_content.add_child(_field_panel)

	var stack := VBoxContainer.new()
	stack.name = "BattlefieldStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	_field_panel.add_child(stack)

	_field_header = SectionHeaderScript.new() as DigiSectionHeader
	_field_header.name = "BattlefieldHeader"
	_field_header.configure("BATTLEFIELD", "5 FIELDS", HUB_V2.CYAN)
	_field_header.set_icon_texture(OperatorIcons.section_icon("battlefield"))
	_field_header.set_workspace_mode(true)
	stack.add_child(_field_header)

	var margin := MarginContainer.new()
	margin.name = "FieldListMargin"
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	stack.add_child(margin)

	_field_list = VBoxContainer.new()
	_field_list.name = "FieldList"
	_field_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_list.add_theme_constant_override("separation", 7)
	margin.add_child(_field_list)

	_field_order.clear()
	for definition: BattlefieldDefinition in _field_catalog.all_definitions():
		_field_order.append(definition.battlefield_id)
		var button := SelectionCardScript.new() as DigiSelectionCard
		button.name = "Field_%s" % definition.battlefield_id
		button.configure(
			definition.display_name.to_upper(),
			_field_list_subtitle(definition),
			_field_card_status(definition),
			"",
			_field_accent(definition)
		)
		button.set_icon_texture(OperatorIcons.battlefield_icon(definition.battlefield_id))
		button.set_meta("operator_kind", "field")
		button.set_meta("operator_id", definition.battlefield_id)
		button.pressed.connect(_select_battlefield.bind(definition.battlefield_id))
		_field_list.add_child(button)
		_battlefield_buttons[definition.battlefield_id] = button

	var default_field := _field_catalog.default_definition()
	if default_field != null:
		_selected_battlefield_id = default_field.battlefield_id
	elif not _field_order.is_empty():
		_selected_battlefield_id = _field_order[0]

	_field_pager = PagerScript.new() as DigiPager
	_field_pager.name = "FieldPager"
	_field_pager.set_workspace_mode(true)
	_field_pager.page_delta_requested.connect(_turn_field_page)
	stack.add_child(_field_pager)


func _build_selection_summary() -> void:
	_summary_panel = PanelContainer.new()
	_summary_panel.name = "SimulationPanel"
	WorkspaceChrome.style_workspace_panel(_summary_panel, HUB_V2.CYAN)
	_mobile_dialog_content.add_child(_summary_panel)

	var stack := VBoxContainer.new()
	stack.name = "SimulationStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	_summary_panel.add_child(stack)

	_summary_header = SectionHeaderScript.new() as DigiSectionHeader
	_summary_header.name = "SimulationHeader"
	_summary_header.configure("SIMULATION", "MECHANICS TEST", HUB_V2.CYAN)
	_summary_header.set_icon_texture(OperatorIcons.section_icon("simulation"))
	_summary_header.set_workspace_mode(true)
	stack.add_child(_summary_header)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	stack.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "SimulationContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	_summary_program = _workspace_label("", 16, HUB_V2.WHITE, true)
	_summary_program.name = "SelectedProgram"
	content.add_child(_summary_program)

	_summary_field = _workspace_label("", 14, HUB_V2.CYAN, true)
	_summary_field.name = "SelectedField"
	content.add_child(_summary_field)

	_summary_description = _workspace_label("", 11, HUB_V2.MUTED, false)
	_summary_description.name = "SelectionDescription"
	_summary_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_description.max_lines_visible = 3
	_summary_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_summary_description)

	_summary_meta = _workspace_label("", 10, HUB_V2.MUTED, false)
	_summary_meta.name = "SelectionMeta"
	_summary_meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(_summary_meta)

	var actions := HBoxContainer.new()
	actions.name = "SimulationActions"
	actions.add_theme_constant_override("separation", 10)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(actions)

	_summary_state = _workspace_label("READY", 11, HUB_V2.GREEN, true)
	_summary_state.name = "SimulationState"
	_summary_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	actions.add_child(_summary_state)

	if _start_battle_button.get_parent() != null:
		_start_battle_button.reparent(actions)
	_start_battle_button.custom_minimum_size = Vector2(220.0, HUB_V2.TOUCH_TARGET)
	_start_battle_button.size_flags_horizontal = Control.SIZE_SHRINK_END


func _workspace_label(text_value: String, font_size: int, color: Color, heading: bool) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if heading:
		HUB_V2.apply_heading(label)
	else:
		HUB_V2.apply_body(label)
	return label


func _field_list_subtitle(definition: BattlefieldDefinition) -> String:
	return "%dx%d · %s" % [
		definition.grid_size.x,
		definition.grid_size.y,
		definition.description,
	]


func _enforce_operator_header_focus_contract() -> void:
	if _operator_header == null:
		return
	var close_button := _operator_header.get_close_button()
	if close_button != null:
		close_button.focus_mode = Control.FOCUS_NONE



func _open_dialog() -> void:
	if _operator_transition_surface == null:
		return
	if not DigiUiTransitionDirector.begin_open(_operator_transition_surface, "battle_operator"):
		return
	_analog_gate.reset()
	super._open_dialog()
	if not _dialog_open:
		DigiUiTransitionDirector.cancel_transition()
		return
	_refresh_operator_state()
	_sync_pages_to_selection()
	_layout_ui()
	# Preserve the existing focus contract immediately. The transition director
	# consumes input while construction is active, so focus can be prepared safely
	# without letting the player interact with unrevealed controls.
	_focus_selected_program()
	call_deferred("_focus_selected_program")
	await DigiUiTransitionDirector.reveal_open()


func _close_dialog() -> void:
	if not _dialog_open or _transitioning or _operator_transition_surface == null:
		return
	if not DigiUiTransitionDirector.begin_close(_operator_transition_surface, "battle_operator"):
		return
	UiSfxDirector.play_back()
	await DigiUiTransitionDirector.conceal_close()
	super._close_dialog()
	DigiUiTransitionDirector.complete_close()

func _refresh_operator_state() -> void:
	var party_error := OverworldState.battle_party_validation_error()
	_refresh_battle_program_availability()
	_refresh_battlefield_availability()
	_refresh_program_cards()
	_refresh_field_cards()
	_refresh_selection_summary()
	_refresh_launch_state(party_error)
	_refresh_page_visibility()

func _refresh_battle_program_availability() -> void:
	var database: DigimonDatabase = OverworldState.get_database() as DigimonDatabase
	_battle_catalog.prepare(database)
	for program_id: String in PROGRAM_IDS:
		var button := _battle_program_buttons.get(program_id) as DigiSelectionCard
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
		var button := _battlefield_buttons.get(battlefield_id) as DigiSelectionCard
		if definition == null or button == null:
			continue
		var compatible := definition.supports_teams(player_footprints, enemy_footprints)
		button.set_interactive(compatible)
		if compatible and first_compatible.is_empty():
			first_compatible = battlefield_id

	var selected_button := _battlefield_buttons.get(_selected_battlefield_id) as DigiSelectionCard
	if selected_button != null and selected_button.disabled and not first_compatible.is_empty():
		_selected_battlefield_id = first_compatible

func _refresh_program_cards() -> void:
	for program_id: String in PROGRAM_IDS:
		var button := _battle_program_buttons.get(program_id) as DigiSelectionCard
		if button == null:
			continue
		var spec := _program_spec(program_id)
		button.configure(
			String(spec.get("title", program_id.to_upper())),
			String(spec.get("subtitle", "")),
			"UNAVAILABLE" if button.disabled else String(spec.get("status", "")),
			"",
			spec.get("accent", HUB_V2.CYAN) as Color
		)
		button.set_icon_texture(OperatorIcons.program_icon(program_id))
		button.set_selected(program_id == _selected_program_id)

func _refresh_field_cards() -> void:
	for battlefield_id: String in _field_order:
		var definition := _field_catalog.get_by_id(battlefield_id)
		var button := _battlefield_buttons.get(battlefield_id) as DigiSelectionCard
		if definition == null or button == null:
			continue
		button.configure(
			definition.display_name.to_upper(),
			_field_list_subtitle(definition),
			"INCOMPATIBLE" if button.disabled else _field_card_status(definition),
			"",
			_field_accent(definition)
		)
		button.set_icon_texture(OperatorIcons.battlefield_icon(battlefield_id))
		button.set_selected(battlefield_id == _selected_battlefield_id)

func _refresh_selection_summary() -> void:
	if _summary_program == null:
		return
	var program_spec := _program_spec(_selected_program_id)
	var definition := _field_catalog.get_by_id(_selected_battlefield_id)

	_summary_program.text = String(program_spec.get("title", _selected_program_id)).to_upper()
	if definition == null:
		_summary_field.text = "NO BATTLEFIELD SELECTED"
		_summary_description.text = "Choose a battlefield before starting the simulation."
		_summary_meta.text = ""
		return

	_summary_field.text = definition.display_name.to_upper()
	_summary_description.text = definition.description
	_summary_meta.text = "%s FIELD  ·  GRID %dx%d  ·  MAX FOOTPRINT %s" % [
		definition.size_class.to_upper(),
		definition.grid_size.x,
		definition.grid_size.y,
		FootprintScript.display_label(definition.max_supported_footprint_id()),
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
	_refresh_start_battle_content()
	if _summary_state != null:
		_summary_state.text = "READY TO SIMULATE" if message.is_empty() else "NOT READY"
		_summary_state.add_theme_color_override("font_color", HUB_V2.GREEN if message.is_empty() else HUB_V2.RED)
	if not message.is_empty() and _summary_description != null:
		_summary_description.text = message

func _select_battle_program(program_id: String) -> void:
	var button := _battle_program_buttons.get(program_id) as DigiSelectionCard
	if button == null or button.disabled:
		return
	_selected_program_id = program_id
	_refresh_program_cards()
	_refresh_selection_summary()
	_refresh_launch_state(OverworldState.battle_party_validation_error())
	_sync_pages_to_selection()
	_refresh_page_visibility()

func _select_battlefield(battlefield_id: String) -> void:
	var button := _battlefield_buttons.get(battlefield_id) as DigiSelectionCard
	if button == null or button.disabled:
		return
	_selected_battlefield_id = battlefield_id
	_refresh_field_cards()
	_refresh_selection_summary()
	_refresh_launch_state(OverworldState.battle_party_validation_error())
	_sync_pages_to_selection()
	_refresh_page_visibility()

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
	if _summary_state != null:
		_summary_state.text = "SIMULATION UNAVAILABLE"
		_summary_state.add_theme_color_override("font_color", HUB_V2.RED)
	if _summary_description != null:
		_summary_description.text = message
	if _start_battle_button != null:
		_start_battle_button.grab_focus()

func _set_operator_controls_disabled(disabled: bool) -> void:
	for program_id: String in PROGRAM_IDS:
		var button := _battle_program_buttons.get(program_id) as DigiSelectionCard
		if button != null:
			button.set_interactive(not disabled)
	for battlefield_id: String in _field_order:
		var button := _battlefield_buttons.get(battlefield_id) as DigiSelectionCard
		if button != null:
			button.set_interactive(not disabled)
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
			return {"title": "BASIC BATTLE", "subtitle": "Koromon, Tanemon and Veemon. Fixed low-level baseline encounter.", "status": "MIXED", "accent": HUB_V2.CYAN}
		"random_fresh":
			return {"title": "RANDOM FRESH", "subtitle": "Three verified Fresh Digimon scaled to your squad.", "status": "FRESH", "accent": HUB_V2.CYAN}
		"random_baby":
			return {"title": "RANDOM BABY", "subtitle": "Three verified In-Training Digimon scaled to your squad.", "status": "IN-TRAINING", "accent": HUB_V2.BLUE}
		"random_rookie":
			return {"title": "RANDOM ROOKIE", "subtitle": "Three verified Rookie Digimon scaled to your squad.", "status": "ROOKIE", "accent": HUB_V2.GREEN}
		"random_champion":
			return {"title": "RANDOM CHAMPION", "subtitle": "Three verified Champion Digimon scaled to your squad.", "status": "CHAMPION", "accent": HUB_V2.AMBER}
		"random_ultimate":
			return {"title": "RANDOM ULTIMATE", "subtitle": "Three verified Ultimate Digimon scaled to your squad.", "status": "ULTIMATE", "accent": HUB_V2.RED}
		"random_mega":
			return {"title": "RANDOM MEGA", "subtitle": "Three verified Mega Digimon scaled to your squad.", "status": "MEGA", "accent": HUB_V2.PURPLE}
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


func _field_card_status(definition: BattlefieldDefinition) -> String:
	return definition.size_class.to_upper()

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
		if joy.pressed:
			if joy.button_index == JOY_BUTTON_LEFT_SHOULDER:
				_switch_operator_section(-1, true)
				get_viewport().set_input_as_handled()
				return
			if joy.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				_switch_operator_section(1, true)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		# Match the approved service screens: menu navigation belongs exclusively
		# to the left stick and passes through one hysteresis gate. Right-stick
		# motion and trigger axes are consumed but never mapped to menu focus.
		match motion.axis:
			JOY_AXIS_LEFT_Y:
				var step := _analog_gate.vertical_step(motion.axis_value)
				if step != 0:
					_focus_operator_neighbor("down" if step > 0 else "up")
			JOY_AXIS_LEFT_X:
				var step := _analog_gate.horizontal_step(motion.axis_value)
				if step != 0:
					_focus_operator_neighbor("right" if step > 0 else "left")
			_:
				pass
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_TAB:
			_switch_operator_section(-1 if key.shift_pressed else 1, true)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		_close_dialog()
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
		"action":
			if control_id == "launch":
				_launch_selected_battle()


func _handle_operator_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		if _fallback_action_touch != -1:
			return
		for program_id: String in PROGRAM_IDS:
			var program_button := _battle_program_buttons.get(program_id) as Button
			if program_button != null and program_button.visible and not program_button.disabled:
				if _control_contains_viewport_point(program_button, touch.position, 6.0):
					_fallback_action_touch = touch.index
					_select_battle_program(program_id)
					get_viewport().set_input_as_handled()
					return
		for battlefield_id: String in _field_order:
			var field_button := _battlefield_buttons.get(battlefield_id) as Button
			if field_button != null and field_button.visible and not field_button.disabled:
				if _control_contains_viewport_point(field_button, touch.position, 6.0):
					_fallback_action_touch = touch.index
					_select_battlefield(battlefield_id)
					get_viewport().set_input_as_handled()
					return
		if _compact_operator_layout and _section_tabs != null:
			for section_id: String in [SECTION_PROGRAM, SECTION_FIELD]:
				var tab := _section_tabs.get_button(section_id)
				if tab != null and tab.visible and _control_contains_viewport_point(tab, touch.position, 6.0):
					_fallback_action_touch = touch.index
					_set_operator_section(section_id, false)
					get_viewport().set_input_as_handled()
					return
		if _start_battle_button != null and not _start_battle_button.disabled:
			if _control_contains_viewport_point(_start_battle_button, touch.position, 8.0):
				_fallback_action_touch = touch.index
				_launch_selected_battle()
				get_viewport().set_input_as_handled()
				return
		if _operator_header != null:
			var close := _operator_header.get_close_button()
			if close != null and _control_contains_viewport_point(close, touch.position, 8.0):
				_fallback_action_touch = touch.index
				_close_dialog()
				get_viewport().set_input_as_handled()
				return
	elif touch.index == _fallback_action_touch:
		_fallback_action_touch = -1
		get_viewport().set_input_as_handled()


func _layout_mobile_dialog(physical: Vector2, ui_scale: float, landscape: bool, _edge: float) -> void:
	if (
		_dialog_panel == null
		or _mobile_dialog_content == null
		or _operator_header == null
		or _operator_footer == null
	):
		return

	# Use the exact workspace metrics shared by DigiLab and the modern Digimon
	# menu instead of sizing Battle Operator as a centered conversation dialog.
	_compact_operator_layout = WorkspaceChrome.is_compact(get_viewport())
	var short_landscape := landscape and physical.y < WorkspaceChrome.LOW_HEIGHT
	var workspace_edge := WorkspaceChrome.edge_for(_compact_operator_layout)
	var gap := WorkspaceChrome.GAP
	var header_h := WorkspaceChrome.header_height(_compact_operator_layout)
	var footer_h := WorkspaceChrome.FOOTER_HEIGHT
	var top_gap := WorkspaceChrome.top_gap(_compact_operator_layout)
	var body_top := header_h + top_gap
	var body_bottom := physical.y - footer_h - WorkspaceChrome.BOTTOM_GAP
	var body_h := maxf(120.0, body_bottom - body_top)

	_dialog_panel.scale = Vector2.ONE * ui_scale
	_dialog_panel.position = Vector2.ZERO
	_dialog_panel.size = physical
	_mobile_dialog_content.position = Vector2.ZERO
	_mobile_dialog_content.size = physical

	_operator_header.position = Vector2.ZERO
	_operator_header.size = Vector2(physical.x, header_h)
	_enforce_operator_header_focus_contract()
	if physical.x < 520.0:
		_operator_header.configure("BATTLE", "Battle Operator", 0, false)
	else:
		_operator_header.configure("BATTLE OPERATOR", "Battle Simulation", 0, false)
	_operator_header_rule.position = Vector2(0.0, header_h - 1.0)
	_operator_header_rule.size = Vector2(physical.x, 1.0)
	_operator_footer.position = Vector2(0.0, physical.y - footer_h)
	_operator_footer.size = Vector2(physical.x, footer_h)

	if _compact_operator_layout:
		var tabs_h := 46.0 if not short_landscape else 42.0
		var condensed_summary := short_landscape or physical.x < 620.0
		_section_tabs.visible = true
		_section_tabs.set_compact(true)
		_section_tabs.position = Vector2(workspace_edge, body_top)
		_section_tabs.size = Vector2(physical.x - workspace_edge * 2.0, tabs_h)

		var summary_h := 108.0 if condensed_summary else minf(176.0, body_h * 0.30)
		var list_top := body_top + tabs_h + gap
		var summary_top := body_bottom - summary_h
		var list_h := maxf(72.0, summary_top - gap - list_top)
		var body_rect := Rect2(
			workspace_edge,
			list_top,
			physical.x - workspace_edge * 2.0,
			list_h
		)

		_program_panel.position = body_rect.position
		_program_panel.size = body_rect.size
		_field_panel.position = body_rect.position
		_field_panel.size = body_rect.size
		_summary_panel.position = Vector2(workspace_edge, summary_top)
		_summary_panel.size = Vector2(physical.x - workspace_edge * 2.0, summary_h)

		_summary_header.visible = not condensed_summary
		_summary_description.visible = not condensed_summary
		_summary_meta.visible = not condensed_summary
		_start_battle_button.custom_minimum_size = Vector2(
			150.0 if condensed_summary else 190.0,
			HUB_V2.TOUCH_TARGET
		)

		_program_page_capacity = _page_capacity_for_height(list_h, PROGRAM_IDS.size(), short_landscape)
		_field_page_capacity = _page_capacity_for_height(list_h, _field_order.size(), short_landscape)
		if not landscape and physical.x < 520.0:
			_program_page_capacity = mini(_program_page_capacity, 4)
			_field_page_capacity = mini(_field_page_capacity, 4)
	else:
		_section_tabs.visible = false
		_summary_header.visible = true
		_summary_description.visible = true
		_summary_meta.visible = true
		_start_battle_button.custom_minimum_size = Vector2(220.0, HUB_V2.TOUCH_TARGET)

		var usable_w := physical.x - workspace_edge * 2.0 - gap * 2.0
		var program_w := clampf(usable_w * 0.30, 330.0, 470.0)
		var field_w := clampf(usable_w * 0.29, 320.0, 450.0)
		var summary_w := maxf(340.0, usable_w - program_w - field_w)

		_program_panel.position = Vector2(workspace_edge, body_top)
		_program_panel.size = Vector2(program_w, body_h)
		_field_panel.position = Vector2(workspace_edge + program_w + gap, body_top)
		_field_panel.size = Vector2(field_w, body_h)
		_summary_panel.position = Vector2(workspace_edge + program_w + gap + field_w + gap, body_top)
		_summary_panel.size = Vector2(summary_w, body_h)

		_program_page_capacity = PROGRAM_IDS.size()
		_field_page_capacity = _field_order.size()
		_program_page = 0
		_field_page = 0

	_apply_operator_density(short_landscape)
	_refresh_section_visibility()
	_refresh_page_visibility()
	_wire_operator_focus()

func _page_capacity_for_height(panel_height: float, total: int, short_landscape: bool) -> int:
	if total <= 1:
		return maxi(1, total)
	var card_h := DigiSelectionCard.COMPACT_HEIGHT
	var separation := 7.0
	var header_h := 44.0
	var margins := 16.0
	var pager_h := 43.0
	var list_h := maxf(card_h, panel_height - header_h - margins)
	var without_pager := clampi(int(floor((list_h + separation) / (card_h + separation))), 1, total)
	if without_pager >= total:
		return total
	list_h = maxf(card_h, list_h - pager_h)
	var capacity := clampi(int(floor((list_h + separation) / (card_h + separation))), 1, total)
	if short_landscape:
		capacity = mini(capacity, 2)
	return capacity


func _apply_operator_density(short_landscape: bool) -> void:
	var compact_cards := _compact_operator_layout
	for program_id: String in PROGRAM_IDS:
		var button := _battle_program_buttons.get(program_id) as DigiSelectionCard
		if button != null:
			button.set_compact(compact_cards)
	for battlefield_id: String in _field_order:
		var button := _battlefield_buttons.get(battlefield_id) as DigiSelectionCard
		if button != null:
			button.set_compact(compact_cards)
	if _program_pager != null:
		_program_pager.set_compact(short_landscape or _compact_operator_layout)
	if _field_pager != null:
		_field_pager.set_compact(short_landscape or _compact_operator_layout)
	if _summary_program != null:
		_summary_program.add_theme_font_size_override("font_size", 12 if short_landscape else (14 if _compact_operator_layout else 16))
	if _summary_field != null:
		_summary_field.add_theme_font_size_override("font_size", 11 if short_landscape else (12 if _compact_operator_layout else 14))


func _set_operator_section(section: String, focus_selected: bool = true) -> void:
	if section != SECTION_PROGRAM and section != SECTION_FIELD:
		return
	_operator_section = section
	if _section_tabs != null:
		_section_tabs.set_active(section)
	_sync_page_for_selected(section)
	_refresh_section_visibility()
	_refresh_page_visibility()
	_wire_operator_focus()
	if focus_selected:
		_focus_selected_in_active_section()


func _switch_operator_section(direction: int, focus_selected: bool = true) -> void:
	if direction == 0:
		return
	var next_section := SECTION_FIELD if _operator_section == SECTION_PROGRAM else SECTION_PROGRAM
	_set_operator_section(next_section, focus_selected)


func _refresh_section_visibility() -> void:
	if _program_panel == null or _field_panel == null:
		return
	if _compact_operator_layout:
		_program_panel.visible = _operator_section == SECTION_PROGRAM
		_field_panel.visible = _operator_section == SECTION_FIELD
	else:
		_program_panel.visible = true
		_field_panel.visible = true


func _sync_pages_to_selection() -> void:
	_sync_page_for_selected(SECTION_PROGRAM)
	_sync_page_for_selected(SECTION_FIELD)


func _sync_page_for_selected(section: String) -> void:
	if section == SECTION_PROGRAM:
		var index := PROGRAM_IDS.find(_selected_program_id)
		if index >= 0:
			_program_page = int(index / maxi(1, _program_page_capacity))
	elif section == SECTION_FIELD:
		var index := _field_order.find(_selected_battlefield_id)
		if index >= 0:
			_field_page = int(index / maxi(1, _field_page_capacity))


func _refresh_page_visibility() -> void:
	if _program_pager == null or _field_pager == null:
		return
	var program_pages := _page_count(PROGRAM_IDS.size(), _program_page_capacity)
	var field_pages := _page_count(_field_order.size(), _field_page_capacity)
	_program_page = clampi(_program_page, 0, program_pages - 1)
	_field_page = clampi(_field_page, 0, field_pages - 1)
	_program_pager.configure(_program_page, program_pages)
	_field_pager.configure(_field_page, field_pages)
	_program_pager.visible = _compact_operator_layout and program_pages > 1
	_field_pager.visible = _compact_operator_layout and field_pages > 1

	_apply_page_visibility(PROGRAM_IDS, _battle_program_buttons, _program_page, _program_page_capacity)
	_apply_page_visibility(_field_order, _battlefield_buttons, _field_page, _field_page_capacity)

	if _program_header != null:
		_program_header.set_trailing(
			_page_trailing(PROGRAM_IDS.size(), _program_page, _program_page_capacity, "PROGRAMS")
		)
	if _field_header != null:
		_field_header.set_trailing(
			_page_trailing(_field_order.size(), _field_page, _field_page_capacity, "FIELDS")
		)


func _apply_page_visibility(ids: Array[String], controls: Dictionary, page: int, capacity: int) -> void:
	var start := page * maxi(1, capacity)
	var finish := mini(ids.size(), start + maxi(1, capacity))
	for index in range(ids.size()):
		var control := controls.get(ids[index]) as Control
		if control != null:
			control.visible = not _compact_operator_layout or (index >= start and index < finish)


func _page_trailing(total: int, page: int, capacity: int, noun: String) -> String:
	if not _compact_operator_layout or capacity >= total:
		return "%d %s" % [total, noun]
	var start := page * capacity + 1
	var finish := mini(total, start + capacity - 1)
	return "%d–%d / %d" % [start, finish, total]


func _page_count(total: int, capacity: int) -> int:
	return maxi(1, int(ceil(float(maxi(1, total)) / float(maxi(1, capacity)))))


func _turn_program_page(delta: int, focus_card: bool = false) -> void:
	var count := _page_count(PROGRAM_IDS.size(), _program_page_capacity)
	var next_page := clampi(_program_page + delta, 0, count - 1)
	if next_page == _program_page:
		return
	_program_page = next_page
	_refresh_page_visibility()
	_wire_operator_focus()
	if focus_card:
		_focus_page_edge(SECTION_PROGRAM, delta)


func _turn_field_page(delta: int, focus_card: bool = false) -> void:
	var count := _page_count(_field_order.size(), _field_page_capacity)
	var next_page := clampi(_field_page + delta, 0, count - 1)
	if next_page == _field_page:
		return
	_field_page = next_page
	_refresh_page_visibility()
	_wire_operator_focus()
	if focus_card:
		_focus_page_edge(SECTION_FIELD, delta)


func _focus_page_edge(section: String, direction: int) -> void:
	var ids := PROGRAM_IDS if section == SECTION_PROGRAM else _field_order
	var controls := _battle_program_buttons if section == SECTION_PROGRAM else _battlefield_buttons
	var page := _program_page if section == SECTION_PROGRAM else _field_page
	var capacity := _program_page_capacity if section == SECTION_PROGRAM else _field_page_capacity
	var visible := _visible_ids(ids, page, capacity)
	if visible.is_empty():
		return
	var id := visible[0] if direction > 0 else visible[visible.size() - 1]
	var button := controls.get(id) as Button
	if button != null and not button.disabled:
		button.grab_focus()


func _visible_ids(ids: Array[String], page: int, capacity: int) -> Array[String]:
	if not _compact_operator_layout:
		return ids.duplicate()
	var result: Array[String] = []
	var start := page * maxi(1, capacity)
	var finish := mini(ids.size(), start + maxi(1, capacity))
	for index in range(start, finish):
		result.append(ids[index])
	return result


func _wire_operator_focus() -> void:
	if _start_battle_button == null:
		return
	_wire_selection_list(
		PROGRAM_IDS,
		_battle_program_buttons,
		_program_page,
		_program_page_capacity,
		SECTION_PROGRAM
	)
	_wire_selection_list(
		_field_order,
		_battlefield_buttons,
		_field_page,
		_field_page_capacity,
		SECTION_FIELD
	)
	var selected_field := _selected_field_button()
	if selected_field != null:
		_start_battle_button.focus_neighbor_left = _start_battle_button.get_path_to(selected_field)
		_start_battle_button.focus_neighbor_top = _start_battle_button.get_path_to(selected_field)
	_start_battle_button.focus_neighbor_right = _start_battle_button.get_path()
	_start_battle_button.focus_neighbor_bottom = _start_battle_button.get_path()

func _wire_selection_list(
	ids: Array[String],
	controls: Dictionary,
	page: int,
	capacity: int,
	section: String
) -> void:
	var visible := _visible_ids(ids, page, capacity)
	if visible.is_empty():
		return
	for index in range(visible.size()):
		var button := controls.get(visible[index]) as Button
		if button == null:
			continue

		# Lists use the same page-local wrap contract as the approved roster
		# screens. Focus moves exactly one visible item per navigation step.
		var previous := controls.get(visible[posmod(index - 1, visible.size())]) as Button
		var next := controls.get(visible[posmod(index + 1, visible.size())]) as Button
		if previous != null:
			button.focus_neighbor_top = button.get_path_to(previous)
		if next != null:
			button.focus_neighbor_bottom = button.get_path_to(next)

		if not _compact_operator_layout:
			if section == SECTION_PROGRAM:
				var field := _selected_field_button()
				if field != null:
					button.focus_neighbor_right = button.get_path_to(field)
				button.focus_neighbor_left = button.get_path()
			else:
				var program := _selected_program_button()
				if program != null:
					button.focus_neighbor_left = button.get_path_to(program)
				button.focus_neighbor_right = button.get_path_to(_start_battle_button)
		else:
			# Compact keeps one list visible at a time. Horizontal focus changes
			# section (or reaches Start) in _focus_operator_neighbor rather than
			# inventing hidden focus neighbors.
			button.focus_neighbor_left = button.get_path()
			button.focus_neighbor_right = button.get_path()

func _focus_operator_neighbor(direction: String) -> void:
	var focus := get_viewport().gui_get_focus_owner() as Control
	if focus == null:
		_focus_selected_program()
		return

	var kind := String(focus.get_meta("operator_kind", ""))
	if _compact_operator_layout:
		if kind == "program" and direction == "right":
			_set_operator_section(SECTION_FIELD, true)
			return
		if kind == "field" and direction == "left":
			_set_operator_section(SECTION_PROGRAM, true)
			return
		if kind == "field" and direction == "right":
			_start_battle_button.grab_focus()
			return
		if kind == "action" and direction == "left":
			_set_operator_section(SECTION_FIELD, true)
			return
		if direction == "down" and _maybe_turn_page_at_edge(kind, 1):
			return
		if direction == "up" and _maybe_turn_page_at_edge(kind, -1):
			return

	var path := NodePath()
	match direction:
		"left": path = focus.focus_neighbor_left
		"right": path = focus.focus_neighbor_right
		"up": path = focus.focus_neighbor_top
		"down": path = focus.focus_neighbor_bottom
	if path.is_empty():
		return
	var target := focus.get_node_or_null(path) as Control
	if target != null and target.visible and target.focus_mode != Control.FOCUS_NONE:
		if not (target is Button) or not (target as Button).disabled:
			target.grab_focus()


func _maybe_turn_page_at_edge(kind: String, delta: int) -> bool:
	var section := ""
	var ids: Array[String] = []
	var controls: Dictionary = {}
	var page := 0
	var capacity := 1
	if kind == "program":
		section = SECTION_PROGRAM
		ids = PROGRAM_IDS
		controls = _battle_program_buttons
		page = _program_page
		capacity = _program_page_capacity
	elif kind == "field":
		section = SECTION_FIELD
		ids = _field_order
		controls = _battlefield_buttons
		page = _field_page
		capacity = _field_page_capacity
	else:
		return false

	var focus := get_viewport().gui_get_focus_owner() as Button
	var visible := _visible_ids(ids, page, capacity)
	if focus == null or visible.is_empty():
		return false
	var focused_id := String(focus.get_meta("operator_id", ""))
	var edge_id := visible[visible.size() - 1] if delta > 0 else visible[0]
	if focused_id != edge_id:
		return false

	var page_count := _page_count(ids.size(), capacity)
	var next_page := clampi(page + delta, 0, page_count - 1)
	if next_page == page:
		return false
	if section == SECTION_PROGRAM:
		_turn_program_page(delta, true)
	else:
		_turn_field_page(delta, true)
	return true


func _focus_selected_program() -> void:
	var button := _selected_program_button()
	if button != null and button.visible and not button.disabled:
		button.grab_focus()
		return
	_focus_first_visible(SECTION_PROGRAM)


func _focus_selected_in_active_section() -> void:
	var button := _selected_active_button()
	if button != null and button.visible and not button.disabled:
		button.grab_focus()
		return
	_focus_first_visible(_operator_section)


func _focus_first_visible(section: String) -> void:
	var ids := PROGRAM_IDS if section == SECTION_PROGRAM else _field_order
	var controls := _battle_program_buttons if section == SECTION_PROGRAM else _battlefield_buttons
	var page := _program_page if section == SECTION_PROGRAM else _field_page
	var capacity := _program_page_capacity if section == SECTION_PROGRAM else _field_page_capacity
	for id: String in _visible_ids(ids, page, capacity):
		var button := controls.get(id) as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return


func _selected_active_button() -> Button:
	return _selected_program_button() if _operator_section == SECTION_PROGRAM else _selected_field_button()


func _selected_program_button() -> Button:
	return _battle_program_buttons.get(_selected_program_id) as Button


func _selected_field_button() -> Button:
	return _battlefield_buttons.get(_selected_battlefield_id) as Button

