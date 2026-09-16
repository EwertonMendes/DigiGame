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