extends RefCounted
class_name DebugStateTools

const SnapshotStoreScript = preload("res://src/debug/DebugSnapshotStore.gd")
const HISTORY_LIMIT := 120

var snapshots: DebugSnapshotStore = SnapshotStoreScript.new()
var history: Array[Dictionary] = []

func log_action(action: String, detail: String = "") -> void:
	history.push_front({"time": Time.get_time_string_from_system(), "action": action, "detail": detail})
	if history.size() > HISTORY_LIMIT:
		history.resize(HISTORY_LIMIT)

func capture_snapshot(name: String) -> bool:
	var success := snapshots.capture(name, OverworldState.debug_export_state())
	if success:
		log_action("Snapshot", name.strip_edges() if not name.strip_edges().is_empty() else "auto")
	return success

func list_snapshots() -> Array[Dictionary]:
	return snapshots.list_snapshots()

func restore_snapshot(name: String) -> bool:
	var state := snapshots.get_state(name)
	if state.is_empty() or not OverworldState.debug_import_state(state):
		return false
	log_action("Restore snapshot", name)
	return true

func delete_snapshot(name: String) -> bool:
	var success := snapshots.delete(name)
	if success:
		log_action("Delete snapshot", name)
	return success

func copy_state_json() -> bool:
	var text := JSON.stringify(OverworldState.debug_export_state(), "\t")
	if text.is_empty():
		return false
	DisplayServer.clipboard_set(text)
	log_action("Export state", "Copied current state JSON")
	return true

func set_bits(value: int) -> void:
	OverworldState.debug_set_bits(maxi(0, value))
	log_action("Set Bits", str(maxi(0, value)))

func set_digi_data(species_name_or_seed: String, value: int) -> bool:
	var success := OverworldState.debug_set_digi_data(species_name_or_seed, maxi(0, value))
	if success:
		log_action("Set Digi Data", "%s = %d" % [species_name_or_seed, maxi(0, value)])
	return success

func set_flag(flag_id: String, value: bool) -> bool:
	var clean := flag_id.strip_edges()
	if clean.is_empty():
		return false
	OverworldState.debug_set_progression_flag(clean, value)
	log_action("Set flag", "%s = %s" % [clean, str(value)])
	return true

func apply_scenario(scenario_id: String, selected_instance_id: String, progression_tools: DebugProgressionTools) -> Dictionary:
	match scenario_id:
		"fresh_start":
			OverworldState.debug_reset_progress()
			progression_tools.contexts.clear()
			log_action("Scenario", "Fresh start")
			return {"success": true, "message": "Starter state restored."}
		"party_level_20":
			for value: DigimonInstance in OverworldState.get_active_instances():
				progression_tools.set_level(value.id, 20)
			log_action("Scenario", "Party Level 20")
			return {"success": true, "message": "Active party prepared at Level 20."}
		"critical_party":
			for value: DigimonInstance in OverworldState.get_active_instances():
				progression_tools.set_critical(value.id)
			log_action("Scenario", "Critical party")
			return {"success": true, "message": "Active party set to 1 HP / 0 SP."}
		"rich_account":
			OverworldState.debug_set_bits(50000)
			var selected := progression_tools.instance(selected_instance_id)
			if selected != null:
				var required := OverworldState.get_reconstruction_requirement(selected.species_seed)
				OverworldState.debug_set_digi_data(selected.species_seed, maxi(200, required * 2))
				progression_tools.set_potential(selected.id, 80)
				progression_tools.set_link(selected.id, 80)
			log_action("Scenario", "Resource rich")
			return {"success": true, "message": "50,000 Bits and selected-Digimon resources prepared."}
		"ready_first_evolution":
			var selected := progression_tools.instance(selected_instance_id)
			if selected == null:
				return {"success": false, "message": "Select a Digimon first."}
			var routes := progression_tools.routes(selected.id, false)
			if routes.is_empty():
				return {"success": false, "message": "Selected Digimon has no evolution route."}
			var prepared := progression_tools.meet_requirements(selected.id, String(routes[0].get("targetSeed", "")), false)
			var ready := bool(prepared.get("success", false))
			log_action("Scenario", "First evolution ready" if ready else "Evolution preparation blocked")
			return {"success": ready, "message": "First evolution route prepared." if ready else String(prepared.get("reason", "Could not prepare route."))}
	return {"success": false, "message": "Unknown scenario."}

func diagnostics(selected_instance_id: String = "") -> Dictionary:
	var scene := Engine.get_main_loop().current_scene if Engine.get_main_loop() is SceneTree else null
	var selected := OverworldState.get_instance_by_id(selected_instance_id)
	return {
		"fps": Engine.get_frames_per_second(),
		"scene": scene.scene_file_path if scene != null else "",
		"scene_name": scene.name if scene != null else "",
		"time_scale": Engine.time_scale,
		"collection_size": OverworldState.get_collection_instances().size(),
		"party_size": OverworldState.get_active_instances().size(),
		"bits": OverworldState.get_bits(),
		"selected_level": selected.level if selected != null else 0,
		"selected_hp": selected.current_hp if selected != null else 0,
		"selected_sp": selected.current_mp if selected != null else 0,
		"static_memory": OS.get_static_memory_usage(),
	}
