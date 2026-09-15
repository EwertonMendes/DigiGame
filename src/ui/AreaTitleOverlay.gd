extends Control
class_name AreaTitleOverlay

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

var _card: PanelContainer = null
var _title: Label = null
var _subtitle: Label = null
var _animation: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45
	_build_ui()
	resized.connect(_layout)
	_layout()
	visible = false


func present(area_title: String, area_subtitle: String, hold_seconds: float = 1.75) -> void:
	if _card == null:
		return
	if _animation != null and _animation.is_valid():
		_animation.kill()
	_title.text = area_title
	_subtitle.text = area_subtitle
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_card.scale = Vector2(0.975, 0.975)
	call_deferred("_start_presentation", maxf(0.8, hold_seconds))


func get_area_title() -> String:
	return _title.text if _title != null else ""


func get_area_subtitle() -> String:
	return _subtitle.text if _subtitle != null else ""


func _build_ui() -> void:
	_card = PanelContainer.new()
	_card.name = "AreaTitleCard"
	_card.set_meta("digi_ui_v2_component", true)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override(
		"panel",
		V2.surface_style(
			Color(V2.PANEL_DEEP.r, V2.PANEL_DEEP.g, V2.PANEL_DEEP.b, 0.94),
			Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.42),
			V2.CARD_RADIUS,
			Vector4.ZERO,
			0.14
		)
	)
	add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 16)
	_card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var eyebrow := Label.new()
	eyebrow.text = "DIGITAL AREA"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", V2.CYAN)
	V2.apply_heading(eyebrow)
	stack.add_child(eyebrow)

	_title = Label.new()
	_title.name = "AreaTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 27)
	_title.add_theme_color_override("font_color", V2.WHITE)
	V2.apply_heading(_title)
	stack.add_child(_title)

	_subtitle = Label.new()
	_subtitle.name = "AreaSubtitle"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 12)
	_subtitle.add_theme_color_override("font_color", V2.MUTED)
	V2.apply_body(_subtitle)
	stack.add_child(_subtitle)


func _layout() -> void:
	if _card == null:
		return
	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 760.0 or viewport_size.y < 560.0
	var width := clampf(viewport_size.x - 36.0, 286.0, 600.0)
	var height := 116.0 if compact else 124.0
	_card.position = Vector2(
		(viewport_size.x - width) * 0.5,
		(viewport_size.y - height) * 0.5 - minf(28.0, viewport_size.y * 0.035)
	)
	_card.size = Vector2(width, height)
	_card.pivot_offset = _card.size * 0.5


func _start_presentation(hold_seconds: float) -> void:
	if not visible or _card == null:
		return
	_layout()
	_animation = create_tween()
	_animation.set_trans(Tween.TRANS_QUAD)
	_animation.set_ease(Tween.EASE_OUT)
	_animation.tween_property(self, "modulate:a", 1.0, 0.18)
	_animation.parallel().tween_property(_card, "scale", Vector2.ONE, 0.20)
	_animation.tween_interval(hold_seconds)
	_animation.set_ease(Tween.EASE_IN)
	_animation.tween_property(self, "modulate:a", 0.0, 0.34)
	_animation.parallel().tween_property(_card, "scale", Vector2(1.008, 1.008), 0.34)
	_animation.tween_callback(Callable(self, "hide"))
