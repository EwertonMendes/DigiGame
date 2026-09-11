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

	_assert_isometric_facing(player)

	hub.call("open_test_battle_dialog")
	await get_tree().process_frame
	assert(dialog.visible, "Talking to the operator must open the battle prompt")
	assert(not bool(player.get("movement_enabled")), "Dialogue must pause player movement")

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


func _assert_isometric_facing(player: Node) -> void:
	player.call("set_facing", "down_right")
	player.call("_face_direction", Vector2.UP)
	assert(player.get("facing_direction") == "up_right", "Moving up must keep the current right-side orientation")

	player.call("_face_direction", Vector2.LEFT)
	assert(player.get("facing_direction") == "up_left", "Moving left must turn to the matching upper-left pose")

	player.call("_face_direction", Vector2.DOWN)
	assert(player.get("facing_direction") == "down_left", "Moving down must keep the current left-side orientation")

	player.call("_face_direction", Vector2.RIGHT)
	assert(player.get("facing_direction") == "down_right", "Moving right must turn to the matching lower-right pose")
