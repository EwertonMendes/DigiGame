extends PanelContainer
class_name DigiGlassPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

var _accent := V2.CYAN
var _variant := "floating"
var _content_padding := Vector4.ZERO
var _radius := 10


func _init() -> void:
	set_meta("digi_ui_v2_component", true)
	set_meta("digi_glass_surface", true)


func _ready() -> void:
	_refresh_glass()


func configure_glass(
	accent: Color = V2.CYAN,
	variant: String = "floating",
	content_padding: Vector4 = Vector4.ZERO,
	radius: int = 10
) -> void:
	_accent = accent
	_variant = variant
	_content_padding = content_padding
	_radius = radius
	set_meta("digi_glass_variant", variant)
	_refresh_glass()


func get_glass_variant() -> String:
	return _variant


func _refresh_glass() -> void:
	add_theme_stylebox_override(
		"panel",
		V2.glass_style(_accent, _variant, _content_padding, _radius)
	)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# A restrained inner hairline gives the translucent surface the frosted-glass
	# edge without external art, screen-reading shaders or per-screen decoration.
	# Keeping it procedural makes the component cheap and Web/mobile friendly.
	var alpha := 0.085
	match _variant:
		"modal":
			alpha = 0.105
		"subtle":
			alpha = 0.060
	var inset := float(_radius + 7)
	if size.x > inset * 2.0:
		draw_line(
			Vector2(inset, 1.5),
			Vector2(size.x - inset, 1.5),
			Color(1.0, 1.0, 1.0, alpha),
			1.0,
			true
		)
