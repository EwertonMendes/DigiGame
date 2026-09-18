extends Control
class_name DigiIconView

const ProceduralIconScript = preload("res://src/ui/components/DigiProceduralIcon.gd")

var _procedural: DigiProceduralIcon
var _texture_rect: TextureRect
var _texture: Texture2D = null
var _accent := Color.WHITE
var _procedural_kind := "info"
var _line_width := 2.4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.x <= 0.0 and custom_minimum_size.y <= 0.0:
		custom_minimum_size = Vector2(32.0, 32.0)
	_ensure_children()
	_apply_mode()


func configure_procedural(kind: String, accent: Color, line_width: float = 2.4) -> DigiIconView:
	_texture = null
	_procedural_kind = kind
	_accent = accent
	_line_width = line_width
	if is_node_ready():
		_ensure_children()
		_apply_mode()
	return self


func configure_texture(texture: Texture2D, accent: Color = Color.WHITE) -> DigiIconView:
	_texture = texture
	_accent = accent
	if is_node_ready():
		_ensure_children()
		_apply_mode()
	return self


func uses_texture() -> bool:
	return _texture != null


func get_texture() -> Texture2D:
	return _texture


func _ensure_children() -> void:
	if _procedural == null:
		_procedural = ProceduralIconScript.new() as DigiProceduralIcon
		_procedural.name = "ProceduralIcon"
		_procedural.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_procedural.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_procedural)

	if _texture_rect == null:
		_texture_rect = TextureRect.new()
		_texture_rect.name = "AssetIcon"
		_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_texture_rect)


func _apply_mode() -> void:
	if _procedural == null or _texture_rect == null:
		return
	var asset_mode := _texture != null
	_procedural.visible = not asset_mode
	_texture_rect.visible = asset_mode
	if asset_mode:
		_texture_rect.texture = _texture
		_texture_rect.self_modulate = _accent
	else:
		_texture_rect.texture = null
		_procedural.configure(_procedural_kind, _accent, _line_width)
