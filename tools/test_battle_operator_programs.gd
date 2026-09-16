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

	for rank: String in RANKS:
		var ready_count := catalog.ready_count(rank, database)
		_expect(ready_count >= 3, "%s must expose at least 3 verified battle-ready species (found %d)" % [rank, ready_count])
		var result := catalog.build_rank_encounter(rank, database, 7, rng)
		_expect(bool(result.get("ok", false)), "%s random program must build a valid encounter" % rank)
		if not bool(result.get("ok", false)):
			continue
		var config := result.get("config", {}) as Dictionary
		var definition := EncounterScript.from_dict(config) as BattleEncounterDefinition
		_expect(definition.validate(database).is_empty(), "%s generated encounter must satisfy BattleEncounterDefinition" % rank)
		_expect(definition.enemy_party.size() == 3, "%s program must deploy exactly 3 enemies" % rank)
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
	for _index in range(4):
		await get_tree().process_frame

	var dialog := hub.find_child("BattleDialog", true, false) as Control
	var buttons := hub.get("_battle_program_buttons") as Dictionary
	_expect(dialog != null and dialog.visible, "Battle Operator program menu must open")
	_expect(buttons.size() == 8, "Battle Operator must expose Basic, six random-rank programs, and Not Now")
	var expected_labels := {
		"basic": "BASIC BATTLE",
		"random_fresh": "RANDOM FRESH",
		"random_baby": "RANDOM BABY",
		"random_rookie": "RANDOM ROOKIE",
		"random_champion": "RANDOM CHAMPION",
		"random_ultimate": "RANDOM ULTIMATE",
		"random_mega": "RANDOM MEGA",
		"cancel": "NOT NOW",
	}
	if dialog != null:
		var dialog_rect := dialog.get_global_rect()
		for program_id: String in expected_labels.keys():
			var button := buttons.get(program_id) as Button
			_expect(button != null, "Battle Operator must expose %s" % program_id)
			if button == null:
				continue
			_expect(button.text == String(expected_labels[program_id]), "%s must use the intended player-facing label" % program_id)
			_expect(button.custom_minimum_size.y >= DigiUiTheme.TOUCH_TARGET, "%s must remain touch-safe" % program_id)
			_expect(dialog_rect.encloses(button.get_global_rect()), "%s must stay visually contained inside the Battle Operator panel" % program_id)
			if program_id != "cancel":
				_expect(not button.disabled, "%s must be available when the party is battle-ready" % program_id)
		var cancel := buttons.get("cancel") as Button
		_expect(get_viewport().gui_get_focus_owner() == cancel, "Battle Operator must keep NOT NOW as the safe default focus")

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
