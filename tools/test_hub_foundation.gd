extends Node

const HUB_SCENE = preload("res://scenes/world/hub.tscn")


func _ready() -> void:
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

	hub.call("open_test_battle_dialog")
	await get_tree().process_frame
	assert(dialog.visible, "Talking to the operator must open the battle prompt")
	assert(not bool(player.get("movement_enabled")), "Dialogue must pause player movement")

	print("hub foundation regression passed")
	get_tree().quit()
