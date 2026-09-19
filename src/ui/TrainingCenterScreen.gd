extends Control
class_name TrainingCenterScreen

signal close_requested

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const TrainingServiceScript = preload("res://src/digimon/DigimonTrainingService.gd")
const StatCalculatorScript = preload("res://src/digimon/DigimonStatCalculator.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const TrainingStatRowScript = preload("res://src/ui/TrainingStatRow.gd")
const ModalHeaderScript = preload("res://src/ui/components/DigiModalHeader.gd")
const SectionHeaderScript = preload("res://src/ui/components/DigiSectionHeader.gd")
const InputHintBarScript = preload("res://src/ui/components/DigiInputHintBar.gd")
const ProceduralIconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")
const CommandButtonScript = preload("res://src/ui/components/DigiCommandButton.gd")
const WorkspaceChrome = preload("res://src/ui/components/DigiWorkspaceChrome.gd")
const PagerScript = preload("res://src/ui/components/DigiPager.gd")
const AnalogGateScript = preload("res://src/ui/components/DigiAnalogNavigationGate.gd")
const ConfirmationScript = preload("res://src/ui/components/DigiConfirmationModal.gd")
const TransitionSurfaceScript = preload("res://src/ui/components/DigiUiTransitionSurface.gd")
const TRAINING_BACKGROUND := preload("res://assets/ui/backgrounds/training.webp")

const ROSTER_PAGE_SIZE := 3

enum InteractionMode {
	ROSTER,
	EDITING,
}

enum DetailView {
	ATTRIBUTES,
	MOBILITY,
}

var STAT_META := {
	"hp": ["HP", V2.GREEN],
	"mp": ["SP", V2.BLUE],
	"atk": ["ATK", V2.AMBER],
	"def": ["DEF", V2.CYAN],
	"int": ["INT", V2.PURPLE],
	"speed": ["SPD", V2.ORANGE],
}

var _database: DigimonDatabase
var _training: DigimonTrainingService
var _calculator: DigimonStatCalculator
var _selected_id := ""
var _pending_stats: Dictionary = {}
var _roster_page := 0
var _compact_layout := false
var _interaction_mode := InteractionMode.ROSTER
var _detail_view := DetailView.ATTRIBUTES
var _pointer_card_press := false
var _state_mutation_in_progress := false
var _pending_confirmation_action := ""
var _pending_confirmation_target := ""
var _analog_gate: DigiAnalogNavigationGate = AnalogGateScript.new() as DigiAnalogNavigationGate

var _frame: PanelContainer
var _menu_root: Control
var _header: DigiModalHeader
var _hint_bar: DigiInputHintBar
var _collection_panel: PanelContainer
var _collection_header: DigiSectionHeader
var _collection_list: VBoxContainer
var _roster_pager: DigiPager
var _collection_buttons: Array[Button] = []
var _collection_ids: Array[String] = []
var _collection_previews: Array[DigimonWalkPreview] = []
var _detail_panel: PanelContainer
var _compact_back_button: Button
var _detail_root: VBoxContainer
var _status_panel: PanelContainer
var _status_icon: DigiProceduralIcon
var _status: Label
var _identity_card: PanelContainer
var _identity_portrait: DigimonPortraitPreview
var _identity_name: Label
var _identity_meta: Label
var _identity_copy: Label
var _budget_card: PanelContainer
var _potential_value: Label
var _capacity_value: Label
var _available_value: Label
var _capacity_bar: ProgressBar
var _detail_tabs: HBoxContainer
var _detail_tab_buttons: Dictionary = {}
var _presentation_host: Control
var _attributes_view: VBoxContainer
var _attribute_toolbar_icon: DigiProceduralIcon
var _attribute_toolbar_title: Label
var _attribute_rate: Label
var _stat_grid: GridContainer
var _stat_rows: Dictionary = {}
var _attribute_plan_bar: PanelContainer
var _attribute_plan_summary: Label
var _attribute_plan_validation: Label
var _discard_button: Button
var _apply_button: Button
var _mobility_view: VBoxContainer
var _mobility_card: PanelContainer
var _mobility_title_icon: DigiProceduralIcon
var _mobility_title_label: Label
var _mobility_explanation: Label
var _mobility_value: Label
var _mobility_level: Label
var _mobility_requirement: Label
var _mobility_plus: Button
var _confirmation: DigiConfirmationModal
var _editor_focus_rows: Array = []
var _transition_surface: DigiUiTransitionSurface = null
var _close_lifecycle_managed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_database = OverworldState.get_database() as DigimonDatabase
	_training = TrainingServiceScript.new() as DigimonTrainingService
	_calculator = StatCalculatorScript.new() as DigimonStatCalculator
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	OverworldState.collection_changed.connect(_on_collection_changed)
	get_viewport().size_changed.connect(_layout)
	visible = false


func get_transition_surface() -> DigiUiTransitionSurface:
	return _transition_surface


func set_close_lifecycle_managed(value: bool) -> void:
	_close_lifecycle_managed = value


func open_screen() -> void:
	visible = true
	_analog_gate.reset()
	_interaction_mode = InteractionMode.ROSTER
	_detail_view = DetailView.ATTRIBUTES
	var owned: Array[DigimonInstance] = OverworldState.get_collection_instances()
	if (_selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null) and not owned.is_empty():
		_selected_id = owned[0].id
	_clear_plan()
	_roster_page = _page_for_instance(_selected_id)
	_set_status("Choose a Digimon, then build a permanent training plan.", V2.CYAN)
	_refresh_collection()
	_refresh_detail_values()
	_apply_detail_view()
	_layout()
	_update_footer_hints()
	call_deferred("_layout")
	call_deferred("_focus_selected_collection")
	# Full-screen construction is provided by the shared transition surface.
	_frame.modulate.a = 1.0


func finish_close() -> void:
	if _confirmation != null and _confirmation.visible:
		_confirmation.close_dialog(false)
	_pending_confirmation_action = ""
	_pending_confirmation_target = ""
	_clear_plan()
	visible = false


func close_view() -> void:
	# Preserve the immediate programmatic close contract for tests/tools. Player
	# input uses _request_close(), allowing the Hub to animate before finalizing.
	finish_close()
	close_requested.emit()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible or (_confirmation != null and _confirmation.visible):
		return
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_Y:
			var vertical := _analog_gate.vertical_step(motion.axis_value)
			if vertical != 0:
				if _interaction_mode == InteractionMode.ROSTER:
					_move_roster_focus(vertical)
				else:
					_move_editor_vertical(vertical)
			get_viewport().set_input_as_handled()
			return
		if motion.axis == JOY_AXIS_LEFT_X:
			var horizontal := _analog_gate.horizontal_step(motion.axis_value)
			if horizontal != 0 and _interaction_mode == InteractionMode.EDITING:
				_move_editor_horizontal(horizontal)
			get_viewport().set_input_as_handled()
			return
		if motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			var page_step := _analog_gate.trigger_step(motion.axis, motion.axis_value)
			if page_step != 0 and _interaction_mode == InteractionMode.ROSTER:
				_turn_roster_page(page_step)
				call_deferred("_focus_first_collection")
			get_viewport().set_input_as_handled()
			return
		return


func _unhandled_input(event: InputEvent) -> void:
	if not visible or (_confirmation != null and _confirmation.visible):
		return

	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var joy := event as InputEventJoypadButton
		if joy.button_index == JOY_BUTTON_X and _interaction_mode == InteractionMode.EDITING:
			_toggle_detail_view()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X and _interaction_mode == InteractionMode.EDITING:
		_toggle_detail_view()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		if _interaction_mode == InteractionMode.EDITING:
			_return_to_roster()
		else:
			_request_close()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_up"):
		if _interaction_mode == InteractionMode.ROSTER:
			_move_roster_focus(-1)
		else:
			_move_editor_vertical(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		if _interaction_mode == InteractionMode.ROSTER:
			_move_roster_focus(1)
		else:
			_move_editor_vertical(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		if _interaction_mode == InteractionMode.EDITING:
			_move_editor_horizontal(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		if _interaction_mode == InteractionMode.EDITING:
			_move_editor_horizontal(1)
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_transition_surface = TransitionSurfaceScript.new() as DigiUiTransitionSurface
	_transition_surface.name = "TrainingTransition"
	add_child(_transition_surface)

	var background := TextureRect.new()
	background.name = "TrainingBackgroundImage"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = TRAINING_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.94, 0.98, 1.0, 0.94)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_surface.add_transition_child(background)

	var shade := ColorRect.new()
	shade.name = "TrainingBackgroundShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.004, 0.018, 0.030, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_surface.add_transition_child(shade)

	var cyan_wash := ColorRect.new()
	cyan_wash.name = "TrainingCyanWash"
	cyan_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cyan_wash.color = Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.018)
	cyan_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_surface.add_transition_child(cyan_wash)

	_frame = PanelContainer.new()
	_frame.name = "TrainingWorkspaceV2"
	_frame.clip_contents = false
	_frame.add_theme_stylebox_override("panel", V2.surface_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	_transition_surface.add_transition_child(_frame)

	_menu_root = Control.new()
	_menu_root.name = "TrainingWorkspaceContent"
	_menu_root.clip_contents = true
	_frame.add_child(_menu_root)

	_header = ModalHeaderScript.new() as DigiModalHeader
	_header.name = "TrainingHeader"
	_header.set_workspace_mode(true)
	_header.configure("TRAINING", "Permanent Growth", 0, false)
	_header.configure_tabs([], "")
	_header.close_requested.connect(_request_close)
	_menu_root.add_child(_header)
	var close := _header.get_close_button()
	if close != null:
		close.focus_mode = Control.FOCUS_NONE

	_build_collection_panel(_menu_root)
	_build_detail_panel(_menu_root)

	_compact_back_button = _workspace_button("‹  DIGIMON", V2.CYAN)
	_compact_back_button.name = "CompactBackToRoster"
	_compact_back_button.custom_minimum_size = Vector2(148.0, V2.TOUCH_TARGET)
	_compact_back_button.visible = false
	_compact_back_button.pressed.connect(_return_to_roster)
	_menu_root.add_child(_compact_back_button)

	_hint_bar = InputHintBarScript.new() as DigiInputHintBar
	_hint_bar.name = "TrainingInputHints"
	_hint_bar.set_description("Choose a Digimon and build a permanent training plan.")
	_hint_bar.set_scroll_hint_enabled(false)
	_hint_bar.set_hide_hints_on_touch(true)
	_hint_bar.set_secondary_tabs_label("Attributes / Mobility")
	_menu_root.add_child(_hint_bar)

	_confirmation = ConfirmationScript.new() as DigiConfirmationModal
	_confirmation.name = "TrainingConfirmation"
	_confirmation.confirmed.connect(_on_confirmation_confirmed)
	_confirmation.cancelled.connect(_on_confirmation_cancelled)
	add_child(_confirmation)


func _build_collection_panel(parent: Control) -> void:
	_collection_panel = PanelContainer.new()
	_collection_panel.name = "TrainingRoster"
	_collection_panel.clip_contents = true
	_collection_panel.add_theme_stylebox_override("panel", V2.hospital_panel_style(V2.CYAN))
	parent.add_child(_collection_panel)

	var margin := _margin(10, 10, 10, 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 9)
	margin.add_child(root)

	_collection_header = SectionHeaderScript.new() as DigiSectionHeader
	_collection_header.name = "TrainingRosterHeader"
	_collection_header.configure("DIGIMON", "", V2.CYAN, "digimon")
	_collection_header.set_workspace_mode(true)
	root.add_child(_collection_header)

	var intro := _single_line_label("Choose the individual you want to train.", 11, V2.MUTED)
	intro.custom_minimum_size.y = 24.0
	root.add_child(intro)

	_collection_list = VBoxContainer.new()
	_collection_list.name = "TrainingRosterCards"
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_list.alignment = BoxContainer.ALIGNMENT_BEGIN
	_collection_list.add_theme_constant_override("separation", 9)
	root.add_child(_collection_list)

	_roster_pager = PagerScript.new() as DigiPager
	_roster_pager.name = "TrainingRosterPager"
	_roster_pager.set_workspace_mode(true)
	_roster_pager.page_delta_requested.connect(_turn_roster_page)
	root.add_child(_roster_pager)


func _build_detail_panel(parent: Control) -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "TrainingDetails"
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override("panel", V2.workspace_panel_style(V2.CYAN))
	parent.add_child(_detail_panel)

	var margin := _margin(10, 10, 10, 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(margin)

	_detail_root = VBoxContainer.new()
	_detail_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_root.add_theme_constant_override("separation", 8)
	margin.add_child(_detail_root)

	_build_status()
	_status_panel.visible = false
	_build_identity()
	_build_budget()
	_build_detail_tabs()
	_build_presentation()


func _build_status() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.name = "TrainingStatus"
	_status_panel.custom_minimum_size.y = 38.0
	_detail_root.add_child(_status_panel)
	var margin := _margin(12, 6, 12, 6)
	_status_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	_status_icon = ProceduralIconScript.new() as DigiProceduralIcon
	_status_icon.custom_minimum_size = Vector2(18.0, 18.0)
	_status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_status_icon)
	_status = _single_line_label("Choose a Digimon, then build a permanent training plan.", 10, V2.CYAN, true)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	_set_status(_status.text, V2.CYAN)


func _build_identity() -> void:
	_identity_card = PanelContainer.new()
	_identity_card.name = "TrainingIdentity"
	_identity_card.custom_minimum_size.y = 82.0
	_identity_card.add_theme_stylebox_override("panel", V2.hospital_panel_style(V2.CYAN))
	_detail_root.add_child(_identity_card)

	var margin := _margin(12, 8, 12, 8)
	_identity_card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(78.0, 68.0)
	portrait_frame.add_theme_stylebox_override("panel", V2.surface_style(V2.PANEL_DEEP, Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.42), 8))
	row.add_child(portrait_frame)
	var portrait_margin := _margin(5, 5, 5, 5)
	portrait_frame.add_child(portrait_margin)
	_identity_portrait = PortraitPreviewScript.new() as DigimonPortraitPreview
	_identity_portrait.custom_minimum_size = Vector2(68.0, 58.0)
	portrait_margin.add_child(_identity_portrait)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	_identity_name = _single_line_label("DIGIMON", 19, V2.WHITE, true)
	copy.add_child(_identity_name)
	_identity_meta = _single_line_label("ROOKIE · LV 1 · TIER E", 11, V2.CYAN, true)
	copy.add_child(_identity_meta)
	_identity_copy = _single_line_label("Training is permanent through Digivolution and Degeneration.", 10, V2.MUTED)
	copy.add_child(_identity_copy)


func _build_budget() -> void:
	_budget_card = PanelContainer.new()
	_budget_card.name = "TrainingBudget"
	_budget_card.custom_minimum_size.y = 68.0
	_budget_card.add_theme_stylebox_override("panel", V2.hospital_panel_style(V2.PURPLE))
	_detail_root.add_child(_budget_card)

	var margin := _margin(12, 7, 12, 7)
	_budget_card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size.y = 18.0
	title_row.add_theme_constant_override("separation", 8)
	stack.add_child(title_row)
	var icon := ProceduralIconScript.new() as DigiProceduralIcon
	icon.custom_minimum_size = Vector2(20.0, 20.0)
	icon.configure("training", V2.PURPLE, 1.5)
	title_row.add_child(icon)
	var title := _single_line_label("TRAINING BUDGET", 11, V2.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var formula := _single_line_label("Base 10 · +1 / 2 Potential", 9, V2.MUTED)
	title_row.add_child(formula)

	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 8)
	stack.add_child(metrics)
	_potential_value = _budget_metric(metrics, "POTENTIAL", V2.PURPLE)
	_capacity_value = _budget_metric(metrics, "CAPACITY", V2.CYAN)
	_available_value = _budget_metric(metrics, "AVAILABLE", V2.GREEN)

	_capacity_bar = _progress(V2.PURPLE, 10, 0)
	_capacity_bar.custom_minimum_size.y = 6.0
	stack.add_child(_capacity_bar)


func _budget_metric(parent: HBoxContainer, title: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", V2.surface_style(V2.SURFACE_SOFT, Color(accent.r, accent.g, accent.b, 0.24), 6))
	parent.add_child(panel)
	var margin := _margin(8, 4, 8, 4)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	var caption := _single_line_label(title, 9, V2.MUTED, true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var value := _single_line_label("0", 11, accent, true)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 48.0
	row.add_child(value)
	return value


func _build_detail_tabs() -> void:
	_detail_tabs = HBoxContainer.new()
	_detail_tabs.name = "TrainingViewTabs"
	_detail_tabs.custom_minimum_size.y = V2.TOUCH_TARGET
	_detail_tabs.add_theme_constant_override("separation", 6)
	_detail_root.add_child(_detail_tabs)

	for spec in [[DetailView.ATTRIBUTES, "ATTRIBUTES"], [DetailView.MOBILITY, "MOBILITY"]]:
		var view_id := int(spec[0])
		var button := Button.new()
		button.name = "AttributesTab" if view_id == DetailView.ATTRIBUTES else "MobilityTab"
		button.text = String(spec[1])
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = V2.TOUCH_TARGET
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_set_detail_view.bind(view_id, false))
		V2.apply_heading(button)
		_detail_tabs.add_child(button)
		_detail_tab_buttons[view_id] = button


func _build_presentation() -> void:
	_presentation_host = Control.new()
	_presentation_host.name = "TrainingPresentationHost"
	_presentation_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_presentation_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_presentation_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_presentation_host.clip_contents = true
	_detail_root.add_child(_presentation_host)

	_attributes_view = VBoxContainer.new()
	_attributes_view.name = "AttributesView"
	_attributes_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attributes_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_attributes_view.add_theme_constant_override("separation", 6)
	_presentation_host.add_child(_attributes_view)
	_attributes_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_attribute_toolbar()

	_stat_grid = GridContainer.new()
	_stat_grid.name = "TrainingStatGrid"
	_stat_grid.columns = 2
	_stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_stat_grid.add_theme_constant_override("h_separation", 8)
	_stat_grid.add_theme_constant_override("v_separation", 5)
	_attributes_view.add_child(_stat_grid)

	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed"]:
		var row := TrainingStatRowScript.new() as TrainingStatRow
		row.name = "Training_%s" % stat_key
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_requested.connect(_add_stat)
		row.remove_requested.connect(_remove_stat)
		_stat_grid.add_child(row)
		_stat_rows[stat_key] = row

	_mobility_view = VBoxContainer.new()
	_mobility_view.name = "MobilityView"
	_mobility_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobility_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mobility_view.add_theme_constant_override("separation", 0)
	_presentation_host.add_child(_mobility_view)
	_mobility_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top_spacer := Control.new()
	top_spacer.name = "MobilityTopSpacer"
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.size_flags_stretch_ratio = 1.0
	_mobility_view.add_child(top_spacer)

	_build_mobility_panel()

	var bottom_spacer := Control.new()
	bottom_spacer.name = "MobilityBottomSpacer"
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.size_flags_stretch_ratio = 1.0
	_mobility_view.add_child(bottom_spacer)


func _build_attribute_toolbar() -> void:
	_attribute_plan_bar = PanelContainer.new()
	_attribute_plan_bar.name = "AttributeTrainingToolbar"
	_attribute_plan_bar.custom_minimum_size.y = 58.0
	_attribute_plan_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attribute_plan_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_attribute_plan_bar.add_theme_stylebox_override("panel", V2.workspace_panel_style(V2.CYAN))
	_attributes_view.add_child(_attribute_plan_bar)

	var margin := _margin(10, 3, 10, 3)
	_attribute_plan_bar.add_child(margin)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var title_group := HBoxContainer.new()
	title_group.name = "AttributeTitleGroup"
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_group.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_group.alignment = BoxContainer.ALIGNMENT_BEGIN
	title_group.add_theme_constant_override("separation", 8)
	title_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title_group)

	var icon_center := CenterContainer.new()
	icon_center.name = "AttributeTrainingIconSlot"
	icon_center.custom_minimum_size = Vector2(26.0, 0.0)
	icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_group.add_child(icon_center)
	_attribute_toolbar_icon = ProceduralIconScript.new() as DigiProceduralIcon
	_attribute_toolbar_icon.name = "AttributeTrainingIcon"
	_attribute_toolbar_icon.custom_minimum_size = Vector2(22.0, 22.0)
	_attribute_toolbar_icon.configure("training", V2.CYAN, 1.65)
	icon_center.add_child(_attribute_toolbar_icon)

	_attribute_toolbar_title = _single_line_label("ATTRIBUTE TRAINING", 13, V2.TEXT, true)
	_attribute_toolbar_title.name = "AttributeTrainingTitle"
	_attribute_toolbar_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_group.add_child(_attribute_toolbar_title)
	_attribute_rate = _single_line_label("1 point = +%.1f%%" % _training.stat_bonus_percent(1), 8, V2.MUTED)
	_attribute_rate.name = "AttributeTrainingRate"
	_attribute_rate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_group.add_child(_attribute_rate)

	var summary := VBoxContainer.new()
	summary.name = "AttributePlanSummary"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 0)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(summary)
	_attribute_plan_summary = _single_line_label("NO PENDING CHANGES", 9, V2.GREEN, true)
	_attribute_plan_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary.add_child(_attribute_plan_summary)
	_attribute_plan_validation = _single_line_label("Adjust attributes to build a plan.", 8, V2.MUTED)
	_attribute_plan_validation.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary.add_child(_attribute_plan_validation)

	_discard_button = _training_command_button("DISCARD", "Clear pending attribute changes", "", "move", V2.MUTED, true)
	_discard_button.name = "DiscardAttributePlan"
	_discard_button.pressed.connect(_discard_plan)
	row.add_child(_discard_button)
	_discard_button.custom_minimum_size = Vector2(112.0, V2.TOUCH_TARGET)

	_apply_button = _training_command_button("APPLY", "Save permanent attribute growth", "", "training", V2.GREEN, true)
	_apply_button.name = "ApplyAttributePlan"
	_apply_button.pressed.connect(_request_apply_plan)
	row.add_child(_apply_button)
	_apply_button.custom_minimum_size = Vector2(112.0, V2.TOUCH_TARGET)


func _build_mobility_panel() -> void:
	_mobility_card = PanelContainer.new()
	_mobility_card.name = "MobilityTraining"
	_mobility_card.custom_minimum_size.y = 156.0
	_mobility_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobility_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mobility_card.add_theme_stylebox_override("panel", V2.workspace_panel_style(V2.AMBER))
	_mobility_view.add_child(_mobility_card)

	var margin := _margin(18, 10, 18, 10)
	_mobility_card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size.y = 32.0
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 9)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title_row)

	var title_icon_center := CenterContainer.new()
	title_icon_center.name = "MobilityTitleIconSlot"
	title_icon_center.custom_minimum_size = Vector2(28.0, 0.0)
	title_icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title_icon_center)
	_mobility_title_icon = ProceduralIconScript.new() as DigiProceduralIcon
	_mobility_title_icon.name = "MobilityTitleIcon"
	_mobility_title_icon.custom_minimum_size = Vector2(24.0, 24.0)
	_mobility_title_icon.configure("move", V2.AMBER, 1.8)
	title_icon_center.add_child(_mobility_title_icon)

	_mobility_title_label = _single_line_label("TACTICAL MOBILITY", 14, V2.TEXT, true)
	_mobility_title_label.name = "MobilityTitleLabel"
	_mobility_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_mobility_title_label)
	var permanent := _single_line_label("PERMANENT", 9, V2.AMBER, true)
	permanent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(permanent)

	var body := HBoxContainer.new()
	body.name = "MobilityBody"
	body.custom_minimum_size.y = 82.0
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_theme_constant_override("separation", 18)
	stack.add_child(body)

	var metrics := VBoxContainer.new()
	metrics.custom_minimum_size.x = 170.0
	metrics.size_flags_vertical = Control.SIZE_EXPAND_FILL
	metrics.alignment = BoxContainer.ALIGNMENT_CENTER
	metrics.add_theme_constant_override("separation", 2)
	body.add_child(metrics)
	_mobility_value = _single_line_label("MOV 0", 22, V2.WHITE, true)
	metrics.add_child(_mobility_value)
	_mobility_level = _single_line_label("MOBILITY 0 / 2", 10, V2.AMBER, true)
	metrics.add_child(_mobility_level)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 4)
	body.add_child(copy)
	_mobility_explanation = _single_line_label(
		"MOV is independent from attribute training and applies immediately after confirmation.",
		9,
		V2.MUTED
	)
	_mobility_explanation.name = "MobilityExplanation"
	copy.add_child(_mobility_explanation)
	_mobility_requirement = _single_line_label("", 10, V2.MUTED, true)
	_mobility_requirement.name = "MobilityRequirement"
	copy.add_child(_mobility_requirement)

	_mobility_plus = _training_command_button(
		"TRAIN MOV +1",
		"Apply the next permanent mobility level",
		"",
		"move",
		V2.AMBER,
		false
	)
	_mobility_plus.name = "TrainMobility"
	_mobility_plus.pressed.connect(_request_mobility_training)
	body.add_child(_mobility_plus)
	_mobility_plus.custom_minimum_size = Vector2(250.0, 72.0)


func _refresh_collection() -> void:
	for child in _collection_list.get_children():
		_collection_list.remove_child(child)
		child.queue_free()
	_collection_buttons.clear()
	_collection_ids.clear()
	_collection_previews.clear()

	var owned: Array[DigimonInstance] = OverworldState.get_collection_instances()
	_collection_header.set_trailing("%d OWNED" % owned.size())
	var page_count := maxi(1, ceili(float(owned.size()) / float(ROSTER_PAGE_SIZE)))
	_roster_page = clampi(_roster_page, 0, page_count - 1)
	_roster_pager.configure(_roster_page, page_count)
	_roster_pager.set_compact(_compact_layout)

	if owned.is_empty():
		_collection_list.add_child(_empty_state("No Digimon in your collection."))
		_update_footer_hints()
		return

	if _selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null:
		_selected_id = owned[0].id

	var active_ids := OverworldState.get_active_party_ids()
	var start := _roster_page * ROSTER_PAGE_SIZE
	var finish := mini(owned.size(), start + ROSTER_PAGE_SIZE)
	for index in range(start, finish):
		var instance: DigimonInstance = owned[index]
		var species := _database.get_by_seed(instance.species_seed)
		var card := _collection_button(instance, species, active_ids.has(instance.id))
		_collection_list.add_child(card)
		_collection_buttons.append(card)
		_collection_ids.append(instance.id)

	_style_collection_selection()
	_update_footer_hints()


func _collection_button(instance: DigimonInstance, species: Dictionary, active: bool) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0.0, _roster_card_height())
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Train %s" % instance.get_display_name(String(species.get("name", "Digimon")))
	button.gui_input.connect(_on_roster_card_gui_input)
	button.pressed.connect(_activate_instance.bind(instance.id))
	_style_collection_button(button, instance.id == _selected_id)

	var margin := _margin(10, 8, 10, 8)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.name = "WalkPreview"
	preview.custom_minimum_size = Vector2(72.0, 72.0) if _compact_layout else Vector2(88.0, 88.0)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_species(String(species.get("name", "")))
	preview.set_active(instance.id == _selected_id)
	row.add_child(preview)
	_collection_previews.append(preview)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var name := instance.get_display_name(String(species.get("name", "Unknown")))
	copy.add_child(_single_line_label(name.to_upper(), 15 if _compact_layout else 18, V2.WHITE, true))
	var location := "PARTY" if active else "STORAGE"
	var location_color := V2.GREEN if active else V2.MUTED
	copy.add_child(_single_line_label("LV %d · %s" % [instance.level, location], 10 if _compact_layout else 12, location_color, true))
	copy.add_child(_single_line_label("POTENTIAL %d · TIER %s" % [instance.potential, instance.tier], 10 if _compact_layout else 12, V2.PURPLE, true))
	return button


func _on_roster_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_pointer_card_press = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_pointer_card_press = true


func _activate_instance(instance_id: String) -> void:
	var pointer := _pointer_card_press
	_pointer_card_press = false
	if instance_id.is_empty() or OverworldState.get_instance_by_id(instance_id) == null:
		return
	if instance_id != _selected_id and _has_plan():
		_pending_confirmation_action = "switch"
		_pending_confirmation_target = instance_id
		_confirmation.configure(
			"DISCARD TRAINING PLAN?",
			"The pending plan belongs to the current Digimon. Discard it and train the selected Digimon instead?",
			"DISCARD & SWITCH",
			"KEEP PLAN",
			V2.AMBER,
			"PENDING TRAINING"
		)
		_confirmation.open_dialog(get_viewport().gui_get_focus_owner())
		return
	if instance_id != _selected_id:
		_clear_plan()
		_selected_id = instance_id
		_set_status("Training target selected.", V2.CYAN)
	_refresh_collection()
	_refresh_detail_values()
	_interaction_mode = InteractionMode.EDITING
	_detail_view = DetailView.ATTRIBUTES
	_apply_detail_view()
	_layout()
	_update_footer_hints()
	if not pointer:
		call_deferred("_focus_first_editor_control")


func _style_collection_button(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", V2.hospital_panel_style(V2.CYAN, selected))
	button.add_theme_stylebox_override("hover", V2.hospital_button_style(V2.CYAN, "hover"))
	button.add_theme_stylebox_override("focus", V2.hospital_button_style(V2.CYAN, "focus"))
	button.add_theme_stylebox_override("pressed", V2.hospital_button_style(V2.CYAN, "pressed"))
	button.add_theme_stylebox_override("hover_pressed", V2.hospital_button_style(V2.CYAN, "pressed"))
	button.add_theme_stylebox_override("disabled", V2.hospital_button_style(V2.CYAN, "disabled"))


func _style_collection_selection() -> void:
	for index in range(_collection_buttons.size()):
		var id := _collection_ids[index] if index < _collection_ids.size() else ""
		_style_collection_button(_collection_buttons[index], id == _selected_id)
		if index < _collection_previews.size():
			_collection_previews[index].set_active(id == _selected_id)


func _refresh_detail_values() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		_identity_name.text = "NO DIGIMON SELECTED"
		_identity_meta.text = ""
		_identity_copy.text = "Choose an individual from the roster."
		_set_controls_enabled(false)
		return
	var species := _database.get_by_seed(instance.species_seed)
	if species.is_empty():
		_identity_name.text = "SPECIES DATA UNAVAILABLE"
		_set_controls_enabled(false)
		return

	var preview := DigimonInstance.from_dict(instance.to_dict())
	if _has_plan():
		_training.apply_plan(preview, _pending_stats, 0)
	var current_stats := _calculator.get_all_stats(instance, species)
	var preview_stats := _calculator.get_all_stats(preview, species)

	var rank := String(species.get("rank", "Unknown"))
	var accent := V2.rank_color(rank)
	var display_name := instance.get_display_name(String(species.get("name", "Unknown")))
	_identity_name.text = display_name.to_upper()
	_identity_meta.text = "%s · LV %d · TIER %s" % [rank.to_upper(), instance.level, instance.tier]
	_identity_meta.add_theme_color_override("font_color", accent)
	_identity_portrait.set_species(String(species.get("name", "Unknown")))

	var total := _training.capacity_for(instance)
	var used := _training.used_capacity(instance)
	var planned := _training.plan_cost(instance, _pending_stats, 0)
	var remaining := maxi(0, total - used - planned)
	_potential_value.text = "%d / 100" % instance.potential
	_capacity_value.text = "%d / %d" % [used + planned, total]
	_available_value.text = str(remaining)
	_available_value.add_theme_color_override("font_color", V2.GREEN if remaining > 0 else V2.RED)
	if _compact_layout:
		_identity_meta.text = "%s · LV %d · TIER %s · %d CAP" % [rank.to_upper(), instance.level, instance.tier, remaining]
	_capacity_bar.max_value = maxf(1.0, float(total))
	_capacity_bar.value = float(used + planned)

	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed"]:
		var row := _stat_rows.get(stat_key) as TrainingStatRow
		if row == null:
			continue
		var meta: Array = STAT_META[stat_key]
		var test_plan := _pending_stats.duplicate(true)
		test_plan[stat_key] = int(test_plan.get(stat_key, 0)) + 1
		row.set_compact(_compact_layout)
		row.configure(
			stat_key,
			String(meta[0]),
			int(current_stats.get(stat_key, 0)),
			int(preview_stats.get(stat_key, 0)),
			int(instance.training.get(stat_key, 0)),
			int(_pending_stats.get(stat_key, 0)),
			_training.max_points_per_stat(),
			_training.can_apply_plan(instance, test_plan, 0),
			meta[1] as Color
		)

	var current_mov := int(current_stats.get("mov", 0))
	var mobility_level := _training.mobility_level(instance)
	_mobility_value.text = "MOV %d" % current_mov
	_mobility_value.add_theme_color_override("font_color", V2.TEXT)
	_mobility_level.text = "MOBILITY %d / 2" % mobility_level

	if mobility_level < 2:
		var next_level := mobility_level + 1
		var required_potential := _training.mobility_potential_for_level(next_level)
		var capacity_cost := _training.mobility_cost_for_level(next_level)
		if _has_plan():
			_mobility_requirement.text = "Apply or discard the pending ATTRIBUTE PLAN before training MOV."
			_mobility_requirement.add_theme_color_override("font_color", V2.AMBER)
			_mobility_plus.disabled = true
		else:
			_mobility_requirement.text = "NEXT: MOV +%d  ·  Potential %d required  ·  %d Capacity" % [
				next_level,
				required_potential,
				capacity_cost,
			]
			_mobility_requirement.add_theme_color_override(
				"font_color",
				V2.GREEN if _training.can_train_mobility(instance) else V2.MUTED
			)
			_mobility_plus.disabled = not _training.can_train_mobility(instance)
	else:
		_mobility_requirement.text = "Maximum permanent mobility training reached."
		_mobility_requirement.add_theme_color_override("font_color", V2.GREEN)
		_mobility_plus.disabled = true

	var has_plan := _has_plan()
	var validation := _training.validate_plan(instance, _pending_stats, 0) if has_plan else ""
	_attribute_plan_summary.text = _plan_summary()
	_attribute_plan_summary.add_theme_color_override("font_color", V2.GREEN if has_plan and validation.is_empty() else V2.MUTED)
	if has_plan and not validation.is_empty():
		_attribute_plan_validation.text = validation
		_attribute_plan_validation.add_theme_color_override("font_color", V2.RED)
	elif has_plan:
		_attribute_plan_validation.text = "%d Capacity · permanent after Apply" % planned
		_attribute_plan_validation.add_theme_color_override("font_color", V2.MUTED)
	else:
		_attribute_plan_validation.text = "Adjust attributes to build a plan."
		_attribute_plan_validation.add_theme_color_override("font_color", V2.MUTED)

	_discard_button.disabled = not has_plan
	_apply_button.disabled = not has_plan or not validation.is_empty()
	_refresh_editor_focus_rows()


func _set_controls_enabled(enabled: bool) -> void:
	for row_value in _stat_rows.values():
		var row := row_value as TrainingStatRow
		if row == null:
			continue
		for button in row.get_focus_buttons():
			button.disabled = not enabled
	for button in [_mobility_plus, _discard_button, _apply_button]:
		if button != null:
			button.disabled = not enabled


func _add_stat(stat_key: String) -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	var test_plan := _pending_stats.duplicate(true)
	test_plan[stat_key] = int(test_plan.get(stat_key, 0)) + 1
	var error := _training.validate_plan(instance, test_plan, 0)
	if not error.is_empty():
		_set_status(error, V2.RED)
		return
	_pending_stats = test_plan
	_set_status("Plan updated. Review the preview before applying.", V2.GREEN)
	_refresh_detail_values()
	var row := _stat_rows.get(stat_key) as TrainingStatRow
	if row != null:
		row.pulse()


func _remove_stat(stat_key: String) -> void:
	var value := int(_pending_stats.get(stat_key, 0))
	if value <= 0:
		return
	if value == 1:
		_pending_stats.erase(stat_key)
	else:
		_pending_stats[stat_key] = value - 1
	_set_status("Plan updated.", V2.CYAN)
	_refresh_detail_values()


func _request_mobility_training() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	if _has_plan():
		_set_status("Apply or discard the pending attribute plan before training MOV.", V2.AMBER)
		return
	var error := _training.validate_plan(instance, {}, 1)
	if not error.is_empty():
		_set_status(error, V2.RED)
		return
	var current_level := _training.mobility_level(instance)
	var next_level := current_level + 1
	var cost := _training.mobility_cost_for_level(next_level)
	_pending_confirmation_action = "mobility"
	_pending_confirmation_target = ""
	_confirmation.configure(
		"TRAIN MOV +1?",
		"MOV %d → MOV %d is permanent and costs %d Training Capacity." % [current_level, next_level, cost],
		"TRAIN MOV",
		"BACK",
		V2.AMBER,
		"TACTICAL MOBILITY"
	)
	_confirmation.open_dialog(_mobility_plus)


func _commit_mobility_training() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	var error := _training.validate_plan(instance, {}, 1)
	if not error.is_empty():
		_set_status(error, V2.RED)
		return
	_state_mutation_in_progress = true
	var applied := OverworldState.apply_training_plan(_selected_id, {}, 1)
	_state_mutation_in_progress = false
	if not applied:
		_set_status("Mobility training could not be applied.", V2.RED)
		return
	_set_status("MOV training applied and saved.", V2.GREEN)
	_refresh_collection()
	_refresh_detail_values()
	var tween := create_tween()
	tween.tween_property(_mobility_card, "modulate", Color(1.05, 1.05, 1.05, 1.0), 0.08)
	tween.tween_property(_mobility_card, "modulate", Color.WHITE, 0.20)
	call_deferred("_focus_first_editor_control")


func _discard_plan() -> void:
	_clear_plan()
	_set_status("Pending attribute training discarded.", V2.CYAN)
	_refresh_detail_values()
	call_deferred("_focus_first_editor_control")


func _request_apply_plan() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null or not _has_plan():
		return
	var error := _training.validate_plan(instance, _pending_stats, 0)
	if not error.is_empty():
		_set_status(error, V2.RED)
		return
	_pending_confirmation_action = "apply"
	_pending_confirmation_target = ""
	_confirmation.configure(
		"APPLY PERMANENT TRAINING?",
		"%s\nCapacity used by this attribute plan: %d." % [_plan_summary(), _training.plan_cost(instance, _pending_stats, 0)],
		"APPLY TRAINING",
		"REVIEW",
		V2.GREEN,
		"PERMANENT GROWTH"
	)
	_confirmation.open_dialog(_apply_button)


func _commit_plan() -> void:
	var instance := OverworldState.get_instance_by_id(_selected_id)
	if instance == null:
		return
	var error := _training.validate_plan(instance, _pending_stats, 0)
	if not error.is_empty():
		_set_status(error, V2.RED)
		return
	_state_mutation_in_progress = true
	var applied := OverworldState.apply_training_plan(_selected_id, _pending_stats, 0)
	_state_mutation_in_progress = false
	if not applied:
		_set_status("Training could not be applied.", V2.RED)
		return
	_clear_plan()
	_set_status("Training applied and saved.", V2.GREEN)
	_refresh_collection()
	_refresh_detail_values()
	var tween := create_tween()
	tween.tween_property(_detail_panel, "modulate", Color(1.05, 1.05, 1.05, 1.0), 0.08)
	tween.tween_property(_detail_panel, "modulate", Color.WHITE, 0.20)
	call_deferred("_focus_first_editor_control")


func _request_close() -> void:
	if not _has_plan():
		if _close_lifecycle_managed:
			close_requested.emit()
		else:
			close_view()
		return
	_pending_confirmation_action = "close"
	_pending_confirmation_target = ""
	_confirmation.configure(
		"DISCARD TRAINING PLAN?",
		"You have unapplied permanent training changes. Discard them and leave Training?",
		"DISCARD & LEAVE",
		"STAY",
		V2.AMBER,
		"PENDING TRAINING"
	)
	_confirmation.open_dialog(get_viewport().gui_get_focus_owner())


func _on_confirmation_confirmed() -> void:
	var action := _pending_confirmation_action
	var target := _pending_confirmation_target
	_pending_confirmation_action = ""
	_pending_confirmation_target = ""
	match action:
		"apply":
			_commit_plan()
		"mobility":
			_commit_mobility_training()
		"switch":
			_clear_plan()
			_selected_id = target
			_interaction_mode = InteractionMode.EDITING
			_detail_view = DetailView.ATTRIBUTES
			_set_status("Training target changed. Previous pending plan discarded.", V2.CYAN)
			_refresh_collection()
			_refresh_detail_values()
			_apply_detail_view()
			_layout()
			_update_footer_hints()
			call_deferred("_focus_first_editor_control")
		"close":
			_clear_plan()
			if _close_lifecycle_managed:
				close_requested.emit()
			else:
				close_view()


func _on_confirmation_cancelled() -> void:
	_pending_confirmation_action = ""
	_pending_confirmation_target = ""


func _plan_summary() -> String:
	if not _has_plan():
		return "NO PENDING CHANGES"
	var parts := PackedStringArray()
	for stat_key: String in ["hp", "mp", "atk", "def", "int", "speed"]:
		var points := int(_pending_stats.get(stat_key, 0))
		if points <= 0:
			continue
		var meta: Array = STAT_META[stat_key]
		parts.append("%s +%d" % [String(meta[0]), points])
	return " · ".join(parts)


func _clear_plan() -> void:
	_pending_stats.clear()


func _has_plan() -> bool:
	for value in _pending_stats.values():
		if int(value) > 0:
			return true
	return false


func _set_detail_view(view_id: int, focus_editor: bool = true) -> void:
	if view_id != DetailView.ATTRIBUTES and view_id != DetailView.MOBILITY:
		return
	_detail_view = view_id
	_apply_detail_view()
	_update_footer_hints()
	if focus_editor:
		call_deferred("_focus_first_editor_control")


func _toggle_detail_view() -> void:
	_set_detail_view(DetailView.MOBILITY if _detail_view == DetailView.ATTRIBUTES else DetailView.ATTRIBUTES)


func _apply_detail_view() -> void:
	if _attributes_view == null or _mobility_view == null:
		return
	_attributes_view.visible = _detail_view == DetailView.ATTRIBUTES
	_mobility_view.visible = _detail_view == DetailView.MOBILITY
	for raw_id in _detail_tab_buttons:
		var button := _detail_tab_buttons[raw_id] as Button
		if button == null:
			continue
		var active := int(raw_id) == _detail_view
		button.add_theme_color_override("font_color", V2.WHITE if active else V2.MUTED)
		button.add_theme_color_override("font_hover_color", V2.WHITE)
		button.add_theme_stylebox_override("normal", V2.pill_style(V2.CYAN, active))
		button.add_theme_stylebox_override("hover", V2.pill_style(V2.CYAN, true))
		button.add_theme_stylebox_override("pressed", V2.pill_style(V2.CYAN, true))
	_refresh_editor_focus_rows()


func _return_to_roster() -> void:
	_interaction_mode = InteractionMode.ROSTER
	_layout()
	_update_footer_hints()
	call_deferred("_focus_selected_collection")


func _turn_roster_page(delta: int) -> void:
	var owned := OverworldState.get_collection_instances()
	var page_count := maxi(1, ceili(float(owned.size()) / float(ROSTER_PAGE_SIZE)))
	if page_count <= 1:
		return
	var next_page := clampi(_roster_page + delta, 0, page_count - 1)
	if next_page == _roster_page:
		return
	_roster_page = next_page
	_refresh_collection()


func _move_roster_focus(step: int) -> void:
	if _collection_buttons.is_empty():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	var index := _collection_buttons.find(focus_owner)
	if index < 0:
		index = 0
	else:
		index = posmod(index + step, _collection_buttons.size())
	_collection_buttons[index].grab_focus()


func _focus_selected_collection() -> void:
	if not visible or _interaction_mode != InteractionMode.ROSTER:
		return
	for index in range(_collection_ids.size()):
		if _collection_ids[index] == _selected_id and index < _collection_buttons.size():
			_collection_buttons[index].grab_focus()
			return
	_focus_first_collection()


func _focus_first_collection() -> void:
	if visible and _interaction_mode == InteractionMode.ROSTER and not _collection_buttons.is_empty():
		_collection_buttons[0].grab_focus()


func _refresh_editor_focus_rows() -> void:
	_editor_focus_rows.clear()
	if _detail_view == DetailView.ATTRIBUTES:
		_editor_focus_rows.append([_discard_button, _apply_button])
		for pair in [["hp", "mp"], ["atk", "def"], ["int", "speed"]]:
			var focus_row: Array[Button] = []
			for stat_key in pair:
				var stat_row := _stat_rows.get(String(stat_key)) as TrainingStatRow
				if stat_row != null:
					focus_row.append_array(stat_row.get_focus_buttons())
			_editor_focus_rows.append(focus_row)
	else:
		_editor_focus_rows.append([_mobility_plus])


func _focus_first_editor_control() -> void:
	if not visible or _interaction_mode != InteractionMode.EDITING:
		return
	_refresh_editor_focus_rows()
	for row_value in _editor_focus_rows:
		var row: Array = row_value
		for control_value in row:
			var control := control_value as Button
			if control != null and not control.disabled and control.visible:
				control.grab_focus()
				return


func _move_editor_vertical(step: int) -> void:
	_refresh_editor_focus_rows()
	if _editor_focus_rows.is_empty():
		return
	var position := _editor_focus_position()
	if position.x < 0:
		_focus_first_editor_control()
		return
	var row_index := int(position.x)
	var column := int(position.y)
	for offset in range(1, _editor_focus_rows.size() + 1):
		var target_row_index := posmod(row_index + step * offset, _editor_focus_rows.size())
		var target_row: Array = _editor_focus_rows[target_row_index]
		if target_row.is_empty():
			continue
		var preferred := clampi(column, 0, target_row.size() - 1)
		for search in range(target_row.size()):
			var candidate_index := posmod(preferred + search, target_row.size())
			var candidate := target_row[candidate_index] as Button
			if candidate != null and not candidate.disabled and candidate.visible:
				candidate.grab_focus()
				return


func _move_editor_horizontal(step: int) -> void:
	_refresh_editor_focus_rows()
	var position := _editor_focus_position()
	if position.x < 0:
		_focus_first_editor_control()
		return
	var row: Array = _editor_focus_rows[int(position.x)]
	if row.is_empty():
		return
	var column := int(position.y)
	for offset in range(1, row.size() + 1):
		var index := posmod(column + step * offset, row.size())
		var candidate := row[index] as Button
		if candidate != null and not candidate.disabled and candidate.visible:
			candidate.grab_focus()
			return


func _editor_focus_position() -> Vector2i:
	var focus_owner := get_viewport().gui_get_focus_owner()
	for row_index in range(_editor_focus_rows.size()):
		var row: Array = _editor_focus_rows[row_index]
		var column := row.find(focus_owner)
		if column >= 0:
			return Vector2i(row_index, column)
	return Vector2i(-1, -1)


func _page_for_instance(instance_id: String) -> int:
	if instance_id.is_empty():
		return 0
	var owned := OverworldState.get_collection_instances()
	for index in range(owned.size()):
		if owned[index].id == instance_id:
			return floori(float(index) / float(ROSTER_PAGE_SIZE))
	return 0


func _on_collection_changed() -> void:
	if not visible or _state_mutation_in_progress:
		return
	var owned := OverworldState.get_collection_instances()
	if (_selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null) and not owned.is_empty():
		_selected_id = owned[0].id
		_clear_plan()
	_roster_page = clampi(_roster_page, 0, maxi(0, ceili(float(owned.size()) / float(ROSTER_PAGE_SIZE)) - 1))
	_refresh_collection()
	_refresh_detail_values()


func _set_status(text: String, accent: Color) -> void:
	if _status != null and _status_panel != null:
		_status.text = text
		_status.add_theme_color_override("font_color", accent)
		_status_icon.configure("info", accent, 1.45)
		_status_panel.add_theme_stylebox_override(
			"panel",
			V2.surface_style(Color(accent.r, accent.g, accent.b, 0.07), Color(accent.r, accent.g, accent.b, 0.34), 7)
		)
	if _hint_bar != null and visible:
		_hint_bar.set_description(text)


func _update_footer_hints() -> void:
	if _hint_bar == null:
		return
	var owned_count := OverworldState.get_collection_instances().size()
	var page_count := maxi(1, ceili(float(owned_count) / float(ROSTER_PAGE_SIZE)))
	var editing := _interaction_mode == InteractionMode.EDITING
	_hint_bar.set_description(
		"Adjust permanent growth, then review and apply the plan." if editing
		else "Choose a Digimon and build a permanent training plan."
	)
	_hint_bar.set_pagination_enabled(not editing and page_count > 1)
	_hint_bar.set_secondary_tabs_enabled(editing)
	_hint_bar.set_scroll_hint_enabled(false)


func _layout() -> void:
	if not visible or _frame == null or _menu_root == null:
		return
	var metrics := WorkspaceChrome.metrics(get_viewport())
	var physical: Vector2 = metrics["physical"]
	var scale_factor := float(metrics["scale"])
	var compact := bool(metrics["compact"])
	var width := maxf(640.0, physical.x)
	var height := maxf(420.0, physical.y)
	var density_changed := compact != _compact_layout
	_compact_layout = compact

	_frame.scale = Vector2.ONE * scale_factor
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(width, height)
	_menu_root.position = Vector2.ZERO
	_menu_root.size = Vector2(width, height)

	var header_h := float(metrics["header_h"])
	var edge := float(metrics["edge"])
	var body_top := float(metrics["body_top"])
	var body_bottom := minf(height - WorkspaceChrome.FOOTER_HEIGHT - WorkspaceChrome.BOTTOM_GAP, float(metrics["body_bottom"]))
	var body_h := maxf(220.0, body_bottom - body_top)
	_header.position = Vector2.ZERO
	_header.size = Vector2(width, header_h)
	_hint_bar.position = Vector2(0.0, height - WorkspaceChrome.FOOTER_HEIGHT)
	_hint_bar.size = Vector2(width, WorkspaceChrome.FOOTER_HEIGHT)

	if compact:
		var editing := _interaction_mode == InteractionMode.EDITING
		_collection_panel.visible = not editing
		_detail_panel.visible = editing
		_compact_back_button.visible = editing
		if not editing:
			_collection_panel.position = Vector2(edge, body_top)
			_collection_panel.size = Vector2(width - edge * 2.0, body_h)
		else:
			_compact_back_button.position = Vector2(edge, body_top)
			_compact_back_button.size = Vector2(148.0, V2.TOUCH_TARGET)
			var detail_top := body_top + V2.TOUCH_TARGET + 8.0
			_detail_panel.position = Vector2(edge, detail_top)
			_detail_panel.size = Vector2(width - edge * 2.0, maxf(160.0, body_bottom - detail_top))
	else:
		_collection_panel.visible = true
		_detail_panel.visible = true
		_compact_back_button.visible = false
		var usable := width - edge * 2.0 - WorkspaceChrome.GAP
		var roster_w := clampf(usable * WorkspaceChrome.ROSTER_RATIO, WorkspaceChrome.ROSTER_MIN, WorkspaceChrome.ROSTER_MAX)
		_collection_panel.position = Vector2(edge, body_top)
		_collection_panel.size = Vector2(roster_w, body_h)
		_detail_panel.position = Vector2(edge + roster_w + WorkspaceChrome.GAP, body_top)
		_detail_panel.size = Vector2(maxf(360.0, width - edge * 2.0 - roster_w - WorkspaceChrome.GAP), body_h)

	_status_panel.visible = false
	_identity_card.custom_minimum_size.y = 72.0 if compact else 82.0
	_budget_card.visible = not compact
	_budget_card.custom_minimum_size.y = 60.0 if compact else 68.0
	_identity_copy.visible = not compact
	_attribute_rate.visible = not compact
	_attribute_plan_validation.visible = not compact
	_mobility_explanation.visible = not compact
	_mobility_card.custom_minimum_size.y = 138.0 if compact else 156.0
	_mobility_plus.custom_minimum_size.x = 190.0 if compact else 250.0
	_stat_grid.add_theme_constant_override("v_separation", 5)
	_detail_tabs.custom_minimum_size.y = V2.TOUCH_TARGET
	for raw_button in _detail_tab_buttons.values():
		(raw_button as Button).custom_minimum_size.y = V2.TOUCH_TARGET
	for row_value in _stat_rows.values():
		(row_value as TrainingStatRow).set_compact(compact)
	_roster_pager.set_compact(compact)

	if density_changed:
		_refresh_collection()
		_refresh_detail_values()


func _roster_card_height() -> float:
	return 96.0 if _compact_layout else 118.0


func _progress(accent: Color, maximum: int, value: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxf(1, maximum)
	bar.value = clampi(value, 0, maxi(1, maximum))
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", V2.progress_track_style())
	bar.add_theme_stylebox_override("fill", V2.progress_fill_style(accent, true))
	return bar


func _workspace_button(text: String, accent: Color) -> Button:
	var button := _action_button(text, accent, 44.0)
	button.add_theme_font_size_override("font_size", 14)
	return button


func _action_button(text: String, accent: Color, height: float = V2.TOUCH_TARGET) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = maxf(V2.TOUCH_TARGET, height)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", V2.TEXT)
	button.add_theme_color_override("font_hover_color", V2.WHITE)
	button.add_theme_color_override("font_focus_color", V2.WHITE)
	button.add_theme_color_override("font_pressed_color", V2.WHITE)
	button.add_theme_color_override("font_disabled_color", V2.SUBTLE)
	V2.apply_heading(button)
	button.add_theme_stylebox_override("normal", V2.hospital_button_style(accent, "normal"))
	button.add_theme_stylebox_override("hover", V2.hospital_button_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", V2.hospital_button_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", V2.hospital_button_style(accent, "pressed"))
	button.add_theme_stylebox_override("disabled", V2.hospital_button_style(accent, "disabled"))
	return button


func _training_command_button(
	title: String,
	subtitle: String,
	status: String,
	icon_kind: String,
	accent: Color,
	minimal: bool
) -> DigiCommandButton:
	var button := CommandButtonScript.new() as DigiCommandButton
	button.configure(title, subtitle, status, icon_kind, accent)
	button.set_compact(true)
	button.set_minimal(minimal)
	return button


func _empty_state(text: String, accent: Color = V2.MUTED) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 96.0
	panel.add_theme_stylebox_override("panel", V2.panel_style(Color(accent.r, accent.g, accent.b, 0.30), 8))
	var margin := _margin(16, 16, 16, 16)
	panel.add_child(margin)
	var label := _label(text, 12, accent, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)
	return panel


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return margin


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		V2.apply_heading(label)
	else:
		V2.apply_body(label)
	return label


func _single_line_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := _label(text, size, color, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label
