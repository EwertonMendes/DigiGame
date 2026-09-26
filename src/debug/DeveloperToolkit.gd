extends CanvasLayer

const UI = preload("res://src/ui/TacticalTheme.gd")
const AccessScript = preload("res://src/debug/DebugToolkitAccess.gd")
const ProgressionToolsScript = preload("res://src/debug/DebugProgressionTools.gd")
const CollectionToolsScript = preload("res://src/debug/DebugCollectionTools.gd")
const StateToolsScript = preload("res://src/debug/DebugStateTools.gd")
const RosterToolsScript = preload("res://src/debug/DebugRosterTools.gd")
const SpeciesPickerScript = preload("res://src/debug/DebugSpeciesPicker.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const SpriteTestLabScript = preload("res://src/ui/DigimonSpriteTestLab.gd")
const BattlefieldCatalogScript = preload("res://src/world/BattlefieldCatalog.gd")
const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

const BATTLE_SCENE := "res://scenes/main.tscn"
const TEST_HUB_SCENE := "res://scenes/world/hub.tscn"
const WORLD_SCENE := "res://scenes/world/world_root.tscn"
const CLOSED_LAYER := 60
const OPEN_LAYER := 180
const MAX_FRAME_SIZE := Vector2(1180, 720)
const BATTLE_FOOTPRINTS := ["single", "large_2x2", "large_3x3"]

var _available := false
var _open := false
var _paused_before_open := false
var _progression: DebugProgressionTools
var _collection_tools: DebugCollectionTools
var _state: DebugStateTools
var _roster: DebugRosterTools
var _pending_battle_config: Dictionary = {}
var _selected_id := ""
var _picker_context := ""

var _dev_button: Button
var _backdrop: ColorRect
var _panel: PanelContainer
var _status: Label
var _tabs: TabContainer
var _collection_panel: PanelContainer
var _collection_list: VBoxContainer
var _collection_summary: Label
var _collection_buttons: Array[Button] = []
var _collection_ids: Array[String] = []
var _collection_previews: Array[DigimonWalkPreview] = []
var _species_picker: DebugSpeciesPicker
var _return_world_header: Button
var _sprite_test_layer: CanvasLayer
var _sprite_test_lab: DigimonSpriteTestLab
var _sprite_test_paused_before_open := false

var _digimon_preview_host: Control
var _digimon_summary: Label
var _level: SpinBox
var _exp: SpinBox
var _potential: SpinBox
var _link: SpinBox
var _current_hp: SpinBox
var _current_sp: SpinBox
var _tier: OptionButton
var _expansion_unlocked: CheckButton
var _expanded: CheckButton
var _training_fields: Dictionary = {}

var _route_mode: OptionButton
var _route_select: OptionButton
var _route_preview_host: Control
var _route_details: Label

var _spawn_species_seed := ""
var _spawn_preview_host: Control
var _spawn_identity: Label
var _spawn_level: SpinBox
var _spawn_exp: SpinBox
var _spawn_potential: SpinBox
var _spawn_link: SpinBox
var _spawn_tier: OptionButton
var _spawn_expanded: CheckButton
var _spawn_resource_state: OptionButton
var _spawn_hp: SpinBox
var _spawn_sp: SpinBox

var _bits: SpinBox
var _data: SpinBox
var _inventory_summary: Label
var _flag_id: LineEdit
var _flag_value: CheckButton
var _snapshot_name: LineEdit
var _snapshot_select: OptionButton

var _battle_roster: Array[Dictionary] = []
var _battle_list: VBoxContainer
var _battle_summary: Label
var _enemy_seed: SpinBox
var _battlefield_catalog: BattlefieldCatalog
var _battlefield_select: OptionButton
var _battlefield_summary: Label

var _diagnostics: Label
var _history: Label

func _ready() -> void:
	layer = CLOSED_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_available = AccessScript.is_available()
	if not _available:
		set_process(false)
		set_process_input(false)
		return
	_progression = ProgressionToolsScript.new() as DebugProgressionTools
	_collection_tools = CollectionToolsScript.new() as DebugCollectionTools
	_state = StateToolsScript.new() as DebugStateTools
	_roster = RosterToolsScript.new() as DebugRosterTools
	_battlefield_catalog = BattlefieldCatalogScript.new() as BattlefieldCatalog
	if not _battlefield_catalog.load_default():
		for error in _battlefield_catalog.validation_errors():
			push_error("Developer Toolkit battlefield catalog: %s" % error)
	_build_ui()
	_initialize_defaults()
	get_viewport().size_changed.connect(_layout)
	OverworldState.collection_changed.connect(_on_state_changed)
	OverworldState.account_rewards_changed.connect(_on_rewards_changed)
	_layout()

func _process(_delta: float) -> void:
	if _open:
		_refresh_diagnostics()

func _input(event: InputEvent) -> void:
	if not _available or not event is InputEventKey:
		return
	if _sprite_test_lab != null and _sprite_test_lab.visible:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.physical_keycode == KEY_F2:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not _open or not key.pressed or key.echo or key.physical_keycode != KEY_ESCAPE:
		return
	if _species_picker != null and _species_picker.visible:
		_species_picker.close_picker()
	else:
		close()
	get_viewport().set_input_as_handled()

func is_available() -> bool:
	return _available

func toggle() -> void:
	if _open:
		close()
	else:
		open()

func open() -> void:
	if not _available or _open:
		return
	_open = true
	layer = OPEN_LAYER
	if _return_world_header != null:
		_return_world_header.visible = _is_test_hub_scene()
	_paused_before_open = get_tree().paused
	get_tree().paused = true
	_backdrop.visible = true
	_panel.visible = true
	_dev_button.visible = false
	_refresh_all()
	call_deferred("_layout")

func close() -> void:
	if not _open:
		return
	if _species_picker != null:
		_species_picker.visible = false
	_open = false
	_backdrop.visible = false
	_panel.visible = false
	_dev_button.visible = true
	layer = CLOSED_LAYER
	get_tree().paused = _paused_before_open

func peek_pending_battle_config() -> Dictionary:
	return _pending_battle_config.duplicate(true)


func consume_pending_battle_config() -> Dictionary:
	var result := _pending_battle_config.duplicate(true)
	_pending_battle_config.clear()
	return result

func _build_ui() -> void:
	_dev_button = _action("DEV · F2", open, UI.PURPLE, 38)
	_dev_button.focus_mode = Control.FOCUS_NONE
	_dev_button.tooltip_text = "Open the in-game developer toolkit."
	add_child(_dev_button)

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.76)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "DeveloperToolkitPanel"
	_panel.visible = false
	_panel.clip_contents = true
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", UI.panel_strong(UI.CYAN, 12))
	add_child(_panel)

	var outer := _margin(18, 15, 18, 16)
	_panel.add_child(outer)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	outer.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 1)
	header.add_child(heading)
	heading.add_child(_label("DEVELOPER TOOLKIT", 23, UI.TEXT, true))
	heading.add_child(_label("Progression, collection and battle state laboratory", 10, UI.SUBTLE))
	_return_world_header = _action("OVERWORLD", _return_to_world, UI.GREEN, 40)
	_return_world_header.name = "ReturnOverworld"
	_return_world_header.visible = _is_test_hub_scene()
	header.add_child(_return_world_header)
	var test_hub := _action("TEST HUB", _open_test_hub, UI.CYAN, 40)
	header.add_child(test_hub)
	var sprite_test := _action("SPRITE TEST", _open_sprite_test, UI.PURPLE, 40)
	header.add_child(sprite_test)
	header.add_child(_action("CLOSE · ESC", close, UI.MUTED, 40))

	_status = _label(AccessScript.activation_hint(), 10, UI.CYAN, true)
	_status.custom_minimum_size.y = 20
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(_status)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	_build_collection_sidebar(body)

	var workspace := VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(workspace)
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 11)
	UI.apply_body_font(_tabs)
	workspace.add_child(_tabs)
	_build_digimon_tab(_tabs)
	_build_evolution_tab(_tabs)
	_build_spawn_tab(_tabs)
	_build_state_tab(_tabs)
	_build_scenarios_tab(_tabs)
	_build_battle_tab(_tabs)
	_build_diagnostics_tab(_tabs)

	_species_picker = SpeciesPickerScript.new() as DebugSpeciesPicker
	_species_picker.configure(_roster.catalog(), OverworldState.get_database() as DigimonDatabase)
	_species_picker.species_selected.connect(_on_species_picked)
	_species_picker.dismissed.connect(func() -> void: _picker_context = "")
	add_child(_species_picker)
	_build_sprite_test_host()


func _build_sprite_test_host() -> void:
	_sprite_test_layer = CanvasLayer.new()
	_sprite_test_layer.name = "GlobalSpriteTestLayer"
	_sprite_test_layer.layer = OPEN_LAYER + 40
	_sprite_test_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sprite_test_layer)
	_sprite_test_lab = SpriteTestLabScript.new() as DigimonSpriteTestLab
	_sprite_test_lab.name = "GlobalSpriteTestLab"
	_sprite_test_lab.close_requested.connect(_on_global_sprite_test_closed)
	_sprite_test_layer.add_child(_sprite_test_lab)

func _build_collection_sidebar(parent: Control) -> void:
	_collection_panel = PanelContainer.new()
	_collection_panel.custom_minimum_size.x = 250
	_collection_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_panel.clip_contents = true
	_collection_panel.add_theme_stylebox_override("panel", UI.glass_panel(UI.CYAN, 0.84, 10))
	parent.add_child(_collection_panel)
	var margin := _margin(10, 10, 10, 10)
	_collection_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	margin.add_child(root)
	root.add_child(_section_label("OWNED DIGIMON", UI.CYAN))
	_collection_summary = _label("", 9, UI.SUBTLE)
	root.add_child(_collection_summary)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_collection_list = VBoxContainer.new()
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_collection_list)

func _build_digimon_tab(tabs: TabContainer) -> void:
	var page := _page(tabs, "DIGIMON")
	page.add_child(_section_label("SELECTED DIGIMON", UI.CYAN))
	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", UI.glass_panel(UI.CYAN, 0.82, 10))
	page.add_child(hero)
	var hero_margin := _margin(10, 9, 12, 9)
	hero.add_child(hero_margin)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	hero_margin.add_child(hero_row)
	_digimon_preview_host = Control.new()
	_digimon_preview_host.custom_minimum_size = Vector2(92, 84)
	hero_row.add_child(_digimon_preview_host)
	_digimon_summary = _label("Select an owned Digimon.", 11, UI.TEXT)
	_digimon_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_digimon_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_row.add_child(_digimon_summary)

	page.add_child(_section_label("EXACT PROGRESSION STATE", UI.GOLD))
	var state_grid := GridContainer.new()
	state_grid.columns = 2
	state_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_grid.add_theme_constant_override("h_separation", 10)
	state_grid.add_theme_constant_override("v_separation", 8)
	page.add_child(state_grid)
	_level = _spin(1, 99, 1)
	_exp = _spin(0, 9999999, 1)
	_potential = _spin(0, 100, 1)
	_link = _spin(0, 100, 1)
	_current_hp = _spin(0, 9999999, 1)
	_current_sp = _spin(0, 9999999, 1)
	_tier = OptionButton.new()
	for tier_name: String in _progression.tier_options():
		_tier.add_item(tier_name)
	_style_field(_tier)
	_expansion_unlocked = CheckButton.new()
	_expansion_unlocked.text = "Unlocked"
	UI.apply_body_font(_expansion_unlocked)
	_expanded = CheckButton.new()
	_expanded.text = "Active 2×2"
	UI.apply_body_font(_expanded)
	var expansion_flags := HBoxContainer.new()
	expansion_flags.add_theme_constant_override("separation", 8)
	expansion_flags.add_child(_expansion_unlocked)
	expansion_flags.add_child(_expanded)
	state_grid.add_child(_field_card("LEVEL", _level, UI.CYAN))
	state_grid.add_child(_field_card("XP", _exp, UI.CYAN))
	state_grid.add_child(_field_card("POTENTIAL", _potential, UI.PURPLE))
	state_grid.add_child(_field_card("LINK", _link, UI.GOLD))
	state_grid.add_child(_field_card("CURRENT HP", _current_hp, UI.GREEN))
	state_grid.add_child(_field_card("CURRENT SP", _current_sp, UI.BLUE))
	state_grid.add_child(_field_card("TIER", _tier, UI.GOLD))
	state_grid.add_child(_field_card("EXPANSION", expansion_flags, UI.PURPLE))
	page.add_child(_button_row([_action("APPLY EXACT STATE", _apply_exact_state, UI.GOLD), _action("+100 XP", _add_xp.bind(100), UI.CYAN), _action("+1000 XP", _add_xp.bind(1000), UI.CYAN), _action("HEAL", _heal, UI.GREEN), _action("CRITICAL", _critical, UI.ORANGE), _action("KNOCK OUT", _knock_out, UI.RED), _action("DELETE DIGIMON", _delete_digimon, UI.RED)]))

	page.add_child(_section_label("SQUAD LOCATION", UI.CYAN))
	page.add_child(_button_row([
		_action("ASSIGN ACTIVE", _assign_selected_active, UI.GOLD),
		_action("ASSIGN RESERVE", _assign_selected_reserve, UI.PURPLE),
		_action("MOVE TO STORAGE", _move_selected_to_storage, UI.CYAN),
	]))

	page.add_child(_section_label("TRAINING", UI.PURPLE))
	var training_grid := GridContainer.new()
	training_grid.columns = 4
	training_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	training_grid.add_theme_constant_override("h_separation", 8)
	training_grid.add_theme_constant_override("v_separation", 8)
	page.add_child(training_grid)
	for entry in [["hp", "HP"], ["mp", "SP"], ["atk", "ATK"], ["def", "DEF"], ["int", "INT"], ["speed", "SPD"], ["mov", "MOV"]]:
		var key := String(entry[0])
		var field := _spin(0, 2 if key == "mov" else 5000, 1)
		_training_fields[key] = field
		training_grid.add_child(_field_card(String(entry[1]), field, UI.PURPLE))
	page.add_child(_button_row([_action("APPLY TRAINING", _apply_training, UI.PURPLE), _action("CLEAR TRAINING", _clear_training, UI.MUTED)]))

func _build_evolution_tab(tabs: TabContainer) -> void:
	var page := _page(tabs, "EVOLUTION")
	page.add_child(_section_label("ROUTE DEBUGGER", UI.GOLD))
	_route_mode = OptionButton.new()
	_route_mode.add_item("Digivolution")
	_route_mode.add_item("Degeneration")
	_style_field(_route_mode)
	_route_mode.item_selected.connect(func(_index: int) -> void: _refresh_routes())
	page.add_child(_field_row("MODE", _route_mode, []))
	_route_select = OptionButton.new()
	_style_field(_route_select)
	_route_select.item_selected.connect(func(_index: int) -> void: _refresh_route_details())
	page.add_child(_field_row("ROUTE", _route_select, []))
	var route_card := PanelContainer.new()
	route_card.add_theme_stylebox_override("panel", UI.glass_panel(UI.GOLD, 0.82, 10))
	page.add_child(route_card)
	var route_margin := _margin(10, 10, 10, 10)
	route_card.add_child(route_margin)
	var route_row := HBoxContainer.new()
	route_row.add_theme_constant_override("separation", 12)
	route_margin.add_child(route_row)
	_route_preview_host = Control.new()
	_route_preview_host.custom_minimum_size = Vector2(92, 92)
	route_row.add_child(_route_preview_host)
	_route_details = _label("Select a route.", 11, UI.TEXT)
	_route_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_route_details.custom_minimum_size.y = 110
	route_row.add_child(_route_details)
	page.add_child(_button_row([_action("MEET REQUIREMENTS", _meet_requirements, UI.GOLD), _action("APPLY REAL TRANSITION", _apply_transition, UI.CYAN), _action("FORCE TRANSITION", _force_transition, UI.RED)]))

func _build_spawn_tab(tabs: TabContainer) -> void:
	var page := _page(tabs, "SPAWN")
	page.add_child(_section_label("ADD ANY DIGIMON TO STORAGE", UI.GREEN))
	var hint := _label("Creates a real persistent Digimon instance directly in Storage. Configure its starting state here, then fine-tune it in the Digimon tab if needed.", 10, UI.SUBTLE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hint)
	var identity_card := PanelContainer.new()
	identity_card.add_theme_stylebox_override("panel", UI.glass_panel(UI.GREEN, 0.82, 10))
	page.add_child(identity_card)
	var identity_margin := _margin(10, 9, 10, 9)
	identity_card.add_child(identity_margin)
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 12)
	identity_margin.add_child(identity_row)
	_spawn_preview_host = Control.new()
	_spawn_preview_host.custom_minimum_size = Vector2(92, 84)
	identity_row.add_child(_spawn_preview_host)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	identity_row.add_child(copy)
	_spawn_identity = _label("Choose a species", 15, UI.TEXT, true)
	copy.add_child(_spawn_identity)
	copy.add_child(_label("Visual picker uses the DS field sprites available in the project.", 9, UI.SUBTLE))
	identity_row.add_child(_action("CHOOSE DIGIMON", _choose_spawn_species, UI.GREEN))

	var config_grid := GridContainer.new()
	config_grid.columns = 2
	config_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_grid.add_theme_constant_override("h_separation", 10)
	config_grid.add_theme_constant_override("v_separation", 8)
	page.add_child(config_grid)
	_spawn_level = _spin(1, 99, 1)
	_spawn_exp = _spin(0, 9999999, 1)
	_spawn_potential = _spin(0, 100, 1)
	_spawn_link = _spin(0, 100, 1)
	_spawn_tier = OptionButton.new()
	for tier_name: String in _progression.tier_options():
		_spawn_tier.add_item(tier_name)
	_style_field(_spawn_tier)
	_spawn_expanded = CheckButton.new()
	_spawn_expanded.text = "Start expanded 2×2"
	UI.apply_body_font(_spawn_expanded)
	config_grid.add_child(_field_card("LEVEL", _spawn_level, UI.CYAN))
	config_grid.add_child(_field_card("XP", _spawn_exp, UI.CYAN))
	config_grid.add_child(_field_card("POTENTIAL", _spawn_potential, UI.PURPLE))
	config_grid.add_child(_field_card("LINK", _spawn_link, UI.GOLD))
	config_grid.add_child(_field_card("TIER", _spawn_tier, UI.GOLD))
	config_grid.add_child(_field_card("EXPANSION", _spawn_expanded, UI.PURPLE))
	_spawn_resource_state = OptionButton.new()
	for label in ["FULL", "CRITICAL (1 HP / 0 SP)", "KNOCKED OUT", "CUSTOM"]:
		_spawn_resource_state.add_item(label)
	_style_field(_spawn_resource_state)
	page.add_child(_field_row("RESOURCE STATE", _spawn_resource_state, []))
	_spawn_hp = _spin(0, 9999999, 1)
	_spawn_sp = _spin(0, 9999999, 1)
	page.add_child(_field_row("CUSTOM HP / SP", _spawn_hp, [_spawn_sp]))
	page.add_child(_button_row([_action("CREATE IN STORAGE", _create_storage_digimon, UI.GREEN)]))

func _build_state_tab(tabs: TabContainer) -> void:
	var page := _page(tabs, "ACCOUNT")
	page.add_child(_section_label("ACCOUNT & PROGRESSION FLAGS", UI.CYAN))
	_bits = _spin(0, 9999999, 100)
	page.add_child(_field_row("BITS", _bits, [_action("SET", _set_bits, UI.CYAN)]))
	_data = _spin(0, 9999, 10)
	page.add_child(_field_row("SELECTED SPECIES DATA", _data, [_action("SET", _set_data, UI.CYAN)]))
	page.add_child(_section_label("EXPANSION INVENTORY", UI.PURPLE))
	_inventory_summary = _label("Core 0 · Fragments 0", 10, UI.TEXT, true)
	page.add_child(_inventory_summary)
	page.add_child(_button_row([_action("+ CORE", _grant_expansion_core, UI.PURPLE), _action("+ 5 FRAGMENTS", _grant_expansion_fragments, UI.CYAN), _action("CRAFT CORE", _craft_expansion_core, UI.GOLD)]))
	_flag_id = LineEdit.new()
	_flag_id.placeholder_text = "progression flag id"
	_style_field(_flag_id)
	_flag_value = CheckButton.new()
	_flag_value.text = "true"
	UI.apply_body_font(_flag_value)
	page.add_child(_field_row("FLAG", _flag_id, [_flag_value, _action("SET FLAG", _set_flag, UI.CYAN)]))
	var hint := _label("Flags are written to persistent progression state so world and quest code can observe them.", 10, UI.SUBTLE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hint)

func _build_scenarios_tab(tabs: TabContainer) -> void:
	var page := _page(tabs, "SAVE")
	page.add_child(_section_label("REPRODUCIBLE SCENARIOS", UI.GOLD))
	page.add_child(_button_row([_action("FRESH START", _scenario.bind("fresh_start"), UI.MUTED), _action("PARTY LV.20", _scenario.bind("party_level_20"), UI.CYAN), _action("READY EVOLUTION", _scenario.bind("ready_first_evolution"), UI.GOLD), _action("CRITICAL PARTY", _scenario.bind("critical_party"), UI.ORANGE), _action("RICH ACCOUNT", _scenario.bind("rich_account"), UI.GREEN)]))
	page.add_child(_section_label("SNAPSHOTS", UI.PURPLE))
	_snapshot_name = LineEdit.new()
	_snapshot_name.placeholder_text = "Snapshot name, e.g. Before WarGreymon evolution"
	_style_field(_snapshot_name)
	page.add_child(_field_row("NEW SNAPSHOT", _snapshot_name, [_action("CAPTURE", _capture_snapshot, UI.PURPLE)]))
	_snapshot_select = OptionButton.new()
	_style_field(_snapshot_select)
	page.add_child(_field_row("SAVED SNAPSHOT", _snapshot_select, [_action("RESTORE", _restore_snapshot, UI.CYAN), _action("DELETE", _delete_snapshot, UI.RED)]))
	page.add_child(_button_row([_action("COPY CURRENT STATE JSON", _copy_state, UI.MUTED)]))

func _build_battle_tab(tabs: TabContainer) -> void:
	var page := _page(tabs, "BATTLE")
	page.add_child(_section_label("BATTLE SANDBOX ROSTER", UI.RED))
	var intro := _label("Build the enemy team slot by slot. Every row can use a different Digimon, level, profile, Tier and tactical footprint. The real persistent player party and battle runtime are used.", 10, UI.SUBTLE)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(intro)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	page.add_child(toolbar)
	toolbar.add_child(_action("+ ADD ENEMY", _add_battle_enemy, UI.GREEN))
	toolbar.add_child(_action("CLEAR", _clear_battle_roster, UI.MUTED))
	_battle_summary = _label("", 10, UI.SUBTLE, true)
	_battle_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toolbar.add_child(_battle_summary)

	var roster_surface := PanelContainer.new()
	roster_surface.custom_minimum_size.y = 260
	roster_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_surface.clip_contents = true
	roster_surface.add_theme_stylebox_override("panel", UI.glass_panel(UI.RED, 0.82, 10))
	page.add_child(roster_surface)
	var roster_margin := _margin(8, 8, 8, 8)
	roster_surface.add_child(roster_margin)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	roster_scroll.follow_focus = true
	roster_margin.add_child(roster_scroll)
	_battle_list = VBoxContainer.new()
	_battle_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_list.add_theme_constant_override("separation", 7)
	roster_scroll.add_child(_battle_list)

	page.add_child(_section_label("BATTLEFIELD V2", UI.CYAN))
	_battlefield_select = OptionButton.new()
	_battlefield_select.custom_minimum_size = Vector2(320, 40)
	_battlefield_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battlefield_select.add_item("AUTO · CATALOG DEFAULT")
	_battlefield_select.set_item_metadata(0, "")
	for definition: BattlefieldDefinition in _battlefield_catalog.all_definitions():
		_battlefield_select.add_item("%s · %dx%d" % [definition.display_name.to_upper(), definition.grid_size.x, definition.grid_size.y])
		_battlefield_select.set_item_metadata(_battlefield_select.item_count - 1, definition.battlefield_id)
	_style_field(_battlefield_select)
	_battlefield_select.item_selected.connect(_on_battlefield_changed)
	page.add_child(_field_row("BATTLEFIELD", _battlefield_select, []))
	_battlefield_summary = _label("", 9, UI.SUBTLE)
	_battlefield_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_battlefield_summary)

	_enemy_seed = _spin(1, 999999999, 1)
	_enemy_seed.value = 1337
	page.add_child(_field_row("DETERMINISTIC RNG SEED", _enemy_seed, []))
	page.add_child(_button_row([_action("START SELECTED FIELD", _start_debug_battle, UI.GOLD)]))

func _build_diagnostics_tab(tabs: TabContainer) -> void:
	var page := _page(tabs, "DIAGNOSTICS")
	page.add_child(_section_label("LIVE DIAGNOSTICS", UI.CYAN))
	_diagnostics = _label("", 11, UI.TEXT)
	_diagnostics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_diagnostics)
	page.add_child(_button_row([
		_action("TEST HUB", _open_test_hub, UI.CYAN),
		_action("RETURN WORLD", _return_to_world, UI.GREEN),
		_action("OPEN SPRITE TEST", _open_sprite_test, UI.PURPLE),
	]))
	page.add_child(_section_label("DEBUG ACTION HISTORY", UI.GOLD))
	_history = _label("No debug mutations yet.", 10, UI.SUBTLE)
	_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_history)

func _initialize_defaults() -> void:
	var agumon := _roster.database.get_by_name("Agumon")
	if not agumon.is_empty():
		_spawn_species_seed = String(agumon.get("seed", ""))
	for entry in [["Agumon", 5, "wild"], ["Gabumon", 5, "trained"], ["Veemon", 6, "wild"]]:
		var species := _roster.database.get_by_name(String(entry[0]))
		if species.is_empty():
			continue
		var descriptor := _roster.make_enemy_descriptor(String(species.get("seed", "")), int(entry[1]), String(entry[2]), "E", "single")
		if not descriptor.is_empty():
			_battle_roster.append(descriptor)
	_refresh_spawn_identity()
	_refresh_battle_roster()
	_refresh_battlefield_summary()

func _refresh_all() -> void:
	_refresh_collection()
	_refresh_selected()
	_refresh_account_inventory()
	_refresh_snapshots()
	_refresh_battle_roster()
	_refresh_battlefield_summary()
	_refresh_diagnostics()

func _refresh_collection() -> void:
	if _collection_list == null:
		return
	if _selected_id.is_empty() or OverworldState.get_instance_by_id(_selected_id) == null:
		var collection := OverworldState.get_collection_instances()
		if not collection.is_empty():
			_selected_id = collection[0].id
	for child in _collection_list.get_children():
		child.queue_free()
	_collection_buttons.clear()
	_collection_ids.clear()
	_collection_previews.clear()
	var active_ids := OverworldState.get_active_party_ids()
	var reserve_ids := OverworldState.get_reserve_party_ids()
	var collection := OverworldState.get_collection_instances()
	_collection_summary.text = "%d owned · %d active · %d reserve" % [collection.size(), active_ids.size(), reserve_ids.size()]
	if collection.is_empty():
		_collection_list.add_child(_label("No Digimon available.", 10, UI.MUTED))
		return
	for value: DigimonInstance in collection:
		var species := _roster.database.get_by_seed(value.species_seed)
		var active := active_ids.has(value.id)
		var reserve := reserve_ids.has(value.id)
		var selected := value.id == _selected_id
		var accent := UI.GREEN if selected else (UI.GOLD if active else (UI.PURPLE if reserve else UI.CYAN))
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(0, 70)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.clip_contents = true
		_style_button(button, accent, selected)
		button.pressed.connect(_select_instance.bind(value.id))
		button.focus_entered.connect(_select_instance.bind(value.id))
		var margin := _margin(7, 5, 8, 5)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 7)
		margin.add_child(row)
		var preview := WalkPreviewScript.new() as DigimonWalkPreview
		preview.custom_minimum_size = Vector2(58, 58)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.set_species(String(species.get("name", "")))
		preview.set_active(selected)
		row.add_child(preview)
		var copy := VBoxContainer.new()
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation", 1)
		row.add_child(copy)
		copy.add_child(_single_line_label(_progression.display_name(value).to_upper(), 11, UI.TEXT, true))
		var location_label := "ACTIVE" if active else ("RESERVE" if reserve else ("HOSPITAL" if OverworldState.get_collection_location(value.id) == PlayerCollection.LOCATION_HOSPITAL else "STORAGE"))
		var location_color := UI.GOLD if active else (UI.PURPLE if reserve else UI.CYAN)
		copy.add_child(_single_line_label("TIER %s · %s · %s" % [value.tier, "2×2" if value.is_expanded() else "1×1", location_label], 9, location_color, true))
		copy.add_child(_single_line_label("LV %d · POT %d · LINK %d" % [value.level, value.potential, value.link], 8, UI.SUBTLE))
		_collection_list.add_child(button)
		_collection_buttons.append(button)
		_collection_ids.append(value.id)
		_collection_previews.append(preview)

func _select_instance(instance_id: String) -> void:
	if instance_id.is_empty() or OverworldState.get_instance_by_id(instance_id) == null:
		return
	if _selected_id == instance_id:
		return
	_selected_id = instance_id
	_refresh_collection()
	_refresh_selected()
	_refresh_diagnostics()

func _refresh_selected() -> void:
	var value := _selected_instance()
	if value == null:
		_digimon_summary.text = "No owned Digimon."
		_clear_preview(_digimon_preview_host)
		_refresh_routes()
		return
	var species := _roster.database.get_by_seed(value.species_seed)
	var species_name := String(species.get("name", value.species_seed))
	var rank := String(species.get("rank", "Unknown"))
	var stats := _progression.final_stats(value.id)
	_replace_preview(_digimon_preview_host, species_name, true)
	_digimon_summary.text = "%s\n%s · TIER %s · %s%s · UUID %s\nLV %d · XP %d · POT %d · LINK %d\nHP %d/%d · SP %d/%d · ATK %d · DEF %d · INT %d · SPD %d · MOV %d" % [
		_progression.display_name(value).to_upper(), rank.to_upper(), value.tier, "2×2" if value.is_expanded() else "1×1", " · EXPANSION UNLOCKED" if value.expansion_unlocked else "", value.id.substr(0, mini(12, value.id.length())), value.level, value.exp, value.potential, value.link,
		value.current_hp, int(stats.get("hp", 0)), value.current_mp, int(stats.get("mp", stats.get("sp", 0))), int(stats.get("atk", 0)), int(stats.get("def", 0)), int(stats.get("int", 0)), int(stats.get("speed", 0)), int(stats.get("mov", 0))
	]
	_level.value = value.level
	_exp.value = value.exp
	_potential.value = value.potential
	_link.value = value.link
	_current_hp.max_value = maxi(1, int(stats.get("hp", 1)))
	_current_sp.max_value = maxi(0, int(stats.get("mp", stats.get("sp", 0))))
	_current_hp.value = value.current_hp
	_current_sp.value = value.current_mp
	var tier_index := _progression.tier_options().find(value.tier)
	_tier.select(maxi(0, tier_index))
	_expansion_unlocked.button_pressed = value.expansion_unlocked
	_expanded.button_pressed = value.is_expanded()
	for key in _training_fields.keys():
		(_training_fields[key] as SpinBox).value = int(value.training.get(String(key), 0))
	_bits.value = OverworldState.get_bits()
	_data.value = OverworldState.get_digi_data_for(value.species_seed)
	_refresh_routes()

func _refresh_account_inventory() -> void:
	if _inventory_summary == null:
		return
	_inventory_summary.text = "Expansion Core ×%d · Expansion Fragment ×%d · Recipe: 5 Fragments + 50,000 Bits" % [_progression.get_item_count("expansion_core"), _progression.get_item_count("expansion_fragment")]

func _refresh_routes() -> void:
	if _route_select == null:
		return
	_route_select.clear()
	var value := _selected_instance()
	if value != null:
		var degenerating := _route_mode.selected == 1
		for route: Dictionary in _progression.routes(value.id, degenerating):
			var state := "READY" if bool(route.get("unlocked", false)) else "LOCKED"
			_route_select.add_item("%s · %s" % [String(route.get("targetName", route.get("targetSeed", "?"))), state])
			_route_select.set_item_metadata(_route_select.item_count - 1, String(route.get("targetSeed", "")))
	_refresh_route_details()

func _refresh_route_details() -> void:
	if _route_details == null:
		return
	var route := _selected_route()
	if route.is_empty():
		_route_details.text = "No route available for this form."
		_clear_preview(_route_preview_host)
		return
	var target_name := String(route.get("targetName", route.get("targetSeed", "?")))
	_replace_preview(_route_preview_host, target_name, false)
	var lines: Array[String] = ["%s · %s" % [target_name.to_upper(), "READY" if bool(route.get("unlocked", false)) else "LOCKED"]]
	var results = route.get("requirement_results", [])
	if results is Array and not results.is_empty():
		for raw in results:
			if raw is Dictionary:
				var item := raw as Dictionary
				var mark := "READY" if bool(item.get("is_met", false)) else "LOCKED"
				lines.append("%s · %s · current %s / required %s" % [mark, String(item.get("subject", item.get("type", "requirement"))).to_upper(), str(item.get("current_value", "?")), str(item.get("required_value", "?"))])
	else:
		lines.append("No explicit requirements.")
	_route_details.text = "\n".join(lines)

func _refresh_spawn_identity() -> void:
	if _spawn_identity == null:
		return
	var species := _roster.species(_spawn_species_seed)
	if species.is_empty():
		_spawn_identity.text = "Choose a species"
		_clear_preview(_spawn_preview_host)
		return
	var name := String(species.get("name", "Unknown"))
	_spawn_identity.text = "%s\n%s" % [name.to_upper(), String(species.get("rank", "Unknown")).to_upper()]
	_replace_preview(_spawn_preview_host, name, true)

func _refresh_snapshots() -> void:
	if _snapshot_select == null:
		return
	_snapshot_select.clear()
	for row: Dictionary in _state.list_snapshots():
		var name := String(row.get("name", "Snapshot"))
		_snapshot_select.add_item("%s · %s" % [name, String(row.get("created_text", ""))])
		_snapshot_select.set_item_metadata(_snapshot_select.item_count - 1, name)

func _refresh_battle_roster() -> void:
	if _battle_list == null:
		return
	for child in _battle_list.get_children():
		child.queue_free()
	_battle_summary.text = "%d / %d ENEMIES" % [_battle_roster.size(), DebugRosterTools.MAX_SANDBOX_ENEMIES]
	_refresh_battlefield_summary()
	if _battle_roster.is_empty():
		_battle_list.add_child(_label("No enemies configured. Add at least one Digimon.", 10, UI.MUTED))
		return
	for index in range(_battle_roster.size()):
		var descriptor := _battle_roster[index]
		var species := _roster.species(String(descriptor.get("species_seed", "")))
		var name := String(species.get("name", descriptor.get("species_seed", "Unknown")))
		var rank := String(species.get("rank", "Unknown"))
		var accent := UI.rank_color(rank)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.glass_panel(accent, 0.72, 8))
		_battle_list.add_child(card)
		var margin := _margin(8, 6, 8, 6)
		card.add_child(margin)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		margin.add_child(row)
		var preview := WalkPreviewScript.new() as DigimonWalkPreview
		preview.custom_minimum_size = Vector2(52, 52)
		preview.set_species(name)
		preview.set_active(false)
		row.add_child(preview)
		var identity := VBoxContainer.new()
		identity.custom_minimum_size.x = 125
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(identity)
		identity.add_child(_single_line_label("%02d · %s" % [index + 1, name.to_upper()], 10, UI.TEXT, true))
		identity.add_child(_single_line_label("%s · TIER %s · %s" % [rank.to_upper(), String(descriptor.get("tier", "E")), _footprint_label(String(descriptor.get("footprint", "single")))], 8, accent, true))
		row.add_child(_action("CHANGE", _change_battle_species.bind(index), accent, 34))
		var level := _spin(1, 99, 1)
		level.custom_minimum_size.x = 72
		level.value = int(descriptor.get("level", 1))
		level.tooltip_text = "Enemy level"
		level.value_changed.connect(_on_battle_level_changed.bind(index))
		row.add_child(level)
		var profile := OptionButton.new()
		profile.custom_minimum_size = Vector2(96, 34)
		for profile_name: String in DebugRosterTools.BATTLE_PROFILES:
			profile.add_item(profile_name.to_upper())
			if profile_name == String(descriptor.get("profile", "wild")):
				profile.select(profile.item_count - 1)
		_style_field(profile)
		profile.item_selected.connect(_on_battle_profile_changed.bind(index))
		row.add_child(profile)
		var tier := OptionButton.new()
		tier.custom_minimum_size = Vector2(68, 34)
		for tier_name: String in _progression.tier_options():
			tier.add_item(tier_name)
			if tier_name == String(descriptor.get("tier", "E")):
				tier.select(tier.item_count - 1)
		_style_field(tier)
		tier.item_selected.connect(_on_battle_tier_changed.bind(index))
		row.add_child(tier)
		var footprint := OptionButton.new()
		footprint.custom_minimum_size = Vector2(78, 34)
		for footprint_id: String in BATTLE_FOOTPRINTS:
			footprint.add_item(_footprint_label(footprint_id))
		var current_footprint := String(descriptor.get("footprint", FootprintScript.SINGLE))
		footprint.select(maxi(0, BATTLE_FOOTPRINTS.find(current_footprint)))
		_style_field(footprint)
		footprint.item_selected.connect(_on_battle_footprint_changed.bind(index))
		row.add_child(footprint)
		row.add_child(_action("DUP", _duplicate_battle_enemy.bind(index), UI.CYAN, 34))
		row.add_child(_action("REMOVE", _remove_battle_enemy.bind(index), UI.RED, 34))

func _refresh_diagnostics() -> void:
	if _diagnostics == null:
		return
	var info := _state.diagnostics(_selected_id)
	_diagnostics.text = "Scene: %s\nFPS: %d · Frame %.2f ms · Physics %.2f ms\nDraw calls: %d · Render objects: %d · Nodes: %d\nTime scale %.2f · Memory %.1f MB\nCollection: %d · Squad: %d (Active %d + Reserve %d) · Bits: %d\nSelected: Lv.%d · HP %d · SP %d" % [String(info.get("scene", "")), int(info.get("fps", 0)), float(info.get("frame_ms", 0.0)), float(info.get("physics_ms", 0.0)), int(info.get("draw_calls", 0)), int(info.get("render_objects", 0)), int(info.get("node_count", 0)), float(info.get("time_scale", 1.0)), float(info.get("static_memory", 0)) / 1048576.0, int(info.get("collection_size", 0)), int(info.get("squad_size", 0)), int(info.get("active_size", 0)), int(info.get("reserve_size", 0)), int(info.get("bits", 0)), int(info.get("selected_level", 0)), int(info.get("selected_hp", 0)), int(info.get("selected_sp", 0))]
	var history_lines: Array[String] = []
	var limit := mini(10, _state.history.size())
	for index in range(limit):
		var row := _state.history[index] as Dictionary
		history_lines.append("%s · %s · %s" % [String(row.get("time", "")), String(row.get("action", "")), String(row.get("detail", ""))])
	_history.text = "\n".join(history_lines) if not history_lines.is_empty() else "No debug mutations yet."

func _selected_instance() -> DigimonInstance:
	return _progression.instance(_selected_id) if _progression != null and not _selected_id.is_empty() else null

func _selected_route() -> Dictionary:
	var value := _selected_instance()
	if value == null or _route_select == null or _route_select.item_count == 0 or _route_select.selected < 0:
		return {}
	var target := String(_route_select.get_item_metadata(_route_select.selected))
	for route: Dictionary in _progression.routes(value.id, _route_mode.selected == 1):
		if String(route.get("targetSeed", "")) == target:
			return route
	return {}

func _apply_exact_state() -> void:
	var value := _selected_instance()
	if value == null:
		return
	var tier_name := _tier.get_item_text(_tier.selected) if _tier.selected >= 0 else "E"
	_progression.set_level(value.id, int(_level.value))
	_progression.set_exp(value.id, int(_exp.value))
	_progression.set_potential(value.id, int(_potential.value))
	_progression.set_link(value.id, int(_link.value))
	_progression.set_tier_and_expansion(value.id, tier_name, _expansion_unlocked.button_pressed, _expanded.button_pressed)
	_progression.set_resources(value.id, int(_current_hp.value), int(_current_sp.value))
	_state.log_action("Set exact state", "%s · Lv.%d · Tier %s · %s · XP %d · POT %d · LINK %d" % [_selected_name(), int(_level.value), tier_name, "2×2" if _expanded.button_pressed else "1×1", int(_exp.value), int(_potential.value), int(_link.value)])
	_status.text = "Exact Digimon state applied."
	_refresh_all()

func _add_xp(amount: int) -> void:
	if not _progression.add_xp(_selected_id, amount).is_empty():
		_state.log_action("Add XP", "%s +%d" % [_selected_name(), amount])
	_refresh_all()

func _heal() -> void:
	if _progression.heal(_selected_id):
		_state.log_action("Heal", _selected_name())
	_refresh_all()

func _critical() -> void:
	if _progression.set_critical(_selected_id):
		_state.log_action("Critical resources", _selected_name())
	_refresh_all()

func _knock_out() -> void:
	if _progression.set_knocked_out(_selected_id):
		_state.log_action("Knock out", _selected_name())
	_refresh_all()

func _assign_selected_active() -> void:
	if _selected_id.is_empty():
		return
	var ok := OverworldState.add_to_active_party(_selected_id)
	_status.text = "Assigned to Active Squad." if ok else "Could not assign Active: check the 3-slot limit or keep at least one Active."
	if ok:
		_state.log_action("Assign Active", _selected_name())
	_refresh_all()


func _assign_selected_reserve() -> void:
	if _selected_id.is_empty():
		return
	var ok := OverworldState.add_to_reserve_party(_selected_id)
	_status.text = "Assigned to Reserve Squad." if ok else "Could not assign Reserve: check the 3-slot limit or keep at least one Active."
	if ok:
		_state.log_action("Assign Reserve", _selected_name())
	_refresh_all()


func _move_selected_to_storage() -> void:
	if _selected_id.is_empty():
		return
	var ok := OverworldState.move_squad_member_to_storage(_selected_id)
	_status.text = "Moved to Storage." if ok else "Could not move to Storage: at least one Active Digimon must remain."
	if ok:
		_state.log_action("Move to Storage", _selected_name())
	_refresh_all()


func _delete_digimon() -> void:
	var value := _selected_instance()
	if value == null or _collection_tools == null:
		_status.text = "Select an owned Digimon first."
		return
	var deleted_id := value.id
	var deleted_name := _selected_name()
	var result := _collection_tools.delete_instance(deleted_id)
	if bool(result.get("success", false)):
		_progression.contexts.erase(deleted_id)
		_selected_id = ""
		var previous_location := String(result.get("previous_location", "collection")).capitalize()
		_status.text = "%s permanently deleted from player data." % deleted_name
		_state.log_action("Delete Digimon", "%s · %s · UUID %s" % [deleted_name, previous_location, deleted_id])
	else:
		match String(result.get("reason", "remove_failed")):
			"last_owned_digimon":
				_status.text = "Delete blocked: at least one owned Digimon must remain."
			"invalid_collection_state":
				_status.text = "Delete blocked: collection state is inconsistent."
			"instance_not_found":
				_status.text = "Delete blocked: the selected Digimon no longer exists."
			_:
				_status.text = "Delete failed."
	_refresh_all()

func _apply_training() -> void:
	var values: Dictionary = {}
	for key in _training_fields.keys():
		values[String(key)] = int((_training_fields[key] as SpinBox).value)
	if _progression.set_training(_selected_id, values):
		_state.log_action("Set training", _selected_name())
		_status.text = "Training values applied."
	_refresh_all()

func _clear_training() -> void:
	for key in _training_fields.keys():
		(_training_fields[key] as SpinBox).value = 0
	_apply_training()

func _meet_requirements() -> void:
	var route := _selected_route()
	if route.is_empty():
		return
	var result := _progression.meet_requirements(_selected_id, String(route.get("targetSeed", "")), _route_mode.selected == 1)
	_status.text = "Requirements prepared." if bool(result.get("success", false)) else String(result.get("reason", "Could not prepare requirements."))
	_state.log_action("Meet requirements", "%s -> %s" % [_selected_name(), String(route.get("targetName", "?"))])
	_refresh_all()

func _apply_transition() -> void:
	_transition_selected(false)

func _force_transition() -> void:
	_transition_selected(true)

func _transition_selected(bypass: bool) -> void:
	var route := _selected_route()
	if route.is_empty():
		return
	var target := String(route.get("targetSeed", ""))
	var before := _selected_name()
	var ok := _progression.transition(_selected_id, target, _route_mode.selected == 1, bypass)
	_status.text = "Transition applied through the real evolution pipeline." if ok else "Transition blocked. Use Meet Requirements or Force Transition."
	if ok:
		_state.log_action("Force transition" if bypass else "Transition", "%s -> %s" % [before, String(route.get("targetName", target))])
	_refresh_all()

func _choose_spawn_species() -> void:
	_picker_context = "spawn"
	_species_picker.open_picker("CHOOSE DIGIMON FOR STORAGE", _spawn_species_seed)

func _create_storage_digimon() -> void:
	if _spawn_species_seed.is_empty():
		_status.text = "Choose a Digimon species first."
		return
	var resource_state: String = String(["full", "critical", "empty", "custom"][_spawn_resource_state.selected])
	var tier_name := _spawn_tier.get_item_text(_spawn_tier.selected) if _spawn_tier.selected >= 0 else "E"
	var instance := _roster.create_storage_instance({
		"species_seed": _spawn_species_seed,
		"level": int(_spawn_level.value),
		"exp": int(_spawn_exp.value),
		"potential": int(_spawn_potential.value),
		"link": int(_spawn_link.value),
		"tier": tier_name,
		"expansion_unlocked": _spawn_expanded.button_pressed,
		"footprint": "large_2x2" if _spawn_expanded.button_pressed else "single",
		"resource_state": resource_state,
		"current_hp": int(_spawn_hp.value),
		"current_sp": int(_spawn_sp.value),
	})
	if instance == null:
		_status.text = "Could not create the Digimon in Storage."
		return
	_selected_id = instance.id
	var species := _roster.species(instance.species_seed)
	_status.text = "%s Lv.%d · Tier %s · %s added directly to Storage." % [String(species.get("name", "Digimon")), instance.level, instance.tier, "2×2" if instance.is_expanded() else "1×1"]
	_state.log_action("Create storage Digimon", "%s · Lv.%d · Tier %s · %s · POT %d · LINK %d" % [String(species.get("name", "Digimon")), instance.level, instance.tier, "2×2" if instance.is_expanded() else "1×1", instance.potential, instance.link])
	_refresh_all()

func _set_bits() -> void:
	_state.set_bits(int(_bits.value))
	_refresh_all()

func _set_data() -> void:
	var value := _selected_instance()
	if value != null:
		_state.set_digi_data(value.species_seed, int(_data.value))
	_refresh_all()

func _grant_expansion_core() -> void:
	var count := _progression.grant_expansion_core(1)
	_status.text = "Expansion Core granted. Inventory: %d." % count
	_state.log_action("Grant item", "Expansion Core ×1")
	_refresh_all()

func _grant_expansion_fragments() -> void:
	var count := _progression.grant_expansion_fragments(5)
	_status.text = "Five Expansion Fragments granted. Inventory: %d." % count
	_state.log_action("Grant item", "Expansion Fragment ×5")
	_refresh_all()

func _craft_expansion_core() -> void:
	var result := _progression.craft_expansion_core()
	_status.text = "Expansion Core crafted." if bool(result.get("success", false)) else "Craft blocked: %s" % String(result.get("reason", "invalid"))
	if bool(result.get("success", false)):
		_state.log_action("Craft item", "Expansion Core · 5 fragments + 50,000 Bits")
	_refresh_all()

func _set_flag() -> void:
	_status.text = "Flag updated." if _state.set_flag(_flag_id.text, _flag_value.button_pressed) else "Enter a flag id first."
	_refresh_diagnostics()

func _scenario(id: String) -> void:
	var result := _state.apply_scenario(id, _selected_id, _progression)
	_status.text = String(result.get("message", "Scenario complete."))
	_refresh_all()

func _capture_snapshot() -> void:
	_status.text = "Snapshot captured." if _state.capture_snapshot(_snapshot_name.text) else "Could not capture snapshot."
	_snapshot_name.clear()
	_refresh_snapshots()
	_refresh_diagnostics()

func _restore_snapshot() -> void:
	var name := _selected_snapshot_name()
	_status.text = "Snapshot restored." if not name.is_empty() and _state.restore_snapshot(name) else "Select a valid snapshot."
	_refresh_all()

func _delete_snapshot() -> void:
	var name := _selected_snapshot_name()
	if not name.is_empty():
		_state.delete_snapshot(name)
	_refresh_snapshots()
	_refresh_diagnostics()

func _copy_state() -> void:
	_status.text = "State JSON copied to clipboard." if _state.copy_state_json() else "Could not copy state JSON."
	_refresh_diagnostics()

func _add_battle_enemy() -> void:
	if _battle_roster.size() >= DebugRosterTools.MAX_SANDBOX_ENEMIES:
		_status.text = "Battle sandbox supports up to %d enemies in one encounter." % DebugRosterTools.MAX_SANDBOX_ENEMIES
		return
	_picker_context = "battle_add"
	_species_picker.open_picker("ADD ENEMY TO BATTLE ROSTER")

func _change_battle_species(index: int) -> void:
	if index < 0 or index >= _battle_roster.size():
		return
	_picker_context = "battle_replace:%d" % index
	_species_picker.open_picker("CHANGE ENEMY %d" % (index + 1), String(_battle_roster[index].get("species_seed", "")))

func _duplicate_battle_enemy(index: int) -> void:
	if index < 0 or index >= _battle_roster.size() or _battle_roster.size() >= DebugRosterTools.MAX_SANDBOX_ENEMIES:
		return
	_battle_roster.insert(index + 1, _battle_roster[index].duplicate(true))
	_refresh_battle_roster()

func _remove_battle_enemy(index: int) -> void:
	if index < 0 or index >= _battle_roster.size():
		return
	_battle_roster.remove_at(index)
	_refresh_battle_roster()

func _clear_battle_roster() -> void:
	_battle_roster.clear()
	_refresh_battle_roster()

func _on_battle_level_changed(value: float, index: int) -> void:
	if index < 0 or index >= _battle_roster.size():
		return
	_battle_roster[index]["level"] = int(value)

func _on_battle_profile_changed(selected: int, index: int) -> void:
	if index < 0 or index >= _battle_roster.size():
		return
	var profile_index := clampi(selected, 0, DebugRosterTools.BATTLE_PROFILES.size() - 1)
	_battle_roster[index]["profile"] = DebugRosterTools.BATTLE_PROFILES[profile_index]

func _on_battle_tier_changed(selected: int, index: int) -> void:
	if index < 0 or index >= _battle_roster.size():
		return
	var tiers := _progression.tier_options()
	if tiers.is_empty():
		return
	_battle_roster[index]["tier"] = tiers[clampi(selected, 0, tiers.size() - 1)]

func _on_battle_footprint_changed(selected: int, index: int) -> void:
	if index < 0 or index >= _battle_roster.size():
		return
	_battle_roster[index]["footprint"] = String(BATTLE_FOOTPRINTS[clampi(selected, 0, BATTLE_FOOTPRINTS.size() - 1)])
	_refresh_battle_roster()


func _on_battlefield_changed(_selected: int) -> void:
	_refresh_battlefield_summary()


func _selected_battlefield_id() -> String:
	if _battlefield_select == null or _battlefield_select.item_count == 0 or _battlefield_select.selected < 0:
		return ""
	return String(_battlefield_select.get_item_metadata(_battlefield_select.selected))


func _refresh_battlefield_summary() -> void:
	if _battlefield_summary == null or _battlefield_catalog == null:
		return
	var battlefield_id := _selected_battlefield_id()
	var definition := (
		_battlefield_catalog.default_definition()
		if battlefield_id.is_empty()
		else _battlefield_catalog.get_by_id(battlefield_id)
	)
	if definition == null:
		_battlefield_summary.text = "No valid battlefield definition is available."
		return

	var player_footprints: Array = []
	for instance: DigimonInstance in OverworldState.get_battle_ready_active_instances():
		if instance != null:
			player_footprints.append(instance.battle_footprint_id)
	var enemy_footprints: Array = []
	for descriptor: Dictionary in _battle_roster:
		enemy_footprints.append(String(descriptor.get("footprint", FootprintScript.SINGLE)))
	var compatible := definition.supports_teams(player_footprints, enemy_footprints)
	var mode := "AUTO" if battlefield_id.is_empty() else "LOCKED"
	var readiness := "READY FOR CURRENT ROSTERS" if compatible else "INCOMPATIBLE WITH CURRENT FOOTPRINTS"
	_battlefield_summary.text = "%s · %s · %s\nMax footprint %s · %d player spawn cells · %d enemy spawn cells · %d difficult tiles" % [
		mode,
		definition.summary(),
		readiness,
		_footprint_label(definition.max_supported_footprint_id()),
		definition.player_deployment_cells.size(),
		definition.enemy_deployment_cells.size(),
		definition.movement_cost_cells.size(),
	]


func _footprint_label(footprint_id: String) -> String:
	return FootprintScript.display_label(footprint_id)


func _start_debug_battle() -> void:
	if _battle_roster.is_empty():
		_status.text = "Add at least one enemy before starting the sandbox battle."
		return
	var enemies: Array[Dictionary] = []
	for raw in _battle_roster:
		if raw is Dictionary:
			enemies.append((raw as Dictionary).duplicate(true))
	var battlefield_id := _selected_battlefield_id()
	var selected_definition := (
		_battlefield_catalog.default_definition()
		if battlefield_id.is_empty()
		else _battlefield_catalog.get_by_id(battlefield_id)
	)
	var player_footprints: Array = []
	for instance: DigimonInstance in OverworldState.get_battle_ready_active_instances():
		if instance != null:
			player_footprints.append(instance.battle_footprint_id)
	var enemy_footprints: Array = []
	for descriptor: Dictionary in enemies:
		enemy_footprints.append(String(descriptor.get("footprint", FootprintScript.SINGLE)))
	if selected_definition != null and not selected_definition.supports_teams(player_footprints, enemy_footprints):
		_status.text = "%s cannot fit the current player/enemy footprints. Choose a compatible field." % selected_definition.display_name
		_refresh_battlefield_summary()
		return
	_pending_battle_config = {
		"encounter_id": "debug_sandbox",
		"enemy_party": enemies,
		"battle_map": battlefield_id,
		"reward_modifier": 1.0,
		"repeatable": true,
		"seed": int(_enemy_seed.value),
	}
	var names: Array[String] = []
	for descriptor: Dictionary in enemies:
		var species := _roster.species(String(descriptor.get("species_seed", "")))
		names.append("%s Lv.%d · T%s · %s" % [String(species.get("name", "?")), int(descriptor.get("level", 1)), String(descriptor.get("tier", "E")), _footprint_label(String(descriptor.get("footprint", "single")))])
	_state.log_action("Battle sandbox", "%d enemies · %s" % [enemies.size(), ", ".join(names)])
	var current_scene_path := WORLD_SCENE
	if get_tree().current_scene != null and not get_tree().current_scene.scene_file_path.is_empty():
		current_scene_path = get_tree().current_scene.scene_file_path
	WorldState.stage_return_scene(current_scene_path, {"source": "developer_toolkit_battle"})
	close()
	if not DigitalSceneTransition.enter_battle(BATTLE_SCENE):
		_status.text = "Battle transition is currently busy."

func _on_species_picked(seed: String) -> void:
	var context := _picker_context
	_picker_context = ""
	if context == "spawn":
		_spawn_species_seed = seed
		_refresh_spawn_identity()
		return
	if context == "battle_add":
		var descriptor := _roster.make_enemy_descriptor(seed, 5, "wild", "E", "single")
		if not descriptor.is_empty():
			_battle_roster.append(descriptor)
			_refresh_battle_roster()
		return
	if context.begins_with("battle_replace:"):
		var index_text := context.trim_prefix("battle_replace:")
		if not index_text.is_valid_int():
			return
		var index := index_text.to_int()
		if index < 0 or index >= _battle_roster.size():
			return
		_battle_roster[index]["species_seed"] = seed
		_refresh_battle_roster()

func _open_test_hub() -> void:
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == TEST_HUB_SCENE:
		_status.text = "Already in the Test Hub."
		return
	close()
	DigitalSceneTransition.request_scene(TEST_HUB_SCENE, "debug_hub")


func _return_to_world() -> void:
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == WORLD_SCENE:
		_status.text = "Already in the campaign world."
		return
	WorldState.clear_return_scene()
	close()
	DigitalSceneTransition.request_scene(WORLD_SCENE, "world")


func _open_sprite_test() -> void:
	if _sprite_test_lab == null:
		_status.text = "Sprite Test failed to initialize."
		return
	close()
	_sprite_test_paused_before_open = get_tree().paused
	get_tree().paused = true
	_sprite_test_lab.open_lab()


func _on_global_sprite_test_closed() -> void:
	get_tree().paused = _sprite_test_paused_before_open


func _is_test_hub_scene() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == TEST_HUB_SCENE

func _on_state_changed() -> void:
	if _open:
		call_deferred("_refresh_all")

func _on_rewards_changed(_bits_value: int, _digi_data_value: Dictionary) -> void:
	if _open:
		call_deferred("_refresh_all")

func _selected_name() -> String:
	var value := _selected_instance()
	return _progression.display_name(value) if value != null else "Digimon"

func _selected_snapshot_name() -> String:
	if _snapshot_select == null or _snapshot_select.item_count == 0 or _snapshot_select.selected < 0:
		return ""
	return String(_snapshot_select.get_item_metadata(_snapshot_select.selected))

func _layout() -> void:
	if _dev_button == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	_dev_button.scale = Vector2.ONE * scale_factor
	_dev_button.size = Vector2(100, 38)
	_dev_button.position = Vector2(maxf(10.0, physical.x - 112.0), 62.0) * scale_factor
	if _panel == null:
		return
	var compact := UI.is_compact(get_viewport(), 820.0)
	var edge := 12.0 if compact else 20.0
	var available := Vector2(maxf(1.0, physical.x - edge * 2.0), maxf(1.0, physical.y - edge * 2.0))
	var requested := Vector2(minf(MAX_FRAME_SIZE.x, available.x), minf(MAX_FRAME_SIZE.y, available.y))
	_panel.scale = Vector2.ONE * scale_factor
	_panel.size = requested
	_panel.position = Vector2((physical.x - requested.x) * 0.5, (physical.y - requested.y) * 0.5) * scale_factor
	_panel.clip_contents = true
	_collection_panel.custom_minimum_size.x = 218 if compact else 250
	if _species_picker != null and _species_picker.visible:
		_species_picker.call_deferred("_layout")

func _page(tabs: TabContainer, name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	var margin := _margin(8, 12, 8, 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	return page

func _field_card(title: String, field: Control, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UI.glass_panel(accent, 0.68, 8))
	var margin := _margin(9, 7, 9, 7)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var label := _label(title, 9, accent, true)
	label.custom_minimum_size.x = 76
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return card

func _field_row(title: String, field: Control, actions: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _label(title, 9, UI.SUBTLE, true)
	label.custom_minimum_size.x = 155
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	for action in actions:
		if action is Control:
			row.add_child(action)
	return row

func _button_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	for button in buttons:
		if button is Control:
			row.add_child(button)
	return row

func _action(text: String, callback: Callable, accent: Color = UI.CYAN, minimum_height: float = 38.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = minimum_height
	button.add_theme_font_size_override("font_size", 10)
	_style_button(button, accent, false)
	UI.apply_body_font(button)
	button.pressed.connect(callback)
	return button

func _style_button(button: Button, accent: Color, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", UI.action_style(accent, "selected" if selected else "normal"))
	button.add_theme_stylebox_override("hover", UI.action_style(accent, "hover"))
	button.add_theme_stylebox_override("focus", UI.action_style(accent, "focus"))
	button.add_theme_stylebox_override("pressed", UI.action_style(accent, "pressed"))
	button.add_theme_color_override("font_color", UI.TEXT)
	button.add_theme_color_override("font_hover_color", UI.TEXT)
	button.add_theme_color_override("font_focus_color", UI.TEXT)
	button.add_theme_color_override("font_pressed_color", UI.TEXT)

func _style_field(field: Control) -> void:
	field.add_theme_font_size_override("font_size", 10)
	UI.apply_body_font(field)

func _spin(min_value: float, max_value: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.custom_minimum_size = Vector2(120, 36)
	_style_field(spin)
	return spin

func _section_label(text: String, accent: Color) -> Label:
	var label := _label(text, 11, accent, true)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	return label

func _label(text: String, size: int, color: Color, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label

func _single_line_label(text: String, size: int, color: Color, heading: bool = false) -> Label:
	var label := _label(text, size, color, heading)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return label

func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var result := MarginContainer.new()
	result.add_theme_constant_override("margin_left", left)
	result.add_theme_constant_override("margin_top", top)
	result.add_theme_constant_override("margin_right", right)
	result.add_theme_constant_override("margin_bottom", bottom)
	return result

func _replace_preview(host: Control, species_name: String, active: bool) -> void:
	if host == null:
		return
	_clear_preview(host)
	var preview := WalkPreviewScript.new() as DigimonWalkPreview
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.set_species(species_name)
	preview.set_active(active)
	host.add_child(preview)

func _clear_preview(host: Control) -> void:
	if host == null:
		return
	for child in host.get_children():
		child.queue_free()
