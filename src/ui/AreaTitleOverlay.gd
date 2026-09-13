extends Control
class_name AreaTitleOverlay

const UI = preload("res://src/ui/TacticalTheme.gd")

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
	_card.scale = Vector2(0.985, 0.985)
	call_deferred("_start_presentation", maxf(0.8, hold_seconds))


func get_area_title() -> String:
	return _title.text if _title != null else ""


func get_area_subtitle() -> String:
	return _subtitle.text if _subtitle != null else ""


func _build_ui() -> void:
	_card = PanelContainer.new()
	_card.name = "AreaTitleCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.004, 0.010, 0.016, 0.78)
	style.border_color = Color(UI.CYAN.r, UI.CYAN.g, UI.CYAN.b, 0.38)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 10
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 17)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 17)
	_card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	_title = Label.new()
	_title.name = "AreaTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", UI.TEXT)
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	_title.add_theme_constant_override("outline_size", 3)
	UI.apply_heading_font(_title)
	stack.add_child(_title)

	_subtitle = Label.new()
	_subtitle.name = "AreaSubtitle"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 13)
	_subtitle.add_theme_color_override("font_color", UI.CYAN)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_subtitle.add_theme_constant_override("outline_size", 2)
	UI.apply_body_font(_subtitle)
	stack.add_child(_subtitle)


func _layout() -> void:
	if _card == null:
		return
	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport().get_visible_rect().size
	var width := clampf(viewport_size.x - 48.0, 300.0, 620.0)
	var height := 112.0
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
	_animation.tween_property(self, "modulate:a", 1.0, 0.22)
	_animation.parallel().tween_property(_card, "scale", Vector2.ONE, 0.22)
	_animation.tween_interval(hold_seconds)
	_animation.set_ease(Tween.EASE_IN)
	_animation.tween_property(self, "modulate:a", 0.0, 0.42)
	_animation.parallel().tween_property(_card, "scale", Vector2(1.012, 1.012), 0.42)
	_animation.tween_callback(Callable(self, "hide"))
