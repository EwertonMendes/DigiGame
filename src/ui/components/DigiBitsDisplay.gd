extends Panel
class_name DigiBitsDisplay

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const BITS_TEXTURE = preload("res://assets/ui/icons/bits.png")

const VARIANT_COMPACT := "compact"
const VARIANT_STANDARD := "standard"
const VARIANT_EMPHASIS := "emphasis"

var _value: int = 0
var _variant: String = VARIANT_STANDARD
var _has_presented_value: bool = false
var _animate_changes: bool = true

var _medallion: Panel
var _icon: TextureRect
var _value_label: Label
var _currency_label: Label
var _delta_label: Label
var _delta_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build()
	resized.connect(_layout)
	_apply_variant()
	_refresh_copy()
	_layout()


func set_value(value: int, animate: bool = true) -> void:
	var next_value: int = maxi(0, value)
	var delta: int = next_value - _value
	var should_animate: bool = animate and _animate_changes and _has_presented_value and delta != 0
	_value = next_value
	_has_presented_value = true
	_refresh_copy()
	if should_animate and is_inside_tree():
		_play_delta(delta)


func get_value() -> int:
	return _value


func set_variant(variant: String) -> void:
	var normalized: String = variant.to_lower()
	if normalized not in [VARIANT_COMPACT, VARIANT_STANDARD, VARIANT_EMPHASIS]:
		normalized = VARIANT_STANDARD
	if _variant == normalized:
		return
	_variant = normalized
	if is_node_ready():
		_apply_variant()
		_layout()


func get_variant() -> String:
	return _variant


func set_change_animation_enabled(enabled: bool) -> void:
	_animate_changes = enabled


func prime_value(value: int) -> void:
	_value = maxi(0, value)
	_has_presented_value = true
	_refresh_copy()


func get_icon_rect() -> TextureRect:
	return _icon


func get_value_label() -> Label:
	return _value_label


func _build() -> void:
	_medallion = Panel.new()
	_medallion.name = "BitsMedallion"
	_medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion.clip_contents = false
	add_child(_medallion)

	_icon = TextureRect.new()
	_icon.name = "BitsIcon"
	_icon.texture = BITS_TEXTURE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.z_index = 2
	_medallion.add_child(_icon)

	_value_label = Label.new()
	_value_label.name = "BitsValue"
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	V2.apply_heading(_value_label)
	add_child(_value_label)

	_currency_label = Label.new()
	_currency_label.name = "BitsCurrency"
	_currency_label.text = "BITS"
	_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_currency_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	V2.apply_body(_currency_label)
	add_child(_currency_label)

	_delta_label = Label.new()
	_delta_label.name = "BitsDelta"
	_delta_label.visible = false
	_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_delta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta_label.z_index = 10
	V2.apply_heading(_delta_label)
	add_child(_delta_label)


func _apply_variant() -> void:
	var outer: StyleBoxFlat = V2.surface_style(
		Color(0.019, 0.038, 0.052, 0.985),
		Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.62),
		12
	)
	outer.set_border_width_all(1)
	outer.border_blend = true
	outer.shadow_color = Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.13)
	outer.shadow_size = 10
	outer.shadow_offset = Vector2(0.0, 2.0)
	add_theme_stylebox_override("panel", outer)

	var medallion_style: StyleBoxFlat = V2.surface_style(
		Color(0.125, 0.090, 0.020, 0.90),
		Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.84),
		10
	)
	medallion_style.set_border_width_all(1)
	medallion_style.shadow_color = Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.18)
	medallion_style.shadow_size = 7
	_medallion.add_theme_stylebox_override("panel", medallion_style)

	_value_label.add_theme_color_override("font_color", V2.WHITE)
	_currency_label.add_theme_color_override("font_color", Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.86))

	match _variant:
		VARIANT_COMPACT:
			custom_minimum_size = Vector2(150.0, 42.0)
			_value_label.add_theme_font_size_override("font_size", 16)
			_currency_label.add_theme_font_size_override("font_size", 8)
		VARIANT_EMPHASIS:
			custom_minimum_size = Vector2(204.0, 60.0)
			_value_label.add_theme_font_size_override("font_size", 23)
			_currency_label.add_theme_font_size_override("font_size", 10)
		_:
			custom_minimum_size = Vector2(184.0, 52.0)
			_value_label.add_theme_font_size_override("font_size", 20)
			_currency_label.add_theme_font_size_override("font_size", 9)


func _layout() -> void:
	if _medallion == null:
		return
	var height: float = size.y
	var compact: bool = _variant == VARIANT_COMPACT or height <= 44.0
	var emphasis: bool = _variant == VARIANT_EMPHASIS and height >= 56.0
	var medal_size: float = 34.0 if compact else (44.0 if emphasis else 40.0)
	var outer_pad: float = 6.0
	var medal_y: float = floorf((height - medal_size) * 0.5)
	_medallion.position = Vector2(outer_pad, medal_y)
	_medallion.size = Vector2(medal_size, medal_size)

	var icon_pad: float = 5.0 if compact else 6.0
	_icon.position = Vector2(icon_pad, icon_pad)
	_icon.size = Vector2(medal_size - icon_pad * 2.0, medal_size - icon_pad * 2.0)

	var copy_x: float = _medallion.position.x + medal_size + (10.0 if compact else 12.0)
	var copy_w: float = maxf(0.0, size.x - copy_x - 10.0)
	if compact:
		_value_label.position = Vector2(copy_x, 3.0)
		_value_label.size = Vector2(copy_w, 23.0)
		_currency_label.position = Vector2(copy_x, 23.0)
		_currency_label.size = Vector2(copy_w, 14.0)
	else:
		_value_label.position = Vector2(copy_x, 3.0 if not emphasis else 4.0)
		_value_label.size = Vector2(copy_w, 30.0 if not emphasis else 34.0)
		_currency_label.position = Vector2(copy_x, 30.0 if not emphasis else 34.0)
		_currency_label.size = Vector2(copy_w, 16.0)

	_delta_label.position = Vector2(copy_x, -10.0)
	_delta_label.size = Vector2(copy_w, 20.0)


func _refresh_copy() -> void:
	if _value_label != null:
		_value_label.text = _format_amount(_value)


func _format_amount(value: int) -> String:
	var raw: String = str(maxi(0, value))
	var formatted: String = ""
	while raw.length() > 3:
		formatted = "," + raw.right(3) + formatted
		raw = raw.left(raw.length() - 3)
	return raw + formatted


func _play_delta(delta: int) -> void:
	if _delta_label == null:
		return
	if _delta_tween != null and _delta_tween.is_valid():
		_delta_tween.kill()
	_delta_label.text = "+%d" % delta if delta > 0 else str(delta)
	_delta_label.add_theme_font_size_override("font_size", 11)
	_delta_label.add_theme_color_override("font_color", V2.GREEN if delta > 0 else V2.AMBER)
	_delta_label.modulate = Color.WHITE
	_delta_label.visible = true
	_delta_label.position.y = -4.0
	_medallion.modulate = Color(1.18, 1.12, 0.82, 1.0)

	_delta_tween = create_tween()
	_delta_tween.set_parallel(true)
	_delta_tween.tween_property(_delta_label, "position:y", -18.0, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_delta_tween.tween_property(_delta_label, "modulate:a", 0.0, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_delta_tween.tween_property(_medallion, "modulate", Color.WHITE, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_delta_tween.chain().tween_callback(func(): _delta_label.visible = false)
