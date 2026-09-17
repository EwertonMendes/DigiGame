extends RefCounted
class_name DigiUiAssetIcons

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const BITS_TEXTURE = preload("res://assets/ui/icons/bits.png")
const LEGACY_BITS_PATH := "res://assets/ui/icons/bits.svg"

const BITS_ICON_SIZE := Vector2(30.0, 30.0)
const BITS_BADGE_SIZE := Vector2(144.0, 42.0)


static func apply_bits_icon(root: Node) -> void:
	if root == null:
		return
	_replace_bits_texture(root)
	# DigiBitsDisplay owns its complete presentation. The legacy polish pass is
	# intentionally skipped when the shared premium component is present so old
	# screen compatibility helpers cannot resize or restyle it underneath us.
	if root.find_child("BitsDisplay", true, false) is DigiBitsDisplay or root.find_child("BitsBadge", true, false) is DigiBitsDisplay:
		return
	if root is Control:
		var control := root as Control
		_polish_bits_badge(control)
		if not bool(control.get_meta("bits_badge_polish_connected", false)):
			control.set_meta("bits_badge_polish_connected", true)
			control.resized.connect(func(): _polish_bits_badge(control))


static func _replace_bits_texture(node: Node) -> void:
	if node is TextureRect:
		var rect := node as TextureRect
		if rect.texture != null and rect.texture.resource_path == LEGACY_BITS_PATH:
			rect.texture = BITS_TEXTURE
			rect.self_modulate = Color.WHITE
			rect.custom_minimum_size = BITS_ICON_SIZE
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in node.get_children():
		_replace_bits_texture(child)


static func _polish_bits_badge(root: Control) -> void:
	var rect := _find_bits_rect(root)
	if rect == null:
		return
	rect.custom_minimum_size = BITS_ICON_SIZE
	rect.self_modulate = Color.WHITE

	var row := rect.get_parent() as HBoxContainer
	if row == null:
		return
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	for child in row.get_children():
		if child is Label:
			var label := child as Label
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", V2.WHITE)
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var badge := row.get_parent() as PanelContainer
	if badge == null:
		return
	badge.custom_minimum_size = BITS_BADGE_SIZE
	badge.add_theme_stylebox_override(
		"panel",
		V2.surface_style(
			Color(0.035, 0.055, 0.075, 0.99),
			Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.48),
			8,
			Vector4(12.0, 6.0, 12.0, 6.0)
		)
	)
	badge.size = BITS_BADGE_SIZE

	var close_button := root.find_child("ModalClose", true, false) as Control
	if close_button != null:
		badge.position = Vector2(maxf(0.0, close_button.position.x - 12.0 - BITS_BADGE_SIZE.x), 9.0)


static func _find_bits_rect(root: Node) -> TextureRect:
	for child in root.get_children():
		if child is TextureRect:
			var rect := child as TextureRect
			if rect.texture == BITS_TEXTURE or (rect.texture != null and rect.texture.resource_path == BITS_TEXTURE.resource_path):
				return rect
		var nested := _find_bits_rect(child)
		if nested != null:
			return nested
	return null
