extends RefCounted
class_name DebugStateTools

const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const SnapshotStoreScript = preload("res://src/debug/DebugSnapshotStore.gd")
const HISTORY_LIMIT := 120

var snapshots: DebugSnapshotStore = SnapshotStoreScript.new()
var history: Array[Dictionary] = []

func log_action(action: String, detail: String = "") -> void:
	history.push_front({"time": Time.get_time_string_from_system(), "action": action, "detail": detail})
	if history.size() > HISTORY_LIMIT:
		history.resize(HISTORY_LIMIT)

func capture_snapshot(name: String) -> bool:
	var success := snapshots.capture(name, _export_state())
	if success:
		log_action("Snapshot", name.strip_edges() if not name.strip_edges().is_empty() else "auto")
	return success

func list_snapshots() -> Array[Dictionary]:
	return snapshots.list_snapshots()

func restore_snapshot(name: String) -> bool:
	var state := snapshots.get_state(name)
	if state.is_empty() or not _import_state(state):
		return false
	log_action("Restore snapshot", name)
	return true

func delete_snapshot(name: String) -> bool:
	var success := snapshots.delete(name)
	if success:
		log_action("Delete snapshot", name)
	return success

func copy_state_json() -> bool:
	var text := JSON.stringify(_export_state(), "\t")
	if text.is_empty():
		return false
	DisplayServer.clipboard_set(text)
	log_action("Export state", "Copied current state JSON")
	return true

func set_bits(value: int) -> void:
	var collection := _collection()
	if collection == null:
		return
	collection.bits = maxi(0, value)
	_emit_full_state_changed()
	log_action("Set Bits", str(collection.bits))

func set_digi_data(species_name_or_seed: String, value: int) -> bool:
	var collection := _collection()
	if collection == null:
		return false
	var database := OverworldState.get_database() as DigimonDatabase
	var species := database.get_by_seed(species_name_or_seed)
	if species.is_empty():
		species = database.get_by_name(species_name_or_seed)
	if species.is_empty():
		return false
	var seed := String(species.get("seed", ""))
	var current := collection.get_digi_data(seed)
	var target := maxi(0, value)
	if target > current:
		collection.add_digi_data(seed, target - current)
	elif target < current:
		collection.consume_digi_data(seed, current - target)
	_emit_full_state_changed()
	log_action("Set Digi Data", "%s = %d" % [String(species.get("name", seed)), target])
	return true

func set_fusion_data(fusion_id: String, value: int) -> bool:
	var collection := _collection()
	var clean_id := fusion_id.to_lower().strip_edges()
	if collection == null or clean_id.is_empty():
		return false
	var known := false
	for definition: Dictionary in OverworldState.get_fusion_definitions():
		if String(definition.get("id", "")) == clean_id:
			known = true
			break
	if not known:
		return false
	var target := collection.set_fusion_data(clean_id, value)
	_emit_full_state_changed()
	OverworldState.fusion_progress_changed.emit(clean_id, {"fusion_id": clean_id, "after": target, "unlocked": target >= 100})
	log_action("Set Fusion Data", "%s = %d" % [clean_id, target])
	return true


func unlock_all_fusions() -> int:
	var collection := _collection()
	if collection == null:
		return 0
	var count := 0
	for definition: Dictionary in OverworldState.get_fusion_definitions():
		var fusion_id := String(definition.get("id", ""))
		if fusion_id.is_empty():
			continue
		collection.set_fusion_data(fusion_id, 100)
		OverworldState.fusion_progress_changed.emit(fusion_id, {"fusion_id": fusion_id, "after": 100, "unlocked": true})
		count += 1
	_emit_full_state_changed()
	log_action("Unlock all Fusions", "%d recipes" % count)
	return count


func set_flag(flag_id: String, value: bool) -> bool:
	var clean := flag_id.strip_edges()
	var collection := _collection()
	if clean.is_empty() or collection == null:
		return false
	collection.progression_flags[clean] = value
	_emit_full_state_changed()
	log_action("Set flag", "%s = %s" % [clean, str(value)])
	return true

func progression_flags() -> Dictionary:
	var collection := _collection()
	return collection.progression_flags.duplicate(true) if collection != null else {}

func quest_states() -> Dictionary:
	var collection := _collection()
	return collection.quest_states.duplicate(true) if collection != null else {}

func apply_scenario(scenario_id: String, selected_instance_id: String, progression_tools: DebugProgressionTools) -> Dictionary:
	match scenario_id:
		"fresh_start":
			OverworldState.reset_progress_for_tests(false)
			OverworldState.save_progress()
			progression_tools.contexts.clear()
			log_action("Scenario", "Fresh start")
			return {"success": true, "message": "Starter state restored."}
		"party_level_20":
			for value: DigimonInstance in OverworldState.get_squad_instances():
				progression_tools.set_level(value.id, 20)
			log_action("Scenario", "Squad Level 20")
			return {"success": true, "message": "Active and Reserve Squad prepared at Level 20."}
		"critical_party":
			for value: DigimonInstance in OverworldState.get_squad_instances():
				progression_tools.set_critical(value.id)
			log_action("Scenario", "Critical Squad")
			return {"success": true, "message": "Active and Reserve Squad set to 1 HP / 0 SP."}
		"rich_account":
			set_bits(50000)
			var selected := progression_tools.instance(selected_instance_id)
			if selected != null:
				var required := OverworldState.get_reconstruction_requirement(selected.species_seed)
				set_digi_data(selected.species_seed, maxi(200, required * 2))
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
	var tree := Engine.get_main_loop() as SceneTree
	var scene := tree.current_scene if tree != null else null
	var selected := OverworldState.get_instance_by_id(selected_instance_id)
	return {
		"fps": Engine.get_frames_per_second(),
		"frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"scene": scene.scene_file_path if scene != null else "",
		"scene_name": scene.name if scene != null else "",
		"time_scale": Engine.time_scale,
		"collection_size": OverworldState.get_collection_instances().size(),
		"active_size": OverworldState.get_active_instances().size(),
		"reserve_size": OverworldState.get_reserve_party_instances().size(),
		"squad_size": OverworldState.get_squad_instances().size(),
		"party_size": OverworldState.get_squad_instances().size(),
		"bits": OverworldState.get_bits(),
		"selected_level": selected.level if selected != null else 0,
		"selected_hp": selected.current_hp if selected != null else 0,
		"selected_sp": selected.current_mp if selected != null else 0,
		"static_memory": OS.get_static_memory_usage(),
	}

func _collection() -> PlayerCollection:
	var raw = OverworldState.get("_collection")
	return raw as PlayerCollection if raw is PlayerCollection else null

func _export_state() -> Dictionary:
	var collection := _collection()
	return {"version": 1, "collection": collection.to_dict()} if collection != null else {}

func _import_state(state: Dictionary) -> bool:
	var raw = state.get("collection", {})
	if not raw is Dictionary:
		return false
	var restored: PlayerCollection = CollectionScript.new()
	restored.load_dict(raw as Dictionary)
	if restored.is_empty():
		return false
	OverworldState.set("_collection", restored)
	_emit_full_state_changed()
	return true

func _emit_full_state_changed() -> void:
	OverworldState.collection_changed.emit()
	OverworldState.active_party_changed.emit(OverworldState.get_active_party())
	OverworldState.squad_changed.emit(OverworldState.get_active_party_ids(), OverworldState.get_reserve_party_ids())
	OverworldState.account_rewards_changed.emit(OverworldState.get_bits(), OverworldState.get_digi_data())
	OverworldState.save_progress()
