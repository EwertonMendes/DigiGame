extends Control
class_name BattleStartBanner

const UI = preload("res://src/ui/TacticalTheme.gd")

var _title: Label = null
var _subtitle: Label = null
var _reveal := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_labels()
	get_viewport().size_changed.connect(_layout_labels)
	call_deferred("_layout_labels")


func play() -> void:
	visible = true
	modulate = Color.WHITE
	_reveal = 0.0
	queue_redraw()
	_layout_labels()

	_title.modulate.a = 0.0
	_title.scale = Vector2.ONE * 0.74
	_subtitle.modulate.a = 0.0
	_subtitle.position.y += 8.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_reveal, 0.0, 1.0, 0.24)
	tween.parallel().tween_property(_title, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(_title, "scale", Vector2.ONE * 1.08, 0.24)
	tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.22)
	tween.parallel().tween_property(_subtitle, "position:y", _subtitle.position.y - 8.0, 0.22)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title, "scale", Vector2.ONE, 0.13)
	tween.tween_interval(0.42)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.20)
	await tween.finished

	visible = false
	modulate = Color.WHITE
	print("[BattleIntro] BATTLE_START")


func _build_labels() -> void:
	_title = Label.new()
	_title.text = "BATTLE START"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.82, 0.94, 0.96))
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))
	_title.add_theme_constant_override("outline_size", 7)
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 5)
	UI.apply_heading_font(_title)
	add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = "DIGITAL ENGAGE  //  DATA LINK ONLINE"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_color_override("font_color", UI.GOLD)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.96))
	_subtitle.add_theme_constant_override("outline_size", 4)
	UI.apply_body_font(_subtitle)
	add_child(_subtitle)


func _layout_labels() -> void:
	if _title == null or _subtitle == null:
		return
	var compact := size.y < 560.0 or size.x < 900.0
	var center_y := size.y * 0.48
	var title_width := minf(size.x * 0.82, 760.0)
	var title_height := 72.0 if not compact else 58.0
	_title.position = Vector2((size.x - title_width) * 0.5, center_y - title_height * 0.72)
	_title.size = Vector2(title_width, title_height)
	_title.pivot_offset = _title.size * 0.5
	_title.add_theme_font_size_override("font_size", 52 if not compact else 40)

	var subtitle_width := minf(size.x * 0.76, 680.0)
	_subtitle.position = Vector2((size.x - subtitle_width) * 0.5, center_y + 34.0)
	_subtitle.size = Vector2(subtitle_width, 32.0)
	_subtitle.add_theme_font_size_override("font_size", 15 if not compact else 12)
	queue_redraw()


func _set_reveal(value: float) -> void:
	_reveal = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var center := size * Vector2(0.5, 0.48)
	var full_width := minf(size.x * 0.78, 820.0)
	var width := full_width * _reveal
	var band_height := 118.0 if size.y >= 560.0 else 94.0
	var band := Rect2(center.x - width * 0.5, center.y - band_height * 0.5, width, band_height)

	if width > 2.0:
		draw_rect(band.grow(10.0), Color(0.05, 0.72, 0.82, 0.055), true)
		draw_rect(band, Color(0.015, 0.035, 0.045, 0.88), true)
		draw_line(Vector2(band.position.x, band.position.y), Vector2(band.end.x, band.position.y), Color(0.35, 0.92, 1.0, 0.78), 2.0, true)
		draw_line(Vector2(band.position.x, band.end.y), Vector2(band.end.x, band.end.y), Color(0.98, 0.76, 0.16, 0.62), 2.0, true)

	var diamond_scale := lerpf(0.35, 1.0, _reveal)
	var half_w := 54.0 * diamond_scale
	var half_h := 27.0 * diamond_scale
	var points := PackedVector2Array([
		center + Vector2(-half_w, 0.0),
		center + Vector2(0.0, -half_h),
		center + Vector2(half_w, 0.0),
		center + Vector2(0.0, half_h),
	])
	draw_colored_polygon(points, Color(0.18, 0.70, 0.80, 0.10 * _reveal))
	var outline := PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	draw_polyline(outline, Color(0.40, 0.94, 1.0, 0.34 * _reveal), 2.0, true)
