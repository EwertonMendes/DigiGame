extends "res://src/DigimonInfoPanel.gd"

const CompactUI = preload("res://src/ui/TacticalTheme.gd")
const CARD_BREAKPOINT := 760.0

var _pointer_tail: ColorRect = null
var _bubble_below_actor := false


func _ready() -> void:
	super._ready()
	_pointer_tail = ColorRect.new()
	_pointer_tail.name = "PointerTail"
	_pointer_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer_tail.size = Vector2(13.0, 13.0)
	_pointer_tail.pivot_offset = Vector2(6.5, 6.5)
	_pointer_tail.rotation = PI / 4.0
	_pointer_tail.color = Color(CompactUI.GLASS.r, CompactUI.GLASS.g, CompactUI.GLASS.b, 0.90)
	_card.add_child(_pointer_tail)

	# The hover surface is intentionally only two information rows beside a
	# prominent avatar. Everything else belongs to menus/details, not hover.
	_eyebrow.visible = false
	_team_tag.visible = false
	_rank_label.visible = false
	_attribute_label.visible = false
	_species_label.visible = false
	_divider.visible = false
	_sp_caption.visible = false
	_sp_value.visible = false
	_sp_bar.visible = false
	_mov_label.visible = false
	_spd_label.visible = false


func _process(delta: float) -> void:
	super._process(delta)
	# Unlike the old fixed inspection card, the bubble follows the hovered actor
	# while the camera pans/zooms, so its placement must be refreshed every frame.
	if _card != null and _card.visible:
		_layout_card()


func _refresh_context() -> void:
	super._refresh_context()
	if _card == null:
		return
	var hovered: Node = null
	if _digimon_controller != null and _digimon_controller.has_method("get_hovered_digimon"):
		hovered = _digimon_controller.call("get_hovered_digimon") as Node

	_card.visible = hovered != null and is_instance_valid(hovered)
	if not _card.visible:
		return

	_name_label.text = _name_label.text.capitalize()
	_level_label.text = _level_label.text.replace("LV ", "Lv.")
	var player_team := bool(hovered.get("is_player_controlled"))
	var accent := CompactUI.BLUE if player_team else CompactUI.RED
	_card.add_theme_stylebox_override("panel", CompactUI.glass_panel(accent, 0.88, 12))
	_portrait_frame.add_theme_stylebox_override("panel", _avatar_style(accent))
	if _pointer_tail != null:
		_pointer_tail.color = Color(CompactUI.GLASS.r, CompactUI.GLASS.g, CompactUI.GLASS.b, 0.94)
	_layout_card()


func _layout_card() -> void:
	if _card == null or not _card.visible or _current_actor == null or not is_instance_valid(_current_actor):
		return
	var viewport_obj := get_viewport()
	var logical := viewport_obj.get_visible_rect().size
	var physical := CompactUI.physical_window_size(viewport_obj)
	var ui_scale := CompactUI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var compact := CompactUI.is_compact(viewport_obj, CARD_BREAKPOINT)

	var width := 280.0 if not compact else minf(260.0, physical.x - 18.0)
	var height := 86.0
	var canvas_actor := _current_actor as CanvasItem
	if canvas_actor == null:
		return
	var anchor := canvas_actor.get_global_transform_with_canvas().origin
	var desired_x := anchor.x - width * 0.5
	var desired_y := anchor.y - height - 58.0
	_bubble_below_actor = desired_y < 62.0
	if _bubble_below_actor:
		desired_y = anchor.y + 48.0

	# Keep the tooltip clear of the turn timeline and command edges while still
	# visually pointing at the hovered Digimon.
	var right_guard := 88.0 if not compact else 10.0
	var max_x := maxf(8.0, physical.x - width - right_guard)
	var max_y := maxf(8.0, physical.y - height - 12.0)
	var card_x := clampf(desired_x, 8.0, max_x)
	var card_y := clampf(desired_y, 58.0 if not compact else 52.0, max_y)

	_card.scale = Vector2.ONE * ui_scale
	_card.position = Vector2(card_x * ui_scale, card_y * ui_scale)
	_card.size = Vector2(width, height)

	var portrait_side := 70.0
	_portrait_frame.position = Vector2(8.0, 8.0)
	_portrait_frame.size = Vector2(portrait_side, portrait_side)
	_portrait_frame.clip_contents = true
	_portrait.position = Vector2(5.0, 5.0)
	_portrait.size = Vector2(portrait_side - 10.0, portrait_side - 10.0)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var info_x := 90.0
	var info_w := width - info_x - 10.0
	_name_label.position = Vector2(info_x, 10.0)
	_name_label.size = Vector2(maxf(86.0, info_w - 58.0), 27.0)
	_name_label.add_theme_font_size_override("font_size", 18 if not compact else 17)
	_level_label.position = Vector2(width - 66.0, 11.0)
	_level_label.size = Vector2(56.0, 25.0)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_label.add_theme_font_size_override("font_size", 13)
	_level_label.add_theme_color_override("font_color", CompactUI.MUTED)

	_hp_caption.position = Vector2(info_x, 46.0)
	_hp_caption.size = Vector2(26.0, 22.0)
	_hp_caption.add_theme_font_size_override("font_size", 13)
	_hp_bar.position = Vector2(info_x + 30.0, 53.0)
	_hp_bar.size = Vector2(maxf(54.0, info_w - 106.0), 9.0)
	_hp_value.position = Vector2(width - 82.0, 45.0)
	_hp_value.size = Vector2(72.0, 23.0)
	_hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_value.add_theme_font_size_override("font_size", 13)

	# Place the pointer under/above the bubble at the actor's horizontal anchor.
	if _pointer_tail != null:
		var local_anchor_x := clampf(anchor.x - card_x, 24.0, width - 24.0)
		_pointer_tail.position.x = local_anchor_x - 6.5
		_pointer_tail.position.y = -5.0 if _bubble_below_actor else height - 8.0


func _avatar_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(CompactUI.GLASS_LIGHT.r, CompactUI.GLASS_LIGHT.g, CompactUI.GLASS_LIGHT.b, 0.84)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.88)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 17
	style.corner_radius_top_right = 17
	style.corner_radius_bottom_left = 17
	style.corner_radius_bottom_right = 17
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 2.0)
	return style
