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

DigiGame uses selected frame silhouettes from the original vector without palette recoloring. Runtime artwork stays monochrome: white Kenney geometry over a simple semi-transparent black center. There are no baked glows, gradients, colored highlights or decorative light streaks. Text remains native Godot Controls so typography color and animation can evolve independently from the frame artwork.

Runtime files:

- `panel_standard.svg` — ordinary monochrome framed surfaces
- `panel_emphasis.svg` — modal / important monochrome framed surfaces
- `button_normal.svg` — neutral dialog button
- `button_hover.svg` — brighter monochrome hover/focus state
- `button_pressed.svg` — high-contrast monochrome pressed state

Structural UI uses grayscale styling; gameplay/text semantics may still use accent colors where useful. The previous sci-fi skin is not used by the runtime.