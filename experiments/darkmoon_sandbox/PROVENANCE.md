# Asset provenance

| Asset | Source | Distribution / files |
| --- | --- | --- |
| City atlas | User-supplied Darkmoon_City_Assets_Only.zip; Digimon World Dusk artwork | Explicitly requested by the user for inclusion in the repository/game on 2026-10-14; assets/scenery/darkmoon_city/tiles_8x8.png |
| Assembled modules | Native cells from the same supplied atlas | assets/scenery/darkmoon_city/pieces.png; deterministic cell layout in brushes.json |
| Trainer and Koromon | Existing DigiGame legacy assets | Existing assets retained; no additional character pixels introduced |

Source atlas SHA-256:
`a9abb47ff5433abdcdc82632b6e6e748bb4389f1919e2e452e3f92e493a1226a`.
The asset manifest records both shipped PNG hashes and the user's authorization.
No independent third-party license is asserted. The user's explicit instruction
supersedes the earlier attachment's private-only handling requirement.

Pixels retain native RGBA, color and transparency. Module assembly copies whole
8×8 cells without scaling or recoloring. Original maps, reference images, temporary
crops, unused 16/32-pixel atlases and source ZIPs are not shipped. All 3,825 valid
source cells remain available for building original scenery.

The plaza paving module is the native 64-by-64 panel from reference layer 26a
at (480, 240). Front edge strips use 24a at (576, 280) and (640, 280);
back strips use 23a at (480, 64) and (576, 40). Front and rear corner caps
come from 24a at (624, 320) and 23a at (560, 40). The arrival inlay uses
24a at (576, 248), and the basin with both landings uses 25a at (112, 96).
These identify component cells only. None of those reference images or their
map layouts is distributed. `rebuild_palette.py` reproduces the shipped palette
directly from the committed atlas and the explicit cell matrices.

The facade reference contains a 16-pixel displacement in its final 48-pixel
side section. Those native cells are placed two rows lower to continue the blue
foundation baseline. Native purple fascia cells from 24a at (656, 0) extend the
upper wall under the roof. The basin's mask now excludes both blue bridge
landings; no replacement floor is painted over them, so the shared paving
continues beneath the cutout without additional seams.
