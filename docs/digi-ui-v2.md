# Digi UI V2 foundation

Digi UI V2 is the reusable presentation foundation introduced with the Digimon screen redesign. It now acts as the default presentation language for player-facing menus, modal decisions, contextual prompts and transient overlays, while legacy tactical code keeps its domain behavior intact.

## Visual direction

- Dark slate surfaces instead of black/neon chrome.
- Cyan is the neutral navigation accent; amber marks the selected/important state.
- Green, blue, orange, purple and red are semantic stat/action colors.
- Glows are limited to short, low-alpha progress/focus shadows.
- Floating prompts and decision surfaces use the shared frosted-glass treatment: translucent slate fill, restrained semantic border, soft shadow and a procedural inner highlight. The effect avoids external assets and screen-reading blur shaders so it stays predictable on Web/mobile.
- Typography reuses the existing vector font stack from `TacticalTheme` so text stays crisp at Full HD and browser scaling.
- Layout is built from Godot `Control`, `Container`, `StyleBoxFlat`, `ProgressBar` and procedural `_draw()` icons. No new external UI art is required.

## Reusable components

- `DigiUiTheme.gd`: palette, responsive helpers, surface/button/pill/progress styles, shared glass styles and sizing tokens.
- `DigiGlassPanel.gd`: reusable glassmorphism foundation for floating panels and modal cards. It centralizes translucency, semantic border tint, shadow, radius and procedural inner highlight. Use `configure_glass(accent, variant, padding, radius)` instead of recreating per-screen styleboxes.
- `DigiProceduralIcon.gd`: anti-aliased vector icons drawn by Godot for stats and major actions.
- `DigiIconView.gd`: shared icon presenter that preserves existing procedural icons while allowing authored `Texture2D`/SVG assets to use the same sizing, tinting and component hierarchy.
- `DigiActionCard.gd`: focusable/touch-safe action card with icon, title, description and status footer.
- `DigiCommandButtonStyle.gd`: raised command-button language that remains visually distinct from informational panels in normal, hover, focus, pressed and disabled states.
- `DigiCommandButton.gd`: reusable icon/title/subtitle/status command control built on the shared command style.
- `DigiSelectionCard.gd`: persistent-selection list card for roster/configuration workspaces. Focus/hover are transient navigation states; committed selection keeps a stable cyan highlight without changing card geometry or shadow depth.
- `DigiSegmentedTabs.gd`: shared bounded section switcher used by DigiLab-style compact workspaces.
- `DigiPager.gd`: pointer/touch pager with an explicit page indicator; its arrows deliberately stay outside directional focus navigation.
- `DigiAnalogNavigationGate.gd`: reusable analog-stick/trigger hysteresis so one intentional deflection produces one menu navigation step.
- `DigiRosterProfilePanel.gd`: compact adaptive Digimon profile surface for paged, no-scroll roster workspaces.
- `DigiStatRow.gd`: compact stat/value/progress presentation.
- `DigiInputHintBar.gd`: last-input-aware keyboard/mouse, Xbox, PlayStation and touch hints.
- `DigiInteractionPrompt.gd`: contextual world prompt with separate input badge and concise action copy. It follows the active input family instead of embedding keyboard-only text in the action and composes `DigiGlassPanel` for its floating surface.
- `DigiConfirmationModal.gd`: reusable blocking decision modal with dimmed backdrop, responsive centered glass card, minimum 52 px actions and safe cancel/no focus by default.
- `DigiProfileHero.gd`: reusable Digimon identity card with portrait, rank/type chips, level, XP, Potential and Link.
- `DigiStatsPanel.gd`: semantic combat-stat presentation using the reusable stat rows.
- `DigiDevelopmentPanel.gd`: reusable aptitude/training summary with readable semantic colors.
- `DigiModalHeader.gd` and `DigiSectionHeader.gd`: shared screen/section hierarchy used by the Digimon, DigiLab, Party / Storage and Training flows.
- `DigiUiRuntime.gd`: compatibility bridge that normalizes the remaining named player-facing legacy HUD surfaces/buttons to the V2 visual language without duplicating gameplay/domain logic.
- `DigiUiTransitionSurface.gd` + `DigiUiTransitionDirector.gd`: GPU-backed menu lifecycle transition. Full-screen service UIs are rendered through a `CanvasGroup` and revealed cell-by-cell from lower-left to upper-right; closing runs the exact inverse while the world remains visible behind unrevealed cells. The director owns transition concurrency/input blocking while screens keep their own domain logic.

## Interaction rules

- Primary touch targets are at least 52 logical pixels where the component represents a direct action.
- Buttons expose distinct normal, hover, focus, pressed and disabled states.
- Focus is never represented by color alone: focused controls also receive a stronger border.
- Configuration/roster workspaces keep committed selection separate from transient focus, hover and press. Selection remains persistently highlighted while navigation moves elsewhere, and press feedback must not change card geometry.
- Touch never depends on hover-only information.
- Reversible or potentially destructive confirmation flows default keyboard/controller focus to the safe cancel/no action. `ui_accept` activates the currently focused button instead of being hard-coded to confirm.
- Contextual world prompts separate the current input badge (`E`, Xbox `A`, PlayStation `X`, or touch) from the action text so copy remains concise and input-aware.
- The main Digimon menu has explicit roster, command and Technique Library interaction modes. Controller focus stays inside the active content region instead of entering header chrome or pager arrows.
- Vertical roster navigation is page-local. LT/RT (L2/R2 on PlayStation) changes pages explicitly, while LB/RB (L1/R1) switches the Stats/Development overview.
- Analog menu navigation uses hysteresis: a held stick or trigger does not race across multiple Digimon or pages.
- Mouse/touch can select another Digimon directly without requiring an intermediate focus-reset action.
- Input hints follow the last active input family and avoid font-dependent symbol glyphs that can render inconsistently on Web/mobile builds. Touch-only menus may hide redundant hints entirely.
- Screens that rebuild dynamic content after an action must explicitly restore focus to the equivalent control instead of dropping keyboard/controller focus.

## Responsive layout

The main Digimon menu is a paged, no-scroll workspace:

- Large screens: three-Digimon Party roster on the left, profile and command surface in the center, and Stats/Development overview on the right.
- Smaller landscape screens: the same hierarchy becomes denser while retaining authored card heights and touch targets instead of enabling scrolling.
- More than three Party Digimon are reached through explicit pages; unused roster slots remain empty rather than stretching cards to fill the column.
- The Technique Library uses its own fixed-capacity pages so favorite/archive/reorder controls remain accessible without a scrolling focus trap.
- Stats and Development share one overview region and are switched as tabs, preventing the detail column from growing beyond the available viewport.
- The Web canvas still uses the physical-size helpers proven by CI and fills the browser viewport while Godot preserves the intended proportions.

Other specialized screens may use scrolling where their information model genuinely requires it, but paged task-focused surfaces should prefer bounded layouts when all required actions can remain visible and readable.

The Training Center follows the same responsive rules: a persistent roster column beside the training workspace on desktop, a compact roster above the workspace on smaller screens, and one-column stat/budget grids when horizontal space is constrained.

Global overlays follow the same physical-size helpers. Confirmation cards remain centered and bounded on desktop/mobile, contextual prompts remain compact, and touch actions keep the V2 minimum target size instead of shrinking to fit.

## Migrated screens and global components

- Digimon / progression menu: paged no-scroll V2 workspace with explicit controller/touch interaction states, profile, commands and switchable overview.
- DigiLab and Party / Storage: shared modal hierarchy and V2 surfaces/components.
- Digi Hospital: full-screen V2 treatment workspace with paged patients, explicit exploration/action modes and controller-aware input hints.
- Training Center: V2 modal header, responsive roster, training budget, semantic attribute steppers, mobility planning, plan summary, adaptive input hints and focus restoration after dynamic updates.
- Hub chrome: V2 location surface, contextual interaction prompt and a responsive Battle Operator mechanics-test workspace that reuses the DigiLab/Digimon workspace hierarchy: persistent program list, persistent battlefield list, simulation summary/action panel, and compact paged section navigation. Battle Operator presentation uses its own original SVG family under `assets/ui/icons/battle_operator/`; program-rank icons form one progressive data-core language, battlefield icons describe authored arena geometry, and section/action icons remain separate from combat/stat semantics.
- Full-screen Hub services (Digimon, DigiLab, Battle Operator, Digi Hospital and Training) share the same reversible digital construction transition. Internal tab/page changes intentionally do not replay the full-screen effect.
- Confirmation flows: shared V2 confirmation component is used by battle retreat, while specialized evolution confirmation is normalized by the V2 runtime and keeps its richer transition summary.
- Transient overlays: area-title and battle-start presentation use V2 slate surfaces, typography and restrained semantic accents.
- Remaining named legacy battle/dialog surfaces are normalized by `DigiUiRuntime` so player-facing chrome no longer falls back to the old Kenney-frame presentation while deeper screens are migrated structurally.
