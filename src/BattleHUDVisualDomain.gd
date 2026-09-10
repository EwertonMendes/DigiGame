extends "res://src/BattleHUDDomain.gd"

const NAV_ICON_ROOT := "res://assets/ui/icons"


func _ready() -> void:
	super._ready()
	_install_technique_navigation_hint()


func _install_technique_navigation_hint() -> void:
	if _combat_overlay == null:
		return
	var technique_panel := _combat_overlay.get_node_or_null("TechniqueMenu") as Control
	if technique_panel == null:
		return

	# The font used by the battle HUD does not reliably contain Unicode arrow
	# glyphs on every export target. Keep the legacy Hint node alive because the
	# overlay's responsive layout still addresses it, but make it invisible and
	# render navigation directions as SVG assets instead. This keeps browser,
	# desktop and mobile exports visually deterministic without breaking layout.
	var legacy_hint := technique_panel.get_node_or_null("Hint") as Label
	if legacy_hint != null:
		legacy_hint.text = ""
		legacy_hint.visible = false
		legacy_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if technique_panel.get_node_or_null("HintIcons") != null:
		return

	var row := HBoxContainer.new()
	row.name = "HintIcons"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0.0
	row.anchor_top = 0.0
	row.anchor_right = 1.0
	row.anchor_bottom = 0.0
	row.offset_left = 14.0
	row.offset_top = 29.0
	row.offset_right = -14.0
	row.offset_bottom = 51.0
	row.add_theme_constant_override("separation", 5)
	technique_panel.add_child(row)

	row.add_child(_navigation_icon("nav_vertical.svg", "Navigate techniques up or down"))
	row.add_child(_hint_label("Select"))
	row.add_child(_hint_separator())
	row.add_child(_hint_label("A / Enter  Choose"))
	row.add_child(_hint_separator())
	row.add_child(_navigation_icon("nav_horizontal.svg", "Return to the Skill command"))
	row.add_child(_hint_label("B / Esc  Back"))


func _navigation_icon(file_name: String, tooltip: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = file_name.get_basename().to_pascal_case()
	icon.custom_minimum_size = Vector2(17.0, 17.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = tooltip
	icon.self_modulate = UI.SUBTLE
	var path := "%s/%s" % [NAV_ICON_ROOT, file_name]
	if ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
	return icon


func _hint_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", UI.SUBTLE)
	UI.apply_body_font(label)
	return label


func _hint_separator() -> ColorRect:
	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(1.0, 12.0)
	separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.color = Color(UI.SUBTLE.r, UI.SUBTLE.g, UI.SUBTLE.b, 0.28)
	return separator
