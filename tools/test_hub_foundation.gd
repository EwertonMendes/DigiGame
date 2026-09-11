extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")
const PLAYER_SHEET_PATH := "res://assets/characters/world/player_blond.png"
const OPERATOR_SHEET_PATH := "res://assets/characters/world/battle_operator_purple.png"
const FRAME_WIDTH := 24
const FRAME_HEIGHT := 32
const FRAME_COLUMNS := 3
const FRAME_ROWS := 4


func _ready() -> void:
	_assert_character_sheet_padding(PLAYER_SHEET_PATH)
	_assert_character_sheet_padding(OPERATOR_SHEET_PATH)

	var hub := HUB_SCENE.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := hub.get_node_or_null("Actors/Player")
	var operator := hub.get_node_or_null("Actors/BattleOperator")
	var portal := hub.get_node_or_null("Actors/TestBattlePortal")
	var dialog := hub.get_node_or_null("HubUI/Root/BattleDialog")
	assert(player != null, "Hub must create the controllable player")
	assert(operator != null, "Hub must create the nearby battle operator")
	assert(portal != null, "Hub must create the animated test battle portal")
	assert(dialog != null, "Hub must expose the test battle conversation")
	assert(player.position.distance_to(operator.position) <= 94.0, "Operator must be reachable from spawn immediately")
	assert(bool(hub.call("can_actor_move_to", player.position, player)), "Spawn must be walkable")

	_assert_directional_frames(player)
	_assert_screen_direction_facing(player)
	_assert_walk_sequence(player)

	hub.call("open_test_battle_dialog")
	await get_tree().process_frame
	assert(dialog.visible, "Talking to the operator must open the battle prompt")
	assert(not bool(player.get("movement_enabled")), "Dialogue must pause player movement")
	assert(player.get("facing_direction") == "up", "Player must face up toward the operator in dialogue")
	assert(operator.get("facing_direction") == "down", "Operator must face down toward the player in dialogue")

	print("hub foundation regression passed")
	get_tree().quit()


func _assert_character_sheet_padding(path: String) -> void:
	var image := Image.load_from_file(path)
	assert(image.get_width() == FRAME_WIDTH * FRAME_COLUMNS, "%s must be a 3-column 24px atlas" % path)
	assert(image.get_height() == FRAME_HEIGHT * FRAME_ROWS, "%s must be a 4-row 32px atlas" % path)

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


func _assert_directional_frames(player: Node) -> void:
	var sprite := player.get_node("CharacterSprite") as Sprite2D
	var expected_idle_frames := {
		"down": 0,
		"left": 3,
		"right": 6,
		"up": 9,
	}
	for direction_name in expected_idle_frames:
		player.call("set_facing", String(direction_name))
		assert(
			sprite.frame == int(expected_idle_frames[direction_name]),
			"%s must use atlas row starting at frame %d, got %d" % [direction_name, expected_idle_frames[direction_name], sprite.frame]
		)

	var legacy_expected := {
		"down_left": "down",
		"down_right": "left",
		"up_left": "right",
		"up_right": "up",
	}
	for legacy_name in legacy_expected:
		player.call("set_facing", String(legacy_name))
		assert(player.get("facing_direction") == legacy_expected[legacy_name], "%s alias mapped to the wrong sprite row" % legacy_name)


func _assert_screen_direction_facing(player: Node) -> void:
	var cases := [
		[Vector2.RIGHT, "right"],
		[Vector2.LEFT, "left"],
		[Vector2.UP, "up"],
		[Vector2.DOWN, "down"],
	]
	for test_case in cases:
		player.call("set_facing", "down")
		player.call("_face_direction", Vector2(test_case[0]))
		assert(
			player.get("facing_direction") == String(test_case[1]),
			"Movement %s must show the %s-facing sprite" % [test_case[0], test_case[1]]
		)

	player.call("set_facing", "up")
	player.call("_face_direction", Vector2(1.0, -1.0).normalized())
	assert(player.get("facing_direction") == "up", "Up-right diagonal must retain a compatible up-facing pose")
	player.call("set_facing", "left")
	player.call("_face_direction", Vector2(-1.0, 1.0).normalized())
	assert(player.get("facing_direction") == "left", "Down-left diagonal must retain a compatible left-facing pose")


func _assert_walk_sequence(player: Node) -> void:
	var sprite := player.get_node("CharacterSprite") as Sprite2D
	player.call("set_facing", "right")
	assert(sprite.frame == 6, "Right idle must start on frame 6")
	player.call("_advance_walk_animation", 0.11)
	assert(sprite.frame == 7, "Right walk first step must use frame 7")
	player.call("_advance_walk_animation", 0.10)
	assert(sprite.frame == 6, "Right walk midpoint must return to frame 6")
	player.call("_advance_walk_animation", 0.10)
	assert(sprite.frame == 8, "Right walk opposite step must use frame 8")
