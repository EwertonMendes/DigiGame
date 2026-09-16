extends RefCounted
class_name HospitalService

const CalculatorScript = preload("res://src/hospital/HospitalRecoveryCalculator.gd")

var _calculator: HospitalRecoveryCalculator


func _init(calculator: HospitalRecoveryCalculator = null) -> void:
	_calculator = calculator if calculator != null else CalculatorScript.new() as HospitalRecoveryCalculator


func preview(instance: DigimonInstance, max_hp: int, available_bits: int, now_unix: int = -1) -> Dictionary:
	var now := _resolve_now(now_unix)
	var normalized_max := maxi(1, max_hp)
	var cost := _calculator.instant_cost(instance, normalized_max)
	var duration := _calculator.recovery_seconds(instance, normalized_max)
	var status := status_for(instance, normalized_max, now)
	var completes_at := instance.get_hospital_recovery_end_time() if instance != null else 0
	return {
		"status": status,
		"current_hp": clampi(instance.current_hp, 0, normalized_max) if instance != null else 0,
		"max_hp": normalized_max,
		"missing_hp": _calculator.missing_hp(instance, normalized_max),
		"missing_hp_ratio": _calculator.missing_hp_ratio(instance, normalized_max),
		"recovery_seconds": duration,
		"instant_cost": cost,
		"can_admit": status in ["injured", "critical"],
		"can_recover_now": cost > 0 and available_bits >= cost,
		"has_enough_bits": available_bits >= cost,
		"started_at": instance.get_hospital_recovery_start_time() if instance != null else 0,
		"completes_at": completes_at,
		"remaining_seconds": maxi(0, completes_at - now),
	}


func status_for(instance: DigimonInstance, max_hp: int, now_unix: int = -1) -> String:
	if instance == null:
		return "unavailable"
	var now := _resolve_now(now_unix)
	if instance.has_hospital_recovery():
		return "ready" if instance.get_hospital_recovery_end_time() <= now else "recovering"
	var normalized_max := maxi(1, max_hp)
	if instance.current_hp <= 0:
		return "critical"
	if instance.current_hp < normalized_max:
		return "injured"
	return "healthy"


func admit(instance: DigimonInstance, max_hp: int, now_unix: int = -1) -> Dictionary:
	var result := {"success": false, "reason": "invalid", "started_at": 0, "completes_at": 0}
	if instance == null:
		return result
	var now := _resolve_now(now_unix)
	if complete_if_ready(instance, max_hp, now):
		result["reason"] = "healthy"
		return result
	if instance.has_hospital_recovery():
		result["reason"] = "already_recovering"
		return result
	var duration := _calculator.recovery_seconds(instance, max_hp)
	if duration <= 0:
		result["reason"] = "healthy"
		return result
	var completes_at := now + duration
	instance.start_hospital_recovery(now, completes_at)
	result["success"] = true
	result["reason"] = ""
	result["started_at"] = now
	result["completes_at"] = completes_at
	result["duration_seconds"] = duration
	return result


func recover_now(collection: PlayerCollection, instance: DigimonInstance, max_hp: int) -> Dictionary:
	var result := {"success": false, "reason": "invalid", "bits_spent": 0}
	if collection == null or instance == null:
		return result
	var cost := _calculator.instant_cost(instance, max_hp)
	if cost <= 0:
		result["reason"] = "healthy"
		return result
	if collection.bits < cost:
		result["reason"] = "insufficient_bits"
		return result
	collection.bits -= cost
	instance.current_hp = maxi(1, max_hp)
	instance.clear_hospital_recovery()
	result["success"] = true
	result["reason"] = ""
	result["bits_spent"] = cost
	return result


func complete_if_ready(instance: DigimonInstance, max_hp: int, now_unix: int = -1) -> bool:
	if instance == null or not instance.has_hospital_recovery():
		return false
	if instance.get_hospital_recovery_end_time() > _resolve_now(now_unix):
		return false
	instance.current_hp = maxi(1, max_hp)
	instance.clear_hospital_recovery()
	return true


func battle_eligibility_error(instance: DigimonInstance, max_hp: int, display_name: String, now_unix: int = -1) -> String:
	if instance == null:
		return "The active party contains an unavailable Digimon."
	var status := status_for(instance, max_hp, now_unix)
	if status == "recovering":
		return "%s is still recovering at the Hospital." % display_name
	if status == "critical" or status == "ready":
		return "%s is in critical condition and cannot battle." % display_name
	return ""


func _resolve_now(now_unix: int) -> int:
	return now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
