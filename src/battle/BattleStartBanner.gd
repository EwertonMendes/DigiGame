extends Control
class_name BattleStartBanner

const UI = preload("res://src/ui/TacticalTheme.gd")
const DIVIDER_PATH := "res://assets/ui/kenney_fantasy_digi/divider-fade-000.png"

var _banner: Control = null
var _backdrop: Panel = null
var _left_divider: TextureRect = null
var _right_divider: TextureRect = null
var _kicker: Label = null
var _title: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_layout_ui)
	call_deferred("_layout_ui")


func play() -> void:
	visible = true
	modulate = Color.WHITE
	_layout_ui()

	_banner.modulate.a = 0.0
	_kicker.modulate.a = 0.0
	_title.modulate.a = 0.0
	_title.scale = Vector2.ONE * 0.96
	_left_divider.modulate.a = 0.0
	_right_divider.modulate.a = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_banner, "modulate:a", 1.0, 0.10)
	tween.parallel().tween_property(_kicker, "modulate:a", 1.0, 0.13).set_delay(0.02)
	tween.parallel().tween_property(_title, "modulate:a", 1.0, 0.15).set_delay(0.03)
	tween.parallel().tween_property(_title, "scale", Vector2.ONE, 0.16).set_delay(0.03)
	tween.parallel().tween_property(_left_divider, "modulate:a", 1.0, 0.14).set_delay(0.04)
	tween.parallel().tween_property(_right_divider, "modulate:a", 1.0, 0.14).set_delay(0.04)
	tween.tween_interval(0.62)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.15)
	await tween.finished

	visible = false
	_banner.modulate = Color.WHITE
	_kicker.modulate = Color.WHITE
	_title.modulate = Color.WHITE
	_left_divider.modulate = Color.WHITE
	_right_divider.modulate = Color.WHITE
	print("[BattleIntro] BATTLE_START")


func _build_ui() -> void:
	_banner = Control.new()
	_banner.name = "BattleStartBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	_backdrop = Panel.new()
	_backdrop.name = "Backdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop_style := StyleBoxFlat.new()
	backdrop_style.bg_color = Color(0.0, 0.0, 0.0, 0.42)
	backdrop_style.border_color = Color(UI.FRAME_DARK.r, UI.FRAME_DARK.g, UI.FRAME_DARK.b, 0.86)
	backdrop_style.border_width_bottom = 1
	_backdrop.add_theme_stylebox_override("panel", backdrop_style)
	_banner.add_child(_backdrop)

	var divider_texture := load(DIVIDER_PATH) as Texture2D
	_left_divider = TextureRect.new()
	_left_divider.name = "LeftDivider"
	_left_divider.texture = divider_texture
	_left_divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_left_divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_left_divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_left_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_left_divider)

	_right_divider = TextureRect.new()
	_right_divider.name = "RightDivider"
	_right_divider.texture = divider_texture
	_right_divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right_divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_right_divider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_right_divider.flip_h = true
	_right_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_right_divider)

	_kicker = Label.new()
	_kicker.name = "Kicker"
	_kicker.text = "Digital field"
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kicker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kicker.add_theme_color_override("font_color", UI.GOLD)
	_kicker.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	_kicker.add_theme_constant_override("outline_size", 2)
	UI.apply_body_font(_kicker)
	_banner.add_child(_kicker)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "Battle Started"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_color_override("font_color", UI.TEXT)
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.98))
	_title.add_theme_constant_override("outline_size", 3)
	UI.apply_heading_font(_title)
	_banner.add_child(_title)


func _layout_ui() -> void:
	if _banner == null:
		return
	var compact := size.y < 560.0 or size.x < 900.0
	var banner_width := minf(size.x * (0.88 if compact else 0.64), 680.0)
	var banner_height := 88.0 if compact else 102.0
	var center_y := size.y * 0.44
	_banner.position = Vector2((size.x - banner_width) * 0.5, center_y - banner_height * 0.5)
	_banner.size = Vector2(banner_width, banner_height)
	_backdrop.position = Vector2.ZERO
	_backdrop.size = _banner.size

	var kicker_height := 18.0
	_kicker.position = Vector2(24.0, 8.0 if compact else 10.0)
	_kicker.size = Vector2(banner_width - 48.0, kicker_height)
	_kicker.add_theme_font_size_override("font_size", 11 if compact else 12)

	var title_y := 24.0 if compact else 27.0
	var title_height := 46.0 if compact else 54.0
	_title.position = Vector2(118.0 if compact else 138.0, title_y)
	_title.size = Vector2(banner_width - (236.0 if compact else 276.0), title_height)
	_title.pivot_offset = _title.size * 0.5
	_title.add_theme_font_size_override("font_size", 30 if compact else 36)

	var divider_width := 92.0 if compact else 112.0
	var divider_height := 22.0 if compact else 26.0
	var divider_y := title_y + (title_height - divider_height) * 0.5
	var side_pad := 20.0 if compact else 28.0
	_left_divider.position = Vector2(side_pad, divider_y)
	_left_divider.size = Vector2(divider_width, divider_height)
	_right_divider.position = Vector2(banner_width - side_pad - divider_width, divider_y)
	_right_divider.size = Vector2(divider_width, divider_height)
