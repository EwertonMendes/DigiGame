extends "res://src/DigitalTransitionBattleHUD.gd"

const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")

var _tier_icon: DigiTierIcon = null


func _build_status_panel() -> void:
	super._build_status_panel()
	_tier_icon = TierIconScript.new() as DigiTierIcon
	_tier_icon.name = "TierIcon"
	_tier_icon.configure("E", Vector2(38.0, 24.0))
	_tier_icon.visible = false
	_status_panel.add_child(_tier_icon)


func _update_unit_summary(actor: Node, state: Dictionary) -> void:
	super._update_unit_summary(actor, state)
	if _tier_icon == null:
		return
	_tier_icon.visible = actor != null
	if actor == null:
		return
	var tier := String(state.get("tier", "E"))
	_tier_icon.set_tier(tier)

	var actor_name := String(state.get("actor_name", "Digimon"))
	var tier_marker := actor_name.find("  ·  TIER ")
	if tier_marker >= 0:
		actor_name = actor_name.substr(0, tier_marker)
	elif actor.has_method("get_display_name"):
		actor_name = String(actor.call("get_display_name"))
	var level := int(state.get("level", 1))
	var size_badge := String(state.get("size_badge", ""))
	var size_suffix := "   %s" % size_badge if not size_badge.is_empty() else ""
	_actor_label.text = "%s   Lv.%d%s" % [actor_name, level, size_suffix]


func _layout_status(panel_size: Vector2, compact: bool) -> void:
	super._layout_status(panel_size, compact)
	if _tier_icon == null:
		return
	var pad := 10.0 if compact else 12.0
	var portrait_side := 56.0 if compact else 68.0
	var info_x := pad + portrait_side + 10.0
	var icon_size := Vector2(34.0, 22.0) if compact else Vector2(40.0, 26.0)
	var top := 9.0 if compact else 10.0
	_tier_icon.position = Vector2(panel_size.x - pad - icon_size.x, top)
	_tier_icon.size = icon_size
	_tier_icon.custom_minimum_size = icon_size
	_actor_label.size = Vector2(
		maxf(80.0, panel_size.x - info_x - pad - icon_size.x - 8.0),
		_actor_label.size.y
	)
