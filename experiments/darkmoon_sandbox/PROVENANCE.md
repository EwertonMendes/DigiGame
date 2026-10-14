# Asset provenance

| Asset | Source / author | License / distribution | Files used |
| --- | --- | --- | --- |
| Public sandbox atlas | Original geometric artwork authored for DigiGame | Project-owned original art; safe to include with the project | `palette.svg` |
| Private city fragments | User-supplied `Darkmoon_City_Assets_Only.zip`, derived from Digimon World Dusk; commercial franchise artwork | No redistribution permission provided; local only; excluded from Git and public builds | `darkmoon_city/tiles_32x32.png` selected chunk IDs in `brushes.json`; 8×8 and 16×16 source atlases retained locally for further curation |
| Trainer | Existing DigiGame legacy asset | Existing prototype asset retained under repository policy; no new character pixels introduced | `assets/characters/world/player_blond.png` |

The private ZIP provides `atlas_info.json` with hashes, useful tile counts,
32-column atlas metadata, zero margins/separation, and native RGBA information.
`import_private_assets.py` verifies every copied atlas against that manifest.
The selected 32×32 chunks are reassembled into a palette and painted in 8×8
cells. Unused source atlas cells and the source map placements are not imported
into the scene. Optional `shared_interiors` graphics are not used.

No public CI fetch is configured for the private artwork. The privacy check
allows only `.gitignore` and `.gdignore` under the local asset directory.
