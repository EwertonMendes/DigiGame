extends RefCounted
class_name DebugToolkitAccess

const DEBUG_QUERY_KEYS: Array[String] = ["debug", "dev", "debug_toolkit"]

static func is_available() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if OS.is_debug_build() or OS.has_feature("editor"):
		return true
	for arg in OS.get_cmdline_user_args():
		var token := String(arg).strip_edges().to_lower()
		if token == "--debug-toolkit" or token == "--dev-tools":
			return true
	if OS.has_feature("web"):
		return _web_query_enables_toolkit()
	return false

static func activation_hint() -> String:
	if OS.has_feature("web"):
		return "F2 · append ?debug=1 to a development Web build"
	return "F2 · run a debug build or pass --debug-toolkit"

static func _web_query_enables_toolkit() -> bool:
	var raw = JavaScriptBridge.eval("window.location.search", true)
	var query := String(raw).trim_prefix("?")
	if query.is_empty():
		return false
	for pair in query.split("&"):
		var parts := String(pair).split("=", false, 2)
		var key := String(parts[0]).uri_decode().to_lower().strip_edges()
		if not DEBUG_QUERY_KEYS.has(key):
			continue
		var value := "1" if parts.size() < 2 else String(parts[1]).uri_decode().to_lower().strip_edges()
		if ["1", "true", "yes", "on"].has(value):
			return true
	return false
