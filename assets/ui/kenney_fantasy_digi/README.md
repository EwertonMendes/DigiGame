# Digi Fantasy Border skin

This folder contains DigiGame's runtime use of **Kenney — Fantasy UI Borders**.

- Original pack: Fantasy UI Borders
- Author/publisher: Kenney
- Official source: https://kenney.nl/assets/fantasy-ui-borders
- Original release: 1.0 (2023)
- License: CC0 1.0 Universal / public domain dedication
- Attribution required: No
- Source-inspection mirror: https://github.com/Tiddybub/2d-assets/tree/e0cbe0d995554a490d4c182fe9beb8769ffbb606/ui/fantasy-ui-borders
- Pinned mirror commit: `e0cbe0d995554a490d4c182fe9beb8769ffbb606`

Exact source files vendored for runtime use:

- `panel-border-000.png` — `PNG/Default/Border/panel-border-000.png`; exact border-only source pixels used for focused/selected overlays.
- `divider-fade-000.png` — `PNG/Default/Divider Fade/divider-fade-000.png`; exact divider used by the Battle Started announcement.

`frame_original.svg` is a crisp 48×48 reconstruction of the exact opaque-pixel geometry from `panel-border-000.png`, with only a neutral semi-transparent black backing added so labels remain readable over the battlefield. Runtime tinting preserves the geometry while presenting normal containers in Kenney-style dark slate and focused/selected states in DigiGame orange.

There are no baked gradients, glows, satin streaks, colored dots or decorative light effects. Normal structural containers stay dark. Orange is reserved for focused, selected or actively prompted surfaces. Text remains native Godot Controls so typography color and animation stay independent from the frame artwork.
