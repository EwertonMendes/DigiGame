# Digi UI V2 foundation

Digi UI V2 is the reusable presentation foundation introduced with the Digimon screen redesign. It intentionally coexists with the current UI so screens can migrate incrementally instead of forcing a project-wide rewrite.

## Visual direction

- Dark slate surfaces instead of black/neon chrome.
- Cyan is the neutral navigation accent; amber marks the selected/important state.
- Green, blue, orange, purple and red are semantic stat/action colors.
- Glows are limited to short, low-alpha progress/focus shadows.
- Typography reuses the existing vector font stack from `TacticalTheme` so text stays crisp at Full HD and browser scaling.
- Layout is built from Godot `Control`, `Container`, `StyleBoxFlat`, `ProgressBar` and procedural `_draw()` icons. No new external UI art is required.

## Reusable components

- `DigiUiTheme.gd`: palette, responsive helpers, surface/button/pill/progress styles and shared sizing tokens.
- `DigiProceduralIcon.gd`: anti-aliased vector icons drawn by Godot for stats and major actions.
- `DigiActionCard.gd`: focusable/touch-safe action card with icon, title, description and status footer.
- `DigiStatRow.gd`: compact stat/value/progress presentation.
- `DigiInputHintBar.gd`: last-input-aware keyboard/mouse, Xbox, PlayStation and touch hints.
- `DigiProfileHero.gd`: reusable Digimon identity card with portrait, rank/type chips, level, XP, Potential and Link.
- `DigiStatsPanel.gd`: semantic combat-stat presentation using the reusable stat rows.
- `DigiDevelopmentPanel.gd`: reusable aptitude/training summary with readable semantic colors.
- `DigiModalHeader.gd` and `DigiSectionHeader.gd`: shared screen/section hierarchy now used by the Digimon, DigiLab, Party / Storage and Training flows.

## Interaction rules

- Primary touch targets are at least 52 logical pixels where the component represents a direct action.
- Buttons expose distinct normal, hover, focus, pressed and disabled states.
- Focus is never represented by color alone: focused controls also receive a stronger border.
- Touch never depends on hover-only information.
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

## Migrated screens

- Digimon / progression menu: original Digi UI V2 reference implementation.
- DigiLab and Party / Storage: shared modal hierarchy and V2 surfaces/components.
- Training Center: V2 modal header, responsive roster, training budget, semantic attribute steppers, mobility planning, plan summary, adaptive input hints and focus restoration after dynamic updates.

Other screens should adopt these components gradually rather than forcing a project-wide rewrite.
