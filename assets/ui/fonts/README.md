# DigiGame UI fonts

The battle HUD uses **Rajdhani** for its tactical display typography.

## Provenance

- Asset family: Rajdhani
- Publisher/source repository: Google Fonts / Indian Type Foundry
- License: SIL Open Font License 1.1
- Source repository: https://github.com/google/fonts
- Pinned source commit: `9d1ce2fc3c335cca32b6db00c19f55d57b0a68fe`
- Exact files used:
  - `ofl/rajdhani/Rajdhani-Regular.ttf`
  - `ofl/rajdhani/Rajdhani-SemiBold.ttf`
- Runtime destination:
  - `assets/ui/fonts/Rajdhani-Regular.ttf`
  - `assets/ui/fonts/Rajdhani-SemiBold.ttf`
- Attribution required: the OFL license/copyright notice is retained in `RAJDHANI-OFL.txt`.

The TTF binaries are intentionally fetched rather than committed. Run:

```bash
python3 tools/fetch_ui_fonts.py
```

The GitHub Actions Web build runs the same fetcher before Godot import/export and verifies each downloaded binary against its pinned Git blob SHA.
