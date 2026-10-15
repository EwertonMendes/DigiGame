# Asset provenance

| Asset | Source / author | License / distribution | Files used |
| --- | --- | --- | --- |
| Neutral atlas layouts | Original diagnostic textures authored for DigiGame | Project-owned; no substitute city art | `palette.svg`, `raw-atlas-layout.svg` |
| Private city atlas | User-supplied `Darkmoon_City_Assets_Only.zip`, derived from Digimon World Dusk | No redistribution permission provided; local/browser memory only; excluded from Git and public builds | `darkmoon_city/tiles_8x8.png`; 16×16 and 32×32 copies retained locally |
| Trainer | Existing DigiGame legacy asset | Existing prototype asset retained under repository policy; no new character pixels introduced | `assets/characters/world/player_blond.png` |
| Koromon guide | Existing DigiGame legacy asset | Existing prototype asset retained under repository policy; separate scene-local NPC | `assets/characters/koromon/field.png` |

The pinned 8×8 atlas SHA-256 is
`a9abb47ff5433abdcdc82632b6e6e748bb4389f1919e2e452e3f92e493a1226a`.
Both the browser ZIP reader and Godot assembler verify it. Python imports also
verify the ZIP's `atlas_info.json` manifest for each copied city atlas.

Complete fixture/facade modules and blue/orange roof surfaces are assembled from
explicit native 8×8 cell IDs in `brushes.json`, without resampling or recoloring.
Local reference layers identify matching cells and diagonal bevel components;
they are not scene backgrounds or city-layout templates. Original street and
map placements are absent. All 3,825 valid city cells are also available through
the raw authoring source. Shared-interior atlases are not used.

No public CI download is configured for the private graphics. The public Web
page reads the user's selected ZIP locally and preloads only the verified atlas
into engine memory. It does not send the file over the network or persist it in
browser storage. A reload requests the file again.

Editor tools substitute live private textures but restore neutral references
before serialization. Local checks verify both native pixel equality and saved
scenes without ImageTexture data or private asset paths. The privacy check allows
only `.gitignore` and `.gdignore` under the local asset directory.
