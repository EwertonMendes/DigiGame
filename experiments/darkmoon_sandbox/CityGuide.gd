extends Node2D

var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	get_node("Body").position.y = -32.0 + roundf(sin(elapsed * 2.0))
	var scene := get_parent().get_parent()
	if scene.has_method("resolve_actor_depth"):
		z_index = int(scene.call("resolve_actor_depth",self))
