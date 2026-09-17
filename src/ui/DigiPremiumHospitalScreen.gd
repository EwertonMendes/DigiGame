extends "res://src/ui/DigiHospitalScreen.gd"
class_name DigiPremiumHospitalScreen

const BitsDisplayScript = preload("res://src/ui/components/DigiBitsDisplay.gd")

const PREMIUM_BITS_SIZE := Vector2(184.0, 52.0)
const COMPACT_BITS_SIZE := Vector2(150.0, 42.0)

var _premium_bits_display: DigiBitsDisplay


func _build_header() -> void:
	super._build_header()
	var badge: Panel = _header.get_node_or_null("BitsBadge") as Panel
	if badge == null:
		return

	# Preserve the legacy header contract while replacing only its presentation.
	# HospitalScreen still owns the balance lifecycle; this layer supplies the
	# same reusable currency component used by the modern workspace headers.
	badge.clip_contents = false
	badge.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for child: Node in badge.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

	_premium_bits_display = BitsDisplayScript.new() as DigiBitsDisplay
	_premium_bits_display.name = "PremiumBitsDisplay"
	_premium_bits_display.prime_value(OverworldState.get_bits())
	badge.add_child(_premium_bits_display)
	_apply_premium_bits_layout()


func _layout() -> void:
	super._layout()
	_apply_premium_bits_layout()


func _refresh_structure(restore_focus: bool = true) -> void:
	super._refresh_structure(restore_focus)
	_sync_premium_bits()


func _refresh_live() -> void:
	super._refresh_live()
	_sync_premium_bits()


func _apply_premium_bits_layout() -> void:
	if _header == null or _close_button == null or _premium_bits_display == null:
		return
	var badge: Panel = _header.get_node_or_null("BitsBadge") as Panel
	if badge == null:
		return
	var compact: bool = _is_compact()
	var badge_size: Vector2 = COMPACT_BITS_SIZE if compact else PREMIUM_BITS_SIZE
	badge.size = badge_size
	badge.position = Vector2(
		maxf(0.0, _close_button.position.x - 12.0 - badge_size.x),
		floorf((_header.size.y - badge_size.y) * 0.5)
	)
	_premium_bits_display.set_variant(DigiBitsDisplay.VARIANT_COMPACT if compact else DigiBitsDisplay.VARIANT_STANDARD)
	_premium_bits_display.position = Vector2.ZERO
	_premium_bits_display.size = badge_size


func _sync_premium_bits() -> void:
	if _premium_bits_display != null:
		_premium_bits_display.set_value(OverworldState.get_bits())
