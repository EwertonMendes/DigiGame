# Night Circuit: isolated city sandbox

Open `experiments/darkmoon_sandbox/DarkmoonSandbox.tscn` in the existing
DigiGame project and press **F6**. F5 still opens the normal game. This scene
does not change the main scene, menus, progression, autoloads, or save format.
The game's existing autoloads still initialize normally.

## Play

| Control | Action |
| --- | --- |
| WASD / arrow keys / joystick | Eight-direction movement |
| Shift | Run |
| F3 / Collision button | Show green walkable polygons, red bases, yellow actor clearance |
| Tab / Map button | Toggle whole-city overview |
| R / Reset button | Return to the plaza |
| F4 | Run the actual actor around the complete loop and both courts |

The scene has an arrival plaza, four connected diagonal avenues, two side
courts, three market facades, terminals, lights, walls, and shallow decorative
steps. All movement uses one ground plane. The four dark interior gaps and the
outside of the city are deliberately unwalkable. It is an original arrangement;
the source city's street layout is not included.

## Private local graphics

The supplied ZIP contains proprietary ROM-derived pixels with no redistribution
license. They are **not** committed, downloaded in CI, or included in public
artifacts. The public preview uses the original `palette.svg` instead, with the
same geometry, actor, controls, and collision queries.

To enable the supplied graphics locally, install Pillow in your Python runtime
and run from the repository root:

```powershell
python experiments/darkmoon_sandbox/import_private_assets.py "C:/Users/ewert/Documents/Dev/digimon-world-dusk-pc/.private/scenery/Darkmoon_City_Assets_Only.zip"
```

The importer checks the supplied SHA-256 manifest and copies the three city
atlases into `assets/local/darkmoon_sandbox/darkmoon_city/`. It assembles only
the selected fragments into a private 256×192 palette without resizing,
recoloring, or altering alpha. `brushes.json` records the selected 32-pixel
chunk IDs. The actual scene paints those fragments on a **square 8×8 visual
grid**, with zero margin/separation and nearest filtering at 2× scale.
Private pixels are loaded with `Image.load_from_file` at runtime because
`.gdignore` keeps their directory out of Godot's normal import/export scan.
Keep both `.gdignore` and `.gitignore` in place.

`Use Private Art` on the root defaults to true, with automatic public fallback
when the private palette is absent. Turn it off to compare the original art.
The fragment brushes are experimental compositions, not a classified complete
city tileset. More facades and precise edge variants can be curated from the
remaining source atlas without importing the original map arrangement.

## Paint and edit

* Select `Ground` or an `Art` TileMapLayer and use Godot's TileMap painting tools.
  All layers are serialized in the scene; edits survive F6 and reopening.
* The atlas regions are square 8×8, even though the art depicts isometric forms.
  The visual grid and movement polygons are deliberately separate.
* The ground repeats either the floor or paver brush. Object layers use complete
  brush rectangles. `brushes.json` documents their positions in the palette.
* Move buildings by moving their parent under `Depth`, preserving the shared
  ground anchor between `Art` and `Footprint`. Objects and the actor use Y sorting.
* `Art Offset` metadata places the brush above its ground anchor. Keep offsets
  and painting on integer native pixels (layer scale is 2×).
* `Rebuild Tiles` on the root regenerates painted layers from the current
  walkable polygons and object metadata. **It replaces existing paint edits**;
  save a scene copy before using it. It preserves footprints and object positions.
* `bake_scene.gd` is the initial-layout generator. It replaces the entire scene,
  so use it only when deliberately regenerating the original experiment.

The editor shows the public palette. Runtime substitutes the private palette
at identical cell coordinates. To paint additional private brushes, curate their
chunk IDs in `brushes.json`, assign a matching rectangle in `palette.svg`, rerun
the private importer, and regenerate the tiles. Preserve the palette dimensions
or adjust the explicit size contract in `DarkmoonSandbox.gd`.

## Edit collision

`Walkable/*` are hidden Polygon2D nodes; enable their visibility temporarily
when editing their vertices in Godot's 2D editor. Their union defines surfaces.
`Depth/<object>/Footprint` polygons subtract solid ground bases from that union.
They do not cover roof or facade height. Moving an object moves its base too.
The same polygons drive both debug drawing and movement, with no extra physical
obstacle bodies to drift out of sync.

The adapter reuses `OverworldActor` / `HubActor` for input, animation, acceleration,
and axis sliding. It samples the complete movement segment every four pixels,
with nine clearance samples matching the inherited 10-pixel-radius capsule.
This follows `WorldRoot`'s surface/segment/clearance principle without reusing
its city loading, traversal levels, services, or persistence behavior.
Use F3 and walk around each changed corner. Make gaps wider than the capsule;
painting a floor tile alone does not make an unwalkable polygon walkable.

## Web preview and validation

CI exports the ordinary game unchanged, then generates `sandbox.html`, which
passes the experiment scene to Godot's Web engine. Both entry points share the
same exported resources. The PR preview is `/pr-N/sandbox.html`; `/pr-N/` still
opens the normal game. CI runs the normal Web and browser suites plus the
sandbox's actual actor route, collision checks, and responsive browser checks.

```powershell
godot --headless --path . --script experiments/darkmoon_sandbox/test_sandbox.gd
godot --path . --script experiments/darkmoon_sandbox/test_sandbox.gd -- --private
```

The second command captures private desktop screenshots under ignored `.tmp/`.
Public browser screenshots go to the normal CI screenshot artifact. Never upload
private screenshots or the local palette. Tests cover eight directions, diagonal
sliding, full-loop/court traversal, obstacle contouring, thin-obstacle tunneling,
external edges, inner voids, and roof clearance. Manual play remains useful when
editing source fragments or collision polygons.
