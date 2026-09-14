extends Node

const RuntimeControllerScript = preload("res://src/DigimonRuntimeController.gd")
const FollowerScript = preload("res://src/world/OverworldDigimonFollower.gd")
const DirectionalContractScript = preload("res://src/sprites/DirectionalSpriteContract.gd")
const PortraitResolverScript = preload("res://src/ui/DigimonPortraitResolver.gd")
const MANIFEST_PATH := "res://database/early-rank-playables.json"
const EXPECTED_RANKS := ["Fresh", "In-Training", "Rookie"]
const FACINGS := ["down_left", "down_right", "up_left", "up_right"]


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert(parsed is Dictionary, "Early-rank playable manifest must be a dictionary")
	var manifest := parsed as Dictionary
	assert(Array(manifest.get("ranks", [])) == EXPECTED_RANKS, "Manifest must cover Fresh, In-Training and Rookie ranks")
	var species_rows: Array = manifest.get("species", [])
	assert(not species_rows.is_empty(), "Early-rank playable manifest must contain species")

	var runtime := RuntimeControllerScript.new()
	runtime.name = "EarlyRankBattleRuntime"
	add_child(runtime)
	await get_tree().process_frame
	assert(runtime.get_factory() != null, "Battle runtime must initialize the canonical Digimon factory")

	await get_tree().process_frame
	for demo_actor in runtime.get_battle_digimons():
		runtime.remove_child(demo_actor)
		demo_actor.free()
	await get_tree().process_frame

	var tested := 0
	var seen_ranks: Dictionary = {}
	for raw_row in species_rows:
		assert(raw_row is Dictionary, "Manifest species rows must be dictionaries")
		var row := raw_row as Dictionary
		var species_name := String(row.get("name", ""))
		var rank := String(row.get("rank", ""))
		assert(not species_name.is_empty(), "Manifest species must have a name")
		assert(rank in EXPECTED_RANKS, "%s has unsupported early rank %s" % [species_name, rank])
		seen_ranks[rank] = true
		print("early-rank battle check %d/%d: %s [%s]" % [tested + 1, species_rows.size(), species_name, rank])

		var resource_path := String(row.get("resource", ""))
		assert(ResourceLoader.exists(resource_path), "%s runtime resource must be packaged" % species_name)
		var resource := load(resource_path) as Digimon
		assert(resource != null, "%s runtime resource must load as Digimon" % species_name)
		assert(resource.display_name == species_name, "%s resource must use the canonical database name" % species_name)
		assert(resource.texture != null, "%s resource must expose a field texture" % species_name)
		assert(resource.sprite_layout == "directional_12", "%s must use a directional DS field strip, not a portrait fallback" % species_name)
		assert(resource.sprite_hframes == 12 and resource.sprite_vframes == 1, "%s DS field strip must contain 12 horizontal frames" % species_name)
		assert(String(row.get("visual_mode", "")) == "directional_12", "%s manifest must expose directional_12 visual mode" % species_name)
		assert(String(row.get("field_sprite", "")).ends_with("/field.png"), "%s manifest must link its DS field sprite" % species_name)

		var portrait_key := PortraitResolverScript.resolve_key(species_name)
		assert(not portrait_key.is_empty(), "%s portrait must resolve through the shared battle/detail resolver" % species_name)
		var portrait_meta_path := PortraitResolverScript.metadata_path(portrait_key)
		assert(FileAccess.file_exists(portrait_meta_path), "%s portrait metadata must be packaged" % species_name)
		assert(ResourceLoader.exists(PortraitResolverScript.strip_path(portrait_key)), "%s portrait strip must be packaged" % species_name)
		if species_name == "Grass Agumon":
			assert(portrait_key == "grassagumon", "Grass Agumon spaced runtime key must resolve to compact portrait assets")
			var portrait_metadata = JSON.parse_string(FileAccess.get_file_as_string(portrait_meta_path))
			assert(portrait_metadata is Dictionary, "Grass Agumon portrait metadata must be valid")
			var portrait_data := portrait_metadata as Dictionary
			assert(int(portrait_data.get("frame_width", 0)) == 160 and int(portrait_data.get("frame_height", 0)) == 180, "Grass Agumon details must use profile frames rather than 48px walking frames")
			var field_image := resource.texture.get_image()
			assert(field_image != null and field_image.get_width() > 0, "Grass Agumon field image must be readable")
			var cell_width := field_image.get_width() / 12
			for field_frame in range(12):
				var left := field_frame * cell_width
				var right := left + cell_width - 1
				assert(field_image.get_pixel(left, 0).a < 0.01 and field_image.get_pixel(right, 0).a < 0.01, "Grass Agumon field frame %d must have a transparent background" % field_frame)

		var actor := runtime.instantiate_player_digimon(species_name, 1, 100)
		assert(actor != null, "%s must instantiate through DigimonRuntimeController" % species_name)
		var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
		assert(sprite != null and sprite.texture != null, "%s battle actor must have a DS field texture" % species_name)
		assert(sprite.hframes == 12, "%s battle actor must expose the 12 DS movement frames" % species_name)
		assert(not sprite.flip_h, "%s battle actor must not mirror a normalized directional strip" % species_name)
		assert(String(actor.get("digimon_key")) == species_name.to_lower(), "%s must keep its canonical battle key" % species_name)
		var instance = actor.get("digimon_instance")
		assert(instance is DigimonInstance, "%s must bind a DigimonInstance" % species_name)
		assert(String(instance.species_seed) == String(row.get("seed", "")), "%s must bind the database seed from the manifest" % species_name)

		# Exercise the exact battle-facing implementation for every species and
		# direction. A normalized strip must never need runtime mirroring, and the
		# canonical idle frame for the selected facing must be used immediately.
		for facing in FACINGS:
			var actor_target := actor.global_position + _target_for_facing(facing)
			actor.call("face_toward_world_position", actor_target)
			var actor_idle_frame := DirectionalContractScript.idle_frame(facing)
			assert(String(actor.get("facing_direction")) == facing, "%s battle actor must resolve %s facing" % [species_name, facing])
			assert(sprite.frame == actor_idle_frame, "%s battle %s must use the canonical idle frame" % [species_name, facing])
			assert(not sprite.flip_h, "%s battle %s must not use runtime horizontal mirroring" % [species_name, facing])

		# Exercise the exact overworld/test-lab movement implementation for every
		# species and every facing. This catches bad frame counts/layouts before a
		# playable PR is deployed.
		var follower := FollowerScript.new() as OverworldDigimonFollower
		follower.configure(resource, species_name.to_lower(), 0)
		add_child(follower)
		await get_tree().process_frame
		var follower_sprite := follower.get_node_or_null("Sprite2D") as Sprite2D
		assert(follower_sprite != null and follower_sprite.texture != null, "%s follower must load its DS field texture" % species_name)
		for facing in FACINGS:
			follower.teleport_to(Vector2.ZERO, facing)
			var idle_frame := DirectionalContractScript.idle_frame(facing)
			assert(follower_sprite.frame == idle_frame, "%s %s must start on the canonical idle frame" % [species_name, facing])
			assert(not follower_sprite.flip_h, "%s follower %s must not mirror a normalized directional strip" % [species_name, facing])
			var expected_walk := [idle_frame + 1, idle_frame, idle_frame + 2, idle_frame]
			for expected_frame in expected_walk:
				follower.step_toward(_target_for_facing(facing), 0.11, [])
				assert(follower_sprite.frame == expected_frame, "%s %s must follow idle/step-a/idle/step-b" % [species_name, facing])
				assert(not follower_sprite.flip_h, "%s follower %s walk must not mirror the normalized strip" % [species_name, facing])
		follower.queue_free()

		await get_tree().process_frame
		runtime.remove_child(actor)
		actor.free()
		tested += 1

	for rank in EXPECTED_RANKS:
		assert(seen_ranks.has(rank), "Battle regression must exercise %s Digimon" % rank)
	assert(tested == int(manifest.get("count", -1)), "Battle regression must instantiate every early-rank Digimon")

	print("early-rank playable battle regression passed: %d species with directional DS field sprites" % tested)
	get_tree().quit()


func _target_for_facing(facing: String) -> Vector2:
	match facing:
		"down_left":
			return Vector2(-128.0, 128.0)
		"down_right":
			return Vector2(128.0, 128.0)
		"up_left":
			return Vector2(-128.0, -128.0)
		_:
			return Vector2(128.0, -128.0)
