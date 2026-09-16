extends RefCounted
class_name DigiCommandButtonStyle

# Shared visual language for primary command/action buttons. These controls are
# intentionally more "raised" than informational cards: a strong leading rail,
# asymmetric corners and a persistent drop shadow keep the button silhouette
# readable even when it is not hovered or focused.
const V2 = preload("res://src/ui/components/DigiUiTheme.gd")


static func style(accent: Color, state: String) -> StyleBoxFlat:
	var fill := Color(0.018, 0.050, 0.069, 0.985)
	var edge := Color(accent.r, accent.g, accent.b, 0.74)
	var leading_width := 4
	var edge_width := 1
	var shadow_color := Color(0.0, 0.0, 0.0, 0.34)
	var shadow_size := 9
	var shadow_offset := Vector2(0.0, 3.0)

	match state:
		"hover":
			fill = Color(
				lerpf(fill.r, accent.r, 0.12),
				lerpf(fill.g, accent.g, 0.12),
				lerpf(fill.b, accent.b, 0.12),
				0.995
			)
			edge = Color(accent.r, accent.g, accent.b, 0.96)
			leading_width = 5
			shadow_color = Color(accent.r, accent.g, accent.b, 0.20)
			shadow_size = 12
		"focus":
			fill = Color(
				lerpf(fill.r, accent.r, 0.17),
				lerpf(fill.g, accent.g, 0.17),
				lerpf(fill.b, accent.b, 0.17),
				1.0
			)
			edge = Color(accent.r, accent.g, accent.b, 1.0)
			leading_width = 5
			edge_width = 2
			shadow_color = Color(accent.r, accent.g, accent.b, 0.30)
			shadow_size = 15
		"pressed":
			fill = Color(
				lerpf(fill.r, accent.r, 0.22),
				lerpf(fill.g, accent.g, 0.22),
				lerpf(fill.b, accent.b, 0.22),
				1.0
			)
			edge = Color(accent.r, accent.g, accent.b, 1.0)
			leading_width = 5
			edge_width = 2
			shadow_color = Color(0.0, 0.0, 0.0, 0.22)
			shadow_size = 6
			shadow_offset = Vector2(0.0, 1.0)
		"disabled":
			fill = Color(0.012, 0.025, 0.034, 0.965)
			edge = Color(V2.SUBTLE.r, V2.SUBTLE.g, V2.SUBTLE.b, 0.62)
			leading_width = 4
			edge_width = 1
			shadow_color = Color(0.0, 0.0, 0.0, 0.22)
			shadow_size = 7

	var result := V2.surface_style(fill, edge, 12)
	result.border_width_left = leading_width
	result.border_width_top = edge_width
	result.border_width_right = edge_width
	result.border_width_bottom = edge_width
	# A slightly tighter leading edge differentiates commands from the rounded
	# informational cards beside them without introducing a one-off asset.
	result.corner_radius_top_left = 6
	result.corner_radius_bottom_left = 6
	result.corner_radius_top_right = 12
	result.corner_radius_bottom_right = 12
	result.border_blend = true
	result.shadow_color = shadow_color
	result.shadow_size = shadow_size
	result.shadow_offset = shadow_offset
	return result
