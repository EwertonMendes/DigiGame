extends Node

const ActionDatabaseScript = preload("res://src/battle/actions/BattleActionDatabase.gd")
const DamageCalculatorScript = preload("res://src/battle/combat/DamageCalculator.gd")
const HudScript = preload("res://src/DigiIconBattleHUD.gd")
const ZEKE_SEED := "48b7a3e5-3e43-4819-96b8-673bfe67d5c1"
const ZEKE_ACTION_IDS := ["zeke_flame", "trident_fang", "plasma_railgun"]


class ActorStub:
	extends Node
	var digimon_key := "zeke greymon"
	var is_player_controlled := true
	var is_defending := false
	var battle_state = null
	var display_name := "Zeke Greymon"
	var species_data: Dictionary = {"type": "Data", "attribute": "Data", "element": "fire"}

	func get_display_name() -> String:
		return display_name

	func get_final_stat(stat_key: String) -> int:
		match stat_key:
			"hp":
				return 355
			"sp":
				return 350
			"atk":
				return 178
			"def":
				return 152
			"int":
				return 170
			_:
				return 100

	func get_current_hp() -> int:
		return 306


func _ready() -> void:
	if not _test_technique_contract():
		return
	if not _test_sprite_contract():
		return
	if not await _test_responsive_identity_layout():
		return
	print("zeke greymon regression passed")
	get_tree().quit()


func _test_technique_contract() -> bool:
	var database = ActionDatabaseScript.new()
	if not _check(database.load_default(), "Battle action database must load"):
		return false

	var early_actions: Array[Dictionary] = database.get_known_actions(ZEKE_SEED, 3)
	if not _check(early_actions.size() == 1, "Level-3 Zeke Greymon must expose exactly its signature technique"):
		return false
	if not _check(String(early_actions[0].get("id", "")) == "zeke_flame", "Zeke signature must resolve to the curated canonical id"):
		return false
	if not _check(String(early_actions[0].get("name", "")) == "Zeke Flame", "Zeke signature must expose its proper display name"):
		return false

	var all_actions: Array[Dictionary] = database.get_known_actions(ZEKE_SEED, 30)
	if not _check(all_actions.size() == ZEKE_ACTION_IDS.size(), "Level-30 Zeke Greymon must expose the complete curated technique set"):
		return false
	var actions_by_id: Dictionary = {}
	for action: Dictionary in all_actions:
		actions_by_id[String(action.get("id", ""))] = action
	for action_id: String in ZEKE_ACTION_IDS:
		if not _check(actions_by_id.has(action_id), "Zeke curated learnset is missing %s" % action_id):
			return false
		if not _check(_action_resolves_damage(actions_by_id[action_id]), "%s must resolve through the standard battle damage path" % action_id):
			return false
	return true


func _action_resolves_damage(action: Dictionary) -> bool:
	if int(action.get("power", 0)) <= 0:
		return false
	var has_damage_effect := false
	for effect in action.get("effects", []):
		if effect is Dictionary and String(effect.get("type", "")) == "damage":
			has_damage_effect = true
			break
	if not has_damage_effect:
		return false

	var source := ActorStub.new()
	var target := ActorStub.new()
	target.species_data = {"type": "Vaccine", "attribute": "Vaccine", "element": "neutral"}
	var calculator = DamageCalculatorScript.new()
	var preview: Dictionary = calculator.preview(source, target, action)
	source.free()
	target.free()
	return int(preview.get("damage", 0)) > 0


func _test_sprite_contract() -> bool:
	var resource = load("res://assets/resources/zeke greymon.tres")
	if not _check(resource != null, "Zeke runtime resource must load"):
		return false
	var texture := resource.get("texture") as Texture2D
	var hframes := maxi(1, int(resource.get("sprite_hframes")))
	var vframes := maxi(1, int(resource.get("sprite_vframes")))
	if not _check(texture != null, "Zeke runtime resource must have a field texture"):
		return false
	var frame_size := Vector2i(texture.get_width() / hframes, texture.get_height() / vframes)
	if not _check(frame_size.x <= 44 and frame_size.y <= 48, "1x1 Zeke sprite must stay inside the normalized Mega visual envelope"):
		return false
	return _check(String(resource.get("sprite_layout")) == "directional_12", "Sprite normalization must preserve the canonical directional contract")


func _test_responsive_identity_layout() -> bool:
	var hud := HudScript.new() as Control
	add_child(hud)
	await get_tree().process_frame

	var actor := ActorStub.new()
	actor.display_name = "Imperialdramon (Fighter Mode)"
	add_child(actor)
	hud.call("_update_unit_summary", actor, {
		"actor_name": actor.display_name,
		"level": 3,
		"tier": "E",
		"size_badge": "1x1",
		"max_sp": 350,
		"current_sp": 331,
	})

	for layout in [
		{"size": Vector2(306.0, 112.0), "compact": false},
		{"size": Vector2(244.0, 78.0), "compact": true},
	]:
		hud.call("_layout_status", layout["size"], layout["compact"])
		var actor_label := hud.get("_actor_label") as Label
		var meta_label := hud.get("_actor_meta_label") as Label
		var tier_icon := hud.get("_tier_icon") as Control
		if not _check(actor_label != null and meta_label != null and tier_icon != null, "Responsive identity controls must exist"):
			return false
		if not _check(actor_label.text == actor.display_name, "Species name must stay separate from level metadata"):
			return false
		if not _check(meta_label.text.begins_with("Lv.3"), "Level and footprint must live in the metadata row"):
			return false
		if not _check(actor_label.position.x + actor_label.size.x <= tier_icon.position.x, "Long species names must never overlap the Tier icon"):
			return false
		if not _check(meta_label.position.x + meta_label.size.x <= tier_icon.position.x, "Metadata must never overlap the Tier icon"):
			return false

	actor.queue_free()
	hud.queue_free()
	await get_tree().process_frame
	return true


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	print("[zeke-greymon] FAIL: %s" % message)
	get_tree().quit(1)
	return false
