# Asset provenance

| Asset | Source / author | License / distribution | Files used |
| --- | --- | --- | --- |
| Public sandbox atlas | Original geometric artwork authored for DigiGame | Project-owned original art; safe to include with the project | `palette.svg` |
| Private city modules | User-supplied `Darkmoon_City_Assets_Only.zip`, derived from Digimon World Dusk; commercial franchise artwork | No redistribution permission provided; local only; excluded from Git and public builds | `darkmoon_city/tiles_8x8.png` curated cell IDs in `brushes.json`; 16×16 and 32×32 source atlases retained locally for further curation |
| Trainer | Existing DigiGame legacy asset | Existing prototype asset retained under repository policy; no new character pixels introduced | `assets/characters/world/player_blond.png` |
| Koromon guide | Existing DigiGame legacy asset | Existing prototype asset retained under repository policy; separate scene-local NPC | `assets/characters/koromon/field.png` |

The private ZIP provides `atlas_info.json` with hashes, useful tile counts,
32-column atlas metadata, zero margins/separation, and native RGBA information.
`import_private_assets.py` verifies every copied atlas against that manifest.
Complete fixture/facade modules are reassembled from verified 8×8 source cells,
without resampling or recoloring. Local reference layers were used to identify
matching cells, not as scene backgrounds or city-layout templates. Original
street/map placements are not imported. Optional `shared_interiors` atlases are
not used; the supplied main city atlas contains the selected counter materials.

No public CI fetch is configured for the private artwork. The privacy check
allows only `.gitignore` and `.gdignore` under the local asset directory.
