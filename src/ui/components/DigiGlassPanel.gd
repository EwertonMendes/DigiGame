extends PanelContainer
class_name DigiGlassPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const GLASS_SHADER = preload("res://src/ui/components/digi_glass_backdrop.gdshader")

var _accent := V2.CYAN
var _variant := "floating"
var _content_padding := Vector4.ZERO
var _radius := 10
var _glass_material: ShaderMaterial = null
var _bound_viewport: Viewport = null
var _use_backdrop_blur := true


func _init() -> void:
	set_meta("digi_ui_v2_component", true)
	set_meta("digi_glass_surface", true)
	# The Compatibility/Web renderer is not stable when a mipmapped
	# hint_screen_texture is sampled while scenes are being replaced. Keep the
	# same V2 translucent glass surface on Web, but use the procedural treatment
	# that predates the screen-reading shader. Native builds retain the full
	# renderer-backed frosted blur.
	_use_backdrop_blur = not OS.has_feature("web")
	set_meta("digi_glass_blur", _use_backdrop_blur)
	if _use_backdrop_blur:
		_ensure_glass_material()


func _ready() -> void:
	_refresh_glass()
	if not _use_backdrop_blur:
		return
	_bound_viewport = get_viewport()
	if _bound_viewport != null:
		if not _bound_viewport.size_changed.is_connected(_refresh_screen_pixel_size):
			_bound_viewport.size_changed.connect(_refresh_screen_pixel_size)
	_refresh_screen_pixel_size()


func _exit_tree() -> void:
	if _bound_viewport != null and is_instance_valid(_bound_viewport):
		if _bound_viewport.size_changed.is_connected(_refresh_screen_pixel_size):
			_bound_viewport.size_changed.disconnect(_refresh_screen_pixel_size)
	_bound_viewport = null
	# Release the CanvasItem reference before this node leaves the tree so native
	# renderer resources cannot outlive the component that owns them.
	material = null
	_glass_material = null


func configure_glass(
	accent: Color = V2.CYAN,
	variant: String = "floating",
	content_padding: Vector4 = Vector4.ZERO,
	radius: int = 10
) -> void:
	_accent = accent
	_variant = variant
	_content_padding = content_padding
	_radius = radius
	set_meta("digi_glass_variant", variant)
	_refresh_glass()


func get_glass_variant() -> String:
	return _variant


func get_glass_material() -> ShaderMaterial:
	if not _use_backdrop_blur:
		return null
	_ensure_glass_material()
	return _glass_material


func _ensure_glass_material() -> void:
	if not _use_backdrop_blur or _glass_material != null:
		return
	_glass_material = ShaderMaterial.new()
	_glass_material.shader = GLASS_SHADER
	material = _glass_material


func _refresh_glass() -> void:
	add_theme_stylebox_override(
		"panel",
		V2.glass_style(_accent, _variant, _content_padding, _radius)
	)
	if not _use_backdrop_blur:
		material = null
		queue_redraw()
		return
	_ensure_glass_material()
	_apply_blur_profile()
	_refresh_screen_pixel_size()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _use_backdrop_blur:
		queue_redraw()


func _draw() -> void:
	if _use_backdrop_blur or size.x <= 0.0 or size.y <= 0.0:
		return
	# Web keeps the original procedural glass highlight. This preserves the V2
	# material language without reading the current framebuffer during scene churn.
	var alpha := 0.085
	match _variant:
		"modal":
			alpha = 0.105
		"subtle":
			alpha = 0.060
	var inset := float(_radius + 7)
	if size.x > inset * 2.0:
		draw_line(
			Vector2(inset, 1.5),
			Vector2(size.x - inset, 1.5),
			Color(1.0, 1.0, 1.0, alpha),
			1.0,
			true
		)


func _refresh_screen_pixel_size() -> void:
	if not _use_backdrop_blur or _glass_material == null or not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_glass_material.set_shader_parameter(
		"screen_pixel_size",
		Vector2(1.0 / viewport_size.x, 1.0 / viewport_size.y)
	)


func _apply_blur_profile() -> void:
	if not _use_backdrop_blur or _glass_material == null:
		return
	var profile := _blur_profile(_variant)
	var base_tint := V2.PANEL_DEEP
	var tint_mix := float(profile.get("accent_tint", 0.04))
	var glass_tint := base_tint.lerp(_accent, tint_mix)
	_glass_material.set_shader_parameter("glass_tint", glass_tint)
	_glass_material.set_shader_parameter("blur_lod", float(profile.get("blur_lod", 3.2)))
	_glass_material.set_shader_parameter("blur_spread", float(profile.get("blur_spread", 1.35)))
	_glass_material.set_shader_parameter("saturation", float(profile.get("saturation", 0.64)))
	_glass_material.set_shader_parameter("brightness", float(profile.get("brightness", 0.80)))
	_glass_material.set_shader_parameter("frost", float(profile.get("frost", 0.24)))
	_glass_material.set_shader_parameter("edge_style", float(profile.get("edge_style", 0.56)))
	_glass_material.set_shader_parameter("glass_opacity", float(profile.get("glass_opacity", 0.90)))


func _blur_profile(variant: String) -> Dictionary:
	# One centralized material profile per semantic glass surface. New screens only
	# choose a variant; they do not duplicate blur/shader tuning locally.
	match variant:
		"modal":
			return {
				"blur_lod": 4.00,
				"blur_spread": 1.65,
				"saturation": 0.52,
				"brightness": 0.76,
				"frost": 0.31,
				"edge_style": 0.60,
				"accent_tint": 0.035,
				"glass_opacity": 0.95,
			}
		"subtle":
			return {
				"blur_lod": 2.45,
				"blur_spread": 1.10,
				"saturation": 0.74,
				"brightness": 0.84,
				"frost": 0.18,
				"edge_style": 0.50,
				"accent_tint": 0.045,
				"glass_opacity": 0.82,
			}
		_:
			return {
				"blur_lod": 3.35,
				"blur_spread": 1.40,
				"saturation": 0.60,
				"brightness": 0.80,
				"frost": 0.25,
				"edge_style": 0.56,
				"accent_tint": 0.04,
				"glass_opacity": 0.91,
			}
