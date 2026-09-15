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
- `DigiActionCard.gd`: focusable/touch-safe action card with icon, title, description and status footer.
- `DigiStatRow.gd`: compact stat/value/progress presentation.
- `DigiInputHintBar.gd`: last-input-aware keyboard/mouse, Xbox, PlayStation and touch hints.
- `DigiInteractionPrompt.gd`: contextual world prompt with separate input badge and concise action copy. It follows the active input family instead of embedding keyboard-only text in the action and composes `DigiGlassPanel` for its floating surface.
- `DigiConfirmationModal.gd`: reusable blocking decision modal with dimmed backdrop, responsive centered glass card, minimum 52 px actions and safe cancel/no focus by default.
- `DigiProfileHero.gd`: reusable Digimon identity card with portrait, rank/type chips, level, XP, Potential and Link.
- `DigiStatsPanel.gd`: semantic combat-stat presentation using the reusable stat rows.
- `DigiDevelopmentPanel.gd`: reusable aptitude/training summary with readable semantic colors.
- `DigiModalHeader.gd` and `DigiSectionHeader.gd`: shared screen/section hierarchy used by the Digimon, DigiLab, Party / Storage and Training flows.
- `DigiUiRuntime.gd`: compatibility bridge that normalizes the remaining named player-facing legacy HUD surfaces/buttons to the V2 visual language without duplicating gameplay/domain logic.

## Interaction rules

- Primary touch targets are at least 52 logical pixels where the component represents a direct action.
- Buttons expose distinct normal, hover, focus, pressed and disabled states.
- Focus is never represented by color alone: focused controls also receive a stronger border.
- Touch never depends on hover-only information.
- Reversible or potentially destructive confirmation flows default keyboard/controller focus to the safe cancel/no action. `ui_accept` activates the currently focused button instead of being hard-coded to confirm.
- Contextual world prompts separate the current input badge (`E`, Xbox `A`, PlayStation `X`, or touch) from the action text so copy remains concise and input-aware.
- The Digimon screen keeps keyboard/controller spatial focus navigation while mouse and touch use the same underlying controls.
- Input hints follow the last active input family and avoid font-dependent symbol glyphs that can render inconsistently on Web/mobile builds.
- Screens that rebuild dynamic content after an action must explicitly restore focus to the equivalent control instead of dropping keyboard/controller focus.

## Responsive layout

The Digimon screen uses the physical-size helpers already proven by the Web build:

- Large screens: roster on the left, profile/actions in the center, combat/development information in the right column.
- Compact screens: roster becomes a top collection area and details stack below it inside the existing scroll container.
- Very narrow screens: the identity and action grids collapse to one column instead of shrinking fonts to unreadable sizes.
- Existing scroll containers remain the overflow mechanism, so information is never intentionally clipped to fit a smaller viewport.

The Training Center follows the same responsive rules: a persistent roster column beside the training workspace on desktop, a compact roster above the workspace on smaller screens, and one-column stat/budget grids when horizontal space is constrained.

Global overlays follow the same physical-size helpers. Confirmation cards remain centered and bounded on desktop/mobile, contextual prompts remain compact, and touch actions keep the V2 minimum target size instead of shrinking to fit.

## Migrated screens and global components

- Digimon / progression menu: original Digi UI V2 reference implementation.
- DigiLab and Party / Storage: shared modal hierarchy and V2 surfaces/components.
- Training Center: V2 modal header, responsive roster, training budget, semantic attribute steppers, mobility planning, plan summary, adaptive input hints and focus restoration after dynamic updates.
- Hub chrome: V2 location surface, contextual glass interaction prompt, contextual mobile action labels and safe-default glass Battle Operator decision flow.
- Confirmation flows: shared V2 confirmation component is used by battle retreat, while specialized evolution confirmation is normalized by the V2 runtime and keeps its richer transition summary.
- Transient overlays: area-title and battle-start presentation use V2 slate surfaces, typography and restrained semantic accents.
- Remaining named legacy battle/dialog surfaces are normalized by `DigiUiRuntime` so player-facing chrome no longer falls back to the old Kenney-frame presentation while deeper screens are migrated structurally.
