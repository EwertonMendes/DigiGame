extends Node

const ChartScript = preload("res://src/ui/EvolutionChart.gd")
const CanvasScript = preload("res://src/ui/EvolutionChartCanvas.gd")
const V2 = preload("res://src/ui/components/DigiUiTheme.gd")

var _failures: Array[String] = []


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.name = "EvolutionChartUiV2RegressionViewport"
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)

	var chart := ChartScript.new() as EvolutionChart
	viewport.add_child(chart)
	await _frames(2)
	chart.visible = true
	chart.call("_layout")
	await _frames(2)

	_check(chart.has_meta("digi_ui_v2_component"), "Evolution Chart root must opt into Digi UI V2")
	var frame := chart.get("_frame") as Control
	_check(frame != null and frame.has_meta("digi_glass_surface"), "Evolution Chart must use the shared V2 glass frame")
	var detail := chart.get("_detail_panel") as Control
	_check(detail != null and detail.has_meta("digi_glass_surface"), "Evolution Chart detail must use a V2 glass surface")
	var close_button := chart.get("_close_button") as Button
	_check(close_button != null and close_button.custom_minimum_size.y >= V2.TOUCH_TARGET, "Evolution Chart close action must remain touch-safe")

	var canvas := chart.get("_canvas") as Control
	_check(canvas != null and canvas.get_script() == CanvasScript, "Evolution Chart must preserve the existing graph canvas implementation")
	_check(chart.find_child("EvolutionChartHeaderV2", true, false) != null, "Evolution Chart requires the V2 header surface")
	_check_frame_inside_viewport(chart, viewport, "desktop")
	_check_regions(chart, false)
	await _check_node_sprite_sizing(canvas)

	viewport.size = Vector2i(700, 540)
	await _frames(2)
	chart.call("_layout")
	await _frames(2)
	_check_frame_inside_viewport(chart, viewport, "compact")
	_check_regions(chart, true)

	chart.queue_free()
	viewport.queue_free()
	await _frames(2)
	if _failures.is_empty():
		print("evolution chart ui v2 regression passed")
		get_tree().quit()
		return
	for failure in _failures:
		push_error("[evolution-chart-ui-v2] %s" % failure)
	get_tree().quit(1)


func _check_node_sprite_sizing(canvas: Control) -> void:
	var cases: Array[Dictionary] = [
		{"label": "Fresh", "name": "Botamon", "key": "botamon", "rank": "Fresh", "rank_index": 0, "minimum_fill": 0.60},
		{"label": "Rookie", "name": "Agumon", "key": "agumon", "rank": "Rookie", "rank_index": 2, "minimum_fill": 0.78},
		{"label": "Champion", "name": "Greymon", "key": "greymon", "rank": "Champion", "rank_index": 3, "minimum_fill": 0.88},
	]
	var extents: Dictionary = {}

	for case: Dictionary in cases:
		var node := {
			"seed": "regression-%s" % String(case.get("key", "")),
			"name": String(case.get("name", "")),
			"rank": String(case.get("rank", "")),
			"rank_index": int(case.get("rank_index", 0)),
		}
		var button := canvas.call("_create_node_button", node) as Button
		if not _check(button != null, "%s Evolution node must be constructible" % String(case.get("label", ""))):
			continue
		canvas.add_child(button)
		await _frames(2)

		var preview := button.find_child("WalkPreview", true, false) as Control
		if not _check(preview != null, "%s Evolution node must expose its field preview" % String(case.get("label", ""))):
			button.queue_free()
			continue
		var sprite := preview.get_node_or_null("FieldSprite") as Sprite2D
		if not _check(sprite != null and sprite.texture != null, "%s Evolution preview must load its field sprite" % String(case.get("label", ""))):
			button.queue_free()
			continue

		var resource := load("res://assets/resources/%s.tres" % String(case.get("key", ""))) as Digimon
		if not _check(resource != null and resource.texture != null, "%s regression resource must load" % String(case.get("label", ""))):
			button.queue_free()
			continue
		var frame_size := _resource_frame_size(resource)
		var visual_extent := maxf(
			frame_size.x * absf(sprite.scale.x),
			frame_size.y * absf(sprite.scale.y)
		)
		extents[String(case.get("label", ""))] = visual_extent

		_check(
			visual_extent >= minf(preview.size.x, preview.size.y) * float(case.get("minimum_fill", 0.0)),
			"%s Evolution sprite must use most of its available card envelope" % String(case.get("label", ""))
		)
		_check(
			sprite.position.distance_to(preview.size * 0.5) <= 0.6,
			"%s Evolution sprite must be geometrically centered in its card" % String(case.get("label", ""))
		)
		var visual_frame := preview.get_parent() as Control
		_check(
			visual_frame != null and visual_frame.custom_minimum_size.x >= 80.0,
			"Evolution node visual frame must reserve the enlarged readable sprite area"
		)

		button.queue_free()
		await _frames(1)

	if extents.has("Fresh") and extents.has("Rookie") and extents.has("Champion"):
		_check(
			float(extents["Fresh"]) < float(extents["Rookie"]) and float(extents["Rookie"]) < float(extents["Champion"]),
			"Evolution card sprite envelopes must remain monotonic from Fresh to Rookie to Champion"
		)


func _resource_frame_size(resource: Digimon) -> Vector2:
	if resource.sprite_layout == "spaced_9_32":
		return Vector2(32.0, 32.0)
	return Vector2(
		float(resource.texture.get_width()) / float(maxi(1, resource.sprite_hframes)),
		float(resource.texture.get_height()) / float(maxi(1, resource.sprite_vframes))
	)


func _check_frame_inside_viewport(chart: EvolutionChart, viewport: SubViewport, context: String) -> void:
	var frame := chart.get("_frame") as Control
	if not _check(frame != null, "%s layout requires a frame" % context):
		return
	var effective_size := frame.size * frame.scale
	var bottom_right := frame.position + effective_size
	_check(frame.position.x >= -1.0 and frame.position.y >= -1.0, "%s Evolution Chart must not begin outside the viewport" % context)
	_check(bottom_right.x <= float(viewport.size.x) + 1.0, "%s Evolution Chart must not overflow horizontally" % context)
	_check(bottom_right.y <= float(viewport.size.y) + 1.0, "%s Evolution Chart must not overflow vertically" % context)
	_check(frame.clip_contents, "%s Evolution Chart frame must clip late dynamic content safely" % context)


func _check_regions(chart: EvolutionChart, compact: bool) -> void:
	var canvas := chart.get("_canvas") as Control
	var detail := chart.get("_detail_panel") as Control
	if not _check(canvas != null and detail != null, "Chart and detail regions must both exist"):
		return
	_check(canvas.size.x > 0.0 and canvas.size.y > 0.0, "Graph canvas must keep a usable positive size")
	_check(detail.size.x > 0.0 and detail.size.y > 0.0, "Detail panel must keep a usable positive size")
	if compact:
		_check(detail.position.y >= canvas.position.y + canvas.size.y - 1.0, "Compact layout must stack details below the graph without overlap")
	else:
		_check(detail.position.x >= canvas.position.x + canvas.size.x - 1.0, "Desktop layout must keep details beside the graph without overlap")


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame