# Editable city sandbox

The real PNGs are committed in `assets/scenery/darkmoon_city/` and included in
normal Godot/Web exports. Open `DarkmoonSandbox.tscn` and press F6, or open the
PR's `/pr-N/sandbox.html`. Both start directly, without a ZIP picker or substitute
artwork. The original game entry point, maps, progression and saves are unchanged.

This is an original arrangement of reusable pieces. Source maps were references
for identifying component cells; their backgrounds, streets and placements are
not imported.

## Author your own scenes

Save a copy of the sandbox, retaining the `Walkable`, `GroundMask/Ground` and
`Depth` node paths. Change the platform polygon, paint tile layers and arrange
modules under `Depth`. Move each module's parent so its art, footprint and
interaction anchor move together. Keep parent scale 1 and rotation 0; tile layers
already use integer 2× scale and Nearest. Normally snap to 16 pixels, with deliberate
8-pixel offsets for isometric half-cell anchors.

`CityTiles.tres` uses square 8×8 cells, zero margin and separation:

* Source 0: curated complete modules and materials.
* Source 1: all 3,825 valid cells from the original atlas, without the empty tail.

`pieces/` contains reusable DigiLab, Market, MarketCounter, DataTerminalA,
DataDisplay, Fountain and ArrivalPlaza scenes. Their complete art and ground bases
remain editable. Platform-support columns are not used as freestanding lights.

The current plaza uses native interlocking paving, structural edge strips and
corner caps. There is no code-drawn paving grid or flat-color platform facade.
The market and research station share a continuous pedestrian
space around the basin. The indoor counter remains in the module catalogue;
the outdoor scene uses one cabinet attached to the platform edge instead.
The fountain retains its native rim without bridge landings. The surrounding
area uses the same continuous paving as the rest of the plaza. The floating
district monitor and its collision are not instantiated. Water
animation is intentionally deferred.

`brushes.json` records source cell IDs rather than original map placements.
`rebuild_palette.py` rebuilds `pieces.png` and its manifest hash using Pillow and
only the committed source atlas. For platform changes, edit `OUTLINE` in
`bake_scene.gd`; its edges use whole 128-by-64 world-pixel structural segments.
The baker selects front/back faces and clips them to the platform's vertical
extrusion so corners cannot leave floating fragments. Front lips are clipped to
the paving, while vertical faces exclude the paving entirely; walls therefore
cannot cover the adjacent walking surface at a recessed corner. Run it only on the base
sandbox, then review an actual render. The 64-by-64 native paving module repeats
at 128-by-128 world pixels, with native joints preserved across its seams.

For a custom object, paint child TileMapLayers using `CityTiles.tres` at scale 2
and add a hidden `Footprint` Polygon2D following its ground base. Collision uses
that polygon, and depth uses the painted bounds. Roof pixels do not block walking.
F3 shows clearance and footprints. Rebuild Tiles and bake_scene.gd overwrite
paint/module arrangements; do not run them over a hand-authored scene casually.

## Play and validate locally

WASD/arrows move, Shift runs, E interacts, E/Esc closes dialogue, Tab shows the
map/nearby camera, F3 shows collision, R resets and F4 checks the complete circuit. Compact
windows have touch controls.

Desktop starts with the full district visible; compact windows start near the
trainer. Movement works in both camera modes.

```powershell
./experiments/darkmoon_sandbox/validate_local.ps1
./experiments/darkmoon_sandbox/validate_local.ps1 -Capture
```

Tests run headless locally; optional captures use a hidden GPU window. Checks
cover source pixels, atlas coverage, movement, the full route, collision,
tunneling, map edges, roof clearance, depth and interaction. Browser checks open
the bundled build directly and verify keyboard play and responsive canvas sizes.
The sandbox pack URL is versioned to prevent stale browser builds.
