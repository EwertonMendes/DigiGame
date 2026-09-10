extends SceneTree

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("could not load main scene")
		return

	var main: Node = packed.instantiate()
	# Headless Control widgets exercise renderer-specific properties that are
	# already covered by the browser smoke. This probe measures battle FX only.
	for ui_path in ["DigimonInfoUI", "BattleUI", "DebugUI"]:
		var ui_node: Node = main.get_node_or_null(ui_path)
		if ui_node != null:
			ui_node.free()
	root.add_child(main)
	await process_frame
	await process_frame

	var battle: Node = main.get_node_or_null("BattleController")
	var controller: Node = main.get_node_or_null("DigimonController")
	var presentation: Node = main.get_node_or_null("BattlePresentationFX")
	if battle == null or controller == null or presentation == null:
		_fail("main combat nodes are missing")
		return

	battle.set("_battle_over", true)

	var allies: Array[Node] = []
	var enemies: Array[Node] = []
	for child in controller.get_children():
		if not child is CharacterBody2D:
			continue
		if bool(child.get("is_player_controlled")):
			allies.append(child)
		else:
			enemies.append(child)
	if allies.is_empty() or enemies.is_empty():
		_fail("could not find ally/enemy actors")
		return

	var attacker: Node = allies[0]
	var target: Node = enemies[0]
	var best_distance := -1.0
	for ally: Node in allies:
		for enemy: Node in enemies:
			var distance: float = (ally as Node2D).global_position.distance_squared_to((enemy as Node2D).global_position)
			if distance > best_distance:
				best_distance = distance
				attacker = ally
				target = enemy

	var attacker_id: String = String(attacker.call("get_digimon_instance_id"))
	var target_id: String = String(target.call("get_digimon_instance_id"))
	if attacker_id.is_empty() or target_id.is_empty():
		_fail("battle actors do not expose persistent Digimon UUIDs")
		return
	if presentation.call("_find_actor", attacker_id) != attacker:
		_fail("presentation cannot resolve attacker UUID")
		return
	if presentation.call("_find_actor", target_id) != target:
		_fail("presentation cannot resolve target UUID")
		return

	for property_name in ["_slash_texture", "_spark_texture", "_magic_texture", "_flare_texture", "_muzzle_texture", "_ko_smoke_texture"]:
		if presentation.get(property_name) == null:
			_fail("missing combat VFX texture: %s" % property_name)
			return

	var attacker_sprite: Sprite2D = attacker.get_node_or_null("Sprite2D") as Sprite2D
	if attacker_sprite == null:
		_fail("attacker sprite is missing")
		return
	var attack_origin: Vector2 = attacker_sprite.position
	var main_children_before_attack: int = main.get_child_count()
	battle.call("_present_event", "action_started", {
		"actor_id": attacker_id,
		"target_id": target_id,
		"action_id": "basic_attack",
	})
	await create_timer(0.12).timeout
	if int(presentation.get("_presented_events_seen")) < 1:
		_fail("controller did not reach the presentation service")
		return
	if attacker_sprite.position.distance_to(attack_origin) < 2.0:
		_fail("controller-driven presentation did not visibly move the attacker sprite")
		return
	if main.get_child_count() <= main_children_before_attack:
		_fail("attack presentation did not create a visible wind-up VFX node")
		return
	await create_timer(0.42).timeout
	if attacker_sprite.position.distance_to(attack_origin) > 1.5:
		_fail("attacker sprite did not return to its tile after the strike")
		return

	var overlay_root: Control = presentation.get("_overlay_root") as Control
	if overlay_root == null:
		_fail("combat feedback overlay was not created")
		return
	var overlay_children_before: int = overlay_root.get_child_count()
	var main_children_before_damage: int = main.get_child_count()
	battle.call("_present_event", "damage_applied", {
		"actor_id": attacker_id,
		"target_id": target_id,
		"action_id": "basic_attack",
		"damage": 17,
		"critical": false,
	})
	await process_frame
	if overlay_root.get_child_count() <= overlay_children_before:
		_fail("damage presentation did not create floating damage text")
		return
	if main.get_child_count() <= main_children_before_damage:
		_fail("damage presentation did not create slash/spark/flare VFX")
		return

	var damage_label: Control = overlay_root.get_child(overlay_root.get_child_count() - 1) as Control
	var expected_world: Vector2 = Vector2(target.call("get_damage_number_anchor_world"))
	var expected_screen: Vector2 = root.get_canvas_transform() * expected_world
	var actual_screen: Vector2 = damage_label.position + damage_label.size * 0.5
	if actual_screen.distance_to(expected_screen) > 42.0:
		_fail("floating damage text is not anchored to the struck Digimon")
		return

	battle.call("_present_event", "unit_knocked_out", {
		"target_id": target_id,
		"target_name": "Presentation Probe",
		"is_player": false,
	})
	await create_timer(1.05).timeout
	if bool(target.get("visible")):
		_fail("KO presentation did not remove the defeated Digimon from the field")
		return

	print("Combat presentation smoke passed: persistent UUID resolution, controller-driven melee lunge, Kenney VFX, target-anchored damage and KO removal.")
	main.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("Combat presentation smoke failed: %s" % message)
	quit(1)
