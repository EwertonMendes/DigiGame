extends TextureRect
class_name DigiTierIcon

const TIER_TEXTURES := {
	"E": preload("res://assets/ui/tiers/icon_tier_e.png"),
	"D": preload("res://assets/ui/tiers/icon_tier_d.png"),
	"C": preload("res://assets/ui/tiers/icon_tier_c.png"),
	"B": preload("res://assets/ui/tiers/icon_tier_b.png"),
	"A": preload("res://assets/ui/tiers/icon_tier_a.png"),
	"S": preload("res://assets/ui/tiers/icon_tier_s.png"),
	"SS": preload("res://assets/ui/tiers/icon_tier_ss.png"),
	"SSS": preload("res://assets/ui/tiers/icon_tier_sss.png"),
}

var tier := "E"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_tier()


func configure(value: String, minimum_size: Vector2 = Vector2(32.0, 22.0)) -> DigiTierIcon:
	tier = normalize_tier(value)
	custom_minimum_size = minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_tier()
	return self


func set_tier(value: String) -> void:
	tier = normalize_tier(value)
	_apply_tier()


func _apply_tier() -> void:
	texture = texture_for(tier)
	tooltip_text = "Tier %s" % tier
	set_meta("tier", tier)


static func normalize_tier(value: String) -> String:
	var normalized := value.to_upper().strip_edges()
	return normalized if TIER_TEXTURES.has(normalized) else "E"


static func texture_for(value: String) -> Texture2D:
	var normalized := normalize_tier(value)
	return TIER_TEXTURES[normalized] as Texture2D
