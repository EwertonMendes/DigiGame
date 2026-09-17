extends RefCounted
class_name HospitalService

const CalculatorScript = preload("res://src/hospital/HospitalRecoveryCalculator.gd")

var _calculator: HospitalRecoveryCalculator


func _init(calculator: HospitalRecoveryCalculator = null) -> void:
	_calculator = calculator if calculator != null else CalculatorScript.new() as HospitalRecoveryCalculator


func preview(instance: DigimonInstance, max_hp: int, max_sp: int, available_bits: int, now_unix: int = -1, location: String = "") -> Dictionary:
	var now := _resolve_now(now_unix)
	var normalized_max_hp := maxi(1, max_hp)
	var normalized_max_sp := maxi(0, max_sp)
	var status := status_for(instance, normalized_max_hp, now, location)
	var hospitalized := location == PlayerCollection.LOCATION_HOSPITAL
	var party_member := location == PlayerCollection.LOCATION_PARTY
	var cost := _calculator.instant_cost(instance, normalized_max_hp)
	var duration := _calculator.recovery_seconds(instance, normalized_max_hp)
	var completes_at := instance.get_hospital_recovery_end_time() if instance != null else 0
	var progress := _recovery_progress(instance, now) if hospitalized else 0.0
	var current_hp := clampi(instance.current_hp, 0, normalized_max_hp) if instance != null else 0
	var current_sp := clampi(instance.get_current_sp(), 0, normalized_max_sp) if instance != null else 0
	if hospitalized and instance != null and instance.has_hospital_recovery():
		current_hp = _interpolated_resource(current_hp, normalized_max_hp, progress)
		current_sp = _interpolated_resource(current_sp, normalized_max_sp, progress)
	var missing_hp := maxi(0, normalized_max_hp - current_hp)
	var missing_sp := maxi(0, normalized_max_sp - current_sp)
	return {
		"status": status,
		"location": location,
		"current_hp": current_hp,
		"max_hp": normalized_max_hp,
		"current_sp": current_sp,
		"max_sp": normalized_max_sp,
		"missing_hp": missing_hp,
		"missing_hp_ratio": clampf(float(missing_hp) / float(normalized_max_hp), 0.0, 1.0),
		"missing_sp": missing_sp,
		"missing_sp_ratio": clampf(float(missing_sp) / float(normalized_max_sp), 0.0, 1.0) if normalized_max_sp > 0 else 0.0,
		"recovery_progress": progress,
		"recovery_seconds": duration,
		"instant_cost": cost,
		"can_admit": party_member and status in ["injured", "critical"],
		"can_recover_now": (party_member or hospitalized) and status in ["injured", "critical", "recovering"] and cost > 0 and available_bits >= cost,
		"can_discharge": hospitalized and status == "ready",
		"has_enough_bits": available_bits >= cost,
		"started_at": instance.get_hospital_recovery_start_time() if instance != null else 0,
		"completes_at": completes_at,
		"remaining_seconds": maxi(0, completes_at - now) if hospitalized else 0,
	}


func status_for(instance: DigimonInstance, max_hp: int, now_unix: int = -1, location: String = "") -> String:
	if instance == null:
		return "unavailable"
	var now := _resolve_now(now_unix)
	if location == PlayerCollection.LOCATION_HOSPITAL or instance.has_hospital_recovery():
		if not instance.has_hospital_recovery():
			return "ready" if instance.current_hp >= maxi(1, max_hp) else "unavailable"
		return "ready" if instance.get_hospital_recovery_end_time() <= now else "recovering"
	var normalized_max := maxi(1, max_hp)
	if instance.current_hp <= 0:
		return "critical"
	if instance.current_hp < normalized_max:
		return "injured"
	return "healthy"


func admit(collection: PlayerCollection, instance: DigimonInstance, max_hp: int, now_unix: int = -1) -> Dictionary:
	var result := {"success": false, "reason": "invalid", "started_at": 0, "completes_at": 0}
	if collection == null or instance == null:
		return result
	if collection.get_location(instance.id) != PlayerCollection.LOCATION_PARTY:
		result["reason"] = "not_in_party"
		return result
	var now := _resolve_now(now_unix)
	if instance.has_hospital_recovery():
		result["reason"] = "already_recovering"
		return result
	var duration := _calculator.recovery_seconds(instance, max_hp)
	if duration <= 0:
		result["reason"] = "healthy"
		return result
	var completes_at := now + duration
	if not instance.start_hospital_recovery(now, completes_at):
		return result
	if not collection.admit_to_hospital(instance.id):
		instance.clear_hospital_recovery()
		result["reason"] = "location_conflict"
		return result
	result["success"] = true
	result["reason"] = ""
	result["started_at"] = now
	result["completes_at"] = completes_at
	result["duration_seconds"] = duration
	return result


func recover_now(collection: PlayerCollection, instance: DigimonInstance, max_hp: int, max_sp: int, now_unix: int = -1) -> Dictionary:
	var result := {"success": false, "reason": "invalid", "bits_spent": 0}
	if collection == null or instance == null:
		return result
	var location := collection.get_location(instance.id)
	if location not in [PlayerCollection.LOCATION_PARTY, PlayerCollection.LOCATION_HOSPITAL]:
		result["reason"] = "not_in_party_or_hospital"
		return result
	var now := _resolve_now(now_unix)
	var status := status_for(instance, max_hp, now, location)
	if status == "ready":
		result["reason"] = "already_ready"
		return result
	var cost := _calculator.instant_cost(instance, max_hp)
	if cost <= 0:
		result["reason"] = "healthy"
		return result
	if collection.bits < cost:
		result["reason"] = "insufficient_bits"
		return result

	var admitted_during_transaction := false
	if location == PlayerCollection.LOCATION_PARTY:
		if instance.has_hospital_recovery():
			result["reason"] = "location_conflict"
			return result
		if not instance.start_hospital_recovery(now, now):
			return result
		if not collection.admit_to_hospital(instance.id):
			instance.clear_hospital_recovery()
			result["reason"] = "location_conflict"
			return result
		admitted_during_transaction = true
	elif not instance.has_hospital_recovery():
		if not instance.start_hospital_recovery(now, now):
			return result

	var previous_hp := instance.current_hp
	var previous_sp := instance.get_current_sp()
	collection.bits -= cost
	instance.current_hp = maxi(1, max_hp)
	instance.set_current_sp(maxi(0, max_sp))
	if not instance.complete_hospital_recovery(now):
		# This should be unreachable after the validated setup above. Roll back all
		# mutable transaction state rather than leave Bits/location/resources inconsistent.
		collection.bits += cost
		instance.current_hp = previous_hp
		instance.set_current_sp(previous_sp)
		if admitted_during_transaction:
			collection.discharge_from_hospital(instance.id, 0)
		instance.clear_hospital_recovery()
		result["reason"] = "invalid_recovery_state"
		return result
	result["success"] = true
	result["reason"] = ""
	result["bits_spent"] = cost
	result["status"] = "ready"
	return result


func complete_if_ready(instance: DigimonInstance, max_hp: int, max_sp: int, now_unix: int = -1, location: String = "") -> bool:
	if instance == null or location != PlayerCollection.LOCATION_HOSPITAL or not instance.has_hospital_recovery():
		return false
	if instance.get_hospital_recovery_end_time() > _resolve_now(now_unix):
		return false
	var normalized_max_hp := maxi(1, max_hp)
	var normalized_max_sp := maxi(0, max_sp)
	if instance.current_hp >= normalized_max_hp and instance.get_current_sp() >= normalized_max_sp:
		return false
	instance.current_hp = normalized_max_hp
	instance.set_current_sp(normalized_max_sp)
	return true


func discharge(collection: PlayerCollection, instance: DigimonInstance, max_hp: int, maximum_party_size: int, now_unix: int = -1) -> Dictionary:
	var result := {"success": false, "reason": "invalid", "destination": ""}
	if collection == null or instance == null:
		return result
	if collection.get_location(instance.id) != PlayerCollection.LOCATION_HOSPITAL:
		result["reason"] = "not_in_hospital"
		return result
	if status_for(instance, max_hp, now_unix, PlayerCollection.LOCATION_HOSPITAL) != "ready":
		result["reason"] = "still_recovering"
		return result
	var destination := collection.discharge_from_hospital(instance.id, maximum_party_size)
	if destination.is_empty():
		result["reason"] = "location_conflict"
		return result
	instance.clear_hospital_recovery()
	result["success"] = true
	result["reason"] = ""
	result["destination"] = destination
	return result


func battle_eligibility_error(instance: DigimonInstance, max_hp: int, display_name: String, now_unix: int = -1, location: String = "") -> String:
	if instance == null:
		return "The active party contains an unavailable Digimon."
	if location == PlayerCollection.LOCATION_HOSPITAL:
		return "%s is currently at the Hospital." % display_name
	var status := status_for(instance, max_hp, now_unix, location)
	if status == "recovering" or status == "ready":
		return "%s is currently at the Hospital." % display_name
	if status == "critical":
		return "%s is in critical condition and cannot battle." % display_name
	return ""


func _recovery_progress(instance: DigimonInstance, now_unix: int) -> float:
	if instance == null or not instance.has_hospital_recovery():
		return 0.0
	var started_at := instance.get_hospital_recovery_start_time()
	var completes_at := instance.get_hospital_recovery_end_time()
	if completes_at <= started_at:
		return 1.0 if now_unix >= completes_at else 0.0
	return clampf(float(now_unix - started_at) / float(completes_at - started_at), 0.0, 1.0)


func _interpolated_resource(current_value: int, max_value: int, progress: float) -> int:
	var normalized_max := maxi(0, max_value)
	if normalized_max <= 0:
		return 0
	var start_value := clampi(current_value, 0, normalized_max)
	return clampi(int(round(lerpf(float(start_value), float(normalized_max), clampf(progress, 0.0, 1.0)))), 0, normalized_max)


func _resolve_now(now_unix: int) -> int:
	return now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
