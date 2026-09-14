extends Node

const RuntimeControllerScript = preload("res://src/DigimonRuntimeController.gd")
const FollowerScript = preload("res://src/world/OverworldDigimonFollower.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const DirectionalContractScript = preload("res://src/sprites/DirectionalSpriteContract.gd")
const PortraitResolverScript = preload("res://src/ui/DigimonPortraitResolver.gd")
const MANIFEST_PATH := "res://database/additional-ds-playables.json"
const FACINGS := ["down_left", "down_right", "up_left", "up_right"]


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert(parsed is Dictionary, "Additional DS manifest must be a dictionary")
	var manifest := parsed as Dictionary
	var rows: Array = manifest.get("species", [])
	var expected_count := int(manifest.get("count", -1))
	assert(expected_count > 0, "Additional DS manifest must contain at least one species")
	assert(rows.size() == expected_count, "Additional DS regression must cover every generated species")
	print("additional DS regression starting: %d species" % expected_count)

	var runtime := RuntimeControllerScript.new()
	runtime.name = "AdditionalDSBattleRuntime"
	add_child(runtime)
	await get_tree().process_frame
	assert(runtime.get_factory() != null, "Battle runtime must initialize the canonical Digimon factory")
	for demo_actor in runtime.get_battle_digimons():
		runtime.remove_child(demo_actor)
		demo_actor.free()
	await get_tree().process_frame

	for raw_row in rows:
		var row := raw_row as Dictionary
		var species_name := String(row.get("name", ""))
		var resource_path := String(row.get("resource", ""))
		print("additional DS regression species: %s" % species_name)
		assert(ResourceLoader.exists(resource_path), "%s runtime resource must be packaged" % species_name)
		var resource := load(resource_path) as Digimon
		assert(resource != null and resource.texture != null, "%s directional resource must load" % species_name)
		assert(resource.sprite_layout == "directional_12", "%s must use the canonical directional_12 contract" % species_name)
		assert(resource.sprite_hframes == 12 and resource.sprite_vframes == 1, "%s must expose all 12 directional frames" % species_name)

		print("  battle")
		var actor := runtime.instantiate_player_digimon(species_name, 1, 100)
		assert(actor != null, "%s must instantiate in battle through the canonical runtime" % species_name)
		var battle_sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
		assert(battle_sprite != null and battle_sprite.texture != null, "%s battle sprite must load" % species_name)
		for facing in FACINGS:
			actor.call("face_toward_world_position", actor.global_position + _target_for_facing(facing))
			assert(String(actor.get("facing_direction")) == facing, "%s battle facing %s must resolve canonically" % [species_name, facing])
			assert(battle_sprite.frame == DirectionalContractScript.idle_frame(facing), "%s battle facing %s must use its canonical idle frame" % [species_name, facing])
			assert(not battle_sprite.flip_h, "%s battle facing %s must not use runtime mirroring" % [species_name, facing])

		print("  overworld")
		var follower := FollowerScript.new() as OverworldDigimonFollower
		follower.configure(resource, species_name.to_lower(), 0)
		add_child(follower)
		await get_tree().process_frame
		var follower_sprite := follower.get_node_or_null("Sprite2D") as Sprite2D
		assert(follower_sprite != null and follower_sprite.texture != null, "%s overworld follower must load" % species_name)
		for facing in FACINGS:
			follower.teleport_to(Vector2.ZERO, facing)
			var idle := DirectionalContractScript.idle_frame(facing)
			assert(follower_sprite.frame == idle and not follower_sprite.flip_h, "%s follower %s must start canonically" % [species_name, facing])
			for expected in [idle + 1, idle, idle + 2, idle]:
				follower.step_toward(_target_for_facing(facing), 0.11, [])
				assert(follower_sprite.frame == expected and not follower_sprite.flip_h, "%s follower %s walk phase mismatch" % [species_name, facing])
		follower.queue_free()

		print("  menu walk preview")
		var preview := WalkPreviewScript.new() as DigimonWalkPreview
		preview.size = Vector2(96, 96)
		preview.set_species(species_name)
		add_child(preview)
		await get_tree().process_frame
		var preview_sprite := preview.get_node_or_null("FieldSprite") as Sprite2D
		var preview_path := "res://assets/resources/%s.tres" % species_name.strip_edges().to_lower()
		print("    path=%s exists=%s digimon=%s node=%s texture=%s visible=%s" % [preview_path, ResourceLoader.exists(preview_path), preview.get("_digimon") != null, preview_sprite != null, preview_sprite != null and preview_sprite.texture != null, preview_sprite != null and preview_sprite.visible])
		assert(preview_sprite != null and preview_sprite.texture != null and preview_sprite.visible, "%s menu walk preview must resolve the DS field sprite" % species_name)
		preview.queue_free()

		print("  portrait")
		var portrait_key := PortraitResolverScript.resolve_key(species_name)
		assert(not portrait_key.is_empty(), "%s spaced/canonical name must resolve through the shared portrait resolver" % species_name)
		assert(FileAccess.file_exists(PortraitResolverScript.metadata_path(portrait_key)), "%s portrait metadata must be packaged for detail menus" % species_name)
		assert(ResourceLoader.exists(PortraitResolverScript.strip_path(portrait_key)), "%s portrait strip must be packaged for detail menus" % species_name)

		runtime.remove_child(actor)
		actor.free()
		await get_tree().process_frame

	print("additional DS playable regression passed: battle, overworld, walk preview and portrait assets for %d species" % expected_count)
	get_tree().quit()


func _target_for_facing(facing: String) -> Vector2:
	match facing:
		"down_left": return Vector2(-128.0, 128.0)
		"down_right": return Vector2(128.0, 128.0)
		"up_left": return Vector2(-128.0, -128.0)
		_: return Vector2(128.0, -128.0)
