# DigiGame UI fonts

The battle HUD uses **Rajdhani** for its tactical display typography. The exact TTF files used at runtime are **committed to the repository**, so a clean checkout can import and run the UI without fetching font assets from the internet.

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

`tools/fetch_ui_fonts.py` remains only as an optional provenance/reproduction tool. Normal CI runs `tools/validate_runtime_assets.py`, which validates the committed font binaries by Git blob SHA using only the Python standard library.
