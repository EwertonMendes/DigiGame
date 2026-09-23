extends Node
class_name WorldPerformanceMonitor

const FIRST_SAMPLE_SECONDS := 1.0
const REPEAT_SAMPLE_SECONDS := 5.0

var _area: WorldAreaScene = null
var _elapsed := 0.0
var _next_sample := FIRST_SAMPLE_SECONDS
var _last_snapshot: Dictionary = {}


func configure(area: WorldAreaScene) -> void:
	_area = area


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < _next_sample:
		return
	_elapsed = 0.0
	_next_sample = REPEAT_SAMPLE_SECONDS
	_last_snapshot = snapshot()
	print(
		"[WorldPerf] fps=%d frame_ms=%.2f physics_ms=%.2f nodes=%d area_nodes=%d draw_calls=%d render_objects=%d"
		% [
			int(_last_snapshot.get("fps", 0)),
			float(_last_snapshot.get("frame_ms", 0.0)),
			float(_last_snapshot.get("physics_ms", 0.0)),
			int(_last_snapshot.get("nodes", 0)),
			int(_last_snapshot.get("area_nodes", 0)),
			int(_last_snapshot.get("draw_calls", 0)),
			int(_last_snapshot.get("render_objects", 0)),
		]
	)


func snapshot() -> Dictionary:
	return {
		"fps": int(round(Performance.get_monitor(Performance.TIME_FPS))),
		"frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"area_nodes": _area.get_runtime_node_count() if _area != null else 0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}


func get_last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)
