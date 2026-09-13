extends CanvasLayer

const AccessScript = preload("res://src/debug/DebugToolkitAccess.gd")
const ProgressionToolsScript = preload("res://src/debug/DebugProgressionTools.gd")
const StateToolsScript = preload("res://src/debug/DebugStateTools.gd")
const UI = preload("res://src/ui/TacticalTheme.gd")
const MENU = preload("res://src/ui/MenuUiStyle.gd")

const BATTLE_SCENE := "res://scenes/main.tscn"

var _available := false
var _open := false
var _paused_before_open := false
var _progression: DebugProgressionTools
var _state: DebugStateTools
var _pending_battle_config: Dictionary = {}

var _dev_button: Button
var _panel: PanelContainer
var _instance_select: OptionButton
var _status: Label
var _digimon_summary: Label
var _level: SpinBox
var _potential: SpinBox
var _link: SpinBox
var _route_mode: OptionButton
var _route_select: OptionButton
var _route_details: Label
var _bits: SpinBox
var _data: SpinBox
var _flag_id: LineEdit
var _flag_value: CheckButton
var _snapshot_name: LineEdit
var _snapshot_select: OptionButton
var _enemy_species: LineEdit
var _enemy_level: SpinBox
var _enemy_count: SpinBox
var _enemy_seed: SpinBox
var _diagnostics: Label
var _history: Label

func _ready() -> void:
	layer = 900
	process_mode = Node.PROCESS_MODE_ALWAYS
	_available = AccessScript.is_available()
	if not _available:
		set_process_input(false)
		return
	_progression = ProgressionToolsScript.new() as DebugProgressionTools
	_state = StateToolsScript.new() as DebugStateTools
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	OverworldState.collection_changed.connect(_on_state_changed)
	OverworldState.account_rewards_changed.connect(_on_rewards_changed)
	set_process(true)
	_layout()

func _process(_delta: float) -> void:
	if _open and _diagnostics != null:
		_refresh_diagnostics()

func _input(event: InputEvent) -> void:
	if not _available or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.physical_keycode == KEY_F2:
		toggle()
		get_viewport().set_input_as_handled()
	elif _open and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
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
	_paused_before_open = get_tree().paused
	get_tree().paused = true
	_panel.visible = true
	_dev_button.visible = false
	_refresh_all()

func close() -> void:
	if not _open:
		return
	_open = false
	_panel.visible = false
	_dev_button.visible = true
	get_tree().paused = _paused_before_open

func consume_pending_battle_config() -> Dictionary:
	var result := _pending_battle_config.duplicate(true)
	_pending_battle_config.clear()
	return result

func _build_ui() -> void:
	_dev_button = MENU.action_button("DEV · F2", UI.PURPLE, 36.0)
	_dev_button.focus_mode = Control.FOCUS_NONE
	_dev_button.tooltip_text = "Open the in-game developer toolkit."
	_dev_button.pressed.connect(open)
	add_child(_dev_button)

	_panel = PanelContainer.new()
	_panel.name = "DeveloperToolkitPanel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", MENU.screen_frame())
	add_child(_panel)

	var margin := MENU.margin(18, 16, 18, 16)
	_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := _label("DEVELOPER TOOLKIT", 19, UI.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_instance_select = OptionButton.new()
	_instance_select.custom_minimum_size.x = 230
	_instance_select.item_selected.connect(_on_instance_selected)
	header.add_child(_instance_select)
	var close_button := MENU.action_button("CLOSE · ESC", UI.MUTED, 36.0)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_status = _label(AccessScript.activation_hint(), 11, UI.MUTED)
	root.add_child(_status)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	_build_digimon_tab(tabs)
	_build_evolution_tab(tabs)
	_build_state_tab(tabs)
	_build_scenarios_tab(tabs)
	_build_battle_tab(tabs)
	_build_diagnostics_tab(tabs)

func _build_digimon_tab(tabs: TabContainer) -> void:
	var page := _page("DIGIMON")
	tabs.add_child(page)
	_digimon_summary = _label("", 13, UI.TEXT)
	_digimon_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_digimon_summary)
	_level = _spin("Level", 1, 99, 1)
	page.add_child(_field_row("LEVEL", _level, [
		_action("SET", _set_level), _action("MAX", _max_level)
	]))
	page.add_child(_button_row([
		_action("+100 XP", _add_xp.bind(100)), _action("+1000 XP", _add_xp.bind(1000)),
		_action("HEAL", _heal), _action("1 HP / 0 SP", _critical, UI.RED)
	]))
	_potential = _spin("Potential", 0, 100, 1)
	page.add_child(_field_row("POTENTIAL", _potential, [_action("SET", _set_potential)]))
	_link = _spin("Link", 0, 100, 1)
	page.add_child(_field_row("LINK", _link, [_action("SET", _set_link)]))

func _build_evolution_tab(tabs: TabContainer) -> void:
	var page := _page("EVOLUTION")
	tabs.add_child(page)
	_route_mode = OptionButton.new()
	_route_mode.add_item("Digivolution")
	_route_mode.add_item("Degeneration")
	_route_mode.item_selected.connect(func(_index: int): _refresh_routes())
	page.add_child(_field_row("MODE", _route_mode, []))
	_route_select = OptionButton.new()
	_route_select.custom_minimum_size.y = 38
	_route_select.item_selected.connect(func(_index: int): _refresh_route_details())
	page.add_child(_field_row("ROUTE", _route_select, []))
	_route_details = _label("Select a route.", 12, UI.TEXT)
	_route_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_route_details.custom_minimum_size.y = 150
	page.add_child(_route_details)
	page.add_child(_button_row([
		_action("MEET REQUIREMENTS", _meet_requirements, UI.GOLD),
		_action("APPLY REAL TRANSITION", _apply_transition, UI.CYAN),
		_action("FORCE TRANSITION", _force_transition, UI.RED),
	]))

func _build_state_tab(tabs: TabContainer) -> void:
	var page := _page("ACCOUNT / FLAGS")
	tabs.add_child(page)
	_bits = _spin("Bits", 0, 9999999, 100)
	page.add_child(_field_row("BITS", _bits, [_action("SET", _set_bits)]))
	_data = _spin("Digi Data", 0, 9999, 10)
	page.add_child(_field_row("SELECTED SPECIES DATA", _data, [_action("SET", _set_data)]))
	_flag_id = LineEdit.new()
	_flag_id.placeholder_text = "progression flag id"
	_flag_value = CheckButton.new()
	_flag_value.text = "true"
	page.add_child(_field_row("FLAG", _flag_id, [_flag_value, _action("SET FLAG", _set_flag)]))
	var hint := _label("Flags are written to the real persistent collection state so quest/world code can observe them.", 11, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hint)

func _build_scenarios_tab(tabs: TabContainer) -> void:
	var page := _page("SCENARIOS / SAVE")
	tabs.add_child(page)
	page.add_child(_label("One-click reproducible states", 14, UI.GOLD))
	page.add_child(_button_row([
		_action("FRESH START", _scenario.bind("fresh_start")),
		_action("PARTY LV.20", _scenario.bind("party_level_20")),
		_action("READY EVOLUTION", _scenario.bind("ready_first_evolution")),
		_action("CRITICAL PARTY", _scenario.bind("critical_party")),
		_action("RICH ACCOUNT", _scenario.bind("rich_account")),
	]))
	_snapshot_name = LineEdit.new()
	_snapshot_name.placeholder_text = "Snapshot name (for example: Before Greymon evolution)"
	page.add_child(_field_row("NEW SNAPSHOT", _snapshot_name, [_action("CAPTURE", _capture_snapshot, UI.GOLD)]))
	_snapshot_select = OptionButton.new()
	page.add_child(_field_row("SAVED SNAPSHOT", _snapshot_select, [
		_action("RESTORE", _restore_snapshot), _action("DELETE", _delete_snapshot, UI.RED)
	]))
	page.add_child(_button_row([_action("COPY CURRENT STATE JSON", _copy_state)]))

func _build_battle_tab(tabs: TabContainer) -> void:
	var page := _page("BATTLE SANDBOX")
	tabs.add_child(page)
	var text := _label("Build a disposable encounter using the real persistent party and battle runtime.", 12, UI.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(text)
	_enemy_species = LineEdit.new()
	_enemy_species.text = "Agumon"
	_enemy_species.placeholder_text = "Species name or seed"
	page.add_child(_field_row("ENEMY", _enemy_species, []))
	_enemy_level = _spin("Enemy level", 1, 99, 1)
	_enemy_level.value = 5
	page.add_child(_field_row("LEVEL", _enemy_level, []))
	_enemy_count = _spin("Enemy count", 1, 6, 1)
	_enemy_count.value = 3
	page.add_child(_field_row("COUNT", _enemy_count, []))
	_enemy_seed = _spin("RNG seed", 1, 999999999, 1)
	_enemy_seed.value = 1337
	page.add_child(_field_row("RNG SEED", _enemy_seed, []))
	page.add_child(_button_row([_action("START DEBUG BATTLE", _start_debug_battle, UI.GOLD)]))

func _build_diagnostics_tab(tabs: TabContainer) -> void:
	var page := _page("DIAGNOSTICS")
	tabs.add_child(page)
	_diagnostics = _label("", 12, UI.TEXT)
	_diagnostics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_diagnostics)
	page.add_child(_button_row([_action("OPEN SPRITE TEST", _open_sprite_test, UI.PURPLE)]))
	page.add_child(_label("Debug action history", 13, UI.GOLD))
	_history = _label("No debug mutations yet.", 11, UI.MUTED)
	_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_history)

func _refresh_all() -> void:
	_refresh_instances()
	_refresh_selected()
	_refresh_snapshots()
	_refresh_diagnostics()

func _refresh_instances() -> void:
	var previous := _selected_instance_id()
	_instance_select.clear()
	for value: DigimonInstance in OverworldState.get_collection_instances():
		var label := "%s · Lv.%d%s" % [_progression.display_name(value), value.level, " · PARTY" if OverworldState.get_active_party_ids().has(value.id) else ""]
		_instance_select.add_item(label)
		_instance_select.set_item_metadata(_instance_select.item_count - 1, value.id)
		if value.id == previous:
			_instance_select.select(_instance_select.item_count - 1)
	if _instance_select.item_count > 0 and _instance_select.selected < 0:
		_instance_select.select(0)

func _refresh_selected() -> void:
	var value := _selected_instance()
	if value == null:
		_digimon_summary.text = "No owned Digimon."
		return
	var stats := _progression.final_stats(value.id)
	_digimon_summary.text = "%s · UUID %s\nLv.%d · XP %d · Potential %d · Link %d · HP %d · SP %d\nATK %d · DEF %d · INT %d · SPD %d · MOV %d" % [
		_progression.display_name(value), value.id, value.level, value.exp, value.potential, value.link,
		value.current_hp, value.current_mp, int(stats.get("atk", 0)), int(stats.get("def", 0)), int(stats.get("int", 0)), int(stats.get("speed", 0)), int(stats.get("mov", 0))]
	_level.value = value.level
	_potential.value = value.potential
	_link.value = value.link
	_bits.value = OverworldState.get_bits()
	_data.value = OverworldState.get_digi_data_for(value.species_seed)
	_refresh_routes()

func _refresh_routes() -> void:
	if _route_select == null:
		return
	_route_select.clear()
	var value := _selected_instance()
	if value == null:
		_refresh_route_details()
		return
	var degenerating := _route_mode.selected == 1
	for route: Dictionary in _progression.routes(value.id, degenerating):
		var ready := "READY" if bool(route.get("unlocked", false)) else "LOCKED"
		_route_select.add_item("%s · %s" % [String(route.get("targetName", route.get("targetSeed", "?"))), ready])
		_route_select.set_item_metadata(_route_select.item_count - 1, String(route.get("targetSeed", "")))
	_refresh_route_details()

func _refresh_route_details() -> void:
	if _route_details == null:
		return
	var route := _selected_route()
	if route.is_empty():
		_route_details.text = "No route available for this form."
		return
	var lines: Array[String] = ["Target: %s · %s" % [String(route.get("targetName", "?")), "READY" if bool(route.get("unlocked", false)) else "LOCKED"]]
	var results = route.get("requirement_results", [])
	if results is Array and not results.is_empty():
		for raw in results:
			if not raw is Dictionary:
				continue
			var item := raw as Dictionary
			lines.append("%s %s · current %s / required %s" % ["✓" if bool(item.get("is_met", false)) else "×", String(item.get("subject", item.get("type", "requirement"))).to_upper(), str(item.get("current_value", "?")), str(item.get("required_value", "?"))])
	else:
		lines.append("No explicit requirements.")
	_route_details.text = "\n".join(lines)

func _refresh_snapshots() -> void:
	_snapshot_select.clear()
	for row: Dictionary in _state.list_snapshots():
		var name := String(row.get("name", "Snapshot"))
		_snapshot_select.add_item("%s · %s" % [name, String(row.get("created_text", ""))])
		_snapshot_select.set_item_metadata(_snapshot_select.item_count - 1, name)

func _refresh_diagnostics() -> void:
	if _diagnostics == null:
		return
	var info := _state.diagnostics(_selected_instance_id())
	_diagnostics.text = "Scene: %s\nFPS: %d · Time scale %.2f · Memory %.1f MB\nCollection: %d · Party: %d · Bits: %d\nSelected: Lv.%d · HP %d · SP %d" % [
		String(info.get("scene", "")), int(info.get("fps", 0)), float(info.get("time_scale", 1.0)), float(info.get("static_memory", 0)) / 1048576.0,
		int(info.get("collection_size", 0)), int(info.get("party_size", 0)), int(info.get("bits", 0)), int(info.get("selected_level", 0)), int(info.get("selected_hp", 0)), int(info.get("selected_sp", 0))]
	var history_lines: Array[String] = []
	for row: Dictionary in _state.history.slice(0, mini(10, _state.history.size())):
		history_lines.append("%s · %s · %s" % [String(row.get("time", "")), String(row.get("action", "")), String(row.get("detail", ""))])
	_history.text = "\n".join(history_lines) if not history_lines.is_empty() else "No debug mutations yet."

func _selected_instance_id() -> String:
	if _instance_select == null or _instance_select.item_count == 0 or _instance_select.selected < 0:
		return ""
	return String(_instance_select.get_item_metadata(_instance_select.selected))

func _selected_instance() -> DigimonInstance:
	return _progression.instance(_selected_instance_id()) if _progression != null else null

func _selected_route() -> Dictionary:
	var value := _selected_instance()
	if value == null or _route_select == null or _route_select.item_count == 0 or _route_select.selected < 0:
		return {}
	var target := String(_route_select.get_item_metadata(_route_select.selected))
	for route: Dictionary in _progression.routes(value.id, _route_mode.selected == 1):
		if String(route.get("targetSeed", "")) == target:
			return route
	return {}

func _set_level() -> void:
	if _progression.set_level(_selected_instance_id(), int(_level.value)):
		_state.log_action("Set level", "%s → Lv.%d" % [_selected_name(), int(_level.value)])
	_refresh_all()

func _max_level() -> void:
	_level.value = _progression.curve.max_level()
	_set_level()

func _add_xp(amount: int) -> void:
	if not _progression.add_xp(_selected_instance_id(), amount).is_empty():
		_state.log_action("Add XP", "%s +%d" % [_selected_name(), amount])
	_refresh_all()

func _heal() -> void:
	if _progression.heal(_selected_instance_id()):
		_state.log_action("Heal", _selected_name())
	_refresh_all()

func _critical() -> void:
	if _progression.set_critical(_selected_instance_id()):
		_state.log_action("Critical resources", _selected_name())
	_refresh_all()

func _set_potential() -> void:
	if _progression.set_potential(_selected_instance_id(), int(_potential.value)):
		_state.log_action("Set Potential", "%s = %d" % [_selected_name(), int(_potential.value)])
	_refresh_all()

func _set_link() -> void:
	if _progression.set_link(_selected_instance_id(), int(_link.value)):
		_state.log_action("Set Link", "%s = %d" % [_selected_name(), int(_link.value)])
	_refresh_all()

func _meet_requirements() -> void:
	var route := _selected_route()
	if route.is_empty():
		return
	var result := _progression.meet_requirements(_selected_instance_id(), String(route.get("targetSeed", "")), _route_mode.selected == 1)
	_status.text = "Requirements prepared." if bool(result.get("success", false)) else String(result.get("reason", "Could not prepare requirements."))
	_state.log_action("Meet requirements", "%s → %s" % [_selected_name(), String(route.get("targetName", "?"))])
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
	var ok := _progression.transition(_selected_instance_id(), target, _route_mode.selected == 1, bypass)
	_status.text = "Transition applied through the real evolution pipeline." if ok else "Transition blocked. Use Meet Requirements or Force Transition."
	if ok:
		_state.log_action("Force transition" if bypass else "Transition", "%s → %s" % [before, String(route.get("targetName", target))])
	_refresh_all()

func _set_bits() -> void:
	_state.set_bits(int(_bits.value))
	_refresh_all()

func _set_data() -> void:
	var value := _selected_instance()
	if value != null:
		_state.set_digi_data(value.species_seed, int(_data.value))
	_refresh_all()

func _set_flag() -> void:
	_status.text = "Flag updated." if _state.set_flag(_flag_id.text, _flag_value.button_pressed) else "Enter a flag id first."
	_refresh_diagnostics()

func _scenario(id: String) -> void:
	var result := _state.apply_scenario(id, _selected_instance_id(), _progression)
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

func _start_debug_battle() -> void:
	var database := OverworldState.get_database() as DigimonDatabase
	var species := database.get_by_name(_enemy_species.text)
	if species.is_empty():
		species = database.get_by_seed(_enemy_species.text)
	if species.is_empty():
		_status.text = "Unknown enemy species: %s" % _enemy_species.text
		return
	var enemies: Array[Dictionary] = []
	for _index in range(int(_enemy_count.value)):
		enemies.append({"species_seed": String(species.get("seed", "")), "level": int(_enemy_level.value), "profile": "wild"})
	_pending_battle_config = {"encounter_id": "debug_sandbox", "enemy_party": enemies, "reward_modifier": 1.0, "repeatable": true, "seed": int(_enemy_seed.value)}
	_state.log_action("Battle sandbox", "%dx %s Lv.%d · seed %d" % [enemies.size(), String(species.get("name", "?")), int(_enemy_level.value), int(_enemy_seed.value)])
	close()
	if not DigitalSceneTransition.enter_battle(BATTLE_SCENE):
		_status.text = "Battle transition is currently busy."

func _open_sprite_test() -> void:
	var scene := get_tree().current_scene
	var debug_node := scene.get_node_or_null("SpriteTestDebug") if scene != null else null
	if debug_node == null or not debug_node.has_method("_open_lab"):
		_status.text = "Sprite Test is available from the Hub scene."
		return
	close()
	debug_node.call("_open_lab")

func _on_instance_selected(_index: int) -> void:
	_refresh_selected()
	_refresh_diagnostics()

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
	if _snapshot_select.item_count == 0 or _snapshot_select.selected < 0:
		return ""
	return String(_snapshot_select.get_item_metadata(_snapshot_select.selected))

func _layout() -> void:
	if _dev_button == null:
		return
	var physical := UI.physical_window_size(get_viewport())
	var scale_factor := UI.ui_scale(get_viewport())
	_dev_button.scale = Vector2.ONE * scale_factor
	_dev_button.size = Vector2(96, 36)
	_dev_button.position = Vector2(maxf(12.0, physical.x - 110.0), 62.0) * scale_factor
	if _panel != null:
		MENU.apply_safe_frame(_panel, get_viewport(), Vector2(1040, 650), 760.0)

func _page(name: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = name
	page.add_theme_constant_override("separation", 10)
	var margin := MENU.margin(8, 14, 8, 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	return content

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	UI.apply_body_font(label)
	return label

func _spin(tooltip: String, min_value: float, max_value: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.tooltip_text = tooltip
	spin.custom_minimum_size.x = 190
	return spin

func _field_row(title: String, field: Control, actions: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _label(title, 11, UI.MUTED)
	label.custom_minimum_size.x = 160
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	for action in actions:
		if action is Control:
			row.add_child(action)
	return row

func _button_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for button in buttons:
		if button is Control:
			row.add_child(button)
	return row

func _action(text: String, callback: Callable, accent: Color = UI.CYAN) -> Button:
	var button := MENU.action_button(text, accent, 38.0)
	button.pressed.connect(callback)
	return button
