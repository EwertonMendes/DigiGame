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
	# The mark is only a positioning/animation anchor. The HUD frame itself is
	# drawn procedurally by this control, so the Bits artwork never sits inside
	# a nested rounded card or requires another texture asset.
	_medallion = Panel.new()
	_medallion.name = "BitsMark"
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
	V2.apply_heading(_currency_label)
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
	# The panel shape is intentionally custom-drawn with cut corners. Keeping the
	# theme surface empty prevents Godot from reintroducing the old rounded card.
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_medallion.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_value_label.add_theme_color_override("font_color", V2.WHITE)
	var currency_color := Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 1.0)
	_currency_label.add_theme_color_override("font_color", currency_color)
	# The UI typeface is intentionally slim, so a one-pixel same-hue outline gives
	# the small currency label enough weight to stay readable without competing
	# with the balance value above it.
	_currency_label.add_theme_constant_override("outline_size", 1)
	_currency_label.add_theme_color_override("font_outline_color", Color(currency_color.r, currency_color.g, currency_color.b, 0.72))

	match _variant:
		VARIANT_COMPACT:
			custom_minimum_size = Vector2(170.0, 44.0)
			_value_label.add_theme_font_size_override("font_size", 19)
			_currency_label.add_theme_font_size_override("font_size", 10)
		VARIANT_EMPHASIS:
			custom_minimum_size = Vector2(232.0, 64.0)
			_value_label.add_theme_font_size_override("font_size", 27)
			_currency_label.add_theme_font_size_override("font_size", 12)
		_:
			custom_minimum_size = Vector2(208.0, 56.0)
			_value_label.add_theme_font_size_override("font_size", 24)
			_currency_label.add_theme_font_size_override("font_size", 11)
	queue_redraw()


func _draw() -> void:
	if size.x < 24.0 or size.y < 20.0:
		return

	var compact: bool = _is_compact_layout()
	var emphasis: bool = _is_emphasis_layout()
	var w: float = size.x
	var h: float = size.y
	var inset: float = 1.5
	var cut: float = 7.0 if compact else (11.0 if emphasis else 9.0)

	var frame := PackedVector2Array([
		Vector2(inset + cut, inset),
		Vector2(w - inset - cut, inset),
		Vector2(w - inset, inset + cut),
		Vector2(w - inset, h - inset - cut),
		Vector2(w - inset - cut, h - inset),
		Vector2(inset + cut, h - inset),
		Vector2(inset, h - inset - cut),
		Vector2(inset, inset + cut),
	])
	var outline := frame.duplicate()
	outline.append(frame[0])

	# A deep blue-black HUD plate with a faint cyan inner wash. Both remain fully
	# inside the component bounds so the badge never leaks out of the header.
	draw_colored_polygon(frame, Color(0.012, 0.033, 0.046, 0.94))
	var inner_inset: float = 3.0
	var inner_cut: float = maxf(3.0, cut - 2.0)
	var inner := PackedVector2Array([
		Vector2(inner_inset + inner_cut, inner_inset),
		Vector2(w - inner_inset - inner_cut, inner_inset),
		Vector2(w - inner_inset, inner_inset + inner_cut),
		Vector2(w - inner_inset, h - inner_inset - inner_cut),
		Vector2(w - inner_inset - inner_cut, h - inner_inset),
		Vector2(inner_inset + inner_cut, h - inner_inset),
		Vector2(inner_inset, h - inner_inset - inner_cut),
		Vector2(inner_inset, inner_inset + inner_cut),
	])
	draw_colored_polygon(inner, Color(0.020, 0.070, 0.090, 0.22))

	# Layered cyan edge: a restrained glow plus a crisp game-HUD outline.
	draw_polyline(outline, Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.10), 4.0, true)
	draw_polyline(outline, Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.78), 1.35, true)

	# Bright corner strokes reproduce the segmented sci-fi construction from the
	# approved concept without needing exported frame assets.
	var corner_color := Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.98)
	var corner_len: float = 15.0 if compact else 20.0
	draw_line(Vector2(inset + cut, inset), Vector2(minf(w * 0.32, inset + cut + corner_len), inset), corner_color, 2.0, true)
	draw_line(Vector2(w - inset - cut, inset), Vector2(maxf(w * 0.72, w - inset - cut - corner_len), inset), corner_color, 2.0, true)
	draw_line(Vector2(inset, inset + cut), Vector2(inset, minf(h * 0.52, inset + cut + 13.0)), corner_color, 2.0, true)
	draw_line(Vector2(w - inset, h - inset - cut), Vector2(w - inset, maxf(h * 0.58, h - inset - cut - 13.0)), corner_color, 2.0, true)

	# The vertical separator makes the coin read as an equipment/status module
	# rather than a generic rounded badge.
	var divider_x: float = _left_zone_width()
	draw_line(
		Vector2(divider_x, 10.0 if compact else 11.0),
		Vector2(divider_x, h - (10.0 if compact else 11.0)),
		Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.55),
		1.0,
		true
	)

	# Three amber diagnostic slashes give the economy module a distinct game-like
	# signature while staying small enough not to compete with the balance.
	var accent_y: float = h - (8.0 if compact else 9.0)
	var accent_start: float = w - (28.0 if compact else 35.0)
	var accent_step: float = 7.0 if compact else 8.0
	var accent_len: float = 8.0 if compact else 10.0
	for index in range(3):
		var x: float = accent_start + float(index) * accent_step
		draw_line(
			Vector2(x, accent_y),
			Vector2(x + accent_len * 0.55, accent_y - accent_len * 0.70),
			Color(V2.AMBER.r, V2.AMBER.g, V2.AMBER.b, 0.96),
			2.5 if compact else 3.0,
			true
		)


func _layout() -> void:
	if _medallion == null:
		return
	var height: float = size.y
	var compact: bool = _is_compact_layout()
	var emphasis: bool = _is_emphasis_layout()
	var left_zone: float = _left_zone_width()
	var icon_size: float = 36.0 if compact else (52.0 if emphasis else 48.0)
	var icon_x: float = floorf((left_zone - icon_size) * 0.5)
	var icon_y: float = floorf((height - icon_size) * 0.5)
	_medallion.position = Vector2(icon_x, icon_y)
	_medallion.size = Vector2(icon_size, icon_size)
	_icon.position = Vector2.ZERO
	_icon.size = Vector2(icon_size, icon_size)

	var copy_x: float = left_zone + (11.0 if compact else 13.0)
	var copy_w: float = maxf(0.0, size.x - copy_x - (36.0 if compact else 44.0))
	# Keep the balance + currency label centered as one visual block instead of
	# aligning the number to the top edge of the HUD plate.
	if compact:
		_value_label.position = Vector2(copy_x, 4.0)
		_value_label.size = Vector2(copy_w, 25.0)
		_currency_label.position = Vector2(copy_x + 1.0, 25.0)
		_currency_label.size = Vector2(copy_w, 16.0)
	else:
		_value_label.position = Vector2(copy_x, 6.0 if emphasis else 5.0)
		_value_label.size = Vector2(copy_w, 36.0 if emphasis else 31.0)
		_currency_label.position = Vector2(copy_x + 1.0, 39.0 if emphasis else 32.0)
		_currency_label.size = Vector2(copy_w, 18.0)

	_delta_label.position = Vector2(copy_x, -7.0)
	_delta_label.size = Vector2(copy_w, 18.0)
	queue_redraw()


func _left_zone_width() -> float:
	if _is_compact_layout():
		return 58.0
	if _is_emphasis_layout():
		return 76.0
	return 68.0


func _is_compact_layout() -> bool:
	return _variant == VARIANT_COMPACT or size.y <= 46.0


func _is_emphasis_layout() -> bool:
	return _variant == VARIANT_EMPHASIS and size.y >= 60.0


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
	_medallion.modulate = Color(1.20, 1.12, 0.84, 1.0)

	_delta_tween = create_tween()
	_delta_tween.set_parallel(true)
	_delta_tween.tween_property(_delta_label, "position:y", -18.0, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_delta_tween.tween_property(_delta_label, "modulate:a", 0.0, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_delta_tween.tween_property(_medallion, "modulate", Color.WHITE, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_delta_tween.chain().tween_callback(func(): _delta_label.visible = false)
