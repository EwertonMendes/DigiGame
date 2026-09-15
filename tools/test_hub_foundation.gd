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

	# Let the real Hub release scene-owned resources before terminating Godot.
	hub.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# The Hub deliberately starts persistent world music through an autoload. In a
	# real application that resource lives across scene changes and is released at
	# application shutdown; this isolated regression quits immediately after the
	# Hub fixture is freed. Queue the autoload itself before quit so its existing
	# _exit_tree cleanup runs deterministically and the engine leak check measures
	# scene/test leaks rather than an intentionally persistent music service.
	if is_instance_valid(MusicDirector):
		MusicDirector.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame

	print("hub foundation regression passed")
	get_tree().quit()


func _assert_authored_and_mirrored_rows(player: Node) -> void:
	var directions := ["south", "south_west", "west", "north_west", "north"]
	for direction in directions:
		var frames: Array[int] = player.call("get_authored_frame_sequence", direction)
		assert(frames.size() == 3, "%s must expose three authored source frames" % direction)
		var row := int(player.call("get_authored_row_for_direction", direction))
		assert(row >= 0 and row < FRAME_ROWS, "%s must resolve to an authored spritesheet row" % direction)
		for frame in frames:
			assert(frame >= 0 and frame < FRAME_COLUMNS * FRAME_ROWS, "%s frame %d must stay inside the 3x5 spritesheet" % [direction, frame])
			assert(int(floor(float(frame) / float(FRAME_COLUMNS))) == row, "%s frame %d must stay on row %d" % [direction, frame, row])
		assert(not bool(player.call("is_mirrored_direction", direction)), "%s must use authored pixels directly" % direction)

	assert(bool(player.call("is_mirrored_direction", "east")), "east must mirror the authored west row")
	assert(bool(player.call("is_mirrored_direction", "south_east")), "south_east must mirror south_west")
	assert(bool(player.call("is_mirrored_direction", "north_east")), "north_east must mirror north_west")
	assert(player.call("get_authored_frame_sequence", "east") == player.call("get_authored_frame_sequence", "west"), "east must reuse west authored frames")
	assert(player.call("get_authored_frame_sequence", "south_east") == player.call("get_authored_frame_sequence", "south_west"), "south_east must reuse south_west authored frames")
	assert(player.call("get_authored_frame_sequence", "north_east") == player.call("get_authored_frame_sequence", "north_west"), "north_east must reuse north_west authored frames")


func _assert_eight_direction_facing(player: Node) -> void:
	var cases := [
		{"direction": "south", "input": Vector2(0.0, 1.0)},
		{"direction": "south_west", "input": Vector2(-1.0, 1.0).normalized()},
		{"direction": "west", "input": Vector2(-1.0, 0.0)},
		{"direction": "north_west", "input": Vector2(-1.0, -1.0).normalized()},
		{"direction": "north", "input": Vector2(0.0, -1.0)},
		{"direction": "north_east", "input": Vector2(1.0, -1.0).normalized()},
		{"direction": "east", "input": Vector2(1.0, 0.0)},
		{"direction": "south_east", "input": Vector2(1.0, 1.0).normalized()},
	]
	for case in cases:
		player.call("update_visual_from_input", case["input"], true)
		assert(player.get("facing_direction") == case["direction"], "input %s must resolve to %s" % [case["input"], case["direction"]])
		var expected_flip := bool(player.call("is_mirrored_direction", case["direction"]))
		assert(bool(player.call("is_sprite_flipped")) == expected_flip, "%s flip state must match authored/mirrored contract" % case["direction"])


func _assert_walk_sequence(player: Node) -> void:
	for direction in ["south", "west", "north", "east", "south_east"]:
		var expected: Array[int] = player.call("get_authored_frame_sequence", direction)
		player.call("update_visual_from_input", player.call("get_direction_vector", direction), true)
		var observed: Array[int] = []
		for step in range(3):
			player.call("set_walk_frame_for_test", step)
			observed.append(int(player.call("get_current_frame")))
		assert(observed == expected, "%s walk cycle must follow the authored source order" % direction)


func _assert_legacy_hub_facings(player: Node) -> void:
	player.call("face_towards", Vector2(0.0, -1.0))
	assert(player.get("facing_direction") == "north", "north-facing scripted interactions must remain north")
	player.call("face_towards", Vector2(-1.0, 0.0))
	assert(player.get("facing_direction") == "west", "west-facing scripted interactions must remain west")
	player.call("face_towards", Vector2(1.0, 0.0))
	assert(player.get("facing_direction") == "east", "east-facing scripted interactions must remain east")
	player.call("face_towards", Vector2(0.0, 1.0))
	assert(player.get("facing_direction") == "south", "south-facing scripted interactions must remain south")


func _assert_character_sheet_padding(sheet_path: String) -> void:
	var image := Image.load_from_file(sheet_path)
	assert(image != null and not image.is_empty(), "Character sheet must be readable: %s" % sheet_path)
	assert(image.get_width() == FRAME_COLUMNS * FRAME_WIDTH, "Character sheet must keep three 24px columns")
	assert(image.get_height() == FRAME_ROWS * FRAME_HEIGHT, "Character sheet must keep five 32px rows")
	for row in range(FRAME_ROWS):
		for column in range(FRAME_COLUMNS):
			var frame := Rect2i(column * FRAME_WIDTH, row * FRAME_HEIGHT, FRAME_WIDTH, FRAME_HEIGHT)
			var alpha_bounds := _alpha_bounds(image, frame)
			assert(alpha_bounds.size.x > 0 and alpha_bounds.size.y > 0, "Every character frame must contain visible pixels")
			assert(alpha_bounds.position.x >= 1 and alpha_bounds.end.x <= FRAME_WIDTH - 1, "Character frame must preserve horizontal padding")
			assert(alpha_bounds.position.y >= 1 and alpha_bounds.end.y <= FRAME_HEIGHT - 1, "Character frame must preserve vertical padding")


func _alpha_bounds(image: Image, frame: Rect2i) -> Rect2i:
	var min_x := FRAME_WIDTH
	var min_y := FRAME_HEIGHT
	var max_x := -1
	var max_y := -1
	for local_y in range(FRAME_HEIGHT):
		for local_x in range(FRAME_WIDTH):
			var pixel := image.get_pixel(frame.position.x + local_x, frame.position.y + local_y)
			if pixel.a <= 0.01:
				continue
			min_x = mini(min_x, local_x)
			min_y = mini(min_y, local_y)
			max_x = maxi(max_x, local_x)
			max_y = maxi(max_y, local_y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _assert_training_center_entry(hub: Node, player: Node, trainer: Node, training_screen: Control) -> void:
	assert(trainer != null, "Training Specialist must exist")
	assert(training_screen != null, "Training Center screen must exist")
	player.position = trainer.position + Vector2(0.0, 40.0)
	assert(bool(hub.call("can_interact_with", trainer)), "Training Specialist must be interactable from the service counter")
	hub.call("interact_with_actor", trainer)
	await get_tree().process_frame
	assert(training_screen.visible, "Training Specialist must open the Training Center screen")
	assert(not bool(player.get("movement_enabled")), "Training Center must pause Hub movement while open")
	hub.call("close_training_center")
	await get_tree().process_frame
	assert(not training_screen.visible, "Closing Training Center must hide the service screen")
	assert(bool(player.get("movement_enabled")), "Closing Training Center must restore Hub movement")


func _assert_digilab_root_entry(hub: Node, player: Node, digilab: Control) -> void:
	assert(digilab != null, "DigiLab root UI must exist")
	var lab_anchor := hub.get_node_or_null("Actors/BattleOperator") as Node2D
	assert(lab_anchor != null, "Hub needs an authored interaction anchor near the service terminals")
	player.position = lab_anchor.position + Vector2(20.0, 0.0)
	hub.call("open_digilab")
	await get_tree().process_frame
	assert(digilab.visible, "Opening DigiLab must reveal the root DigiLab screen")
	assert(not bool(player.get("movement_enabled")), "DigiLab must pause Hub movement while open")
	hub.call("close_digilab")
	await get_tree().process_frame
	assert(not digilab.visible, "Closing DigiLab must hide the root screen")
	assert(bool(player.get("movement_enabled")), "Closing DigiLab must restore Hub movement")


func _assert_overworld_active_party(player: Node, party_followers: Node) -> void:
	assert(party_followers != null, "Hub must expose PartyFollowers")
	OverworldState.reset_active_party()
	await get_tree().process_frame
	await get_tree().process_frame

	var active_party := OverworldState.get_active_party()
	assert(active_party == ["agumon", "gabumon", "greymon"], "Default overworld party must contain the three starter Digimon")
	assert(int(party_followers.call("get_follower_count")) == 3, "Hub must spawn one follower per active-party member")

	var occupied: Array[Vector2] = [player.global_position]
	var minimum_separation := 10.0
	for follower in party_followers.call("get_followers"):
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