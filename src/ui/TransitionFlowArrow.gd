extends Control
class_name TransitionFlowArrow

# Resolution-independent transition indicator. The arrow is drawn directly on
# the CanvasItem every frame, so it stays crisp at any UI scale instead of
# rasterizing an SVG to a small texture and stretching it.

var accent := Color(0.38, 0.83, 1.0, 1.0)
var vertical := false
var major := false
var phase_offset := 0.0
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(true)
	queue_redraw()


func configure(color: Color, is_major: bool = false, is_vertical: bool = false, phase: float = 0.0) -> void:
	accent = color
	major = is_major
	vertical = is_vertical
	phase_offset = phase
	queue_redraw()


func set_vertical(value: bool) -> void:
	if vertical == value:
		return
	vertical = value
	queue_redraw()


func set_accent(value: Color) -> void:
	accent = value
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time = fmod(_time + delta, 1000.0)
	queue_redraw()


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return

	var along := size.y if vertical else size.x
	var cross := size.x if vertical else size.y
	if along < 8.0 or cross < 6.0:
		return

	var along_margin := maxf(2.5, minf(along * 0.13, 7.0 if major else 4.0))
	var start := along_margin
	var tip := maxf(start + 4.0, along - along_margin)
	var head_length := clampf(along * (0.28 if major else 0.31), 6.0, 16.0 if major else 9.0)
	var head_base := maxf(start + 2.0, tip - head_length)
	var center := cross * 0.5
	var half_head := minf(cross * 0.28, 10.0 if major else 5.0)
	var rail_offset := minf(1.7 if major else 1.0, cross * 0.08)

	var base_color := Color(accent.r, accent.g, accent.b, 0.72 if major else 0.58)
	var bright := accent.lightened(0.30 if major else 0.22)
	var pulse := 0.5 + 0.5 * sin((_time + phase_offset) * (4.1 if major else 4.8))
	var head_color := Color(bright.r, bright.g, bright.b, lerpf(0.74, 1.0, pulse))

	# Soft vector glow. These are geometry layers, not a blurred bitmap, so the
	# silhouette remains sharp while still matching the neon language of the UI.
	_draw_segment(start, center, head_base, center, Color(accent.r, accent.g, accent.b, 0.055), 9.0 if major else 6.0)
	_draw_chevron(head_base, center, tip, half_head, Color(accent.r, accent.g, accent.b, 0.060), 10.0 if major else 6.5)
	_draw_segment(start, center, head_base, center, Color(accent.r, accent.g, accent.b, 0.13), 5.0 if major else 3.5)
	_draw_chevron(head_base, center, tip, half_head, Color(accent.r, accent.g, accent.b, 0.16), 5.5 if major else 3.8)

	# A split core on the hero arrow adds a technical, game-UI feel without
	# making the compact stat arrows visually noisy.
	if major and cross >= 18.0:
		_draw_segment(start, center - rail_offset, head_base, center - rail_offset, Color(base_color.r, base_color.g, base_color.b, 0.54), 1.15)
		_draw_segment(start, center + rail_offset, head_base, center + rail_offset, Color(base_color.r, base_color.g, base_color.b, 0.54), 1.15)
	else:
		_draw_segment(start, center, head_base, center, base_color, 1.35)

	_draw_chevron(head_base, center, tip, half_head, head_color, 1.8 if major else 1.45)

	# Directional energy packet. It repeatedly travels from source to target and
	# fades in/out near the endpoints, making the direction immediately obvious.
	var flow := fmod((_time * (0.78 if major else 0.92)) + phase_offset, 1.0)
	var eased := flow * flow * (3.0 - 2.0 * flow)
	var packet_end := lerpf(start, head_base, eased)
	var packet_length := maxf(3.0, (head_base - start) * (0.24 if major else 0.30))
	var packet_start := maxf(start, packet_end - packet_length)
	var edge_fade := sin(flow * PI)
	var packet_alpha := (0.82 if major else 0.68) * edge_fade
	var packet_glow := Color(bright.r, bright.g, bright.b, packet_alpha * 0.20)
	var packet_core := Color(bright.r, bright.g, bright.b, packet_alpha)
	_draw_segment(packet_start, center, packet_end, center, packet_glow, 6.0 if major else 4.0)
	_draw_segment(packet_start, center, packet_end, center, packet_core, 2.0 if major else 1.45)

	# Two understated trailing chevrons appear only on the hero transition. They
	# reinforce flow while keeping the actual arrowhead dominant.
	if major and head_base - start > 16.0:
		var ghost_spacing := minf(7.0, (head_base - start) * 0.20)
		for index in range(2):
			var ghost_tip := head_base - ghost_spacing * float(index + 1)
			var ghost_base := ghost_tip - minf(4.5, ghost_spacing * 0.65)
			if ghost_base <= start:
				continue
			var ghost_alpha := (0.17 + 0.06 * pulse) * (1.0 - float(index) * 0.28)
			_draw_chevron(ghost_base, center, ghost_tip, half_head * 0.56, Color(accent.r, accent.g, accent.b, ghost_alpha), 1.0)


func _draw_segment(a_along: float, a_cross: float, b_along: float, b_cross: float, color: Color, width: float) -> void:
	draw_line(_point(a_along, a_cross), _point(b_along, b_cross), color, width, true)


func _draw_chevron(base_along: float, center_cross: float, tip_along: float, half_cross: float, color: Color, width: float) -> void:
	var upper := _point(base_along, center_cross - half_cross)
	var tip_point := _point(tip_along, center_cross)
	var lower := _point(base_along, center_cross + half_cross)
	draw_polyline(PackedVector2Array([upper, tip_point, lower]), color, width, true)


func _point(along: float, cross: float) -> Vector2:
	return Vector2(cross, along) if vertical else Vector2(along, cross)
