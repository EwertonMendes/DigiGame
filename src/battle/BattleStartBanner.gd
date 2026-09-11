extends Control
class_name BattleStartBanner

const UI = preload("res://src/ui/TacticalTheme.gd")

var _frame: Panel = null
var _kicker: Label = null
var _title: Label = null
var _subtitle: Label = null
var _left_accent: ColorRect = null
var _right_accent: ColorRect = null
var _reveal := 0.0


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
	_reveal = 0.0
	_layout_ui()
	queue_redraw()

	var target_y := _frame.position.y
	_frame.modulate.a = 0.0
	_frame.position.y = target_y + 10.0
	_title.modulate.a = 0.0
	_title.scale = Vector2.ONE * 0.90
	_subtitle.modulate.a = 0.0
	_kicker.modulate.a = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_reveal, 0.0, 1.0, 0.22)
	tween.parallel().tween_property(_frame, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_frame, "position:y", target_y, 0.20)
	tween.parallel().tween_property(_kicker, "modulate:a", 1.0, 0.18).set_delay(0.04)
	tween.parallel().tween_property(_title, "modulate:a", 1.0, 0.16).set_delay(0.05)
	tween.parallel().tween_property(_title, "scale", Vector2.ONE * 1.035, 0.20).set_delay(0.04)
	tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.18).set_delay(0.10)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title, "scale", Vector2.ONE, 0.12)
	tween.tween_interval(0.48)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	await tween.finished

	visible = false
	modulate = Color.WHITE
	_frame.modulate = Color.WHITE
	print("[BattleIntro] BATTLE_START")


func _build_ui() -> void:
	_frame = Panel.new()
	_frame.name = "BattleStartFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override("panel", UI.panel_strong(UI.PURPLE, 10))
	add_child(_frame)

	_left_accent = ColorRect.new()
	_left_accent.name = "LeftAccent"
	_left_accent.color = UI.CYAN
	_left_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_left_accent)

	_right_accent = ColorRect.new()
	_right_accent.name = "RightAccent"
	_right_accent.color = UI.GOLD
	_right_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_right_accent)

	_kicker = Label.new()
	_kicker.name = "Kicker"
	_kicker.text = "DIGI LINK"
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kicker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kicker.add_theme_color_override("font_color", UI.GOLD)
	UI.apply_heading_font(_kicker)
	_frame.add_child(_kicker)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "BATTLE START"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_color_override("font_color", UI.TEXT)
	_title.add_theme_color_override("font_outline_color", Color(0.035, 0.04, 0.10, 0.98))
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	_title.add_theme_constant_override("outline_size", 5)
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	UI.apply_heading_font(_title)
	_frame.add_child(_title)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.text = "DIGITAL FIELD  •  LINK ESTABLISHED"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_color_override("font_color", UI.CYAN)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.035, 0.04, 0.10, 0.96))
	_subtitle.add_theme_constant_override("outline_size", 3)
	UI.apply_body_font(_subtitle)
	_frame.add_child(_subtitle)


func _layout_ui() -> void:
	if _frame == null:
		return
	var compact := size.y < 560.0 or size.x < 900.0
	var frame_width := minf(size.x * (0.86 if compact else 0.62), 640.0)
	var frame_height := 132.0 if compact else 152.0
	var center_y := size.y * 0.46
	_frame.position = Vector2((size.x - frame_width) * 0.5, center_y - frame_height * 0.5)
	_frame.size = Vector2(frame_width, frame_height)

	var side_pad := 24.0 if compact else 30.0
	_left_accent.position = Vector2(side_pad, 17.0)
	_left_accent.size = Vector2(minf(86.0, frame_width * 0.18), 3.0)
	_right_accent.size = Vector2(minf(58.0, frame_width * 0.13), 3.0)
	_right_accent.position = Vector2(frame_width - side_pad - _right_accent.size.x, frame_height - 20.0)

	_kicker.position = Vector2(side_pad, 13.0)
	_kicker.size = Vector2(frame_width - side_pad * 2.0, 22.0)
	_kicker.add_theme_font_size_override("font_size", 11 if compact else 12)

	_title.position = Vector2(side_pad, 33.0 if compact else 37.0)
	_title.size = Vector2(frame_width - side_pad * 2.0, 54.0 if compact else 62.0)
	_title.pivot_offset = _title.size * 0.5
	_title.add_theme_font_size_override("font_size", 38 if compact else 48)

	_subtitle.position = Vector2(side_pad, 91.0 if compact else 106.0)
	_subtitle.size = Vector2(frame_width - side_pad * 2.0, 24.0)
	_subtitle.add_theme_font_size_override("font_size", 11 if compact else 13)
	queue_redraw()


func _set_reveal(value: float) -> void:
	_reveal = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _reveal <= 0.0:
		return
	var center := size * Vector2(0.5, 0.46)
	var full_width := minf(size.x * 0.82, 900.0)
	var width := full_width * _reveal
	var glow_rect := Rect2(center.x - width * 0.5, center.y - 86.0, width, 172.0)
	var glow := Color(UI.BLUE.r, UI.BLUE.g, UI.BLUE.b, 0.055 * _reveal)
	draw_rect(glow_rect, glow, true)
	var left := Vector2(center.x - width * 0.5, center.y)
	var right := Vector2(center.x + width * 0.5, center.y)
	draw_line(left, right, Color(UI.CYAN.r, UI.CYAN.g, UI.CYAN.b, 0.16 * _reveal), 1.0, true)
	var spark := 6.0 * _reveal
	var diamond := PackedVector2Array([
		center + Vector2(-spark, 0.0),
		center + Vector2(0.0, -spark),
		center + Vector2(spark, 0.0),
		center + Vector2(0.0, spark),
	])
	draw_colored_polygon(diamond, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.28 * _reveal))
