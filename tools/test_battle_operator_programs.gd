extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")
const CatalogScript = preload("res://src/world/BattleOperatorEncounterCatalog.gd")
const EncounterScript = preload("res://src/world/BattleEncounterDefinition.gd")
const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")
const RANKS: Array[String] = ["Fresh", "In-Training", "Rookie", "Champion", "Ultimate", "Mega"]

var _failures: Array[String] = []


func _ready() -> void:
	OverworldState.reset_active_party()
	BattleEncounterSession.clear_pending_encounter()
	var database: DigimonDatabase = OverworldState.get_database() as DigimonDatabase
	_expect(database != null and database.is_loaded(), "Persistent Digimon database must be loaded")
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
	var buttons := hub.get("_battle_program_buttons") as Dictionary
	var fields := hub.get("_battlefield_buttons") as Dictionary
	var launch := hub.find_child("StartBattle", true, false) as Button
	var selected_program_label := hub.find_child("SelectedProgram", true, false) as Label
	var selected_field_label := hub.find_child("SelectedField", true, false) as Label

	_expect(dialog != null and dialog.visible, "Battle Operator workspace must open")
	_expect(header != null and header.is_workspace_mode(), "Battle Operator must use the shared V2 workspace header")
	_expect(program_panel != null and field_panel != null and simulation_panel != null, "Battle Operator must expose Program, Battlefield and Simulation workspace panels")
	_expect(buttons.size() == 7, "Battle Operator must expose Basic plus six random-rank programs")
	_expect(fields.size() == 5, "Battle Operator must expose all five authored Battlefield V2 layouts")
	_expect(launch != null and launch.text == "START BATTLE", "Battle Operator must expose a persistent launch action")
	_expect(String(hub.get("_selected_program_id")) == "basic", "Battle Operator must default to Basic Battle")
	_expect(String(hub.get("_selected_battlefield_id")) == "training_clearing", "Battle Operator must default to Training Clearing")
	_expect(selected_program_label != null and selected_program_label.text == "BASIC BATTLE", "Simulation panel must expose the selected program")
	_expect(selected_field_label != null and selected_field_label.text == "TRAINING CLEARING", "Simulation panel must expose the selected battlefield")

	var basic := buttons.get("basic") as DigiSelectionCard
	var training := fields.get("training_clearing") as DigiSelectionCard
	_expect(basic != null and basic.is_selected(), "Basic Battle must have persistent selected highlight by default")
	_expect(training != null and training.is_selected(), "Training Clearing must have persistent selected highlight by default")
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
			_expect(title != null and title.text == String(expected_titles[program_id]), "%s must use the intended player-facing title" % program_id)
			_expect(button.get_combined_minimum_size().y >= 52.0, "%s must remain touch-safe" % program_id)
			_expect(dialog_rect.encloses(button.get_global_rect()), "%s must stay visually contained inside the Battle Operator workspace" % program_id)
			_expect(not button.disabled, "%s must be available when the party is battle-ready" % program_id)

			var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
			var pressed := button.get_theme_stylebox("pressed") as StyleBoxFlat
			_expect(normal != null and pressed != null, "%s must expose stable V2 selection styles" % program_id)
			if normal != null and pressed != null:
				_expect(normal.shadow_size == 0 and pressed.shadow_size == 0, "%s must not bounce through press/focus shadows" % program_id)
				_expect(
					normal.border_width_left == pressed.border_width_left
					and normal.border_width_top == pressed.border_width_top
					and normal.border_width_right == pressed.border_width_right
					and normal.border_width_bottom == pressed.border_width_bottom,
					"%s press feedback must not change card geometry" % program_id
				)

		for battlefield_id: String in fields.keys():
			var field_button := fields.get(battlefield_id) as DigiSelectionCard
			_expect(field_button != null, "Battle Operator must expose battlefield %s as a selection card" % battlefield_id)
			if field_button == null:
				continue
			_expect(field_button.get_combined_minimum_size().y >= 52.0, "%s battlefield card must remain touch-safe" % battlefield_id)
			_expect(dialog_rect.encloses(field_button.get_global_rect()), "%s battlefield card must stay inside the workspace" % battlefield_id)

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
