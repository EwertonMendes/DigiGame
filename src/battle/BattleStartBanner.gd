extends Control
class_name BattleStartBanner

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const WEB_REVEAL_TIME := 0.20
const WEB_HOLD_TIME := 0.62
const WEB_FADE_TIME := 0.15

var _banner: Control = null
var _backdrop: Panel = null
var _left_rule: ColorRect = null
var _right_rule: ColorRect = null
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
	_left_rule.modulate.a = 0.0
	_right_rule.modulate.a = 0.0

	if OS.has_feature("web"):
		await _play_frame_driven_web()
	else:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_banner, "modulate:a", 1.0, 0.10)
		tween.parallel().tween_property(_kicker, "modulate:a", 1.0, 0.13).set_delay(0.02)
		tween.parallel().tween_property(_title, "modulate:a", 1.0, 0.15).set_delay(0.03)
		tween.parallel().tween_property(_title, "scale", Vector2.ONE, 0.16).set_delay(0.03)
		tween.parallel().tween_property(_left_rule, "modulate:a", 1.0, 0.14).set_delay(0.04)
		tween.parallel().tween_property(_right_rule, "modulate:a", 1.0, 0.14).set_delay(0.04)
		tween.tween_interval(0.62)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(_banner, "modulate:a", 0.0, 0.15)
		await tween.finished

	_reset_visual_state()
	print("[BattleIntro] BATTLE_START")


func _play_frame_driven_web() -> void:
	# The Web battle opening deliberately avoids awaiting render-owned Tweens while
	# the scene is settling. Reproduce the same reveal/hold/fade timing from normal
	# process frames so completing the banner cannot block the combat hand-off.
	var elapsed := 0.0
	while elapsed < WEB_REVEAL_TIME:
		await get_tree().process_frame
		elapsed = minf(WEB_REVEAL_TIME, elapsed + maxf(get_process_delta_time(), 0.0))
		_banner.modulate.a = _quad_ease_out(elapsed, 0.10)
		_kicker.modulate.a = _quad_ease_out(maxf(0.0, elapsed - 0.02), 0.13)
		_title.modulate.a = _quad_ease_out(maxf(0.0, elapsed - 0.03), 0.15)
		var title_scale_progress := _quad_ease_out(maxf(0.0, elapsed - 0.03), 0.16)
		_title.scale = (Vector2.ONE * 0.96).lerp(Vector2.ONE, title_scale_progress)
		_left_rule.modulate.a = _quad_ease_out(maxf(0.0, elapsed - 0.04), 0.14)
		_right_rule.modulate.a = _quad_ease_out(maxf(0.0, elapsed - 0.04), 0.14)

	_banner.modulate.a = 1.0
	_kicker.modulate.a = 1.0
	_title.modulate.a = 1.0
	_title.scale = Vector2.ONE
	_left_rule.modulate.a = 1.0
	_right_rule.modulate.a = 1.0

	elapsed = 0.0
	while elapsed < WEB_HOLD_TIME:
		await get_tree().process_frame
		elapsed = minf(WEB_HOLD_TIME, elapsed + maxf(get_process_delta_time(), 0.0))

	elapsed = 0.0
	while elapsed < WEB_FADE_TIME:
		await get_tree().process_frame
		elapsed = minf(WEB_FADE_TIME, elapsed + maxf(get_process_delta_time(), 0.0))
		var progress := _quad_ease_in(elapsed, WEB_FADE_TIME)
		_banner.modulate.a = lerpf(1.0, 0.0, progress)


func _quad_ease_out(elapsed: float, duration: float) -> float:
	return float(Tween.interpolate_value(0.0, 1.0, elapsed, duration, Tween.TRANS_QUAD, Tween.EASE_OUT))


func _quad_ease_in(elapsed: float, duration: float) -> float:
	return float(Tween.interpolate_value(0.0, 1.0, elapsed, duration, Tween.TRANS_QUAD, Tween.EASE_IN))


func _reset_visual_state() -> void:
	visible = false
	_banner.modulate = Color.WHITE
	_kicker.modulate = Color.WHITE
	_title.modulate = Color.WHITE
	_title.scale = Vector2.ONE
	_left_rule.modulate = Color.WHITE
	_right_rule.modulate = Color.WHITE


func _build_ui() -> void:
	_banner = Control.new()
	_banner.name = "BattleStartBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	_backdrop = Panel.new()
	_backdrop.name = "BattleStartBackdrop"
	_backdrop.set_meta("digi_ui_v2_component", true)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_theme_stylebox_override(
		"panel",
		V2.surface_style(
			Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.95),
			Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.46),
			V2.CARD_RADIUS,
			Vector4.ZERO,
			0.16
		)
	)
	_banner.add_child(_backdrop)

	_left_rule = ColorRect.new()
	_left_rule.color = Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.74)
	_left_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_left_rule)

	_right_rule = ColorRect.new()
	_right_rule.color = Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.74)
	_right_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_right_rule)

	_kicker = Label.new()
	_kicker.name = "Kicker"
	_kicker.text = "DIGITAL FIELD"
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kicker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kicker.add_theme_color_override("font_color", V2.AMBER)
	V2.apply_heading(_kicker)
	_banner.add_child(_kicker)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "BATTLE STARTED"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_color_override("font_color", V2.WHITE)
	V2.apply_heading(_title)
	_banner.add_child(_title)


func _layout_ui() -> void:
	if _banner == null:
		return
	var compact := size.y < 560.0 or size.x < 900.0
	var banner_width := minf(size.x * (0.88 if compact else 0.64), 680.0)
	var banner_height := 92.0 if compact else 106.0
	var center_y := size.y * 0.44
	_banner.position = Vector2((size.x - banner_width) * 0.5, center_y - banner_height * 0.5)
	_banner.size = Vector2(banner_width, banner_height)
	_banner.pivot_offset = _banner.size * 0.5
	_backdrop.position = Vector2.ZERO
	_backdrop.size = _banner.size

	var kicker_height := 18.0
	_kicker.position = Vector2(24.0, 10.0 if compact else 12.0)
	_kicker.size = Vector2(banner_width - 48.0, kicker_height)
	_kicker.add_theme_font_size_override("font_size", 10 if compact else 11)

	var title_y := 29.0 if compact else 32.0
	var title_height := 44.0 if compact else 50.0
	var rule_width := 82.0 if compact else 104.0
	var rule_gap := 16.0 if compact else 20.0
	var title_width := maxf(170.0, banner_width - (rule_width + rule_gap) * 2.0 - 40.0)
	_title.position = Vector2((banner_width - title_width) * 0.5, title_y)
	_title.size = Vector2(title_width, title_height)
	_title.pivot_offset = _title.size * 0.5
	_title.add_theme_font_size_override("font_size", 28 if compact else 34)

	var rule_y := title_y + title_height * 0.5 - 1.0
	_left_rule.position = Vector2(_title.position.x - rule_gap - rule_width, rule_y)
	_left_rule.size = Vector2(rule_width, 2.0)
	_right_rule.position = Vector2(_title.position.x + title_width + rule_gap, rule_y)
	_right_rule.size = Vector2(rule_width, 2.0)
