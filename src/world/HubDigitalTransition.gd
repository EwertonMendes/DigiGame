extends "res://src/world/HubHospitalGameplay.gd"

const BattleOperatorCatalogScript = preload("res://src/world/BattleOperatorEncounterCatalog.gd")
const EncounterDefinitionScript = preload("res://src/world/BattleEncounterDefinition.gd")

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

var _battle_catalog := BattleOperatorCatalogScript.new() as BattleOperatorEncounterCatalog
var _battle_program_rng := RandomNumberGenerator.new()
var _battle_program_buttons: Dictionary = {}
var _battle_program_hint: Label = null
var _battle_program_columns := 2


func _ready() -> void:
	_battle_program_rng.randomize()
	super._ready()
	# MusicDirector is persistent across scenes, so returning from combat fades the
	# battle theme into the Terminal Commons theme instead of restarting audio
	# through a scene-local player.
	MusicDirector.play_zone_1()


func _build_dialog() -> void:
	super._build_dialog()
	if _mobile_dialog_content == null or _start_battle_button == null or _mobile_dialog_cancel == null:
		return

	_mobile_dialog_body.text = "SELECT A BATTLE PROGRAM"
	_start_battle_button.text = "BASIC BATTLE"
	_start_battle_button.tooltip_text = "Start the same standard test encounter used by the Battle Operator today."
	_start_battle_button.set_meta("battle_program_id", "basic")
	_battle_program_buttons["basic"] = _start_battle_button

	_battle_program_hint = _label(
		"Random programs deploy 3 verified battle-ready Digimon from one stage, scaled to your active squad's level.",
		11,
		HUB_V2.MUTED
	)
	_battle_program_hint.name = "ProgramHint"
	_battle_program_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mobile_dialog_content.add_child(_battle_program_hint)

	_add_battle_program_button("random_fresh", "RANDOM FRESH", "Fresh", HUB_V2.CYAN)
	_add_battle_program_button("random_baby", "RANDOM BABY", "In-Training", HUB_V2.BLUE)
	_add_battle_program_button("random_rookie", "RANDOM ROOKIE", "Rookie", HUB_V2.GREEN)
	_add_battle_program_button("random_champion", "RANDOM CHAMPION", "Champion", HUB_V2.AMBER)
	_add_battle_program_button("random_ultimate", "RANDOM ULTIMATE", "Ultimate", HUB_V2.RED)
	_add_battle_program_button("random_mega", "RANDOM MEGA", "Mega", HUB_V2.PURPLE)

	_mobile_dialog_cancel.set_meta("battle_program_id", "cancel")
	_battle_program_cancel_tooltip()
	_battle_program_buttons["cancel"] = _mobile_dialog_cancel
	_wire_battle_program_focus()


func _add_battle_program_button(program_id: String, label: String, rank: String, accent: Color) -> void:
	var button := _dialog_button(label, accent)
	button.name = _program_button_name(program_id)
	button.custom_minimum_size.y = HUB_V2.TOUCH_TARGET
	button.tooltip_text = "Start a battle against 3 random verified %s Digimon." % rank
	button.set_meta("battle_program_id", program_id)
	button.pressed.connect(_start_battle_program.bind(program_id))
	_mobile_dialog_content.add_child(button)
	_apply_v2_dialog_button(button, accent)
	_battle_program_buttons[program_id] = button


func _program_button_name(program_id: String) -> String:
	match program_id:
		"random_fresh": return "RandomFreshBattle"
		"random_baby": return "RandomBabyBattle"
		"random_rookie": return "RandomRookieBattle"
		"random_champion": return "RandomChampionBattle"
		"random_ultimate": return "RandomUltimateBattle"
		"random_mega": return "RandomMegaBattle"
	return "BattleProgram"


func _battle_program_cancel_tooltip() -> void:
	if _mobile_dialog_cancel != null:
		_mobile_dialog_cancel.tooltip_text = "Close the Battle Operator without starting combat."


func _open_dialog() -> void:
	super._open_dialog()
	if not _dialog_open:
		return
	var party_error := OverworldState.battle_party_validation_error()
	_refresh_battle_program_availability(party_error)
	if _mobile_dialog_body != null:
		_mobile_dialog_body.text = "PARTY NOT READY" if not party_error.is_empty() else "SELECT A BATTLE PROGRAM"
	if _battle_program_hint != null:
		_battle_program_hint.text = party_error if not party_error.is_empty() else "Random programs deploy 3 verified battle-ready Digimon from one stage, scaled to your active squad's level."
	if _mobile_dialog_cancel != null and not _mobile_dialog_cancel.disabled:
		_mobile_dialog_cancel.grab_focus()


func _refresh_battle_program_availability(party_error: String) -> void:
	var database := OverworldState.get_database()
	_battle_catalog.prepare(database)
	for program_id: String in PROGRAM_ORDER:
		if program_id == "cancel":
			continue
		var button := _battle_program_buttons.get(program_id) as Button
		if button == null:
			continue
		button.disabled = not party_error.is_empty()
		if button.disabled or program_id == "basic":
			continue
		var rank := _rank_for_program(program_id)
		var available := _battle_catalog.ready_count(rank, database)
		if available < BattleOperatorEncounterCatalog.ENEMY_COUNT:
			button.disabled = true
			button.tooltip_text = "Only %d verified %s Digimon are battle-ready; 3 are required." % [available, rank]
		else:
			button.tooltip_text = "3 random opponents selected from %d verified %s Digimon." % [available, rank]


func _start_test_battle() -> void:
	_start_battle_program("basic")


func _start_battle_program(program_id: String) -> void:
	if _transitioning or DigitalSceneTransition.is_transitioning():
		return
	var party_error := OverworldState.battle_party_validation_error()
	if not party_error.is_empty():
		_show_battle_program_error(party_error)
		return

	var selected_names: Array[String] = []
	if program_id == "basic":
		BattleEncounterSession.clear_pending_encounter()
	else:
		var rank := _rank_for_program(program_id)
		if rank.is_empty():
			_show_battle_program_error("This battle program is not available.")
			return
		var result := _battle_catalog.build_rank_encounter(
			rank,
			OverworldState.get_database(),
			_active_party_level(),
			_battle_program_rng
		)
		if not bool(result.get("ok", false)):
			_show_battle_program_error(String(result.get("error", "Could not prepare this battle program.")))
			return
		var config := result.get("config", {}) as Dictionary
		var definition := EncounterDefinitionScript.from_dict(config) as BattleEncounterDefinition
		var errors := definition.validate(OverworldState.get_database())
		if not errors.is_empty():
			_show_battle_program_error("Could not prepare a safe encounter: %s" % "; ".join(errors))
			return
		if not BattleEncounterSession.stage_encounter(config):
			_show_battle_program_error("Could not stage the selected encounter.")
			return
		for raw_name in Array(result.get("names", [])):
			selected_names.append(String(raw_name))

	_begin_battle_transition(program_id, selected_names)


func _begin_battle_transition(program_id: String, selected_names: Array[String]) -> void:
	_transitioning = true
	_dialog_open = false
	_dialog_panel.visible = false
	if _player != null:
		_player.movement_enabled = false
	_mobile_controls.visible = false
	_set_battle_program_buttons_disabled(true)
	var roster_suffix := "" if selected_names.is_empty() else " · %s" % ", ".join(selected_names)
	print("[Hub] START_BATTLE_PROGRAM program=%s%s" % [program_id, roster_suffix])
	if not DigitalSceneTransition.enter_battle(BATTLE_SCENE_PATH):
		BattleEncounterSession.clear_pending_encounter()
		_transitioning = false
		if _player != null:
			_player.movement_enabled = true
		_set_battle_program_buttons_disabled(false)
		_layout_ui()


func _show_battle_program_error(message: String) -> void:
	if _mobile_dialog_body != null:
		_mobile_dialog_body.text = "BATTLE PROGRAM UNAVAILABLE"
	if _battle_program_hint != null:
		_battle_program_hint.text = message
	if _mobile_dialog_cancel != null:
		_mobile_dialog_cancel.grab_focus()


func _set_battle_program_buttons_disabled(disabled: bool) -> void:
	for program_id: String in PROGRAM_ORDER:
		if program_id == "cancel":
			continue
		var button := _battle_program_buttons.get(program_id) as Button
		if button != null:
			button.disabled = disabled


func _active_party_level() -> int:
	var party: Array[DigimonInstance] = OverworldState.get_active_instances()
	if party.is_empty():
		return 1
	var total := 0
	for instance: DigimonInstance in party:
		total += maxi(1, instance.level)
	return maxi(1, int(round(float(total) / float(party.size()))))


func _rank_for_program(program_id: String) -> String:
	match program_id:
		"random_fresh": return "Fresh"
		"random_baby": return "In-Training"
		"random_rookie": return "Rookie"
		"random_champion": return "Champion"
		"random_ultimate": return "Ultimate"
		"random_mega": return "Mega"
	return ""


func _input(event: InputEvent) -> void:
	if not _dialog_open or _transitioning:
		super._input(event)
		return

	if event.is_action_pressed("ui_cancel"):
		_close_dialog()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_focus_battle_program_delta(-1, 0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_focus_battle_program_delta(1, 0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_focus_battle_program_delta(0, -1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_focus_battle_program_delta(0, 1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_activate_focused_battle_program()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _fallback_action_touch != -1:
				return
			for program_id: String in PROGRAM_ORDER:
				var button := _battle_program_buttons.get(program_id) as Button
				if button == null or button.disabled:
					continue
				if _control_contains_viewport_point(button, touch.position, 6.0):
					_fallback_action_touch = touch.index
					_activate_battle_program(program_id)
					get_viewport().set_input_as_handled()
					return
		elif touch.index == _fallback_action_touch:
			_fallback_action_touch = -1
			get_viewport().set_input_as_handled()


func _activate_focused_battle_program() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner() as Button
	if focus_owner == null:
		return
	var program_id := String(focus_owner.get_meta("battle_program_id", ""))
	_activate_battle_program(program_id)


func _activate_battle_program(program_id: String) -> void:
	if program_id == "cancel":
		_close_dialog()
		return
	var button := _battle_program_buttons.get(program_id) as Button
	if button == null or button.disabled:
		return
	if program_id == "basic":
		_start_test_battle()
	else:
		_start_battle_program(program_id)


func _focus_battle_program_delta(column_delta: int, row_delta: int) -> void:
	var current_index := PROGRAM_ORDER.find(_focused_program_id())
	if current_index < 0:
		current_index = PROGRAM_ORDER.find("cancel")
	var columns := maxi(1, _battle_program_columns)
	var rows := int(ceil(float(PROGRAM_ORDER.size()) / float(columns)))
	var row := current_index / columns
	var column := current_index % columns
	row = clampi(row + row_delta, 0, rows - 1)
	column = clampi(column + column_delta, 0, columns - 1)
	var target_index := mini(row * columns + column, PROGRAM_ORDER.size() - 1)
	_focus_nearest_enabled_program(target_index, current_index)


func _focused_program_id() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner() as Button
	if focus_owner == null:
		return ""
	return String(focus_owner.get_meta("battle_program_id", ""))


func _focus_nearest_enabled_program(target_index: int, fallback_index: int) -> void:
	var target_id := PROGRAM_ORDER[target_index]
	var button := _battle_program_buttons.get(target_id) as Button
	if button != null and not button.disabled:
		button.grab_focus()
		return
	# Disabled rank programs should not trap controller navigation. Walk toward
	# the requested target first, then fall back to the safe NOT NOW action.
	var direction := 1 if target_index >= fallback_index else -1
	var index := target_index
	while index >= 0 and index < PROGRAM_ORDER.size():
		var candidate := _battle_program_buttons.get(PROGRAM_ORDER[index]) as Button
		if candidate != null and not candidate.disabled:
			candidate.grab_focus()
			return
		index += direction
	var cancel := _battle_program_buttons.get("cancel") as Button
	if cancel != null:
		cancel.grab_focus()


func _layout_mobile_dialog(physical: Vector2, ui_scale: float, landscape: bool, edge: float) -> void:
	if _dialog_panel == null or _mobile_dialog_content == null or _battle_program_buttons.is_empty():
		super._layout_mobile_dialog(physical, ui_scale, landscape, edge)
		return

	var compact_landscape := landscape and physical.y < 520.0
	var columns := 4 if compact_landscape else 2
	_battle_program_columns = columns
	var rows := int(ceil(float(PROGRAM_ORDER.size()) / float(columns)))
	var side_pad := 22.0 if compact_landscape else 26.0
	var top_pad := 18.0
	var button_gap := 9.0
	var button_height := HUB_V2.TOUCH_TARGET
	var header_height := 106.0 if compact_landscape else 116.0
	var bottom_pad := 18.0
	var desired_height := header_height + float(rows) * button_height + float(maxi(0, rows - 1)) * button_gap + bottom_pad
	var dialog_height := minf(desired_height, physical.y - edge * 2.0)
	var dialog_width := minf(860.0 if compact_landscape else 760.0, physical.x - edge * 2.0)

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
	_mobile_dialog_title.add_theme_font_size_override("font_size", 11)
	_mobile_dialog_body.position = Vector2(side_pad, top_pad + 25.0)
	_mobile_dialog_body.size = Vector2(dialog_width - side_pad * 2.0, 28.0)
	_mobile_dialog_body.add_theme_font_size_override("font_size", 17 if not compact_landscape else 15)
	if _battle_program_hint != null:
		_battle_program_hint.position = Vector2(side_pad, top_pad + 55.0)
		_battle_program_hint.size = Vector2(dialog_width - side_pad * 2.0, 42.0)
		_battle_program_hint.add_theme_font_size_override("font_size", 10 if compact_landscape else 11)

	var grid_top := header_height
	var available_width := dialog_width - side_pad * 2.0
	var button_width := (available_width - button_gap * float(columns - 1)) / float(columns)
	for index in range(PROGRAM_ORDER.size()):
		var program_id := PROGRAM_ORDER[index]
		var button := _battle_program_buttons.get(program_id) as Button
		if button == null:
			continue
		var row := index / columns
		var column := index % columns
		button.custom_minimum_size.y = HUB_V2.TOUCH_TARGET
		button.position = Vector2(
			side_pad + float(column) * (button_width + button_gap),
			grid_top + float(row) * (button_height + button_gap)
		)
		button.size = Vector2(button_width, button_height)
		button.add_theme_font_size_override("font_size", 10 if compact_landscape or button_width < 185.0 else 12)
	_wire_battle_program_focus()


func _wire_battle_program_focus() -> void:
	if _battle_program_buttons.is_empty():
		return
	var columns := maxi(1, _battle_program_columns)
	for index in range(PROGRAM_ORDER.size()):
		var button := _battle_program_buttons.get(PROGRAM_ORDER[index]) as Button
		if button == null:
			continue
		var row := index / columns
		var column := index % columns
		var left_index := row * columns + maxi(0, column - 1)
		var right_index := mini(row * columns + mini(columns - 1, column + 1), PROGRAM_ORDER.size() - 1)
		var up_index := maxi(0, index - columns)
		var down_index := mini(PROGRAM_ORDER.size() - 1, index + columns)
		var left := _battle_program_buttons.get(PROGRAM_ORDER[left_index]) as Button
		var right := _battle_program_buttons.get(PROGRAM_ORDER[right_index]) as Button
		var up := _battle_program_buttons.get(PROGRAM_ORDER[up_index]) as Button
		var down := _battle_program_buttons.get(PROGRAM_ORDER[down_index]) as Button
		if left != null:
			button.focus_neighbor_left = left.get_path()
		if right != null:
			button.focus_neighbor_right = right.get_path()
		if up != null:
			button.focus_neighbor_top = up.get_path()
		if down != null:
			button.focus_neighbor_bottom = down.get_path()
