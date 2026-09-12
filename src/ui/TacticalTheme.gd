extends RefCounted
class_name TacticalTheme

# Kenney-inspired dark-mode surfaces. Structural chrome stays dark and quiet;
# orange/gold is reserved for focused, selected or otherwise active UI states.
# Text/accent colors intentionally keep stronger luminance than the surfaces:
# the UI sits over a very dark game world and thin low-contrast copy quickly
# becomes tiring at 720p, browser scaling and handheld sizes.
const CYAN: Color = Color(0.50, 0.87, 1.0, 1.0)
const BLUE: Color = Color(0.43, 0.60, 1.0, 1.0)
const RED: Color = Color(1.0, 0.52, 0.59, 1.0)
const ORANGE: Color = Color(1.0, 0.66, 0.42, 1.0)
const PURPLE: Color = Color(0.78, 0.70, 1.0, 1.0)
const GREEN: Color = Color(0.52, 0.92, 0.70, 1.0)
const GOLD: Color = Color(1.0, 0.75, 0.36, 1.0)
const TEXT: Color = Color(0.995, 0.997, 1.0, 1.0)
const MUTED: Color = Color(0.89, 0.90, 0.94, 1.0)
const SUBTLE: Color = Color(0.77, 0.79, 0.84, 1.0)
const BASE: Color = Color(0.015, 0.017, 0.022, 0.82)
const BASE_SOFT: Color = Color(0.028, 0.030, 0.038, 0.78)
const GLASS: Color = Color(0.018, 0.020, 0.026, 0.70)
const GLASS_LIGHT: Color = Color(0.11, 0.11, 0.12, 0.74)
const DISABLED: Color = Color(0.46, 0.48, 0.52, 1.0)
# Slightly brighter than the old structural chrome so panels remain separated
# from black backdrops without competing with text.
const FRAME_DARK: Color = Color(0.16, 0.20, 0.25, 1.0)

# Typography system.
# Oxanium carries display/game identity. Exo 2 handles normal-size interface
# copy. Noto Sans is deliberately used for microcopy because its open forms and
# larger apparent x-height stay readable at 10-12 px and survive translation
# better than a display face. Rajdhani remains a committed bootstrap fallback.
#
# Battle UI is intentionally different from dense menus: every tactical datum
# (commands, HP/SP values, turn labels, hover cards and previews) stays in the
# same Oxanium family for fast visual consistency, but uses the family's maximum
# practical weight so the small/medium glyphs do not look wire-thin in motion.
const FONT_DISPLAY_PATH := "res://assets/ui/fonts/Oxanium[wght].ttf"
const FONT_UI_PATH := "res://assets/ui/fonts/Exo2[wght].ttf"
const FONT_READING_PATH := "res://assets/ui/fonts/NotoSans[wdth,wght].ttf"
const FONT_BOOTSTRAP_REGULAR_PATH := "res://assets/ui/fonts/Rajdhani-Regular.ttf"
const FONT_BOOTSTRAP_SEMIBOLD_PATH := "res://assets/ui/fonts/Rajdhani-SemiBold.ttf"

const DISPLAY_WEIGHT := 700.0
const COMBAT_WEIGHT := 800.0
const UI_WEIGHT := 600.0
const READING_WEIGHT := 500.0
const MICRO_WEIGHT := 650.0
const SMALL_TEXT_BREAKPOINT := 12
const MIN_SMALL_TEXT_SIZE := 10
const TYPOGRAPHY_ROOT_META := &"digi_typography_root_installed"
const TYPOGRAPHY_PENDING_META := &"digi_typography_root_pending"

static var _display_font_cache: Font = null
static var _combat_font_cache: Font = null
static var _body_font_cache: Font = null
static var _reading_font_cache: Font = null
static var _micro_font_cache: Font = null


static func _load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var resource := ResourceLoader.load(path)
	return resource as Font


static func _font_with_fallbacks(
	primary_path: String,
	bootstrap_path: String,
	fallback_paths: Array[String],
	weight: float
) -> Font:
	var primary := _load_font(primary_path)
	if primary == null:
		primary = _load_font(bootstrap_path)
	if primary == null:
		return null

	var fallbacks: Array[Font] = []
	for path in fallback_paths:
		var fallback := _load_font(path)
		if fallback != null and fallback != primary:
			fallbacks.append(fallback)

	# FontVariation is also how Godot exposes OpenType variable-font axes.
	var composed := FontVariation.new()
	composed.base_font = primary
	composed.fallbacks = fallbacks
	composed.variation_opentype = {"wght": weight}
	return composed


static func display_font() -> Font:
	if _display_font_cache == null:
		_display_font_cache = _font_with_fallbacks(
			FONT_DISPLAY_PATH,
			FONT_BOOTSTRAP_SEMIBOLD_PATH,
			[FONT_UI_PATH, FONT_READING_PATH, FONT_BOOTSTRAP_REGULAR_PATH],
			DISPLAY_WEIGHT
		)
	return _display_font_cache


static func combat_font() -> Font:
	if _combat_font_cache == null:
		_combat_font_cache = _font_with_fallbacks(
			FONT_DISPLAY_PATH,
			FONT_BOOTSTRAP_SEMIBOLD_PATH,
			[FONT_UI_PATH, FONT_READING_PATH, FONT_BOOTSTRAP_REGULAR_PATH],
			COMBAT_WEIGHT
		)
	return _combat_font_cache


static func heading_font() -> Font:
	return display_font()


static func body_font() -> Font:
	if _body_font_cache == null:
		_body_font_cache = _font_with_fallbacks(
			FONT_UI_PATH,
			FONT_BOOTSTRAP_SEMIBOLD_PATH,
			[FONT_READING_PATH, FONT_DISPLAY_PATH, FONT_BOOTSTRAP_REGULAR_PATH],
			UI_WEIGHT
		)
	return _body_font_cache


static func reading_font() -> Font:
	if _reading_font_cache == null:
		_reading_font_cache = _font_with_fallbacks(
			FONT_READING_PATH,
			FONT_BOOTSTRAP_REGULAR_PATH,
			[FONT_UI_PATH, FONT_DISPLAY_PATH, FONT_BOOTSTRAP_REGULAR_PATH],
			READING_WEIGHT
		)
	return _reading_font_cache


static func micro_font() -> Font:
	if _micro_font_cache == null:
		_micro_font_cache = _font_with_fallbacks(
			FONT_READING_PATH,
			FONT_BOOTSTRAP_SEMIBOLD_PATH,
			[FONT_UI_PATH, FONT_DISPLAY_PATH, FONT_BOOTSTRAP_REGULAR_PATH],
			MICRO_WEIGHT
		)
	return _micro_font_cache


static func _top_control(control: Control) -> Control:
	var root := control
	while root != null and root.get_parent() is Control:
		root = root.get_parent() as Control
	return root


static func _is_combat_typography_root(root: Control) -> bool:
	if root == null:
		return false
	var script := root.get_script() as Script
	if script == null:
		return false
	var path := script.resource_path
	return (
		path == "res://src/BattleHUD.gd"
		or path == "res://src/TurnOrderHUD.gd"
		or path == "res://src/DigimonInfoPanel.gd"
		or path == "res://src/ui/CombatOverlayHUD.gd"
		or path == "res://src/ui/CompactDigimonInfoPanel.gd"
		or path == "res://src/ui/NavigableTurnOrderHUD.gd"
		or path == "res://src/ui/BattleTopBar.gd"
	)


static func _install_root_typography(control: Control) -> void:
	# Most UI factories style a control before adding it to its parent. Defer the
	# root lookup until tree_entered so the full Control ancestry is available;
	# otherwise only that single Label would receive the default theme.
	if control == null:
		return
	if not control.is_inside_tree():
		if not control.has_meta(TYPOGRAPHY_PENDING_META):
			control.set_meta(TYPOGRAPHY_PENDING_META, true)
			control.tree_entered.connect(func() -> void:
				if is_instance_valid(control):
					control.remove_meta(TYPOGRAPHY_PENDING_META)
					_install_root_typography(control)
			, Object.CONNECT_ONE_SHOT)
		return

	var root := _top_control(control)
	if root == null:
		return
	var combat_root := _is_combat_typography_root(root)

	# Legacy/modal controls that are created directly should inherit the most
	# suitable family for their screen. Menus use the highly readable Noto micro
	# face; tactical screens use the heavier Oxanium combat face consistently.
	if not root.has_meta(TYPOGRAPHY_ROOT_META):
		var default_font := combat_font() if combat_root else micro_font()
		if default_font != null:
			var inherited_theme: Theme = null
			if root.theme != null:
				inherited_theme = root.theme.duplicate() as Theme
			if inherited_theme == null:
				inherited_theme = Theme.new()
			inherited_theme.default_font = default_font
			root.theme = inherited_theme
			root.set_meta(TYPOGRAPHY_ROOT_META, true)

	# Explicit body/heading calls made before the control entered the tree may
	# already have installed Exo/Noto/Oxanium-700. Once the real battle root is
	# known, normalize the individual control to the heavier combat face too.
	if combat_root:
		var tactical_font := combat_font()
		if tactical_font != null:
			control.add_theme_font_override("font", tactical_font)


static func _apply_font(control: Control, font: Font) -> void:
	if control == null:
		return
	_install_root_typography(control)
	var resolved_font := font
	if control.is_inside_tree() and _is_combat_typography_root(_top_control(control)):
		resolved_font = combat_font()
	if resolved_font != null:
		control.add_theme_font_override("font", resolved_font)


static func _legible_font_size(control: Control) -> int:
	if control == null:
		return 16
	var size := control.get_theme_font_size("font_size")
	if size > 0 and size < MIN_SMALL_TEXT_SIZE:
		size = MIN_SMALL_TEXT_SIZE
		control.add_theme_font_size_override("font_size", size)
	return size


static func apply_body_font(control: Control) -> void:
	var size := _legible_font_size(control)
	_apply_font(control, micro_font() if size <= SMALL_TEXT_BREAKPOINT else body_font())


static func apply_heading_font(control: Control) -> void:
	var size := _legible_font_size(control)
	# Tiny all-caps/status headings used Oxanium before this split. At 9-12 px
	# its distinctive shapes are attractive but materially harder to scan in
	# dense menus. Battle roots are normalized back to combat_font() afterwards.
	_apply_font(control, micro_font() if size <= SMALL_TEXT_BREAKPOINT else heading_font())


static func apply_reading_font(control: Control) -> void:
	var size := _legible_font_size(control)
	_apply_font(control, micro_font() if size <= SMALL_TEXT_BREAKPOINT else reading_font())


static func uses_physical_touch_scale() -> bool:
	return DisplayServer.is_touchscreen_available()


static func ui_scale(viewport: Viewport) -> float:
	if viewport == null or not uses_physical_touch_scale():
		return 1.0
	var logical: Vector2 = viewport.get_visible_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return 1.0
	var scale_x: float = logical.x / maxf(float(window_size.x), 1.0)
	var scale_y: float = logical.y / maxf(float(window_size.y), 1.0)
	return maxf(1.0, maxf(scale_x, scale_y))


static func physical_window_size(viewport: Viewport) -> Vector2:
	if viewport == null:
		return Vector2(1280.0, 720.0)
	if not uses_physical_touch_scale():
		return viewport.get_visible_rect().size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		return Vector2(float(window_size.x), float(window_size.y))
	return viewport.get_visible_rect().size


static func is_compact(viewport: Viewport, width_breakpoint: float = 760.0) -> bool:
	var physical: Vector2 = physical_window_size(viewport)
	return physical.x < width_breakpoint or physical.y < 560.0


static func is_laptop(viewport: Viewport) -> bool:
	var physical: Vector2 = physical_window_size(viewport)
	return not is_compact(viewport) and physical.y < 780.0


static func px(viewport: Viewport, value: float) -> float:
	return value * ui_scale(viewport)


static func font_px(viewport: Viewport, value: float) -> int:
	return maxi(1, int(round(value * ui_scale(viewport))))


static func panel(_accent: Color = BLUE, fill_alpha: float = 0.76, border_alpha: float = 0.24, radius: int = 8, _shadow: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BASE.r, BASE.g, BASE.b, fill_alpha)
	style.border_color = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, minf(maxf(border_alpha, 0.28), 0.92))
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_size = 0
	return style


static func glass_panel(_accent: Color = BLUE, fill_alpha: float = 0.70, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GLASS.r, GLASS.g, GLASS.b, fill_alpha)
	style.border_color = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.88)
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_size = 0
	return style


static func ribbon(_accent: Color = GOLD, fill_alpha: float = 0.64) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BASE_SOFT.r, BASE_SOFT.g, BASE_SOFT.b, fill_alpha)
	style.border_color = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.88)
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


static func panel_strong(_accent: Color = BLUE, radius: int = 9) -> StyleBoxFlat:
	var style := glass_panel(Color.WHITE, 0.78, radius)
	style.border_color = FRAME_DARK
	style.set_border_width_all(1)
	return style


static func pill(_accent: Color, alpha: float = 0.10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, clampf(alpha + 0.20, 0.24, 0.42))
	style.border_color = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.94)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func command_style(accent: Color, state: String = "normal", compact: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(0.0, 0.0, 0.0, 0.10)
	var edge := Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.0)
	match state:
		"hover", "focus":
			bg = Color(0.0, 0.0, 0.0, 0.28)
			edge = Color(accent.r, accent.g, accent.b, 0.82)
		"pressed", "selected":
			bg = Color(0.0, 0.0, 0.0, 0.38)
			edge = Color(accent.r, accent.g, accent.b, 1.0)
		"disabled":
			bg = Color(0.0, 0.0, 0.0, 0.04)
	style.bg_color = bg
	style.border_color = edge
	style.border_width_left = 2
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 14.0 if not compact else 11.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func focus_outline(accent: Color = GOLD, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.98)
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.expand_margin_left = 1.0
	style.expand_margin_top = 1.0
	style.expand_margin_right = 1.0
	style.expand_margin_bottom = 1.0
	return style


static func turn_node_style(accent: Color, current: bool, state: String = "normal") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.72 if current else 0.48)
	var border := Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.90)
	if current:
		border = Color(accent.r, accent.g, accent.b, 0.88)
	if state == "hover" or state == "focus":
		style.bg_color = Color(0.0, 0.0, 0.0, 0.66)
		border = Color(accent.r, accent.g, accent.b, 0.94)
	elif state == "pressed":
		style.bg_color = Color(0.0, 0.0, 0.0, 0.76)
		border = Color(accent.r, accent.g, accent.b, 1.0)
	style.border_color = border
	style.set_border_width_all(1)
	var radius := 12 if current else 10
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_size = 0
	return style


static func action_style(accent: Color, state: String = "normal") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := Color(0.0, 0.0, 0.0, 0.50)
	var border := Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.92)
	match state:
		"hover", "focus":
			bg = Color(0.0, 0.0, 0.0, 0.62)
			border = Color(accent.r, accent.g, accent.b, 0.86)
		"pressed", "selected":
			bg = Color(0.0, 0.0, 0.0, 0.72)
			border = Color(accent.r, accent.g, accent.b, 1.0)
		"disabled":
			bg = Color(0.0, 0.0, 0.0, 0.24)
			border = Color(FRAME_DARK.r, FRAME_DARK.g, FRAME_DARK.b, 0.34)
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func separator(_accent: Color = BLUE, alpha: float = 0.20) -> Color:
	return Color(1.0, 1.0, 1.0, alpha)


static func rank_color(rank: String) -> Color:
	match rank.to_lower():
		"rookie": return CYAN
		"champion": return GREEN
		"ultimate": return PURPLE
		"mega": return GOLD
		"ultra": return RED
		"in-training", "training": return Color(0.70, 0.80, 1.0, 1.0)
		"fresh": return MUTED
	return MUTED