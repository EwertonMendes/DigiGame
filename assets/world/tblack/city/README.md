# Central City urban prop kit

Central City's first landscaping pass uses a small project-owned SVG kit under `props/`.
These files are intentionally isolated from gameplay logic so they can be replaced by final
pixel-art sprites later without rewriting placement, walkability or district authoring.

## Replacement contract

The source of truth is `assets/resources/world/central_city_decor.json`.

Each asset entry defines:

- `path`: runtime texture path;
- `foot`: pixel anchor that touches the ground plane;
- `scale`: authored render scale;
- `blocker`: small ground-plane walkability footprint;
- optional `shader` / `layer` metadata.

District profiles contain only asset IDs plus logical grid positions. Positions may be
fractional, so decoration is not visually locked to the 64x32 gameplay cells.

To replace a prop, keep its asset ID stable and update its catalog metadata. No section
script or placement code should need to change.

## Current visual language

The foundation kit follows the Central City exterior palette: graphite structure,
light-gray civic materials, cyan data lighting, warm market lighting and saturated planted
greens. The second-pass assets intentionally use deeper isometric silhouettes and larger
landscape masses so benches, planters and signs read like street furniture instead of UI
icons placed on the map. Long flower beds and clustered props are preferred over uniform
single-object scattering. Holographic signs use `city_hologram.gdshader`; all other props are static and have
no per-frame script processing.

Large buildings remain dedicated authored assets. This kit is only for repeatable city-scale
street furniture and landscaping.
