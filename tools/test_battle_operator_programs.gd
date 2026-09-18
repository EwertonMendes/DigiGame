extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")
const CatalogScript = preload("res://src/world/BattleOperatorEncounterCatalog.gd")
const EncounterScript = preload("res://src/world/BattleEncounterDefinition.gd")
const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")
const OperatorIcons = preload("res://src/ui/battle_operator/BattleOperatorIconCatalog.gd")
const RANKS: Array[String] = ["Fresh", "In-Training", "Rookie", "Champion", "Ultimate", "Mega"]

var _failures: Array[String] = []


func _ready() -> void:
	OverworldState.reset_active_party()
	BattleEncounterSession.clear_pending_encounter()
	var database: DigimonDatabase = OverworldState.get_database() as DigimonDatabase
	_expect(database != null and database.is_loaded(), "Persistent Digimon database must be loaded")
	_test_operator_icon_catalog()
	if not _failures.is_empty():
		_finish()
		return

	var catalog := CatalogScript.new() as BattleOperatorEncounterCatalog
	catalog.prepare(database)
	var action_database := ActionDatabaseScript.new() as BattleActionDatabase
	_expect(action_database.load_default(), "Battle action database must load")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260916

	var basic_result := catalog.build_basic_encounter("grand_digital_field")
	_expect(bool(basic_result.get("ok", false)), "Basic Battle must build through the operator catalog")
	var basic_definition := EncounterScript.from_dict(basic_result.get("config", {}) as Dictionary) as BattleEncounterDefinition
	_expect(basic_definition.validate(database).is_empty(), "Basic Battle must satisfy BattleEncounterDefinition")
	_expect(basic_definition.battle_map == "grand_digital_field", "Basic Battle must preserve the player-selected battlefield")

	for rank: String in RANKS:
		var ready_count := catalog.ready_count(rank, database)
		_expect(ready_count >= 3, "%s must expose at least 3 verified battle-ready species (found %d)" % [rank, ready_count])
		var result := catalog.build_rank_encounter(rank, database, 7, rng, "training_clearing")
		_expect(bool(result.get("ok", false)), "%s random program must build a valid encounter" % rank)
		if not bool(result.get("ok", false)):
			continue
		var config := result.get("config", {}) as Dictionary
		var definition := EncounterScript.from_dict(config) as BattleEncounterDefinition
		_expect(definition.validate(database).is_empty(), "%s generated encounter must satisfy BattleEncounterDefinition" % rank)
		_expect(definition.enemy_party.size() == 3, "%s program must deploy exactly 3 enemies" % rank)
		_expect(definition.battle_map == "training_clearing", "%s program must preserve the player-selected battlefield" % rank)
		var seen: Dictionary = {}
		for descriptor: Dictionary in definition.enemy_party:
			var seed := String(descriptor.get("species_seed", ""))
			var species: Dictionary = database.get_by_seed(seed)
			_expect(not species.is_empty(), "%s generated enemy must reference a known species" % rank)
			_expect(String(species.get("rank", "")) == rank, "%s program must not mix Digimon ranks" % rank)
			_expect(not seen.has(seed), "%s program must select 3 unique Digimon when the pool allows it" % rank)
			seen[seed] = true
			var level := int(descriptor.get("level", 1))
			_expect(not action_database.get_default_action_for_species(seed, level).is_empty(), "%s generated enemy must have a ready battle action at its selected level" % String(species.get("name", seed)))
			var resource_path := "res://assets/resources/%s.tres" % String(species.get("name", "")).to_lower()
			var resource: Digimon = null
			if ResourceLoader.exists(resource_path):
				resource = load(resource_path) as Digimon
			_expect(resource != null and resource.texture != null, "%s generated enemy must have a packaged battle resource" % String(species.get("name", seed)))
			if resource != null:
				_expect(resource.sprite_layout == "directional_12" and resource.sprite_hframes == 12 and resource.sprite_vframes == 1, "%s generated enemy must have the complete 12-frame directional sprite contract" % String(species.get("name", seed)))

	var baby_result := catalog.build_rank_encounter("Baby", database, 3, rng)
	_expect(bool(baby_result.get("ok", false)) and String(baby_result.get("rank", "")) == "In-Training", "Baby UI label must map to the canonical In-Training rank")

	var session_probe := catalog.build_rank_encounter("Rookie", database, 5, rng)
	if bool(session_probe.get("ok", false)):
		var staged := session_probe.get("config", {}) as Dictionary
		_expect(BattleEncounterSession.stage_encounter(staged), "Battle encounter session must accept a generated encounter")
		_expect(BattleEncounterSession.has_pending_encounter(), "Staged encounter must remain available across the scene boundary")
		var consumed := BattleEncounterSession.consume_pending_encounter()
		_expect(String(consumed.get("encounter_id", "")) == String(staged.get("encounter_id", "")), "Battle encounter session must preserve the staged payload")
		_expect(not BattleEncounterSession.has_pending_encounter(), "Battle encounter session must be one-shot after consumption")

	await _test_operator_menu()
	_finish()


func _test_operator_icon_catalog() -> void:
	var textures := OperatorIcons.all_operator_textures()
	_expect(textures.size() == 16, "Battle Operator must ship the complete 16-icon authored SVG family")
	var unique_paths: Dictionary = {}
	for texture: Texture2D in textures:
		_expect(texture != null, "Every Battle Operator icon must import as Texture2D")
		if texture == null:
			continue
		var path := texture.resource_path
		_expect(path.begins_with(OperatorIcons.ICON_ROOT), "Battle Operator icons must come from the dedicated asset namespace")
		_expect(not unique_paths.has(path), "Every Battle Operator semantic slot must have its own SVG asset")
		unique_paths[path] = true

	for section_id: String in ["program", "battlefield", "simulation"]:
		_expect(OperatorIcons.section_icon(section_id) != null, "Section %s must have a dedicated SVG icon" % section_id)
	for program_id: String in PROGRAM_IDS:
		_expect(OperatorIcons.program_icon(program_id) != null, "Program %s must have a dedicated SVG icon" % program_id)
	for battlefield_id: String in ["training_clearing", "twin_grove", "forest_crossing", "broken_clearing", "grand_digital_field"]:
		_expect(OperatorIcons.battlefield_icon(battlefield_id) != null, "Battlefield %s must have a dedicated SVG icon" % battlefield_id)
	_expect(OperatorIcons.action_icon("start_simulation") != null, "Start Simulation must have a dedicated SVG icon")


func _test_operator_menu() -> void:
	var database: DigimonDatabase = OverworldState.get_database() as DigimonDatabase
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	for _index in range(6):
		await get_tree().process_frame
	var player := hub.get("_player") as Node2D
	var operator := hub.get("_operator") as Node2D
	_expect(player != null and operator != null, "Hub must expose player and Battle Operator")
	if player == null or operator == null:
		hub.queue_free()
		return

	player.position = operator.position + Vector2(12.0, 12.0)
	hub.call("_refresh_interaction")
	hub.call("open_test_battle_dialog")
	for _index in range(5):
		await get_tree().process_frame

	var dialog := hub.find_child("BattleDialog", true, false) as Control
	var header := hub.find_child("OperatorHeader", true, false) as DigiModalHeader
	var program_panel := hub.find_child("ProgramPanel", true, false) as PanelContainer
	var field_panel := hub.find_child("BattlefieldPanel", true, false) as PanelContainer
	var simulation_panel := hub.find_child("SimulationPanel", true, false) as PanelContainer
	var program_header := hub.find_child("ProgramHeader", true, false) as DigiSectionHeader
	var field_header := hub.find_child("BattlefieldHeader", true, false) as DigiSectionHeader
	var simulation_header := hub.find_child("SimulationHeader", true, false) as DigiSectionHeader
	var buttons := hub.get("_battle_program_buttons") as Dictionary
	var fields := hub.get("_battlefield_buttons") as Dictionary
	var launch := hub.find_child("StartBattle", true, false) as Button
	var selected_program_label := hub.find_child("SelectedProgram", true, false) as Label
	var selected_field_label := hub.find_child("SelectedField", true, false) as Label
	var operator_layer := hub.get("_operator_ui_layer") as CanvasLayer
	var footer := hub.get("_operator_footer") as DigiInputHintBar
	var close_button := header.get_close_button() if header != null else null

	_expect(dialog != null and dialog.visible, "Battle Operator workspace must open")
	_expect(operator_layer != null and operator_layer.layer > 80, "Battle Operator must render above closed Sprite Test and Dev debug launchers")
	_expect(footer != null, "Battle Operator must reuse the shared workspace input-hint footer")
	_expect(close_button != null and close_button.focus_mode == Control.FOCUS_NONE, "Battle Operator close chrome must stay outside directional focus navigation")
	_expect(header != null and header.is_workspace_mode(), "Battle Operator must use the shared V2 workspace header")
	_expect(program_panel != null and field_panel != null and simulation_panel != null, "Battle Operator must expose Program, Battlefield and Simulation workspace panels")
	_expect(buttons.size() == 7, "Battle Operator must expose Basic plus six random-rank programs")
	_expect(fields.size() == 5, "Battle Operator must expose all five authored Battlefield V2 layouts")
	_expect(launch != null and launch.text == "START BATTLE", "Battle Operator must expose a persistent launch action")
	_expect(launch.icon != null and launch.icon.resource_path == OperatorIcons.action_icon("start_simulation").resource_path, "Start Battle must use the dedicated simulation SVG")
	for header_spec: Array in [
		[program_header, "program"],
		[field_header, "battlefield"],
		[simulation_header, "simulation"],
	]:
		var section_header := header_spec[0] as DigiSectionHeader
		var section_id := String(header_spec[1])
		var icon_view := section_header.get_icon_view() if section_header != null else null
		_expect(icon_view != null and icon_view.uses_texture(), "%s header must render an authored SVG instead of a procedural fallback" % section_id)
		if icon_view != null and icon_view.get_texture() != null:
			_expect(icon_view.get_texture().resource_path == OperatorIcons.section_icon(section_id).resource_path, "%s header must use its dedicated Battle Operator SVG" % section_id)
	_expect(String(hub.get("_selected_program_id")) == "basic", "Battle Operator must default to Basic Battle")
	_expect(String(hub.get("_selected_battlefield_id")) == "training_clearing", "Battle Operator must default to Training Clearing")
	_expect(selected_program_label != null and selected_program_label.text == "BASIC BATTLE", "Simulation panel must expose the selected program")
	_expect(selected_field_label != null and selected_field_label.text == "TRAINING CLEARING", "Simulation panel must expose the selected battlefield")

	var basic := buttons.get("basic") as DigiSelectionCard
	var training := fields.get("training_clearing") as DigiSelectionCard
	_expect(basic != null and basic.is_selected(), "Basic Battle must have persistent selected highlight by default")
	_expect(training != null and training.is_selected(), "Training Clearing must have persistent selected highlight by default")
	var basic_badge := basic.find_child("SelectionStatus", true, false) as Label if basic != null else null
	var training_badge := training.find_child("SelectionStatus", true, false) as Label if training != null else null
	_expect(basic_badge != null and basic_badge.text == "MIXED", "Selected Battle Program must keep its semantic badge instead of displaying SELECTED")
	_expect(training_badge != null and training_badge.text == "COMPACT", "Selected Battlefield must keep its field-class badge instead of displaying SELECTED")
	var basic_surface := basic.find_child("SelectionCommittedSurface", true, false) as Panel if basic != null else null
	var training_surface := training.find_child("SelectionCommittedSurface", true, false) as Panel if training != null else null
	_expect(basic_surface != null and basic_surface.visible, "Selected Battle Program must expose the persistent bright selection surface")
	_expect(training_surface != null and training_surface.visible, "Selected Battlefield must expose the persistent bright selection surface")
	_expect(get_viewport().gui_get_focus_owner() == basic, "Opening Battle Operator must focus the current selected program instead of a destructive/confirm action")

	var expected_titles := {
		"basic": "BASIC BATTLE",
		"random_fresh": "RANDOM FRESH",
		"random_baby": "RANDOM BABY",
		"random_rookie": "RANDOM ROOKIE",
		"random_champion": "RANDOM CHAMPION",
		"random_ultimate": "RANDOM ULTIMATE",
		"random_mega": "RANDOM MEGA",
	}
	if dialog != null:
		var dialog_rect := dialog.get_global_rect()
		for program_id: String in expected_titles.keys():
			var button := buttons.get(program_id) as DigiSelectionCard
			_expect(button != null, "Battle Operator must expose %s as a selection card" % program_id)
			if button == null:
				continue
			var title := button.find_child("SelectionTitle", true, false) as Label
			var icon_view := button.find_child("SelectionIcon", true, false) as DigiIconView
			_expect(title != null and title.text == String(expected_titles[program_id]), "%s must use the intended player-facing title" % program_id)
			_expect(icon_view != null and icon_view.uses_texture(), "%s must use an authored Battle Operator SVG" % program_id)
			if icon_view != null and icon_view.get_texture() != null:
				_expect(icon_view.get_texture().resource_path == OperatorIcons.program_icon(program_id).resource_path, "%s must use its dedicated program SVG" % program_id)
			_expect(button.get_combined_minimum_size().y >= 52.0, "%s must remain touch-safe" % program_id)
			_expect(dialog_rect.encloses(button.get_global_rect()), "%s must stay visually contained inside the Battle Operator workspace" % program_id)
			_expect(not button.disabled, "%s must be available when the party is battle-ready" % program_id)

			var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
			var focus_overlay := button.get_theme_stylebox("focus")
			var pressed := button.get_theme_stylebox("pressed") as StyleBoxFlat
			_expect(normal != null and focus_overlay is StyleBoxEmpty and pressed != null, "%s must use stable workspace state plus an empty native focus overlay" % program_id)
			if normal != null and pressed != null:
				_expect(
					normal.shadow_size == pressed.shadow_size,
					"%s press state must keep the same shared workspace depth" % program_id
				)
				_expect(
					normal.border_width_left == pressed.border_width_left
					and normal.border_width_top == pressed.border_width_top
					and normal.border_width_right == pressed.border_width_right
					and normal.border_width_bottom == pressed.border_width_bottom,
					"%s press feedback must not change card geometry" % program_id
				)
				_expect(normal.border_color == pressed.border_color and normal.bg_color == pressed.bg_color, "%s click must not flash a different border or fill" % program_id)

		for battlefield_id: String in fields.keys():
			var field_button := fields.get(battlefield_id) as DigiSelectionCard
			_expect(field_button != null, "Battle Operator must expose battlefield %s as a selection card" % battlefield_id)
			if field_button == null:
				continue
			var field_icon := field_button.find_child("SelectionIcon", true, false) as DigiIconView
			_expect(field_icon != null and field_icon.uses_texture(), "%s battlefield card must use an authored SVG" % battlefield_id)
			if field_icon != null and field_icon.get_texture() != null:
				_expect(field_icon.get_texture().resource_path == OperatorIcons.battlefield_icon(battlefield_id).resource_path, "%s must use its dedicated battlefield SVG" % battlefield_id)
			_expect(field_button.get_combined_minimum_size().y >= 52.0, "%s battlefield card must remain touch-safe" % battlefield_id)
			_expect(dialog_rect.encloses(field_button.get_global_rect()), "%s battlefield card must stay inside the workspace" % battlefield_id)

	# Controller navigation mirrors the approved service menus: only the left
	# stick navigates, one threshold crossing equals one focus step, and focus is
	# independent from the committed program selection.
	basic.grab_focus()
	await get_tree().process_frame
	var right_motion := InputEventJoypadMotion.new()
	right_motion.axis = JOY_AXIS_RIGHT_Y
	right_motion.axis_value = 0.95
	hub.call("_input", right_motion)
	await get_tree().process_frame
	_expect(get_viewport().gui_get_focus_owner() == basic, "Right analog stick must never navigate Battle Operator")

	var left_down := InputEventJoypadMotion.new()
	left_down.axis = JOY_AXIS_LEFT_Y
	left_down.axis_value = 0.95
	hub.call("_input", left_down)
	await get_tree().process_frame
	var fresh := buttons.get("random_fresh") as DigiSelectionCard
	_expect(get_viewport().gui_get_focus_owner() == fresh, "One left-stick deflection must move focus exactly one program")
	_expect(String(hub.get("_selected_program_id")) == "basic", "Moving focus must not commit a different battle program")

	hub.call("_input", left_down)
	await get_tree().process_frame
	_expect(get_viewport().gui_get_focus_owner() == fresh, "Held left stick must not race through Battle Operator choices")

	var left_release := InputEventJoypadMotion.new()
	left_release.axis = JOY_AXIS_LEFT_Y
	left_release.axis_value = 0.0
	hub.call("_input", left_release)
	var second_down := InputEventJoypadMotion.new()
	second_down.axis = JOY_AXIS_LEFT_Y
	second_down.axis_value = 0.95
	hub.call("_input", second_down)
	await get_tree().process_frame
	var baby := buttons.get("random_baby") as DigiSelectionCard
	_expect(get_viewport().gui_get_focus_owner() == baby, "Releasing and deflecting again must allow the next single focus step")

	# Horizontal navigation moves real focus between workspace regions. It must
	# not alias vertical selection or commit anything implicitly.
	var left_release_horizontal := InputEventJoypadMotion.new()
	left_release_horizontal.axis = JOY_AXIS_LEFT_X
	left_release_horizontal.axis_value = 0.0
	hub.call("_input", left_release_horizontal)
	basic.grab_focus()
	var left_right := InputEventJoypadMotion.new()
	left_right.axis = JOY_AXIS_LEFT_X
	left_right.axis_value = 0.95
	hub.call("_input", left_right)
	await get_tree().process_frame
	_expect(get_viewport().gui_get_focus_owner() == training, "Left-stick horizontal navigation must move actual focus from Program to Battlefield")
	_expect(String(hub.get("_selected_program_id")) == "basic" and String(hub.get("_selected_battlefield_id")) == "training_clearing", "Horizontal focus movement must not mutate committed selections")

	hub.call("_select_battle_program", "random_rookie")
	hub.call("_select_battlefield", "grand_digital_field")
	for _index in range(2):
		await get_tree().process_frame

	var rookie := buttons.get("random_rookie") as DigiSelectionCard
	var grand := fields.get("grand_digital_field") as DigiSelectionCard
	_expect(String(hub.get("_selected_program_id")) == "random_rookie", "Program selection must update without immediately starting combat")
	_expect(String(hub.get("_selected_battlefield_id")) == "grand_digital_field", "Battlefield selection must update without debug tooling")
	_expect(rookie != null and rookie.is_selected(), "New program selection must keep a persistent highlight")
	_expect(basic != null and not basic.is_selected(), "Previous program selection must lose its persistent highlight")
	_expect(grand != null and grand.is_selected(), "New battlefield selection must keep a persistent highlight")
	_expect(training != null and not training.is_selected(), "Previous battlefield selection must lose its persistent highlight")
	var rookie_surface := rookie.find_child("SelectionCommittedSurface", true, false) as Panel if rookie != null else null
	var grand_surface := grand.find_child("SelectionCommittedSurface", true, false) as Panel if grand != null else null
	_expect(rookie_surface != null and rookie_surface.visible, "Newly selected program must keep its committed visual surface visible")
	_expect(grand_surface != null and grand_surface.visible, "Newly selected battlefield must keep its committed visual surface visible")
	_expect(basic_surface != null and not basic_surface.visible, "Previous program committed visual surface must turn off without changing card copy")
	_expect(training_surface != null and not training_surface.visible, "Previous field committed visual surface must turn off without changing card copy")
	_expect(selected_program_label != null and selected_program_label.text == "RANDOM ROOKIE", "Simulation panel must refresh the selected program")
	_expect(selected_field_label != null and selected_field_label.text == "GRAND DIGITAL FIELD", "Simulation panel must refresh the selected battlefield")

	var selected_result := hub.call("_build_selected_battle_encounter", "random_rookie") as Dictionary
	_expect(bool(selected_result.get("ok", false)), "Selected operator configuration must build a valid encounter")
	if bool(selected_result.get("ok", false)):
		var selected_config := selected_result.get("config", {}) as Dictionary
		_expect(String(selected_config.get("battle_map", "")) == "grand_digital_field", "Player-selected field must be staged in the real encounter payload")
		var selected_definition := EncounterScript.from_dict(selected_config) as BattleEncounterDefinition
		_expect(selected_definition.validate(database).is_empty(), "Selected operator configuration must remain valid domain data")

	hub.queue_free()
	for _index in range(3):
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	BattleEncounterSession.clear_pending_encounter()
	if _failures.is_empty():
		print("battle operator programs regression passed")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("[battle-operator-programs] %s" % failure)
	get_tree().quit(1)
