extends Node

const RuntimeControllerScript = preload("res://src/DigimonRuntimeController.gd")
const MANIFEST_PATH := "res://database/early-rank-playables.json"
const EXPECTED_RANKS := ["Fresh", "In-Training", "Rookie"]


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

		var actor := runtime.instantiate_player_digimon(species_name, 1, 100)
		assert(actor != null, "%s must instantiate through DigimonRuntimeController" % species_name)
		var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
		assert(sprite != null and sprite.texture != null, "%s battle actor must have a visual texture" % species_name)
		assert(String(actor.get("digimon_key")) == species_name.to_lower(), "%s must keep its canonical battle key" % species_name)
		var instance = actor.get("digimon_instance")
		assert(instance is DigimonInstance, "%s must bind a DigimonInstance" % species_name)
		assert(String(instance.species_seed) == String(row.get("seed", "")), "%s must bind the database seed from the manifest" % species_name)

		var resource_path := String(row.get("resource", ""))
		assert(ResourceLoader.exists(resource_path), "%s runtime resource must be packaged" % species_name)
		var resource := load(resource_path) as Digimon
		assert(resource != null, "%s runtime resource must load as Digimon" % species_name)
		assert(resource.display_name == species_name, "%s resource must use the canonical database name" % species_name)
		assert(resource.texture != null, "%s resource must expose a texture" % species_name)
		if resource.sprite_layout == "portrait_strip":
			assert(resource.sprite_hframes == int(row.get("frame_count", 0)), "%s portrait-strip frames must match its WebP metadata" % species_name)
			assert(resource.sprite_scale.x > 0.0 and resource.sprite_scale.y > 0.0, "%s portrait fallback must have a positive battle scale" % species_name)

		runtime.remove_child(actor)
		actor.free()
		tested += 1

	for rank in EXPECTED_RANKS:
		assert(seen_ranks.has(rank), "Battle regression must exercise %s Digimon" % rank)
	assert(tested == int(manifest.get("count", -1)), "Battle regression must instantiate every early-rank Digimon")

	print("early-rank playable battle regression passed: %d species" % tested)
	get_tree().quit()
