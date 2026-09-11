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
	var portal := hub.get_node_or_null("Actors/TestBattlePortal")
	var dialog := hub.get_node_or_null("HubUI/Root/BattleDialog")
	var party_followers := hub.get_node_or_null("PartyFollowers")
	assert(player != null, "Hub must create the controllable player")
	assert(operator != null, "Hub must create the nearby battle operator")
	assert(portal != null, "Hub must create the animated test battle portal")
	assert(dialog != null, "Hub must expose the test battle conversation")
	assert(party_followers != null, "Hub must create the overworld active-party follower system")
	assert(player.position.distance_to(operator.position) <= 94.0, "Operator must be reachable from spawn immediately")
	assert(bool(hub.call("can_actor_move_to", player.position, player)), "Spawn must be walkable")

	_assert_authored_and_mirrored_rows(player)
	_assert_eight_direction_facing(player)
	_assert_walk_sequence(player)
	_assert_legacy_hub_facings(player)
	await _assert_overworld_active_party(player, party_followers)

	hub.call("open_test_battle_dialog")
	await get_tree().process_frame
	assert(dialog.visible, "Talking to the operator must open the battle prompt")
	assert(not bool(player.get("movement_enabled")), "Dialogue must pause player movement")
	assert(player.get("facing_direction") == "north", "Player must face north toward the operator in dialogue")
	assert(operator.get("facing_direction") == "south", "Operator must face south toward the player in dialogue")

	print("hub foundation regression passed")
	get_tree().quit()


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
