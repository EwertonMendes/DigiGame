extends RefCounted
class_name DigiUiAssetIcons

const BITS_TEXTURE = preload("res://assets/ui/icons/bits.png")
const LEGACY_BITS_PATH := "res://assets/ui/icons/bits.svg"


static func apply_bits_icon(root: Node) -> void:
	if root == null:
		return
	_replace_bits_texture(root)


static func _replace_bits_texture(node: Node) -> void:
	if node is TextureRect:
		var rect := node as TextureRect
		if rect.texture != null and rect.texture.resource_path == LEGACY_BITS_PATH:
			rect.texture = BITS_TEXTURE
			rect.self_modulate = Color.WHITE
			rect.custom_minimum_size = Vector2(22.0, 22.0)
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in node.get_children():
		_replace_bits_texture(child)
