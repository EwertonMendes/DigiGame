extends Node

const RuntimeControllerScript = preload("res://src/DigimonRuntimeController.gd")
const FollowerScript = preload("res://src/world/OverworldDigimonFollower.gd")
const WalkPreviewScript = preload("res://src/ui/DigimonWalkPreview.gd")

const SPECIES := ["greymon", "agumon", "koromon", "botamon"]
const PREVIEW_SIZE := Vector2(96.0, 96.0)


func _ready() -> void:
	var preview_normalizers: Dictionary = {}
	var native_heights: Dictionary = {}

	for species_key in SPECIES:
		var resource := load("res://assets/resources/%s.tres" % species_key) as Digimon
		if not _require(resource != null and resource.texture != null, "%s resource must load" % species_key):
			return
		if not _require(resource.sprite_scale.x > 0.0 and resource.sprite_scale.y > 0.0, "%s sprite scale must be positive" % species_key):
			return

		var frame_size := _frame_size(resource)
		native_heights[species_key] = frame_size.y * resource.sprite_scale.y

		var preview := WalkPreviewScript.new() as DigimonWalkPreview
		preview.size = PREVIEW_SIZE
		preview.set_species(species_key)
		add_child(preview)
		await get_tree().process_frame

		var preview_sprite := preview.get_node_or_null("FieldSprite") as Sprite2D
		if not _require(preview_sprite != null and preview_sprite.texture != null, "%s menu preview must load" % species_key):
			return
		preview_normalizers[species_key] = preview_sprite.scale.y / resource.sprite_scale.y

		preview.queue_free()
		await get_tree().process_frame

	var reference_normalizer := float(preview_normalizers["greymon"])
	for species_key in SPECIES:
		var normalizer := float(preview_normalizers[species_key])
		if not _require(
			is_equal_approx(normalizer, reference_normalizer),
			"%s menu preview must preserve authored sprite_scale instead of independently filling the card" % species_key
		):
			return

	var greymon_height := float(native_heights["greymon"])
	for smaller_key in ["agumon", "koromon", "botamon"]:
		if not _require(
			greymon_height > float(native_heights[smaller_key]),
			"Greymon's authored field footprint must remain larger than %s" % smaller_key
		):
			return

	var runtime := RuntimeControllerScript.new()
	runtime.name = "SpriteScaleBattleRuntime"
	add_child(runtime)
	await get_tree().process_frame
	if not _require(runtime.get_factory() != null, "Battle runtime must initialize"):
		return

	var battle_normalizers: Dictionary = {}
	for actor in runtime.get_battle_digimons():
		var species_key := String(actor.get("digimon_key")).to_lower()
		if species_key not in ["greymon", "agumon"]:
			continue
		var resource := load("res://assets/resources/%s.tres" % species_key) as Digimon
		var battle_sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
		if not _require(battle_sprite != null, "%s battle sprite must exist" % species_key):
			return
		battle_normalizers[species_key] = battle_sprite.scale.y / resource.sprite_scale.y

	if not _require(
		battle_normalizers.has("greymon") and battle_normalizers.has("agumon"),
		"Battle regression must observe both Greymon and Agumon"
	):
		return
	if not _require(
		is_equal_approx(float(battle_normalizers["greymon"]), float(battle_normalizers["agumon"])),
		"Battle rendering must apply the same global scale on top of each species' authored sprite_scale"
	):
		return

	var follower_normalizers: Dictionary = {}
	for species_key in ["greymon", "agumon"]:
		var resource := load("res://assets/resources/%s.tres" % species_key) as Digimon
		var follower := FollowerScript.new() as OverworldDigimonFollower
		follower.configure(resource, species_key, 0)
		add_child(follower)
		await get_tree().process_frame
		var follower_sprite := follower.get_node_or_null("Sprite2D") as Sprite2D
		if not _require(follower_sprite != null, "%s follower sprite must exist" % species_key):
			return
		follower_normalizers[species_key] = follower_sprite.scale.y / resource.sprite_scale.y
		follower.queue_free()
		await get_tree().process_frame

	if not _require(
		is_equal_approx(float(follower_normalizers["greymon"]), float(follower_normalizers["agumon"])),
		"Overworld rendering must preserve the same authored size relationship as battle"
	):
		return

	print("digimon sprite scale regression passed")
	get_tree().quit(0)


func _frame_size(resource: Digimon) -> Vector2:
	if resource.sprite_layout == "spaced_9_32":
		return Vector2(32.0, 32.0)
	return Vector2(
		float(resource.texture.get_width()) / float(maxi(1, resource.sprite_hframes)),
		float(resource.texture.get_height()) / float(maxi(1, resource.sprite_vframes))
	)


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("[DigimonSpriteScaleRegression] %s" % message)
	get_tree().quit(1)
	return false
