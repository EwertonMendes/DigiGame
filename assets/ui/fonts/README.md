# DigiGame UI fonts

DigiGame uses one packaged typography family for deterministic rendering across
desktop and Web:

- **Rajdhani SemiBold** — display titles, menus, stats, tabs, compact labels and battle UI.
- **Rajdhani Regular** — reading-oriented copy and longer descriptions.

`src/ui/TacticalTheme.gd` owns the role mapping. Both files are committed under
`assets/ui/fonts/`, validated by `tools/validate_runtime_assets.py`, and imported
by Godot from the same repository revision on every target.

## Cross-platform rule

Runtime font selection must never depend on CI-only downloads, developer-local
files, operating-system fonts or an export-time network step. If a new family is
introduced later, its redistributable font files and license must be committed
and validated before `TacticalTheme.gd` can reference it.

This rule prevents desktop and Web builds of the same commit from silently using
different typefaces or weights.

## Localization strategy

Rajdhani covers the current Latin-script interface, including the accented
characters used by the supported Portuguese and English UI. When broader script
coverage is required, add explicit packaged fallback fonts for those scripts
rather than relying on system fallbacks or target-specific downloads.

## Provenance and license

Rajdhani is distributed under the SIL Open Font License 1.1 through Google
Fonts. The repository keeps the corresponding `RAJDHANI-OFL.txt` notice beside
the runtime font files.
