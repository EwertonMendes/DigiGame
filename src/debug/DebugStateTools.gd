extends RefCounted
class_name DebugStateTools

const CollectionScript = preload("res://src/collection/PlayerCollection.gd")
const FactoryScript = preload("res://src/digimon/DigimonFactory.gd")
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
	if species.is_empty() or String(species.get("rank", "")) == "Fusion" or not bool(species.get("reconstructable", true)):
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
	return set_all_fusion_data(100)


func lock_all_fusions() -> int:
	return set_all_fusion_data(0)


func set_all_fusion_data(value: int) -> int:
	var collection := _collection()
	if collection == null:
		return 0
	var target := clampi(value, 0, 100)
	var count := 0
	for definition: Dictionary in OverworldState.get_fusion_definitions():
		var fusion_id := String(definition.get("id", ""))
		if fusion_id.is_empty():
			continue
		collection.set_fusion_data(fusion_id, target)
		OverworldState.fusion_progress_changed.emit(fusion_id, {"fusion_id": fusion_id, "after": target, "unlocked": target >= 100})
		count += 1
	_emit_full_state_changed()
	log_action("Set all Fusion Data", "%d recipes = %d" % [count, target])
	return count


func adjust_fusion_data(fusion_id: String, delta: int) -> bool:
	var clean_id := fusion_id.to_lower().strip_edges()
	var collection := _collection()
	if collection == null or clean_id.is_empty() or _fusion_definition(clean_id).is_empty():
		return false
	var before := collection.get_fusion_data(clean_id)
	var target := collection.set_fusion_data(clean_id, before + delta)
	_emit_full_state_changed()
	OverworldState.fusion_progress_changed.emit(clean_id, {
		"fusion_id": clean_id,
		"before": before,
		"after": target,
		"gained": target - before,
		"unlocked": target >= 100,
		"newly_unlocked": before < 100 and target >= 100,
	})
	log_action("Adjust Fusion Data", "%s · %+d → %d" % [clean_id, delta, target])
	return true


func fusion_material_status(fusion_id: String) -> Dictionary:
	var clean_id := fusion_id.to_lower().strip_edges()
	var definition := _fusion_definition(clean_id)
	var collection := _collection()
	var result := {"fusion_id": clean_id, "rows": [], "items": []}
	if collection == null or definition.is_empty():
		return result
	var database := OverworldState.get_database() as DigimonDatabase
	for material: Dictionary in definition.get("materials", []):
		var kind := String(material.get("type", "digimon"))
		if kind == "item":
			var item_id := String(material.get("itemId", ""))
			var required := maxi(1, int(material.get("amount", 1)))
			(result["items"] as Array).append({
				"itemId": item_id,
				"required": required,
				"owned": collection.get_item_count(item_id),
			})
			continue
		var seed := String(material.get("speciesSeed", ""))
		var required := maxi(1, int(material.get("amount", 1)))
		var min_level := clampi(int(material.get("minLevel", 1)), 1, 99)
		var active := 0
		var reserve := 0
		var storage := 0
		var blocked := 0
		for instance: DigimonInstance in collection.get_instances():
			if instance.species_seed != seed:
				continue
			if collection.is_hospitalized(instance.id) or instance.level < min_level or instance.is_fainted() or not instance.equipment.is_empty():
				blocked += 1
				continue
			var role := collection.get_squad_role(instance.id)
			if role == PlayerCollection.SQUAD_ROLE_ACTIVE:
				active += 1
			elif role == PlayerCollection.SQUAD_ROLE_RESERVE:
				reserve += 1
			else:
				storage += 1
		var species := database.get_by_seed(seed)
		(result["rows"] as Array).append({
			"speciesSeed": seed,
			"name": String(species.get("name", seed)),
			"required": required,
			"minLevel": min_level,
			"active": active,
			"reserve": reserve,
			"storage": storage,
			"eligible": active + reserve + storage,
			"blocked": blocked,
		})
	return result


func spawn_fusion_materials(fusion_id: String, level_bonus: int = 0) -> Dictionary:
	var clean_id := fusion_id.to_lower().strip_edges()
	var definition := _fusion_definition(clean_id)
	var collection := _collection()
	var result := {"success": false, "spawned": 0, "items": 0, "instance_ids": []}
	if collection == null or definition.is_empty():
		return result
	var database := OverworldState.get_database() as DigimonDatabase
	var factory := FactoryScript.new(database) as DigimonFactory
	for material: Dictionary in definition.get("materials", []):
		var kind := String(material.get("type", "digimon"))
		var amount := maxi(1, int(material.get("amount", 1)))
		if kind == "item":
			var item_id := String(material.get("itemId", "")).strip_edges()
			if not item_id.is_empty():
				collection.add_item(item_id, amount)
				result["items"] = int(result["items"]) + amount
			continue
		var seed := String(material.get("speciesSeed", "")).strip_edges()
		var base_level := clampi(int(material.get("minLevel", 1)), 1, 99)
		var level := clampi(base_level + maxi(0, level_bonus), 1, 99)
		for _index in range(amount):
			var instance := factory.create_player_by_seed(seed, level, 100)
			if instance == null:
				continue
			instance.origin = "debug:fusion_material:%s" % clean_id
			var species := database.get_by_seed(seed)
			var key := collection.add_instance(instance, "", String(species.get("name", "digimon")))
			if key.is_empty():
				continue
			(result["instance_ids"] as Array).append(instance.id)
			result["spawned"] = int(result["spawned"]) + 1
	result["success"] = int(result["spawned"]) > 0 or int(result["items"]) > 0
	_emit_full_state_changed()
	log_action("Spawn Fusion materials", "%s · %d Digimon · %d items" % [clean_id, int(result["spawned"]), int(result["items"])])
	return result


func remove_debug_fusion_materials(fusion_id: String) -> int:
	var clean_id := fusion_id.to_lower().strip_edges()
	var collection := _collection()
	if collection == null or clean_id.is_empty():
		return 0
	var prefix := "debug:fusion_material:%s" % clean_id
	var ids: Array[String] = []
	for instance: DigimonInstance in collection.get_instances():
		if instance.origin == prefix:
			ids.append(instance.id)
	for instance_id: String in ids:
		collection.remove_instance(instance_id)
	if not ids.is_empty():
		_emit_full_state_changed()
	log_action("Remove Fusion test materials", "%s · %d removed" % [clean_id, ids.size()])
	return ids.size()


func force_fusion_without_materials(fusion_id: String) -> Dictionary:
	var clean_id := fusion_id.to_lower().strip_edges()
	var definition := _fusion_definition(clean_id)
	var collection := _collection()
	var result := {"success": false, "reason": "invalid_debug_fusion"}
	if collection == null or definition.is_empty():
		return result
	var database := OverworldState.get_database() as DigimonDatabase
	var factory := FactoryScript.new(database) as DigimonFactory
	var spawned_ids: Array[String] = []
	var original_item_counts: Dictionary = {}
	var previous_data := collection.get_fusion_data(clean_id)
	collection.set_fusion_data(clean_id, 100)

	for material: Dictionary in definition.get("materials", []):
		var kind := String(material.get("type", "digimon"))
		var amount := maxi(1, int(material.get("amount", 1)))
		if kind == "item":
			var item_id := String(material.get("itemId", "")).strip_edges()
			if item_id.is_empty():
				continue
			original_item_counts[item_id] = collection.get_item_count(item_id)
			collection.add_item(item_id, amount)
			continue
		var seed := String(material.get("speciesSeed", "")).strip_edges()
		var level := clampi(int(material.get("minLevel", 1)), 1, 99)
		for _index in range(amount):
			var instance := factory.create_player_by_seed(seed, level, 100)
			if instance == null:
				continue
			instance.origin = "debug:fusion_force:%s" % clean_id
			var species := database.get_by_seed(seed)
			var key := collection.add_instance(instance, "", String(species.get("name", "digimon")))
			if not key.is_empty():
				spawned_ids.append(instance.id)

	result = OverworldState.fuse_digimon(clean_id, spawned_ids)

	for raw_item_id in original_item_counts.keys():
		var item_id := String(raw_item_id)
		var original := int(original_item_counts[raw_item_id])
		var current := collection.get_item_count(item_id)
		if current < original:
			collection.add_item(item_id, original - current)
		elif current > original:
			collection.consume_item(item_id, current - original)

	if not bool(result.get("success", false)):
		for instance_id: String in spawned_ids:
			if collection.has_instance(instance_id):
				collection.remove_instance(instance_id)

	collection.set_fusion_data(clean_id, previous_data)
	OverworldState.fusion_progress_changed.emit(clean_id, {"fusion_id": clean_id, "after": previous_data, "unlocked": previous_data >= 100})
	_emit_full_state_changed()
	log_action("Force Fusion without materials", "%s · %s" % [clean_id, "success" if bool(result.get("success", false)) else String(result.get("reason", "failed"))])
	return result


func _fusion_definition(fusion_id: String) -> Dictionary:
	var clean_id := fusion_id.to_lower().strip_edges()
	for definition: Dictionary in OverworldState.get_fusion_definitions():
		if String(definition.get("id", "")) == clean_id:
			return definition
	return {}


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
