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
- Exact source reference: `PNG/Default/Border/panel-border-000.png`

`frame_original.svg` is a crisp 48×48 reconstruction of the exact opaque-pixel geometry from `panel-border-000.png`. The white border is not recolored or embellished. DigiGame only places a simple semi-transparent black rectangle behind the frame so labels remain readable over the battlefield.

There are no baked gradients, glows, satin streaks, colored dots, palette tints or decorative light effects. The same neutral frame is used for panels and important dialog buttons; interaction feedback is handled by native Godot text/icon states instead of changing the artwork.

Runtime file:

- `frame_original.svg` — original monochrome Kenney border geometry plus neutral transparent backing.

Text remains native Godot Controls so typography color and animation stay independent from the frame artwork. The previous custom colored reconstructions are intentionally removed.