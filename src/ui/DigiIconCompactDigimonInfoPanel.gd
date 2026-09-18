extends "res://src/ui/CompactDigimonInfoPanel.gd"

const TierIconScript = preload("res://src/ui/components/DigiTierIcon.gd")

var _tier_icon: DigiTierIcon = null


func _ready() -> void:
	super._ready()
	_tier_icon = TierIconScript.new() as DigiTierIcon
	_tier_icon.name = "TierIcon"
	_tier_icon.configure("E", Vector2(36.0, 23.0))
	_tier_icon.visible = false
	_card.add_child(_tier_icon)


func _refresh_context() -> void:
	super._refresh_context()
	if _tier_icon == null or _card == null:
		return
	var hovered: Node = null
	if _digimon_controller != null and _digimon_controller.has_method("get_hovered_digimon"):
		hovered = _digimon_controller.call("get_hovered_digimon") as Node
	if hovered == null or not is_instance_valid(hovered) or not _card.visible:
		_tier_icon.visible = false
		return

	var tier := String(hovered.call("get_tier")) if hovered.has_method("get_tier") else "E"
	var footprint := String(hovered.call("get_battle_footprint_id")) if hovered.has_method("get_battle_footprint_id") else "single"
	var size_badge := FootprintScript.display_label(footprint)
	_tier_icon.set_tier(tier)
	_tier_icon.visible = true
	_rank_label.text = size_badge
	_rank_label.tooltip_text = "Tier %s · %s tactical footprint" % [tier, size_badge]
	_layout_card()


func _layout_card() -> void:
	super._layout_card()
	if _tier_icon == null or _card == null or not _card.visible:
		return
	var width := _card.size.x
	var icon_size := Vector2(36.0, 23.0)
	var footprint_width := 42.0
	var right_margin := 10.0
	var gap := 5.0
	_tier_icon.position = Vector2(width - right_margin - footprint_width - gap - icon_size.x, 10.0)
	_tier_icon.size = icon_size
	_tier_icon.custom_minimum_size = icon_size
	_rank_label.position = Vector2(width - right_margin - footprint_width, 9.0)
	_rank_label.size = Vector2(footprint_width, 25.0)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
