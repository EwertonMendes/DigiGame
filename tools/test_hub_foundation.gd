extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")
const PLAYER_SHEET_PATH := "res://assets/characters/world/player_blond.png"
const OPERATOR_SHEET_PATH := "res://assets/characters/world/battle_operator_purple.png"
const FRAME_WIDTH := 24
const FRAME_HEIGHT := 32
const FRAME_COLUMNS := 3
const FRAME_ROWS := 5

func _ready() -> void:
	_assert_character_sheet_padding(PLAYER_SHEET_PATH)
	_assert_character_sheet_padding(OPERATOR_SHEET_PATH)

	OverworldState.reset_active_party()
	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := hub.get_node_or_null("Actors/Player")
	var operator := hub.get_node_or_null("Actors/BattleOperator")
	var trainer := hub.get_node_or_null("Actors/TrainingSpecialist")
	var hospital_npc := hub.get_node_or_null("Actors/HospitalSpecialist")
	var portal := hub.get_node_or_null("Actors/TestBattlePortal")
	var dialog := hub.get_node_or_null("BattleOperatorUI/BattleDialog")
	var training_screen := hub.get_node_or_null("TrainingCenterUI/TrainingCenter")
	var hospital_screen := hub.get_node_or_null("HospitalUI/Hospital")
	var digilab := hub.get_node_or_null("DigiLabUI/DigiLab")
	var party_followers := hub.get_node_or_null("PartyFollowers")
	assert(player != null, "Hub must create the controllable player")
	assert(operator != null, "Hub must create the nearby battle operator")
	assert(trainer != null, "Hub must create the Training Specialist near the service terminals")
	assert(hospital_npc != null, "Hub must create the Digi Hospital specialist")
	assert(training_screen != null, "Hub must create the Training Center UI")
	assert(hospital_screen != null, "Hub must create the Digi Hospital UI")
	assert(digilab != null, "Hub must create the DigiLab root UI")
	assert(portal != null, "Hub must create the animated test battle portal")
	assert(dialog != null, "Hub must expose the Battle Operator service workspace")
	assert(party_followers != null, "Hub must create the overworld active-party follower system")
	var sprite_debug := hub.get_node_or_null("SpriteTestDebug")
	assert(sprite_debug != null, "Hub must create the temporary sprite-test controller")
	var sprite_lab := sprite_debug.get_node_or_null("SpriteTestDebugUI/DigimonSpriteTestLab")
	assert(sprite_lab != null, "Sprite-test controller must create the lab UI")
	assert(int(sprite_lab.call("get_testable_species_count")) >= 7, "Sprite test lab must discover packaged Digimon resources")
	assert(Array(sprite_lab.call("get_testable_species_names")).has("Metal Greymon"), "Sprite test lab must include Metal Greymon")
	sprite_lab.call("open_lab")
	await get_tree().process_frame
	await get_tree().process_frame
	var sprite_test_follower := sprite_lab.get("_follower") as Node2D
	assert(sprite_test_follower != null, "Sprite test lab must spawn the selected Digimon")
	var sprite_test_visual := sprite_test_follower.get_node_or_null("Sprite2D") as Sprite2D
	assert(sprite_test_visual != null and sprite_test_visual.texture != null, "Sprite test lab must render the selected field texture")
	sprite_lab.call("close_lab")
	assert(player.position.distance_to(operator.position) <= 94.0, "Operator must be reachable from spawn immediately")
	assert(bool(hub.call("can_actor_move_to", player.position, player)), "Spawn must be walkable")

	# Keep the pre-existing Hub baseline isolated from service regressions.
	# Service checks teleport the player on purpose; running them after follower
	# invariants prevents those tests from mutating trail state before baseline QA.
	_assert_authored_and_mirrored_rows(player)
	_assert_eight_direction_facing(player)
	_assert_walk_sequence(player)
	_assert_legacy_hub_facings(player)
	await _assert_overworld_active_party(player, party_followers)
	await _assert_training_center_entry(hub, player, trainer, training_screen)
	await _assert_digilab_root_entry(hub, player, digilab)
	await _assert_hospital_entry(hub, player, hospital_npc, hospital_screen)

	hub.call("open_test_battle_dialog")
	await _await_ui_transition()
	assert(dialog.visible, "Talking to the operator must open the battle prompt")
	assert(not bool(player.get("movement_enabled")), "Dialogue must pause player movement")
	assert(player.get("facing_direction") == "north", "Player must face north toward the operator in dialogue")
	assert(operator.get("facing_direction") == "south", "Operator must face south toward the player in dialogue")

	# Let the real Hub release scene-owned resources before terminating Godot.
	# Immediate quit after the success marker can otherwise report live resources
	# from deferred cleanup as a false regression failure.
	hub.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	print("hub foundation regression passed")
	get_tree().quit()

func _assert_training_center_entry(hub: Node, player: Node2D, trainer: Node2D, training_screen: Control) -> void:
	var original_position := player.position
	player.position = trainer.position
	await get_tree().process_frame
	assert(bool(hub.call("_trainer_has_interaction_priority")), "Training Specialist must win interaction priority when the player is closest to that NPC")
	hub.call("_open_training")
	await _await_ui_transition()
	assert(training_screen.visible, "Talking to the Training Specialist must open the Training Center")
	assert(not bool(player.get("movement_enabled")), "Training Center must pause overworld movement")
	var collection_list := training_screen.get("_collection_list") as Container
	assert(collection_list != null and collection_list.get_child_count() >= 3, "Training Center must load the persistent Digimon Collection")
	for child in collection_list.get_children():
		var card := child as Button
		assert(card != null and card.focus_mode == Control.FOCUS_ALL, "Training Digimon cards must be keyboard/gamepad focusable")
		assert(card.find_child("DigimonWalkPreview", true, false) != null or card.find_child("WalkPreview", true, false) != null, "Training selection cards must show a DS field preview")
	var training_pager := training_screen.get("_roster_pager") as DigiPager
	assert(training_pager != null, "Training roster must expose the shared workspace pager")
	assert(training_screen.find_children("*", "ScrollContainer", true, false).is_empty(), "Training workspace must be bounded and scroll-free")
	_assert_fullscreen_service_frame(training_screen.get("_frame") as Control, "Training Center")
	hub.call("_close_training")
	await _await_ui_transition()
	assert(not training_screen.visible, "Closing Training Center must return to the Hub")
	assert(bool(player.get("movement_enabled")), "Closing Training Center must restore overworld movement")
	player.position = original_position
	await get_tree().process_frame

func _assert_digilab_root_entry(hub: Node, player: Node2D, digilab: Control) -> void:
	var original_position := player.position
	var terminal := hub.get_node_or_null("Actors/DigiLabTerminal") as Node2D
	assert(terminal != null, "Hub must expose the DigiLab terminal actor")
	player.position = terminal.position
	await get_tree().process_frame
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.physical_keycode = KEY_E
	interact.pressed = true
	hub.call("_unhandled_input", interact)
	await _await_ui_transition()

	assert(digilab.visible, "Pressing E at the DigiLab terminal must open the DigiLab")
	var create_screen := digilab.get("_create_screen") as Control
	var party_screen := digilab.get("_party_screen") as Control
	assert(create_screen != null and create_screen.visible, "DigiLab must open directly on Convert Digi Data")
	assert(party_screen != null and not party_screen.visible, "Party / Storage must stay hidden until its tab is selected")

	var create_frame := create_screen.get("_frame") as Control
	var create_header := create_screen.get("_header") as Control
	var convert_tab := create_header.call("get_tab_button", "convert") as Button
	var party_tab := create_header.call("get_tab_button", "party") as Button
	var ascension_tab := create_header.call("get_tab_button", "ascension") as Button
	assert(create_frame != null and create_frame.visible, "Convert Digi Data must expose the V2 full-screen workspace")
	assert(convert_tab != null and party_tab != null and ascension_tab != null, "DigiLab must expose all three primary workspaces")
	assert(convert_tab.focus_mode == Control.FOCUS_NONE and party_tab.focus_mode == Control.FOCUS_NONE and ascension_tab.focus_mode == Control.FOCUS_NONE, "DigiLab workspace tabs must stay out of D-pad focus navigation")
	var create_list_scroll := create_screen.get("_list_scroll") as ScrollContainer
	var create_detail_scroll := create_screen.get("_detail_scroll") as ScrollContainer
	assert(create_list_scroll != null and create_list_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Digi Data Archive must use explicit pages instead of scrolling")
	assert(create_detail_scroll != null and create_detail_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Digi Data details must remain bounded without scrolling")
	assert(create_screen.get("_roster_pager") is DigiPager, "Digi Data Archive must expose the shared pager")
	_assert_fullscreen_service_frame(create_frame, "Convert Digi Data")

	digilab.call("_switch_tab", "party")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not create_screen.visible and party_screen.visible, "Selecting Party / Storage must switch workspaces without returning to a service-card menu")
	var party_frame := party_screen.get("_frame") as Control
	var party_header := party_screen.get("_header") as Control
	assert(party_header.call("get_tab_button", "convert") != null and party_header.call("get_tab_button", "party") != null and party_header.call("get_tab_button", "ascension") != null, "Party / Storage must retain all three primary DigiLab tabs")
	var party_list_scroll := party_screen.get("_list_scroll") as ScrollContainer
	var party_detail_scroll := party_screen.get("_detail_scroll") as ScrollContainer
	assert(party_list_scroll != null and party_list_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Party collection must use explicit pages instead of scrolling")
	assert(party_detail_scroll != null and party_detail_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Party details must remain bounded without scrolling")
	assert(party_screen.get("_workspace_pager") is DigiPager, "Party / Storage must expose the shared pager")
	_assert_fullscreen_service_frame(party_frame, "Party / Storage")

	hub.call("_close_digilab")
	await _await_ui_transition()
	assert(not digilab.visible, "Closing DigiLab must return to the Hub")
	assert(bool(player.get("movement_enabled")), "Closing DigiLab must restore overworld movement")
	player.position = original_position
	await get_tree().process_frame

func _assert_hospital_entry(hub: Node, player: Node2D, hospital_npc: Node2D, hospital_screen: Control) -> void:
	var original_position := player.position
	player.position = hospital_npc.position
	await get_tree().process_frame
	assert(bool(hub.call("_hospital_has_interaction_priority")), "Digi Hospital must win interaction priority when its specialist is closest")

	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.physical_keycode = KEY_E
	interact.pressed = true
	hub.call("_unhandled_input", interact)
	await _await_ui_transition()

	assert(hospital_screen.visible, "Pressing E at the Hospital specialist must open the Hospital")
	assert(not bool(player.get("movement_enabled")), "Hospital must pause overworld movement")
	assert(hospital_screen.get("_header") is Panel, "Hospital must show its full-width treatment header")
	assert(hospital_screen.get("_confirmation") is DigiConfirmationModal, "Hospital treatments must use the shared safe-default confirmation modal")
	var tabs := hospital_screen.get("_tab_buttons") as Dictionary
	assert(tabs.has("party") and tabs.has("hospital"), "Hospital must expose Party and Hospital tabs")
	var patient_buttons := hospital_screen.get("_cards") as Dictionary
	assert(patient_buttons.size() == mini(3, OverworldState.get_squad_instances().size()), "Squad tab must show one three-card page without scrolling")
	for storage: DigimonInstance in OverworldState.get_storage_instances():
		assert(not patient_buttons.has(storage.id), "Storage Digimon must not appear as Hospital treatment candidates")
	hospital_screen.call("_switch_tab", "hospital")
	patient_buttons = hospital_screen.get("_cards") as Dictionary
	assert(patient_buttons.size() == mini(3, OverworldState.get_hospital_instances().size()), "Hospital tab must page admitted patients without scrolling")
	_assert_fullscreen_service_frame(hospital_screen.get("_canvas") as Control, "Digi Hospital")

	hub.call("_close_hospital")
	await _await_ui_transition()
	assert(not hospital_screen.visible, "Closing Hospital must return to the Hub")
	assert(bool(player.get("movement_enabled")), "Closing Hospital must restore overworld movement")
	player.position = original_position
	await get_tree().process_frame

func _await_ui_transition(max_frames: int = 90) -> void:
	for _frame in range(max_frames):
		if not DigiUiTransitionDirector.is_transitioning():
			return
		await get_tree().process_frame
	assert(not DigiUiTransitionDirector.is_transitioning(), "UI transition must settle within the regression frame budget")


func _assert_fullscreen_service_frame(frame: Control, label: String) -> void:
	assert(frame != null, "%s must expose its V2 workspace frame" % label)
	var viewport_size := get_viewport().get_visible_rect().size
	var effective_size := frame.size * frame.scale
	assert(frame.position.x <= 1.0 and frame.position.y <= 1.0, "%s must align to the viewport origin" % label)
	assert(effective_size.x >= viewport_size.x - 2.0, "%s must use the available viewport width" % label)
	assert(effective_size.y >= viewport_size.y - 2.0, "%s must use the available viewport height" % label)

func _assert_safe_service_frame(frame: Control, label: String) -> void:
	assert(frame != null, "%s must expose a framed modal" % label)
	var viewport_size := get_viewport().get_visible_rect().size
	var effective_size := frame.size * frame.scale
	assert(frame.position.x >= 10.0 and frame.position.y >= 10.0, "%s must keep a visible safe margin from the top/left edges" % label)
	assert(frame.position.x + effective_size.x <= viewport_size.x - 10.0, "%s must stay inside the right safe margin" % label)
	assert(frame.position.y + effective_size.y <= viewport_size.y - 10.0, "%s must stay inside the bottom safe margin" % label)

func _assert_character_sheet_padding(path: String) -> void:
	var image := Image.load_from_file(path)
	assert(image.get_width() == FRAME_WIDTH * FRAME_COLUMNS, "%s must be a 3-column 24px atlas" % path)
	assert(image.get_height() == FRAME_HEIGHT * FRAME_ROWS, "%s must be a 5-row 32px atlas" % path)

	for frame_row in range(FRAME_ROWS):
		for frame_column in range(FRAME_COLUMNS):
			var frame_x := frame_column * FRAME_WIDTH
			var frame_y := frame_row * FRAME_HEIGHT
			var opaque_pixels := 0
			for local_y in range(FRAME_HEIGHT):
				assert(
					image.get_pixel(frame_x, frame_y + local_y).a == 0.0,
					"%s frame (%d,%d) leaks into its left gutter" % [path, frame_column, frame_row]
				)
				assert(
					image.get_pixel(frame_x + FRAME_WIDTH - 1, frame_y + local_y).a == 0.0,
					"%s frame (%d,%d) leaks into its right gutter" % [path, frame_column, frame_row]
				)
			for local_y in range(FRAME_HEIGHT):
				for local_x in range(FRAME_WIDTH):
					if image.get_pixel(frame_x + local_x, frame_y + local_y).a > 0.0:
						opaque_pixels += 1
			assert(opaque_pixels > 150, "%s frame (%d,%d) must contain a complete pose" % [path, frame_column, frame_row])

func _assert_authored_and_mirrored_rows(player: Node) -> void:
	var sprite := player.get_node("CharacterSprite") as Sprite2D
	var cases := [
		["south", 0, false],
		["southwest", 3, false],
		["west", 6, false],
		["northwest", 9, false],
		["north", 12, false],
		["northeast", 9, true],
		["east", 6, true],
		["southeast", 3, true],
	]
	for test_case in cases:
		player.call("set_facing", String(test_case[0]))
		assert(sprite.frame == int(test_case[1]), "%s must start on frame %d" % [test_case[0], test_case[1]])
		assert(sprite.flip_h == bool(test_case[2]), "%s horizontal mirror state is wrong" % test_case[0])

func _assert_eight_direction_facing(player: Node) -> void:
	var cases := [
		[Vector2.DOWN, "south"],
		[Vector2(-1.0, 1.0).normalized(), "southwest"],
		[Vector2.LEFT, "west"],
		[Vector2(-1.0, -1.0).normalized(), "northwest"],
		[Vector2.UP, "north"],
		[Vector2(1.0, -1.0).normalized(), "northeast"],
		[Vector2.RIGHT, "east"],
		[Vector2(1.0, 1.0).normalized(), "southeast"],
	]
	for test_case in cases:
		player.call("set_facing", "south")
		player.call("_face_direction", Vector2(test_case[0]))
		assert(
			player.get("facing_direction") == String(test_case[1]),
			"Movement %s must select %s" % [test_case[0], test_case[1]]
		)

func _assert_walk_sequence(player: Node) -> void:
	var sprite := player.get_node("CharacterSprite") as Sprite2D
	player.call("set_facing", "east")
	assert(sprite.frame == 6 and sprite.flip_h, "East idle must mirror authored west frame 6")
	player.call("_advance_walk_animation", 0.11)
	assert(sprite.frame == 7 and sprite.flip_h, "East first walk step must mirror frame 7")
	player.call("_advance_walk_animation", 0.10)
	assert(sprite.frame == 6 and sprite.flip_h, "East walk midpoint must return to frame 6")
	player.call("_advance_walk_animation", 0.10)
	assert(sprite.frame == 8 and sprite.flip_h, "East opposite walk step must mirror frame 8")

func _assert_legacy_hub_facings(player: Node) -> void:
	player.call("set_facing", "down_left")
	assert(player.get("facing_direction") == "south", "Legacy down_left must preserve the hub's south-facing pose")
	player.call("set_facing", "up_right")
	assert(player.get("facing_direction") == "north", "Legacy up_right must preserve the hub's north-facing pose")

func _assert_overworld_active_party(player: Node2D, party_followers: Node) -> void:
	var default_party := ["botamon", "agumon", "gabumon"]
	assert(OverworldState.get_active_party() == default_party, "Default overworld party must be Botamon, Agumon and Gabumon")
	assert(OverworldState.get_max_active_party_size() == 3, "Active overworld formation must be capped at three Digimon")
	assert(OverworldState.get_max_reserve_party_size() == 3, "Reserve must provide three bench slots")
	assert(OverworldState.get_max_squad_size() == 6, "The complete Squad must support six Digimon")
	assert(int(party_followers.call("get_follower_count")) == 3, "Default active party must render three followers")
	assert(Array(party_followers.call("get_active_party_keys")) == default_party, "Follower order must match active-party order")

	var followers_root := party_followers.get_node_or_null("Followers")
	assert(followers_root != null, "Follower system must expose a stable Followers container")
	var follower_nodes := followers_root.get_children()
	assert(follower_nodes.size() == 3, "Exactly the three active Digimon must exist in the hub")
	var minimum_separation := float(party_followers.call("get_minimum_team_separation"))
	var occupied: Array[Vector2] = [player.global_position]
	for follower in follower_nodes:
		var follower_node := follower as Node2D
		assert(follower_node != null, "Every active-party follower must be a Node2D")
		var hub := party_followers.get_parent()
		assert(hub != null and bool(hub.call("can_actor_move_to", follower_node.global_position, player)), "Followers must never spawn outside walkable hub space")
		for point in occupied:
			assert(
				follower_node.global_position.distance_to(point) >= minimum_separation,
				"Party followers must spawn without overlapping the player or each other"
			)
		occupied.append(follower_node.global_position)

	var reserve_fixture := OverworldState.get_instance_for_party_key("gabumon")
	assert(reserve_fixture != null and OverworldState.add_to_reserve_party(reserve_fixture.id), "An Active Digimon must be assignable to Reserve")
	await get_tree().process_frame
	assert(OverworldState.get_active_instances().size() == 2 and OverworldState.get_reserve_party_instances().size() == 1, "Reserve assignment must preserve 3+3 Squad roles")
	assert(int(party_followers.call("get_follower_count")) == 2, "Reserve Digimon must never render as overworld followers")
	assert(OverworldState.set_active_party(default_party), "Reserve fixture must restore the authored Active order")
	await get_tree().process_frame
	assert(OverworldState.get_active_party() == default_party, "Restoring the fixture must recover the original logical Active order")
	assert(OverworldState.get_reserve_party_instances().is_empty(), "Restoring the fixture must clear its temporary Reserve assignment")
	assert(int(party_followers.call("get_follower_count")) == 3, "Returning Reserve to Active must restore its follower")

	var middle_instance := OverworldState.get_instance_for_party_key("agumon")
	assert(middle_instance != null, "Follower compaction regression requires the middle Party member")
	var middle_hp := middle_instance.current_hp
	middle_instance.current_hp = 0
	OverworldState.notify_collection_changed()
	await get_tree().process_frame
	assert(OverworldState.get_active_party() == default_party, "Fainting must not reorder or remove the logical Party member")
	assert(int(party_followers.call("get_follower_count")) == 2, "Fainted Digimon must disappear from the overworld formation")
	assert(Array(party_followers.call("get_active_party_keys")) == ["botamon", "gabumon"], "Visible followers must preserve relative Party order without a gap")
	var compact_followers := followers_root.get_children()
	assert(compact_followers.size() == 2, "Only battle-ready followers may have overworld nodes")
	assert(int(compact_followers[0].get("slot_index")) == 0 and int(compact_followers[1].get("slot_index")) == 1, "Visible followers must receive contiguous visual slots")
	middle_instance.current_hp = middle_hp
	OverworldState.notify_collection_changed()
	await get_tree().process_frame
	assert(Array(party_followers.call("get_active_party_keys")) == default_party, "Recovered followers must return in the original logical Party order")
	var restored_followers := followers_root.get_children()
	assert(restored_followers.size() == 3 and int(restored_followers[2].get("slot_index")) == 2, "Recovery must rebuild the original compact formation")

	assert(OverworldState.set_active_party(["agumon"]), "A one-Digimon active party must be valid")
	await get_tree().process_frame
	assert(int(party_followers.call("get_follower_count")) == 1, "One-Digimon parties must render exactly one follower")

	assert(OverworldState.set_active_party(["agumon", "gabumon"]), "A two-Digimon active party must be valid")
	await get_tree().process_frame
	assert(int(party_followers.call("get_follower_count")) == 2, "Two-Digimon parties must render exactly two followers")

	var two_member_party := OverworldState.get_active_party()
	assert(not OverworldState.set_active_party([]), "An empty active party must be rejected by ordinary party editing")
	assert(OverworldState.get_active_party() == two_member_party, "Rejected party changes must leave state untouched")
	assert(not OverworldState.set_active_party(["missing_digimon"]), "Active party must reject Digimon without a runtime resource")

	OverworldState.reset_active_party()
	await get_tree().process_frame
	assert(int(party_followers.call("get_follower_count")) == 3, "Resetting state must restore all three starter followers")
