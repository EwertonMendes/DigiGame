# DigiGame UI fonts

DigiGame uses a role-based typography system instead of one font everywhere:

- **Oxanium** — display identity: large titles, battle banners, Digimon names and high-impact headings.
- **Exo 2** — interface text: buttons, menus, stats, tabs and compact HUD labels.
- **Noto Sans** — reading/localization layer: dialogue, longer descriptions and broad Latin/Cyrillic/Greek coverage.
- **Rajdhani** — committed bootstrap fallback so the game remains readable in partial/offline checkouts before the optional font fetch step is run.

`src/ui/TacticalTheme.gd` owns the font roles and fallback chain. Existing UI code that already calls `apply_heading_font()` or `apply_body_font()` automatically inherits this typography system without duplicating font paths across screens.

## Runtime files

Preferred runtime files:

- `assets/ui/fonts/Oxanium[wght].ttf`
- `assets/ui/fonts/Exo2[wght].ttf`
- `assets/ui/fonts/NotoSans[wdth,wght].ttf`

Committed bootstrap fallbacks:

- `assets/ui/fonts/Rajdhani-Regular.ttf`
- `assets/ui/fonts/Rajdhani-SemiBold.ttf`

Run `python tools/fetch_ui_fonts.py` to reproduce/fetch the preferred font stack. Every downloaded binary is verified against its exact Google Fonts Git blob SHA before it is written.

## Localization strategy

The current stack covers the languages expected for the first localization waves, including accented Latin text and Cyrillic/Greek through Noto Sans. CJK, Arabic, Thai and other scripts should be added later as script-specific Noto fallback files rather than replacing the visual identity fonts. Godot will walk the fallback chain whenever the primary font does not contain a requested glyph.

This keeps headings visually consistent while allowing translated body text to render safely as language coverage grows.

## Provenance and license

All families are distributed under the SIL Open Font License 1.1 through Google Fonts.

- Oxanium source: `google/fonts/ofl/oxanium` — verified blob `ead485c7bf517197db91ef657614ac37d8007775`
- Exo 2 source: `google/fonts/ofl/exo2` — verified blob `9cb20188a07687580312d2099e6c79ca8ecb7b58`
- Noto Sans source: `google/fonts/ofl/notosans` — verified blob `75575046c015ff623a848096a15779867ba71453`
- Rajdhani source: `google/fonts/ofl/rajdhani`

Keep the corresponding OFL notices with redistributed font binaries when the preferred font files are committed to the repository.
