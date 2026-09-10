extends Control

const UI = preload("res://src/ui/TacticalTheme.gd")
const PORTRAIT_ROOT := "res://assets/characters"
const COMPACT_BREAKPOINT := 760.0

var _digimon_controller: Node = null
var _battle_controller: Node = null
var _current_actor: Node = null
var _current_key := ""
var _portrait_atlas: AtlasTexture = null
var _frame_size := Vector2.ZERO
var _frame_count := 0
var _frame_durations: Array = []
var _frame_index := 0
var _frame_elapsed := 0.0
var _last_viewport_size := Vector2.ZERO
var _last_window_size := Vector2i.ZERO

var _card: Panel = null
var _team_marker: ColorRect = null
var _signal_line: ColorRect = null
var _eyebrow: Label = null
var _team_tag: Label = null
var _portrait_frame: Panel = null
var _portrait: TextureRect = null
var _name_label: Label = null
var _level_label: Label = null
var _rank_label: Label = null
var _attribute_label: Label = null
var _species_label: Label = null
var _divider: ColorRect = null
var _hp_caption: Label = null
var _hp_value: Label = null
var _sp_caption: Label = null
var _sp_value: Label = null
var _hp_bar: ProgressBar = null
var _sp_bar: ProgressBar = null
var _mov_label: Label = null
var _spd_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_digimon_controller = get_node_or_null("../../DigimonController")
	_battle_controller = get_node_or_null("../../BattleController")
	if _digimon_controller != null and _digimon_controller.has_signal("hovered_digimon_changed"):
		_digimon_controller.connect("hovered_digimon_changed", _on_hovered_digimon_changed)
	if _battle_controller != null and _battle_controller.has_signal("turn_order_changed"):
		_battle_controller.connect("turn_order_changed", _refresh_context)
	get_viewport().size_changed.connect(_layout_card)
	set_process(true)
	call_deferred("_refresh_context")


func _process(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if viewport_size != _last_viewport_size or window_size != _last_window_size:
		_layout_card()
	if _card == null or not _card.visible or _frame_count <= 1 or _portrait_atlas == null:
		return
	_frame_elapsed += delta
	var duration: float = _frame_duration_seconds()
	while _frame_elapsed >= duration:
		_frame_elapsed -= duration
		_frame_index = (_frame_index + 1) % _frame_count
		_apply_portrait_frame()
		duration = _frame_duration_seconds()


func _build_ui() -> void:
	_card = Panel.new()
	_card.name = "DigimonContextCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_card.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.955, 0.56, 12, 12))
	add_child(_card)

	_signal_line = ColorRect.new()
	_signal_line.color = UI.CYAN
	_signal_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_signal_line)

	_team_marker = ColorRect.new()
	_team_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_team_marker)

	_eyebrow = _label("ACTIVE UNIT", 11, UI.MUTED, true)
	_card.add_child(_eyebrow)
	_team_tag = _chip("ALLY", UI.CYAN, true)
	_card.add_child(_team_tag)

	_portrait_frame = Panel.new()
	_portrait_frame.name = "PortraitFrame"
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.96, 0.70, 9, 3))
	_card.add_child(_portrait_frame)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)

	_name_label = _label("DIGIMON", 26, UI.TEXT, true)
	_name_label.clip_text = true
	_card.add_child(_name_label)
	_level_label = _label("LV 1", 13, UI.CYAN, true)
	_card.add_child(_level_label)
	_rank_label = _chip("ROOKIE", UI.CYAN, true)
	_card.add_child(_rank_label)
	_attribute_label = _label("VACCINE", 12, UI.TEXT, true)
	_attribute_label.clip_text = true
	_card.add_child(_attribute_label)
	_species_label = _label("DRAGON", 11, UI.MUTED, false)
	_species_label.clip_text = true
	_card.add_child(_species_label)

	_divider = ColorRect.new()
	_divider.color = UI.separator(UI.CYAN, 0.28)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_divider)

	_hp_caption = _label("HP", 11, UI.GREEN, true)
	_hp_value = _label("0 / 0", 11, UI.TEXT, true)
	_hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sp_caption = _label("SP", 11, UI.BLUE.lightened(0.18), true)
	_sp_value = _label("0 / 0", 11, UI.TEXT, true)
	_sp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_hp_caption)
	_card.add_child(_hp_value)
	_card.add_child(_sp_caption)
	_card.add_child(_sp_value)

	_hp_bar = _progress(UI.GREEN)
	_sp_bar = _progress(UI.BLUE)
	_card.add_child(_hp_bar)
	_card.add_child(_sp_bar)

	_mov_label = _chip("MOV 4", UI.CYAN, true)
	_spd_label = _chip("SPD 1", UI.PURPLE, true)
	_card.add_child(_mov_label)
	_card.add_child(_spd_label)


func _label(text_value: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heading:
		UI.apply_heading_font(label)
	else:
		UI.apply_body_font(label)
	return label


func _chip(text_value: String, accent: Color, heading: bool = false) -> Label:
	var label: Label = _label(text_value, 11, UI.TEXT, heading)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", UI.pill(accent, 0.14))
	return label


func _progress(accent: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.025, 0.075, 0.105, 0.96)
	bg.corner_radius_top_left = 5
	bg.corner_radius_top_right = 5
	bg.corner_radius_bottom_left = 5
	bg.corner_radius_bottom_right = 5
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 5
	fill.corner_radius_top_right = 5
	fill.corner_radius_bottom_left = 5
	fill.corner_radius_bottom_right = 5
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _on_hovered_digimon_changed(_digimon_key: String) -> void:
	_refresh_context()


func _refresh_context() -> void:
	var actor: Node = null
	var hovered: bool = false
	if _digimon_controller != null and _digimon_controller.has_method("get_hovered_digimon"):
		actor = _digimon_controller.call("get_hovered_digimon") as Node
		hovered = actor != null
	if actor == null and _battle_controller != null:
		actor = _battle_controller.get("current_actor") as Node
	if actor == null or not is_instance_valid(actor):
		_card.visible = false
		_current_actor = null
		return

	_current_actor = actor
	var player_team: bool = bool(actor.get("is_player_controlled"))
	var accent: Color = UI.CYAN if player_team else UI.RED
	_eyebrow.text = "FIELD INSPECT" if hovered else "ACTIVE UNIT"
	_eyebrow.add_theme_color_override("font_color", accent.lightened(0.20) if hovered else UI.MUTED)
	_team_tag.text = "ALLY" if player_team else "ENEMY"
	_team_tag.add_theme_stylebox_override("normal", UI.pill(accent, 0.16))
	_team_tag.add_theme_color_override("font_color", accent.lightened(0.22))
	_team_marker.color = accent
	_signal_line.color = accent
	_card.add_theme_stylebox_override("panel", UI.panel(accent, 0.955, 0.58, 12, 12))
	_portrait_frame.add_theme_stylebox_override("panel", UI.panel(accent, 0.97, 0.72, 9, 3))

	var actor_name: String = String(actor.get("digimon_key")).capitalize()
	if actor.has_method("get_display_name"):
		actor_name = String(actor.call("get_display_name"))
	var level: int = int(actor.call("get_level")) if actor.has_method("get_level") else 1
	var raw_species = actor.get("species_data")
	var species_data: Dictionary = raw_species if raw_species is Dictionary else {}
	var rank: String = String(species_data.get("rank", "Unknown"))
	var attribute: String = String(species_data.get("attribute", "Unknown"))
	var species: String = String(species_data.get("species", "Unknown"))

	_name_label.text = actor_name.to_upper()
	_level_label.text = "LV %d" % level
	_level_label.add_theme_color_override("font_color", accent.lightened(0.16))
	_rank_label.text = rank.to_upper()
	var rank_accent: Color = UI.rank_color(rank)
	_rank_label.add_theme_stylebox_override("normal", UI.pill(rank_accent, 0.15))
	_rank_label.add_theme_color_override("font_color", rank_accent.lightened(0.16))
	_attribute_label.text = attribute.to_upper()
	_species_label.text = species.to_upper()

	var max_hp: int = maxi(1, int(actor.call("get_final_stat", "hp"))) if actor.has_method("get_final_stat") else 1
	var max_sp: int = maxi(1, int(actor.call("get_final_stat", "mp"))) if actor.has_method("get_final_stat") else 1
	var current_hp: int = max_hp
	var current_sp: int = max_sp
	var battle_state = actor.get("battle_state")
	if battle_state != null:
		current_hp = int(battle_state.get("current_hp"))
		current_sp = int(battle_state.get("current_mp"))
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(current_hp, 0, max_hp)
	_sp_bar.max_value = max_sp
	_sp_bar.value = clampi(current_sp, 0, max_sp)
	_hp_value.text = "%d / %d" % [current_hp, max_hp]
	_sp_value.text = "%d / %d" % [current_sp, max_sp]

	var mov: int = int(actor.call("get_final_mov")) if actor.has_method("get_final_mov") else 4
	var speed: int = int(actor.call("get_final_stat", "speed")) if actor.has_method("get_final_stat") else 1
	_mov_label.text = "MOV  %d" % mov
	_spd_label.text = "SPD  %d" % speed

	var actor_key: String = String(actor.get("digimon_key")).to_lower()
	var visual_key: String = "%s:%s" % [actor_key, str(actor.get_instance_id())]
	var actor_changed: bool = visual_key != _current_key
	if actor_changed:
		_current_key = visual_key
		_load_portrait_animation(actor_key)
	_card.visible = true
	_layout_card()
	if actor_changed:
		_animate_in()


func _load_portrait_animation(digimon_key: String) -> void:
	_portrait.texture = null
	_portrait_atlas = null
	_frame_size = Vector2.ZERO
	_frame_count = 0
	_frame_durations = []
	_frame_index = 0
	_frame_elapsed = 0.0
	if digimon_key.is_empty():
		return
	var metadata_path: String = "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]
	var strip_path: String = "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(strip_path):
		return
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary:
		return
	var strip: Texture2D = load(strip_path) as Texture2D
	if strip == null:
		return
	_frame_size = Vector2(float(metadata.get("frame_width", 0)), float(metadata.get("frame_height", 0)))
	_frame_count = int(metadata.get("frame_count", 0))
	_frame_durations = metadata.get("durations_ms", [])
	if _frame_size.x <= 0.0 or _frame_size.y <= 0.0 or _frame_count <= 0:
		return
	_portrait_atlas = AtlasTexture.new()
	_portrait_atlas.atlas = strip
	_portrait.texture = _portrait_atlas
	_apply_portrait_frame()


func _frame_duration_seconds() -> float:
	if _frame_index < _frame_durations.size():
		return maxf(0.02, float(_frame_durations[_frame_index]) / 1000.0)
	return 0.1


func _apply_portrait_frame() -> void:
	if _portrait_atlas == null:
		return
	_portrait_atlas.region = Rect2(_frame_size.x * _frame_index, 0.0, _frame_size.x, _frame_size.y)


func _layout_card() -> void:
	if _card == null:
		return
	var viewport_obj: Viewport = get_viewport()
	var logical: Vector2 = viewport_obj.get_visible_rect().size
	var physical: Vector2 = UI.physical_window_size(viewport_obj)
	var ui_scale: float = UI.ui_scale(viewport_obj)
	_last_viewport_size = logical
	_last_window_size = DisplayServer.window_get_size()
	var compact: bool = UI.is_compact(viewport_obj, COMPACT_BREAKPOINT)
	var short_landscape: bool = compact and physical.x > physical.y and physical.y < 560.0
	var laptop: bool = UI.is_laptop(viewport_obj)

	var right_guard: float = 112.0 if compact else 174.0
	var width: float = 286.0 if compact else (390.0 if laptop else 372.0)
	if short_landscape:
		width = 292.0
	width = minf(width, physical.x - right_guard - 20.0)
	width = maxf(228.0, width)
	var height: float = 210.0 if compact else (282.0 if laptop else 270.0)
	if short_landscape:
		height = 196.0
	var card_x: float = 10.0 if compact else 16.0
	var card_y: float = 60.0 if compact else 82.0
	if short_landscape:
		card_y = 58.0

	_card.scale = Vector2.ONE * ui_scale
	_card.position = Vector2(card_x * ui_scale, card_y * ui_scale)
	_card.size = Vector2(width, height)
	_team_marker.position = Vector2(0.0, 34.0)
	_team_marker.size = Vector2(4.0, height - 62.0)
	_signal_line.position = Vector2(16.0, 0.0)
	_signal_line.size = Vector2(92.0 if compact else 118.0, 2.0)
	_eyebrow.position = Vector2(16.0, 9.0)
	_eyebrow.size = Vector2(width - 100.0, 19.0)
	_team_tag.size = Vector2(64.0 if compact else 72.0, 23.0)
	_team_tag.position = Vector2(width - _team_tag.size.x - 14.0, 7.0)

	var portrait_size: Vector2 = Vector2(72.0, 72.0) if compact else Vector2(108.0, 108.0)
	if short_landscape:
		portrait_size = Vector2(66.0, 66.0)
	_portrait_frame.position = Vector2(16.0, 39.0)
	_portrait_frame.size = portrait_size
	_portrait.position = Vector2(4.0, 4.0)
	_portrait.size = portrait_size - Vector2(8.0, 8.0)

	var identity_x: float = _portrait_frame.position.x + portrait_size.x + 14.0
	var identity_w: float = width - identity_x - 16.0
	_name_label.position = Vector2(identity_x, 38.0)
	_name_label.size = Vector2(identity_w, 32.0 if not compact else 26.0)
	_name_label.add_theme_font_size_override("font_size", 19 if compact else (27 if laptop else 25))

	_level_label.position = Vector2(identity_x, 69.0 if not compact else 64.0)
	_level_label.size = Vector2(52.0, 22.0)
	_level_label.add_theme_font_size_override("font_size", 11 if compact else 14)
	_rank_label.position = Vector2(identity_x + 58.0, 68.0 if not compact else 63.0)
	_rank_label.size = Vector2(maxf(64.0, identity_w - 58.0), 24.0)
	_rank_label.add_theme_font_size_override("font_size", 9 if compact else 11)

	_attribute_label.position = Vector2(identity_x, 95.0 if not compact else 88.0)
	_attribute_label.size = Vector2(identity_w, 20.0)
	_attribute_label.add_theme_font_size_override("font_size", 10 if compact else 12)
	_species_label.position = Vector2(identity_x, 114.0 if not compact else 106.0)
	_species_label.size = Vector2(identity_w, 18.0)
	_species_label.add_theme_font_size_override("font_size", 9 if compact else 11)

	var stats_y: float = 122.0 if compact else 158.0
	if short_landscape:
		stats_y = 112.0
	_divider.position = Vector2(16.0, stats_y - 10.0)
	_divider.size = Vector2(width - 32.0, 1.0)

	var caption_w: float = 30.0
	var value_w: float = 76.0 if compact else 92.0
	var bar_x: float = 16.0 + caption_w + 8.0
	var bar_w: float = width - bar_x - value_w - 22.0
	var row_gap: float = 34.0 if compact else 39.0
	var bar_h: float = 8.0 if compact else 10.0

	_hp_caption.position = Vector2(16.0, stats_y)
	_hp_caption.size = Vector2(caption_w, 18.0)
	_hp_value.position = Vector2(width - value_w - 16.0, stats_y)
	_hp_value.size = Vector2(value_w, 18.0)
	_hp_bar.position = Vector2(bar_x, stats_y + 5.0)
	_hp_bar.size = Vector2(maxf(40.0, bar_w), bar_h)

	_sp_caption.position = Vector2(16.0, stats_y + row_gap)
	_sp_caption.size = Vector2(caption_w, 18.0)
	_sp_value.position = Vector2(width - value_w - 16.0, stats_y + row_gap)
	_sp_value.size = Vector2(value_w, 18.0)
	_sp_bar.position = Vector2(bar_x, stats_y + row_gap + 5.0)
	_sp_bar.size = Vector2(maxf(40.0, bar_w), bar_h)

	for label: Label in [_hp_caption, _hp_value, _sp_caption, _sp_value]:
		label.add_theme_font_size_override("font_size", 10 if compact else 12)

	var chip_y: float = height - (31.0 if compact else 34.0)
	var chip_w: float = 72.0 if compact else 88.0
	var chip_h: float = 24.0 if compact else 27.0
	_spd_label.size = Vector2(chip_w, chip_h)
	_spd_label.position = Vector2(width - chip_w - 16.0, chip_y)
	_mov_label.size = Vector2(chip_w, chip_h)
	_mov_label.position = Vector2(_spd_label.position.x - chip_w - 8.0, chip_y)
	_mov_label.add_theme_font_size_override("font_size", 9 if compact else 11)
	_spd_label.add_theme_font_size_override("font_size", 9 if compact else 11)


func _animate_in() -> void:
	if _card == null:
		return
	var viewport_obj: Viewport = get_viewport()
	var ui_scale: float = UI.ui_scale(viewport_obj)
	var compact: bool = UI.is_compact(viewport_obj, COMPACT_BREAKPOINT)
	var target_x: float = (10.0 if compact else 16.0) * ui_scale
	_card.modulate = Color(1.0, 1.0, 1.0, 0.12)
	_card.position.x = target_x - 12.0 * ui_scale
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, 0.18)
	tween.tween_property(_card, "position:x", target_x, 0.18)
