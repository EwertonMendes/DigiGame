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

var _card: Panel = null
var _eyebrow: Label = null
var _portrait: TextureRect = null
var _name_label: Label = null
var _level_label: Label = null
var _rank_label: Label = null
var _attribute_label: Label = null
var _hp_bar: ProgressBar = null
var _sp_bar: ProgressBar = null
var _hp_label: Label = null
var _sp_label: Label = null
var _mov_label: Label = null
var _spd_label: Label = null
var _team_marker: ColorRect = null


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
	var viewport := get_viewport().get_visible_rect().size
	if viewport != _last_viewport_size:
		_layout_card()
	if not _card.visible or _frame_count <= 1 or _portrait_atlas == null:
		return
	_frame_elapsed += delta
	var duration := _frame_duration_seconds()
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
	_card.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.93, 0.48, 10, 9))
	add_child(_card)

	_team_marker = ColorRect.new()
	_team_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_team_marker)

	_eyebrow = _label("ACTIVE UNIT", 9, UI.MUTED)
	_card.add_child(_eyebrow)

	var portrait_frame := Panel.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", UI.panel(UI.CYAN, 0.94, 0.48, 7, 2))
	_card.add_child(portrait_frame)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_portrait)

	_name_label = _label("DIGIMON", 20, UI.TEXT)
	_name_label.clip_text = true
	_card.add_child(_name_label)
	_level_label = _label("LV 1", 10, UI.CYAN)
	_card.add_child(_level_label)
	_rank_label = _chip("ROOKIE", UI.CYAN)
	_card.add_child(_rank_label)
	_attribute_label = _label("UNKNOWN", 9, UI.MUTED)
	_card.add_child(_attribute_label)

	_hp_bar = _progress(UI.GREEN)
	_sp_bar = _progress(UI.BLUE)
	_card.add_child(_hp_bar)
	_card.add_child(_sp_bar)
	_hp_label = _label("HP", 9, UI.TEXT)
	_sp_label = _label("SP", 9, UI.TEXT)
	_card.add_child(_hp_label)
	_card.add_child(_sp_label)

	_mov_label = _chip("MOV 4", UI.CYAN)
	_spd_label = _chip("SPD 1", UI.PURPLE)
	_card.add_child(_mov_label)
	_card.add_child(_spd_label)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _chip(text_value: String, accent: Color) -> Label:
	var label := _label(text_value, 9, UI.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", UI.pill(accent, 0.11))
	return label


func _progress(accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.08, 0.11, 0.88)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _on_hovered_digimon_changed(_digimon_key: String) -> void:
	_refresh_context()


func _refresh_context() -> void:
	var actor: Node = null
	var hovered := false
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
	_eyebrow.text = "FIELD INSPECT" if hovered else "ACTIVE UNIT"
	var player_team := bool(actor.get("is_player_controlled"))
	var accent := UI.CYAN if player_team else UI.RED
	_team_marker.color = accent
	_card.add_theme_stylebox_override("panel", UI.panel(accent, 0.93, 0.48, 10, 9))

	var actor_name := String(actor.get("digimon_key")).capitalize()
	if actor.has_method("get_display_name"):
		actor_name = String(actor.call("get_display_name"))
	var level := int(actor.call("get_level")) if actor.has_method("get_level") else 1
	var species_data: Dictionary = actor.get("species_data") if actor.get("species_data") is Dictionary else {}
	var rank := String(species_data.get("rank", "Unknown"))
	var attribute := String(species_data.get("attribute", "Unknown"))
	var species := String(species_data.get("species", ""))

	_name_label.text = actor_name.to_upper()
	_level_label.text = "LV %d" % level
	_rank_label.text = rank.to_upper()
	var rank_accent := UI.rank_color(rank)
	_rank_label.add_theme_stylebox_override("normal", UI.pill(rank_accent, 0.12))
	_rank_label.add_theme_color_override("font_color", rank_accent.lightened(0.16))
	_attribute_label.text = "%s%s" % [attribute.to_upper(), "  •  %s" % species.to_upper() if not species.is_empty() else ""]

	var max_hp := maxi(1, int(actor.call("get_final_stat", "hp"))) if actor.has_method("get_final_stat") else 1
	var max_sp := maxi(1, int(actor.call("get_final_stat", "mp"))) if actor.has_method("get_final_stat") else 1
	var current_hp := max_hp
	var current_sp := max_sp
	var battle_state = actor.get("battle_state")
	if battle_state != null:
		current_hp = int(battle_state.get("current_hp"))
		current_sp = int(battle_state.get("current_mp"))
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(current_hp, 0, max_hp)
	_sp_bar.max_value = max_sp
	_sp_bar.value = clampi(current_sp, 0, max_sp)
	_hp_label.text = "HP   %d / %d" % [current_hp, max_hp]
	_sp_label.text = "SP   %d / %d" % [current_sp, max_sp]
	var mov := int(actor.call("get_final_mov")) if actor.has_method("get_final_mov") else 4
	var speed := int(actor.call("get_final_stat", "speed")) if actor.has_method("get_final_stat") else 1
	_mov_label.text = "MOV %d" % mov
	_spd_label.text = "SPD %d" % speed

	var actor_key := String(actor.get("digimon_key")).to_lower()
	if actor_key != _current_key:
		_current_key = actor_key
		_load_portrait_animation(actor_key)
		_animate_in()
	_card.visible = true
	_layout_card()


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
	var metadata_path := "%s/%s/portrait_frames.json" % [PORTRAIT_ROOT, digimon_key]
	var strip_path := "%s/%s/portrait_frames.png" % [PORTRAIT_ROOT, digimon_key]
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(strip_path):
		return
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary:
		return
	var strip := load(strip_path) as Texture2D
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
	var viewport := get_viewport().get_visible_rect().size
	_last_viewport_size = viewport
	var compact := viewport.x < COMPACT_BREAKPOINT
	var right_rail_guard := 108.0 if compact else 148.0
	var width := minf(304.0, viewport.x - right_rail_guard - 16.0)
	width = maxf(214.0, width)
	var height := 176.0 if compact else 222.0
	_card.position = Vector2(10.0 if compact else 14.0, 70.0 if compact else 74.0)
	_card.size = Vector2(width, height)
	_team_marker.position = Vector2(0.0, 22.0)
	_team_marker.size = Vector2(3.0, height - 44.0)
	_eyebrow.position = Vector2(12.0, 6.0)
	_eyebrow.size = Vector2(width - 24.0, 16.0)

	var portrait_frame := _card.get_node("PortraitFrame") as Panel
	var portrait_size := Vector2(68.0, 68.0) if compact else Vector2(96.0, 100.0)
	portrait_frame.position = Vector2(12.0, 28.0)
	portrait_frame.size = portrait_size
	_portrait.position = Vector2(3.0, 3.0)
	_portrait.size = portrait_size - Vector2(6.0, 6.0)

	var identity_x := portrait_frame.position.x + portrait_size.x + 10.0
	var identity_w := width - identity_x - 10.0
	_name_label.position = Vector2(identity_x, 28.0)
	_name_label.size = Vector2(identity_w, 27.0)
	_name_label.add_theme_font_size_override("font_size", 16 if compact else 20)
	_level_label.position = Vector2(identity_x, 53.0)
	_level_label.size = Vector2(52.0, 18.0)
	_rank_label.position = Vector2(identity_x + 54.0, 52.0)
	_rank_label.size = Vector2(maxf(54.0, identity_w - 54.0), 20.0)
	_attribute_label.position = Vector2(identity_x, 75.0)
	_attribute_label.size = Vector2(identity_w, 18.0)
	_attribute_label.add_theme_font_size_override("font_size", 7 if compact else 9)

	var bars_y := 106.0 if compact else 137.0
	var bar_left := 12.0
	var bar_width := width - 24.0
	_hp_label.position = Vector2(bar_left, bars_y)
	_hp_label.size = Vector2(bar_width, 16.0)
	_hp_bar.position = Vector2(bar_left, bars_y + 16.0)
	_hp_bar.size = Vector2(bar_width, 7.0)
	_sp_label.position = Vector2(bar_left, bars_y + 27.0)
	_sp_label.size = Vector2(bar_width, 16.0)
	_sp_bar.position = Vector2(bar_left, bars_y + 43.0)
	_sp_bar.size = Vector2(bar_width, 7.0)
	_hp_label.add_theme_font_size_override("font_size", 7 if compact else 9)
	_sp_label.add_theme_font_size_override("font_size", 7 if compact else 9)

	var chip_y := height - 28.0
	_mov_label.position = Vector2(width - 126.0, chip_y)
	_mov_label.size = Vector2(56.0, 20.0)
	_spd_label.position = Vector2(width - 66.0, chip_y)
	_spd_label.size = Vector2(56.0, 20.0)
	if compact:
		_mov_label.position.y = 101.0
		_spd_label.position.y = 101.0


func _animate_in() -> void:
	if _card == null:
		return
	_card.modulate = Color(1.0, 1.0, 1.0, 0.25)
	_card.position.x -= 8.0
	var target_x := 10.0 if get_viewport().get_visible_rect().size.x < COMPACT_BREAKPOINT else 14.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, 0.14)
	tween.tween_property(_card, "position:x", target_x, 0.14)
