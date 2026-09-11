extends Node
class_name CombatPreviewArrowDecorator

const UI = preload("res://src/ui/TacticalTheme.gd")
const HP_ARROW_TEXTURE = preload("res://assets/ui/icons/hp_change_arrow.svg")

var _overlay: Control = null
var _preview_panel: Control = null
var _legacy_damage: Label = null
var _row: HBoxContainer = null
var _damage_label: Label = null
var _hp_before_label: Label = null
var _hp_arrow: TextureRect = null
var _hp_after_label: Label = null


func setup(overlay: Control) -> void:
	_overlay = overlay
	if _overlay == null:
		queue_free()
		return
	_preview_panel = _overlay.get_node_or_null("ActionPreview") as Control
	if _preview_panel == null:
		queue_free()
		return

	var preview_labels: Array[Label] = []
	for child in _preview_panel.get_children():
		if child is Label:
			preview_labels.append(child as Label)
	if preview_labels.size() < 3:
		queue_free()
		return

	# CombatOverlayHUD historically rendered the HP transition inside one Label
	# using the Unicode right-arrow glyph. Some Web/font combinations do not
	# contain that glyph, so keep the data source but replace only that visual row.
	_legacy_damage = preview_labels[2]
	_legacy_damage.visible = false
	_build_row()
	set_process(true)
	_sync_preview()


func _process(_delta: float) -> void:
	_sync_preview()


func _build_row() -> void:
	_row = HBoxContainer.new()
	_row.name = "DamagePreviewWithArrow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.anchor_left = 0.0
	_row.anchor_top = 0.0
	_row.anchor_right = 1.0
	_row.anchor_bottom = 0.0
	_row.offset_left = 14.0
	_row.offset_top = 57.0
	_row.offset_right = -14.0
	_row.offset_bottom = 85.0
	_row.add_theme_constant_override("separation", 6)
	_preview_panel.add_child(_row)

	_damage_label = _make_label("", 20, Color.WHITE)
	_row.add_child(_damage_label)

	_hp_before_label = _make_label("", 20, Color.WHITE)
	_row.add_child(_hp_before_label)

	_hp_arrow = TextureRect.new()
	_hp_arrow.name = "HpChangeArrow"
	_hp_arrow.custom_minimum_size = Vector2(18.0, 18.0)
	_hp_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hp_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hp_arrow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_hp_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_arrow.texture = HP_ARROW_TEXTURE
	_hp_arrow.self_modulate = UI.GOLD
	_row.add_child(_hp_arrow)

	_hp_after_label = _make_label("", 20, Color.WHITE)
	_row.add_child(_hp_after_label)


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	UI.apply_body_font(label)
	return label


func _sync_preview() -> void:
	if _row == null or _preview_panel == null or not is_instance_valid(_preview_panel):
		return
	if not _preview_panel.visible:
		_row.visible = false
		return
	if _overlay == null or not is_instance_valid(_overlay):
		_row.visible = false
		return
	var controller = _overlay.get("_controller") as Node
	if controller == null or not controller.has_method("get_combat_preview"):
		_row.visible = false
		return
	var preview: Dictionary = controller.call("get_combat_preview")
	if preview.is_empty() or not bool(preview.get("valid", false)):
		_row.visible = false
		return

	_row.visible = true
	var damage := int(preview.get("damage", 0))
	if damage <= 0:
		_damage_label.text = "Support action"
		_hp_before_label.visible = false
		_hp_arrow.visible = false
		_hp_after_label.visible = false
		return

	_damage_label.text = "%d damage   •   HP" % damage
	_hp_before_label.text = str(int(preview.get("target_hp", 0)))
	_hp_after_label.text = str(int(preview.get("target_hp_after", 0)))
	_hp_before_label.visible = true
	_hp_arrow.visible = true
	_hp_after_label.visible = true
