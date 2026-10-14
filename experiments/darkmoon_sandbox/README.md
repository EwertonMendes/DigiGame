# Moonrise Commons: local city sandbox

Open `experiments/darkmoon_sandbox/DarkmoonSandbox.tscn` in the existing
DigiGame project and press **F6**. F5 still opens the normal game. The experiment
does not change the main scene, existing maps, progression, menus, or saves.

The authored city has a continuous isometric platform with a finished perimeter,
a fountain plaza and connected blue walking loop, a western market with its
counter and Koromon guide, a northern DigiLab facade, and an eastern data court
with terminals and an interactive district display. All walking uses one plane.

## Controls

| Control | Action |
| --- | --- |
| WASD / arrows | Eight-direction movement |
| Shift | Run |
| E | Talk to Koromon, inspect a facade, or use the district display |
| E / Esc | Close a conversation |
| F3 | Show walkable surfaces, solid ground bases, and actor clearance |
| Tab | Toggle the whole-city overview |
| R | Return to the arrival plaza |
| F4 | Test the full circuit through the actual actor |

Compact windows also show the existing touch joystick and scene-local buttons.
The city guide is a separate NPC, not an owned roster entry. Facade interactions
are local descriptions; they do not open the normal game's services.

## Fast local validation

Use the existing Godot 4.7 executable, without waiting for GitHub Actions:

```powershell
./experiments/darkmoon_sandbox/validate_local.ps1
./experiments/darkmoon_sandbox/validate_local.ps1 -Capture
# Or point at another local executable:
./experiments/darkmoon_sandbox/validate_local.ps1 -Godot "C:/Tools/Godot.exe"
```

The script defaults to the local executable under `.tmp/godot/`. Logic checks
run headless. `-Capture` uses a hidden local rendering window to save actual
GPU images; Godot's headless dummy renderer cannot produce visual screenshots.
Logs, caches, and test user data stay in the ignored `.tmp/` directory.

Tests cover valid spawn, eight directions, the full plaza/market/data-court
circuit, frontal and diagonal collisions, long-step tunneling, obstacle contours,
outer voids, roof clearance, angled-object depth, and NPC interaction pause/resume.
No private screenshots are uploaded by local validation.

## Private artwork

The supplied `Darkmoon_City_Assets_Only.zip` contains proprietary ROM-derived
pixels without redistribution permission. They stay local and ignored. Public
builds use the original project-owned fallback atlas with identical brush regions,
scene geometry, actors, collision, and interaction code.

```powershell
python experiments/darkmoon_sandbox/import_private_assets.py "C:/Users/ewert/Documents/Dev/digimon-world-dusk-pc/.private/scenery/Darkmoon_City_Assets_Only.zip"
```

The importer requires Pillow, checks the supplied atlas SHA-256 manifest, and
preserves native RGBA pixels. The curated 1024×512 palette is assembled from
explicit **8×8 atlas cell IDs** in `brushes.json`, rather than treating arbitrary
32×32 fragments as complete objects. The original three city atlases are retained
under `assets/local/darkmoon_sandbox/` for further work. Keep its `.gitignore`
and `.gdignore` files: raw private PNGs are loaded at runtime, outside normal
Godot import/export scanning.

The original map arrangements are not used. Complete facade and fixture modules
were identified in local references and matched byte-for-byte to cells already in
the supplied atlas; only those module cell IDs are retained. Floor and roof
materials use unmodified solid source cells. The original city streets are absent.

## Editing the city

* Paint the serialized TileMapLayers using their square 8×8 TileSet. Layers use
  integer 2× scale, nearest filtering, and zero atlas margins/separation.
* `GroundMask`, `Courts/*`, and object `ArtMask` polygons clip tile layers to
  smooth authored shapes. Visual clipping avoids stair-step tile-cell boundaries
  and removes adjacent scenery accidentally included in a fixture's source cells.
* Move objects by their parent under `Depth`. Their art, bases, and interaction
  points move together. Building roofs are separate editable tile surfaces.
* `Walkable/CityPlatform` defines the outer walking surface.
  `Depth/<object>/Footprint` subtracts solid ground bases. Temporarily show these
  hidden Polygon2D nodes to edit their vertices, then use F3 during play.
* The same ground bases drive collision and front/back depth. Contact Y is
  evaluated at the actor's X for angled facades and counters; roof height never
  becomes a ground collision rectangle.
* The root's `Rebuild Tiles` regenerates paint from surface and brush metadata.
  **It replaces paint edits**; save a copy first. `bake_scene.gd` regenerates the
  complete initial city, so do not run it over a hand-edited scene casually.
* The editor shows the public palette. F6 substitutes the private palette at the
  same cell coordinates when available. No private image data is serialized into
  the tracked scene. Add new brush regions/cell IDs deliberately and rerun the
  importer to extend the private palette.

The actor adapter reuses existing eight-direction input, animation, acceleration,
and sliding. It checks movement segments every four pixels and applies capsule
clearance. The existing world's loading, elevation traversal, followers, services,
and persistence are not instantiated.

## Web entry point

The regular export remains `index.html`. `create_preview.py` generates
`sandbox.html` and a forked `sandbox.pck` whose only resource change is the
exported main-scene setting. JavaScript/Wasm are shared and the source
`project.godot` is untouched. This works with official templates that disable
command-line scene overrides.

The PR's city entry point is `/pr-N/sandbox.html`; `/pr-N/` opens the normal
game. Public packages are checked for private asset paths. Browser checks cover
actual keyboard movement, the full circuit, fountain collision, map toggle,
runtime errors, and four canvas sizes. Private Web testing preloads the ignored
local palette only into a loopback-served copy; it is never a CI input.
