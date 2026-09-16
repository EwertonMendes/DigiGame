extends "res://src/DigitalTransitionBattleHUD.gd"

const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")

var _tier_icon: DigiTierIcon = null
var _actor_meta_label: Label = null


func _build_status_panel() -> void:
	super._build_status_panel()

	_actor_meta_label = _label("", 12, UI.SUBTLE)
	_actor_meta_label.name = "ActiveUnitMeta"
	_actor_meta_label.clip_text = true
	_actor_meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_panel.add_child(_actor_meta_label)

	_tier_icon = TierIconScript.new() as DigiTierIcon
	_tier_icon.name = "TierIcon"
	_tier_icon.configure("E", Vector2(38.0, 24.0))
	_tier_icon.visible = false
	_status_panel.add_child(_tier_icon)

	_actor_label.clip_text = true
	_actor_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _update_unit_summary(actor: Node, state: Dictionary) -> void:
	super._update_unit_summary(actor, state)
	if _tier_icon == null or _actor_meta_label == null:
		return

	var actor_name := String(state.get("actor_name", "Digimon"))
	var tier_marker := actor_name.find("  ·  TIER ")
	if tier_marker >= 0:
		actor_name = actor_name.substr(0, tier_marker)
	elif actor != null and actor.has_method("get_display_name"):
		actor_name = String(actor.call("get_display_name"))

	_actor_label.text = actor_name
	_actor_label.tooltip_text = actor_name
	_tier_icon.visible = actor != null
	if actor == null:
		_actor_meta_label.text = ""
		return

	var tier := String(state.get("tier", "E"))
	_tier_icon.set_tier(tier)

	var level := int(state.get("level", 1))
	var size_badge := String(state.get("size_badge", ""))
	_actor_meta_label.text = "Lv.%d%s" % [level, "   %s" % size_badge if not size_badge.is_empty() else ""]


func _layout_status(panel_size: Vector2, compact: bool) -> void:
	super._layout_status(panel_size, compact)
	if _tier_icon == null or _actor_meta_label == null:
		return

	var pad := 10.0 if compact else 12.0
	var portrait_side := 56.0 if compact else 68.0
	var info_x := pad + portrait_side + 10.0
	var info_w := maxf(1.0, panel_size.x - info_x - pad)
	var icon_size := Vector2(34.0, 22.0) if compact else Vector2(40.0, 26.0)
	var top := 6.0 if compact else 9.0
	var identity_gap := 8.0

	_tier_icon.position = Vector2(panel_size.x - pad - icon_size.x, top)
	_tier_icon.size = icon_size
	_tier_icon.custom_minimum_size = icon_size

	# Keep identity text and progression artwork in separate layout regions. Long
	# species names are clipped only inside the text region and can never render
	# underneath the Tier icon.
	var identity_right := _tier_icon.position.x - identity_gap
	var identity_w := maxf(56.0, identity_right - info_x)
	var name_y := 4.0 if compact else 7.0
	var name_h := 20.0 if compact else 23.0
	_actor_label.position = Vector2(info_x, name_y)
	_actor_label.size = Vector2(identity_w, name_h)
	_actor_label.add_theme_font_size_override("font_size", 14 if compact else 16)
	_actor_meta_label.position = Vector2(info_x, name_y + name_h - 1.0)
	_actor_meta_label.size = Vector2(identity_w, 15.0)
	_actor_meta_label.add_theme_font_size_override("font_size", 10 if compact else 11)

	# Resource rows live below the complete identity block instead of sharing its
	# horizontal band. This keeps the panel stable for every name length while
	# preserving the same compact/desktop outer dimensions.
	var row_h := 18.0 if compact else 20.0
	var first_y := 37.0 if compact else 48.0
	var caption_w := 22.0 if compact else 24.0
	var value_w := 54.0 if compact else 62.0
	var bar_x := info_x + caption_w + 5.0
	var bar_w := maxf(38.0, info_w - caption_w - value_w - 10.0)

	_hp_caption.position = Vector2(info_x, first_y)
	_hp_caption.size = Vector2(caption_w, row_h)
	_hp_bar.position = Vector2(bar_x, first_y + 6.0)
	_hp_bar.size = Vector2(bar_w, 8.0)
	_hp_value.position = Vector2(panel_size.x - pad - value_w, first_y)
	_hp_value.size = Vector2(value_w, row_h)

	_sp_caption.position = Vector2(info_x, first_y + row_h)
	_sp_caption.size = Vector2(caption_w, row_h)
	_sp_bar.position = Vector2(bar_x, first_y + row_h + 6.0)
	_sp_bar.size = Vector2(bar_w, 8.0)
	_sp_value.position = Vector2(panel_size.x - pad - value_w, first_y + row_h)
	_sp_value.size = Vector2(value_w, row_h)
