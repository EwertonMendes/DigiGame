extends Control
class_name BattleStartBanner

const UI = preload("res://src/ui/TacticalTheme.gd")

var _frame: Panel = null
var _kicker: Label = null
var _title: Label = null
var _subtitle: Label = null


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

	# Keep motion on typography only. The Kenney frame itself stays perfectly
	# still so it never produces glow/blur trails or competes with the field.
	_kicker.modulate.a = 0.0
	_title.modulate.a = 0.0
	_title.scale = Vector2.ONE * 0.96
	_subtitle.modulate.a = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_kicker, "modulate:a", 1.0, 0.14)
	tween.parallel().tween_property(_title, "modulate:a", 1.0, 0.16).set_delay(0.03)
	tween.parallel().tween_property(_title, "scale", Vector2.ONE, 0.18).set_delay(0.03)
	tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.16).set_delay(0.08)
	tween.tween_interval(0.52)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_kicker, "modulate:a", 0.0, 0.12)
	tween.parallel().tween_property(_title, "modulate:a", 0.0, 0.12)
	tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.12)
	await tween.finished

	visible = false
	_kicker.modulate = Color.WHITE
	_title.modulate = Color.WHITE
	_subtitle.modulate = Color.WHITE
	print("[BattleIntro] BATTLE_START")


func _build_ui() -> void:
	_frame = Panel.new()
	_frame.name = "BattleStartFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override("panel", UI.panel_strong(Color.WHITE, 8))
	add_child(_frame)

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
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	_title.add_theme_constant_override("outline_size", 3)
	UI.apply_heading_font(_title)
	_frame.add_child(_title)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.text = "DIGITAL FIELD  •  LINK ESTABLISHED"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_color_override("font_color", UI.CYAN)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	_subtitle.add_theme_constant_override("outline_size", 2)
	UI.apply_body_font(_subtitle)
	_frame.add_child(_subtitle)


func _layout_ui() -> void:
	if _frame == null:
		return
	var compact := size.y < 560.0 or size.x < 900.0
	var frame_width := minf(size.x * (0.84 if compact else 0.58), 600.0)
	var frame_height := 126.0 if compact else 142.0
	var center_y := size.y * 0.46
	_frame.position = Vector2((size.x - frame_width) * 0.5, center_y - frame_height * 0.5)
	_frame.size = Vector2(frame_width, frame_height)

	var side_pad := 28.0 if compact else 34.0
	_kicker.position = Vector2(side_pad, 14.0)
	_kicker.size = Vector2(frame_width - side_pad * 2.0, 20.0)
	_kicker.add_theme_font_size_override("font_size", 11 if compact else 12)

	_title.position = Vector2(side_pad, 34.0 if compact else 38.0)
	_title.size = Vector2(frame_width - side_pad * 2.0, 50.0 if compact else 56.0)
	_title.pivot_offset = _title.size * 0.5
	_title.add_theme_font_size_override("font_size", 36 if compact else 44)

	_subtitle.position = Vector2(side_pad, 88.0 if compact else 98.0)
	_subtitle.size = Vector2(frame_width - side_pad * 2.0, 22.0)
	_subtitle.add_theme_font_size_override("font_size", 11 if compact else 12)
