extends PanelContainer
class_name DigiGlassPanel

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const GLASS_SHADER = preload("res://src/ui/components/digi_glass_backdrop.gdshader")

var _accent := V2.CYAN
var _variant := "floating"
var _content_padding := Vector4.ZERO
var _radius := 10
var _glass_material: ShaderMaterial = null


func _init() -> void:
	set_meta("digi_ui_v2_component", true)
	set_meta("digi_glass_surface", true)
	set_meta("digi_glass_blur", true)
	_ensure_glass_material()


func _ready() -> void:
	_refresh_glass()


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
	_ensure_glass_material()
	return _glass_material


func _ensure_glass_material() -> void:
	if _glass_material != null:
		return
	_glass_material = ShaderMaterial.new()
	_glass_material.shader = GLASS_SHADER
	material = _glass_material


func _refresh_glass() -> void:
	_ensure_glass_material()
	add_theme_stylebox_override(
		"panel",
		V2.glass_style(_accent, _variant, _content_padding, _radius)
	)
	_apply_blur_profile()
	queue_redraw()


func _apply_blur_profile() -> void:
	if _glass_material == null:
		return
	var profile := _blur_profile(_variant)
	var base_tint := V2.PANEL_DEEP
	var tint_mix := float(profile.get("accent_tint", 0.04))
	var glass_tint := base_tint.lerp(_accent, tint_mix)
	_glass_material.set_shader_parameter("glass_tint", glass_tint)
	_glass_material.set_shader_parameter("blur_lod", float(profile.get("blur_lod", 2.6)))
	_glass_material.set_shader_parameter("blur_spread", float(profile.get("blur_spread", 1.25)))
	_glass_material.set_shader_parameter("saturation", float(profile.get("saturation", 0.72)))
	_glass_material.set_shader_parameter("brightness", float(profile.get("brightness", 0.80)))
	_glass_material.set_shader_parameter("frost", float(profile.get("frost", 0.20)))
	_glass_material.set_shader_parameter("edge_style", float(profile.get("edge_style", 0.56)))


func _blur_profile(variant: String) -> Dictionary:
	# One centralized material profile per semantic glass surface. New screens only
	# choose a variant; they do not duplicate blur/shader tuning locally.
	match variant:
		"modal":
			return {
				"blur_lod": 3.15,
				"blur_spread": 1.45,
				"saturation": 0.62,
				"brightness": 0.72,
				"frost": 0.27,
				"edge_style": 0.58,
				"accent_tint": 0.035,
			}
		"subtle":
			return {
				"blur_lod": 1.90,
				"blur_spread": 1.00,
				"saturation": 0.82,
				"brightness": 0.86,
				"frost": 0.15,
				"edge_style": 0.50,
				"accent_tint": 0.045,
			}
		_:
			return {
				"blur_lod": 2.60,
				"blur_spread": 1.25,
				"saturation": 0.70,
				"brightness": 0.79,
				"frost": 0.21,
				"edge_style": 0.55,
				"accent_tint": 0.04,
			}
