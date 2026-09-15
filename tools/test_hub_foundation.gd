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
	var portal := hub.get_node_or_null("Actors/TestBattlePortal")
	var dialog := hub.get_node_or_null("HubUI/Root/BattleDialog")
	var training_screen := hub.get_node_or_null("TrainingCenterUI/TrainingCenter")
	var digilab := hub.get_node_or_null("DigiLabUI/DigiLab")
	var party_followers := hub.get_node_or_null("PartyFollowers")
	assert(player != null, "Hub must create the controllable player")
	assert(operator != null, "Hub must create the nearby battle operator")
	assert(trainer != null, "Hub must create the Training Specialist near the service terminals")
	assert(training_screen != null, "Hub must create the Training Center UI")
	assert(digilab != null, "Hub must create the DigiLab root UI")
	assert(portal != null, "Hub must create the animated test battle portal")
	assert(dialog != null, "Hub must expose the test battle conversation")
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

	hub.call("open_test_battle_dialog")
	await get_tree().process_frame
	assert(dialog.visible, "Talking to the operator must open the battle prompt")
	assert(not bool(player.get("movement_enabled")), "Dialogue must pause player movement")
	assert(player.get("facing_direction") == "north", "Player must face north toward the operator in dialogue")
	assert(operator.get("facing_direction") == "south", "Operator must face south toward the player in dialogue")

	# Exercise a real teardown rather than relying on SceneTree shutdown to dispose
	# the Hub. This keeps the regression sensitive to genuine leaks while avoiding
	# false failures from resources that are still legitimately owned by the scene.
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
	await get_tree().process_frame
	await get_tree().process_frame
	assert(training_screen.visible, "Talking to the Training Specialist must open the Training Center")
	assert(not bool(player.get("movement_enabled")), "Training Center must pause overworld movement")
	var collection_list := training_screen.get("_collection_list") as Container
	assert(collection_list != null and collection_list.get_child_count() >= 3, "Training Center must load the persistent Digimon Collection")
	for child in collection_list.get_children():
		var card := child as Button
		assert(card != null and card.focus_mode == Control.FOCUS_ALL, "Training Digimon cards must be keyboard/gamepad focusable")
		assert(card.find_child("DigimonWalkPreview", true, false) != null or card.find_child("WalkPreview", true, false) != null, "Training selection cards must show a DS field preview")
	var detail_scroll := training_screen.get("_detail_scroll") as ScrollContainer
	assert(detail_scroll != null and detail_scroll.get_node_or_null("SmoothScrollBehavior") != null, "Training details must use smooth scrolling")
	_assert_safe_service_frame(training_screen.get("_frame") as Control, "Training Center")
	hub.call("_close_training")
	await get_tree().process_frame
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
	await get_tree().process_frame
	await get_tree().process_frame

	assert(digilab.visible, "Pressing E at the DigiLab terminal must open the DigiLab")
	var root_frame := digilab.get("_frame") as Control
	var create_screen := digilab.get("_create_screen") as Control
	var party_screen := digilab.get("_party_screen") as Control
	var digimon_screen := digilab.get("_digimon_menu") as Control
	var ascension_screen := digilab.get("_ascension_screen") as Control
	assert(root_frame != null and root_frame.visible, "DigiLab must open on its root service menu")
	assert(create_screen != null and not create_screen.visible, "Convert Digi Data must stay hidden until explicitly selected")
	assert(party_screen != null and not party_screen.visible, "Party / Storage must stay hidden until explicitly selected")
	assert(digimon_screen != null and not digimon_screen.visible, "Digimon details must not open automatically with DigiLab")
	assert(ascension_screen != null and not ascension_screen.visible, "Ascension / Expansion must stay hidden until explicitly selected")
	var service_buttons: Array = digilab.get("_service_buttons")
	assert(service_buttons.size() == 4, "DigiLab root must expose Digimon, Ascension / Expansion, Convert Digi Data and Party / Storage")
	for raw_button in service_buttons:
		var service_button := raw_button as Button
		assert(service_button != null and service_button.focus_mode == Control.FOCUS_ALL, "The whole DigiLab service card must be selectable with keyboard/gamepad")
		assert(service_button.text.is_empty(), "DigiLab service cards must not depend on a separate OPEN button")
	_assert_safe_service_frame(root_frame, "DigiLab")

	hub.call("_close_digilab")
	await get_tree().process_frame
	assert(not digilab.visible, "Closing the root DigiLab must return to the Hub")
	assert(bool(player.get("movement_enabled")), "Closing DigiLab must restore overworld movement")
	player.position = original_position
	await get_tree().process_frame

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
	var default_party := ["agumon", "gabumon", "greymon"]
	assert(OverworldState.get_active_party() == default_party, "Default overworld party must be Agumon, Gabumon and Greymon")
	assert(OverworldState.get_max_active_party_size() == 3, "Active overworld party must cap at three Digimon")
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
		for point in occupied:
			assert(
				follower_node.global_position.distance_to(point) >= minimum_separation,
				"Party followers must spawn without overlapping the player or each other"
			)
		occupied.append(follower_node.global_position)

	assert(OverworldState.set_active_party(["agumon"]), "A one-Digimon active party must be valid")
	await get_tree().process_frame
	assert(int(party_followers.call("get_follower_count")) == 1, "One-Digimon parties must render exactly one follower")

	assert(OverworldState.set_active_party(["agumon", "gabumon"]), "A two-Digimon active party must be valid")
	await get_tree().process_frame
	assert(int(party_followers.call("get_follower_count")) == 2, "Two-Digimon parties must render exactly two followers")

	var two_member_party := OverworldState.get_active_party()
	assert(not OverworldState.set_active_party([]), "An empty active party must be rejected")
	assert(OverworldState.get_active_party() == two_member_party, "Rejected party changes must leave state untouched")
	assert(not OverworldState.set_active_party(["agumon", "gabumon", "greymon", "veemon"]), "Active party must reject more than three Digimon")
	assert(not OverworldState.set_active_party(["missing_digimon"]), "Active party must reject Digimon without a runtime resource")

	OverworldState.reset_active_party()
	await get_tree().process_frame
	assert(int(party_followers.call("get_follower_count")) == 3, "Resetting state must restore all three starter followers")
