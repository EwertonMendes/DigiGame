# Digi Fantasy Border skin

This folder contains a compact DigiGame UI skin derived from the vector geometry in **Kenney — Fantasy UI Borders**.

- Original pack: Fantasy UI Borders
- Author/publisher: Kenney
- Official source: https://kenney.nl/assets/fantasy-ui-borders
- Original release: 1.0 (2023)
- License: CC0 1.0 Universal / public domain dedication
- Attribution required: No
- Source-inspection mirror: https://github.com/Tiddybub/2d-assets/tree/e0cbe0d995554a490d4c182fe9beb8769ffbb606/ui/fantasy-ui-borders
- Pinned mirror commit: `e0cbe0d995554a490d4c182fe9beb8769ffbb606`
- Source vector: `Vector/fantasy-ui-borders.svg`

DigiGame uses selected frame silhouettes from the source vector and recolors them into a custom digital-fantasy palette. Text is never baked into the artwork; labels and buttons stay native Godot Controls so localization and responsive layout remain independent of the skin.

Runtime files:

- `panel_standard.svg` — ordinary framed surfaces
- `panel_emphasis.svg` — modal / important framed surfaces
- `button_normal.svg` — dialog / secondary action button
- `button_hover.svg` — hovered/focused dialog button
- `button_pressed.svg` — pressed/selected dialog button

The previous sci-fi skin is intentionally not used by the runtime after this refresh.