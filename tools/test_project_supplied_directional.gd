extends Node

const RuntimeControllerScript = preload("res://src/DigimonRuntimeController.gd")
const FollowerScript = preload("res://src/world/OverworldDigimonFollower.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")
const PortraitPreviewScript = preload("res://src/ui/DigimonPortraitPreview.gd")
const SpriteTestLabScript = preload("res://src/ui/DigimonSpriteTestLab.gd")
const DebugRosterToolsScript = preload("res://src/debug/DebugRosterTools.gd")
const DirectionalContractScript = preload("res://src/sprites/DirectionalSpriteContract.gd")
const PortraitResolverScript = preload("res://src/ui/DigimonPortraitResolver.gd")
const MANIFEST_PATH := "res://database/project-supplied-playables.json"
const FACINGS := ["down_left", "down_right", "up_left", "up_right"]


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert(parsed is Dictionary, "Project-supplied directional manifest must be a dictionary")
	var manifest := parsed as Dictionary
	var rows: Array = manifest.get("species", [])
	var expected_count := int(manifest.get("count", -1))
	assert(expected_count > 0 and rows.size() == expected_count, "Project-supplied regression must cover every generated species")

	var runtime := RuntimeControllerScript.new()
	runtime.name = "ProjectSuppliedBattleRuntime"
	add_child(runtime)
	await get_tree().process_frame
	assert(runtime.get_factory() != null, "Battle runtime must initialize the canonical Digimon factory")
	for demo_actor in runtime.get_battle_digimons():
		runtime.remove_child(demo_actor)
		demo_actor.free()
	await get_tree().process_frame

	# These are the two developer-facing entry points used to test/spawn any
	# playable species. Keep project-supplied species on the same generic paths
	# as every other Digimon instead of special-casing them in runtime code.
	var sprite_lab := SpriteTestLabScript.new() as DigimonSpriteTestLab
	add_child(sprite_lab)
	await get_tree().process_frame
	var sprite_test_names := sprite_lab.get_testable_species_names()

	var roster_tools := DebugRosterToolsScript.new() as DebugRosterTools
	var spawn_catalog := roster_tools.catalog()

	for raw_row in rows:
		var row := raw_row as Dictionary
		var species_name := String(row.get("name", ""))
		var resource_path := String(row.get("resource", ""))
		assert(ResourceLoader.exists(resource_path), "%s runtime resource must be packaged" % species_name)
		var resource := load(resource_path) as Digimon
		assert(resource != null and resource.texture != null, "%s directional resource must load" % species_name)
		assert(resource.sprite_layout == "directional_12", "%s must use directional_12" % species_name)
		assert(resource.sprite_hframes == 12 and resource.sprite_vframes == 1, "%s must expose 12 frames" % species_name)

		assert(sprite_test_names.has(species_name), "%s must be discoverable in Sprite Test" % species_name)
		var spawn_catalog_has_species := false
		for catalog_entry in spawn_catalog:
			if String((catalog_entry as Dictionary).get("name", "")) == species_name:
				spawn_catalog_has_species = true
				break
		assert(spawn_catalog_has_species, "%s must be selectable in Spawn Digimon" % species_name)

		var actor := runtime.instantiate_player_digimon(species_name, 1, 100)
		assert(actor != null, "%s must instantiate in battle" % species_name)
		var battle_sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
		assert(battle_sprite != null and battle_sprite.texture != null, "%s battle sprite must load" % species_name)
		for facing in FACINGS:
			actor.call("face_toward_world_position", actor.global_position + _target_for_facing(facing))
			assert(String(actor.get("facing_direction")) == facing, "%s battle facing %s must resolve canonically" % [species_name, facing])
			assert(battle_sprite.frame == DirectionalContractScript.idle_frame(facing), "%s battle facing %s must use canonical idle frame" % [species_name, facing])
			assert(not battle_sprite.flip_h, "%s battle facing %s must not mirror at runtime" % [species_name, facing])

		var follower := FollowerScript.new() as OverworldDigimonFollower
		follower.configure(resource, species_name.to_lower(), 0)
		add_child(follower)
		await get_tree().process_frame
		var follower_sprite := follower.get_node_or_null("Sprite2D") as Sprite2D
		assert(follower_sprite != null and follower_sprite.texture != null, "%s follower sprite must load" % species_name)
		for facing in FACINGS:
			follower.teleport_to(Vector2.ZERO, facing)
			var idle := DirectionalContractScript.idle_frame(facing)
			assert(follower_sprite.frame == idle and not follower_sprite.flip_h, "%s follower %s must start canonically" % [species_name, facing])
			for expected in [idle + 1, idle, idle + 2, idle]:
				follower.step_toward(_target_for_facing(facing), 0.11, [])
				assert(follower_sprite.frame == expected and not follower_sprite.flip_h, "%s follower %s walk phase mismatch" % [species_name, facing])
		follower.queue_free()
		await get_tree().process_frame

		var preview := WalkPreviewScript.new() as DigimonWalkPreview
		preview.size = Vector2(96, 96)
		preview.set_species(species_name)
		add_child(preview)
		await get_tree().process_frame
		var preview_sprite := preview.get_node_or_null("FieldSprite") as Sprite2D
		assert(preview_sprite != null and preview_sprite.texture != null and preview_sprite.visible, "%s walk preview must resolve the normalized field sprite" % species_name)
		preview.queue_free()
		await get_tree().process_frame

		var portrait_key := PortraitResolverScript.resolve_key(species_name)
		assert(not portrait_key.is_empty(), "%s must resolve through the portrait resolver" % species_name)
		assert(FileAccess.file_exists(PortraitResolverScript.metadata_path(portrait_key)), "%s portrait metadata must be packaged" % species_name)
		assert(ResourceLoader.exists(PortraitResolverScript.strip_path(portrait_key)), "%s portrait strip must be packaged" % species_name)

		# Exercise the same shared animated portrait component used by Details,
		# Evolution screens, storage and other UI surfaces. This catches the exact
		# failure where a project-supplied Digimon had a valid field sprite but a
		# one-frame/static UI portrait.
		var portrait_preview := PortraitPreviewScript.new() as DigimonPortraitPreview
		portrait_preview.size = Vector2(128, 128)
		add_child(portrait_preview)
		portrait_preview.set_species(species_name)
		await get_tree().process_frame
		var expected_portrait_frames := int(row.get("portrait_frames", 0))
		assert(expected_portrait_frames > 0, "%s manifest must expose portrait frame count" % species_name)
		assert(int(portrait_preview.get("_frame_count")) == expected_portrait_frames, "%s shared portrait preview must load every generated frame" % species_name)
		var portrait_node := portrait_preview.get_node_or_null("Portrait") as TextureRect
		assert(portrait_node != null and portrait_node.texture != null, "%s shared portrait preview must render" % species_name)
		if expected_portrait_frames > 1:
			assert(portrait_preview.is_processing(), "%s animated portrait must actively process frames" % species_name)
			var durations := portrait_preview.get("_durations") as Array
			var before_frame := int(portrait_preview.get("_frame_index"))
			var first_duration := 0.12
			if not durations.is_empty():
				first_duration = maxf(0.02, float(durations[0]) / 1000.0)
			portrait_preview.call("_process", first_duration + 0.001)
			assert(int(portrait_preview.get("_frame_index")) != before_frame, "%s animated portrait must advance frames" % species_name)
		portrait_preview.queue_free()
		await get_tree().process_frame

		runtime.remove_child(actor)
		actor.free()
		await get_tree().process_frame

	sprite_lab.queue_free()
	await get_tree().process_frame
	print("project-supplied directional regression passed: Sprite Test, Spawn Digimon, battle, overworld, walk preview and animated UI portraits for %d species" % expected_count)
	get_tree().quit()


func _target_for_facing(facing: String) -> Vector2:
	match facing:
		"down_left": return Vector2(-128.0, 128.0)
		"down_right": return Vector2(128.0, 128.0)
		"up_left": return Vector2(-128.0, -128.0)
		_: return Vector2(128.0, -128.0)
