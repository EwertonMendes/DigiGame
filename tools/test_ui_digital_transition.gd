extends Node

const TransitionSurfaceScript = preload("res://src/ui/components/DigiUiTransitionSurface.gd")

var _failures: Array[String] = []


func _ready() -> void:
	var surface := TransitionSurfaceScript.new()
	surface.name = "TransitionSurface"
	add_child(surface)

	var content := ColorRect.new()
	content.color = Color.WHITE
	content.size = Vector2(640.0, 360.0)
	content.clip_contents = true
	var authored_material := CanvasItemMaterial.new()
	content.material = authored_material
	surface.add_transition_child(content)
	await get_tree().process_frame

	_assert(surface is Control and not surface is CanvasGroup, "transition surface must not depend on CanvasGroup/backbuffer composition")
	_assert(surface.get_content_root() != null, "transition surface must own a stable content root")
	_assert(content.get_parent() == surface.get_content_root(), "transition content must be hosted by the shared content root")
	_assert(not DigiUiTransitionDirector.is_transitioning(), "director must start idle")
	_assert(DigiUiTransitionDirector.begin_open(surface, "digimon"), "open transition must start")
	_assert(DigiUiTransitionDirector.is_transitioning(), "open transition must own input while active")
	_assert(surface.is_transition_active(), "surface must install the direct mask only while animating")
	_assert(surface.transition_target_count() >= 2, "surface must mask its content tree without a backbuffer")
	_assert(content.material != authored_material, "transition must temporarily replace authored CanvasItem material")
	_assert(content.clip_contents, "transition must preserve authored clipping")
	_assert(is_equal_approx(surface.get_transition_progress(), 0.0), "open must begin fully concealed")
	await DigiUiTransitionDirector.reveal_open()
	_assert(not DigiUiTransitionDirector.is_transitioning(), "open transition must release the director")
	_assert(not surface.is_transition_active(), "surface must remove the transition material after opening")
	_assert(content.material == authored_material, "opening must restore the authored CanvasItem material")
	_assert(is_equal_approx(surface.get_transition_progress(), 1.0), "open must finish fully revealed")

	_assert(DigiUiTransitionDirector.begin_close(surface, "digimon"), "close transition must start")
	await DigiUiTransitionDirector.conceal_close()
	_assert(DigiUiTransitionDirector.is_transitioning(), "close must remain owned until the screen finalizes")
	_assert(is_equal_approx(surface.get_transition_progress(), 0.0), "close must finish fully concealed")
	content.visible = false
	DigiUiTransitionDirector.complete_close()
	_assert(not DigiUiTransitionDirector.is_transitioning(), "close completion must release the director")
	_assert(not surface.is_transition_active(), "close completion must remove the transition material")
	_assert(content.material == authored_material, "close completion must restore the authored CanvasItem material")
	_assert(content.clip_contents, "close completion must not mutate authored clipping")
	_assert(is_equal_approx(surface.get_transition_progress(), 1.0), "hidden surface must reset for future opens")

	if _failures.is_empty():
		print("ui digital transition regression passed")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("[ui-digital-transition] %s" % failure)
	get_tree().quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
