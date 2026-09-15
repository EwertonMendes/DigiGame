extends RefCounted
class_name DigiAttributeChip

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const SemanticPalette = preload("res://src/ui/components/DigiSemanticPalette.gd")

const VACCINE_ICON = preload("res://assets/ui/icons/vaccine.png")
const VIRUS_ICON = preload("res://assets/ui/icons/virus.png")
const DATA_ICON = preload("res://assets/ui/icons/data.png")

const CHIP_HEIGHT := 30.0
const ICON_SIZE := Vector2(30.0, 19.0)


static func build(attribute: String) -> PanelContainer:
	var normalized := attribute.strip_edges()
	var accent := SemanticPalette.data_attribute_color(normalized)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = CHIP_HEIGHT
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", V2.pill_style(accent, true))
	panel.tooltip_text = "%s attribute" % normalized.capitalize()

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var texture := texture_for(normalized)
	if texture != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = ICON_SIZE
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var label := Label.new()
	label.text = normalized.to_upper()
	label.custom_minimum_size.y = CHIP_HEIGHT
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", accent)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	V2.apply_heading(label)
	row.add_child(label)
	return panel


static func texture_for(attribute: String) -> Texture2D:
	match attribute.strip_edges().to_lower():
		"vaccine":
			return VACCINE_ICON
		"virus":
			return VIRUS_ICON
		"data":
			return DATA_ICON
		_:
			return null


static func replace_text_pill(root: Node, attribute: String) -> bool:
	if root == null or texture_for(attribute) == null:
		return false
	var label := _find_label_exact(root, attribute.to_upper())
	if label == null:
		return false
	var parent := label.get_parent()
	if parent == null:
		return false
	var index := label.get_index()
	parent.remove_child(label)
	label.queue_free()
	parent.add_child(build(attribute))
	parent.move_child(parent.get_child(parent.get_child_count() - 1), index)
	return true


static func normalize_text_pill_height(root: Node, text: String) -> void:
	var label := _find_label_exact(root, text)
	if label != null:
		label.custom_minimum_size.y = CHIP_HEIGHT


static func _find_label_exact(root: Node, text: String) -> Label:
	for child in root.get_children():
		if child is Label and (child as Label).text == text:
			return child as Label
		var nested := _find_label_exact(child, text)
		if nested != null:
			return nested
	return null
