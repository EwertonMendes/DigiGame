extends Control
class_name DigiUiTransitionSurface

const TRANSITION_SHADER = preload("res://shaders/digi_ui_transition.gdshader")

var _material: ShaderMaterial
var _content_root: Control
var _progress := 1.0
var _transition_active := false
var _original_materials: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_content_root()
	_ensure_material()
	_sync_content_rect()
	var owner := get_parent() as Control
	if owner != null and not owner.resized.is_connected(_sync_content_rect):
		owner.resized.connect(_sync_content_rect)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_sync_content_rect):
		get_viewport().size_changed.connect(_sync_content_rect)


func get_content_root() -> Control:
	_ensure_content_root()
	return _content_root


func add_transition_child(node: Node) -> void:
	if node == null:
		return
	get_content_root().add_child(node)


func begin_transition() -> void:
	_ensure_material()
	_transition_active = true
	refresh_transition_targets()


func refresh_transition_targets() -> void:
	if not _transition_active or _content_root == null:
		return
	_apply_transition_material_recursive(_content_root)


func end_transition() -> void:
	if not _transition_active and _original_materials.is_empty():
		return
	for raw_entry: Variant in _original_materials.values():
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var ref := entry.get("ref") as WeakRef
		var item := ref.get_ref() as CanvasItem if ref != null else null
		if item == null or not is_instance_valid(item):
			continue
		item.material = entry.get("material") as Material
	_transition_active = false
	_original_materials.clear()


func is_transition_active() -> bool:
	return _transition_active


func transition_target_count() -> int:
	return _original_materials.size()


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


func _ensure_content_root() -> void:
	if _content_root != null:
		return
	_content_root = Control.new()
	_content_root.name = "TransitionContent"
	_content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content_root)
	_sync_content_rect()


func _sync_content_rect() -> void:
	if _content_root == null:
		return
	position = Vector2.ZERO
	var owner := get_parent() as Control
	if owner != null:
		size = owner.size
	else:
		size = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2.ZERO
	_content_root.position = Vector2.ZERO
	_content_root.size = size


func _apply_transition_material_recursive(node: Node) -> void:
	if node is CanvasItem:
		var item := node as CanvasItem
		var instance_id := item.get_instance_id()
		if not _original_materials.has(instance_id):
			_original_materials[instance_id] = {
				"ref": weakref(item),
				"material": item.material,
			}
		item.material = _material
	for child: Node in node.get_children():
		_apply_transition_material_recursive(child)
