# Zeke Greymon source sheet

`movement-sheet.webp` contains the 12 movement poses extracted from the project-supplied sheet. The original attachment is pinned in `database/ds-project-supplied-sources.json` by SHA-256; only the unused canvas area and authored blue background were removed when storing the repository source.

The runtime asset is **not** read directly from this sheet. `tools/build_additional_ds_fields.py` maps the four authored triples and three authored walk phases into the same `directional_12` contract used by the other DS-style Digimon. Source boxes, background cleanup and render scale are data-driven so no Zeke Greymon runtime conditional, horizontal flip or direction workaround is required.
