extends CanvasGroup
class_name DigiUiTransitionSurface

const TRANSITION_SHADER = preload("res://shaders/digi_ui_transition.gdshader")

var _material: ShaderMaterial
var _content_root: Control
var _progress := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_content_root()
	_ensure_material()


func get_content_root() -> Control:
	_ensure_content_root()
	return _content_root


func add_transition_child(node: Node) -> void:
	if node == null:
		return
	get_content_root().add_child(node)


func set_transition_progress(value: float) -> void:
	_ensure_material()
	_progress = clampf(value, 0.0, 1.0)
	_material.set_shader_parameter("progress", _progress)


func get_transition_progress() -> float:
	return _progress


func set_phase_seed(value: float) -> void:
	_ensure_material()
	_material.set_shader_parameter("phase_seed", value)


func configure_palette(primary: Color, accent: Color) -> void:
	_ensure_material()
	_material.set_shader_parameter("primary_color", primary)
	_material.set_shader_parameter("accent_color", accent)


func _ensure_material() -> void:
	if _material != null:
		return
	_material = ShaderMaterial.new()
	_material.shader = TRANSITION_SHADER
	_material.set_shader_parameter("progress", _progress)
	material = _material


func _ensure_content_root() -> void:
	if _content_root != null:
		return
	_content_root = Control.new()
	_content_root.name = "TransitionContent"
	_content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content_root)
