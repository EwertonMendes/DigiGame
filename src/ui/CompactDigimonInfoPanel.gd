extends "res://src/DigimonInfoPanel.gd"

const CompactUI = preload("res://src/ui/TacticalTheme.gd")
const CARD_BREAKPOINT := 760.0

var _pointer_tail: ColorRect = null
var _bubble_below_actor := false
var _entry_offset_y := 0.0
var _entry_tween: Tween = null
var _last_hover_instance_id := 0


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

	# Hover is a compact tactical glance, not a second full character sheet.
	# Keep identity/rank plus battle resources that the player is allowed to know.
	_eyebrow.visible = false
	_team_tag.visible = false
	_level_label.visible = false
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
	# The bubble follows the hovered actor while the camera pans/zooms. Entry
	# motion is expressed as an offset so following the actor cannot cancel it.
	if _card != null and _card.visible:
		_layout_card()


func _refresh_context() -> void:
	var was_visible := _card != null and _card.visible

	# DigimonInfoPanel owns portrait/data refresh. Its old lateral animation is
	# overridden below so it can never flash at the legacy left-side position.
	super._refresh_context()
	if _card == null:
		return

	var hovered: Node = null
	if _digimon_controller != null and _digimon_controller.has_method("get_hovered_digimon"):
		hovered = _digimon_controller.call("get_hovered_digimon") as Node

	if hovered == null or not is_instance_valid(hovered):
		_card.visible = false
		_last_hover_instance_id = 0
		_entry_offset_y = 0.0
		if _entry_tween != null and _entry_tween.is_valid():
			_entry_tween.kill()
		return

	_card.visible = true
	var player_team := bool(hovered.get("is_player_controlled"))
	var accent := CompactUI.BLUE if player_team else CompactUI.RED

	var actor_name := String(hovered.get("digimon_key")).capitalize()
	if hovered.has_method("get_display_name"):
		actor_name = String(hovered.call("get_display_name"))
	var level := int(hovered.call("get_level")) if hovered.has_method("get_level") else 1
	_name_label.text = "%s  ·  Lv.%d" % [actor_name.capitalize(), level]
	_level_label.visible = false

	var raw_species = hovered.get("species_data")
	var species_data: Dictionary = raw_species if raw_species is Dictionary else {}
	var rank := String(species_data.get("rank", "Unknown"))
	var rank_accent := CompactUI.rank_color(rank)
	_rank_label.text = rank.capitalize()
	_rank_label.visible = true
	_rank_label.add_theme_stylebox_override("normal", CompactUI.pill(rank_accent, 0.14))
	_rank_label.add_theme_color_override("font_color", rank_accent.lightened(0.16))

	# Allied SP is useful tactical information. Enemy SP intentionally remains
	# hidden so the player cannot inspect a resource they should not know.
	_sp_caption.visible = player_team
	_sp_value.visible = player_team
	_sp_bar.visible = player_team

	_card.add_theme_stylebox_override("panel", CompactUI.glass_panel(accent, 0.88, 12))
	_portrait_frame.add_theme_stylebox_override("panel", _avatar_style(accent))
	if _pointer_tail != null:
		_pointer_tail.color = Color(CompactUI.GLASS.r, CompactUI.GLASS.g, CompactUI.GLASS.b, 0.94)

	_layout_card()
	var hover_instance_id := hovered.get_instance_id()
	if not was_visible or hover_instance_id != _last_hover_instance_id:
		_play_bubble_entry()
	_last_hover_instance_id = hover_instance_id


# DigimonInfoPanel animates its legacy fixed card horizontally from x=10/16.
# Suppress that inherited transition completely; this subclass owns a local,
# actor-anchored fade/slide instead.
func _animate_in() -> void:
	pass


func _play_bubble_entry() -> void:
	if _card == null or not _card.visible:
		return
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()

	_entry_offset_y = 10.0
	_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_layout_card()

	_entry_tween = create_tween().set_parallel(true)
	_entry_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_entry_tween.tween_method(Callable(self, "_set_entry_offset_y"), 10.0, 0.0, 0.18)
	_entry_tween.tween_property(_card, "modulate:a", 1.0, 0.16)


func _set_entry_offset_y(value: float) -> void:
	_entry_offset_y = value
	if _card != null and _card.visible:
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
	var player_team := bool(_current_actor.get("is_player_controlled"))

	var width := 324.0 if not compact else minf(304.0, physical.x - 18.0)
	var height := 108.0 if player_team else 88.0
	var canvas_actor := _current_actor as CanvasItem
	if canvas_actor == null:
		return
	var anchor := canvas_actor.get_global_transform_with_canvas().origin
	var desired_x := anchor.x - width * 0.5
	var desired_y := anchor.y - height - 58.0
	_bubble_below_actor = desired_y < 62.0
	if _bubble_below_actor:
		desired_y = anchor.y + 48.0

	# Keep the bubble clear of screen edges and the turn timeline while still
	# visually pointing at the hovered Digimon.
	var right_guard := 88.0 if not compact else 10.0
	var max_x := maxf(8.0, physical.x - width - right_guard)
	var max_y := maxf(8.0, physical.y - height - 12.0)
	var card_x := clampf(desired_x, 8.0, max_x)
	var card_y := clampf(desired_y, 58.0 if not compact else 52.0, max_y)

	_card.scale = Vector2.ONE * ui_scale
	_card.position = Vector2(card_x * ui_scale, (card_y + _entry_offset_y) * ui_scale)
	_card.size = Vector2(width, height)

	# Prominent rounded avatar. clip_contents guarantees the full portrait stays
	# inside the rounded frame instead of visually leaking into the bubble.
	var portrait_side := 76.0
	_portrait_frame.position = Vector2(8.0, (height - portrait_side) * 0.5)
	_portrait_frame.size = Vector2(portrait_side, portrait_side)
	_portrait_frame.clip_contents = true
	_portrait.position = Vector2(5.0, 5.0)
	_portrait.size = Vector2(portrait_side - 10.0, portrait_side - 10.0)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var info_x := 96.0
	var info_w := width - info_x - 10.0
	var rank_w := 72.0

	_name_label.position = Vector2(info_x, 9.0)
	_name_label.size = Vector2(maxf(92.0, info_w - rank_w - 8.0), 27.0)
	_name_label.add_theme_font_size_override("font_size", 17 if not compact else 16)
	_name_label.clip_text = true

	_rank_label.position = Vector2(width - rank_w - 10.0, 9.0)
	_rank_label.size = Vector2(rank_w, 25.0)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.add_theme_font_size_override("font_size", 11)

	var value_w := 66.0
	var caption_w := 25.0
	var bar_x := info_x + caption_w + 5.0
	var bar_w := maxf(54.0, info_w - caption_w - value_w - 10.0)

	var hp_y := 43.0 if player_team else 48.0
	_hp_caption.position = Vector2(info_x, hp_y)
	_hp_caption.size = Vector2(caption_w, 20.0)
	_hp_caption.add_theme_font_size_override("font_size", 12)
	_hp_bar.position = Vector2(bar_x, hp_y + 6.0)
	_hp_bar.size = Vector2(bar_w, 8.0)
	_hp_value.position = Vector2(width - value_w - 10.0, hp_y - 1.0)
	_hp_value.size = Vector2(value_w, 22.0)
	_hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_value.add_theme_font_size_override("font_size", 12)

	if player_team:
		var sp_y := 69.0
		_sp_caption.position = Vector2(info_x, sp_y)
		_sp_caption.size = Vector2(caption_w, 20.0)
		_sp_caption.add_theme_font_size_override("font_size", 12)
		_sp_bar.position = Vector2(bar_x, sp_y + 6.0)
		_sp_bar.size = Vector2(bar_w, 8.0)
		_sp_value.position = Vector2(width - value_w - 10.0, sp_y - 1.0)
		_sp_value.size = Vector2(value_w, 22.0)
		_sp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_sp_value.add_theme_font_size_override("font_size", 12)

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
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 2.0)
	return style
