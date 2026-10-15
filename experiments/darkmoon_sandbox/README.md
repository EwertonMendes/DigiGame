# Moonrise Commons: editable city assets

Open `experiments/darkmoon_sandbox/DarkmoonSandbox.tscn` in DigiGame and press
**F6**. The scene is an original arrangement of reusable city modules. Source
maps were used only to identify matching component cells; their streets and map
placements are not imported. The normal main scene, maps, progression and saves
are unchanged.

## Use the real artwork

The Web entry point `/pr-N/sandbox.html` asks for
**Darkmoon_City_Assets_Only.zip**. Choose the supplied ZIP from your computer.
JavaScript reads only its pinned 8×8 atlas, checks SHA-256, and preloads it into
the game's memory. It never uploads the ZIP or PNG. Reloading asks for the file
again. An invalid ZIP remains on the selection screen; it cannot silently launch
substitute city art.

For the local editor, import the ZIP once:

```powershell
python experiments/darkmoon_sandbox/import_private_assets.py "C:/Users/ewert/Documents/Dev/digimon-world-dusk-pc/.private/scenery/Darkmoon_City_Assets_Only.zip"
```

The importer requires Pillow and verifies the source manifest. All PNGs stay
under ignored `assets/local/darkmoon_sandbox/`, with `.gdignore` excluding them
from normal Godot imports and exports. Editor tools load these images directly.
The editor and F6 display the real city artwork when that local atlas exists.
Before an editor save, tools restore neutral texture references; after saving,
they restore the live private preview. Painted cells are retained. Private image
data is never embedded in saved scene resources.

`palette.svg` and `raw-atlas-layout.svg` are neutral layout textures for a clean
checkout and automated geometry checks. They are not replacement city artwork.
The normal browser entry point never starts with them. Public CI uses the explicit
`?geometry=1` diagnostic mode after checking the asset-selection screen.

## Create your own scenes

Save a copy of the sandbox under a new scene name. Keep its `Walkable`,
`GroundMask/Ground` and `Depth` node paths so the scene controller can query
walking surfaces and solid bases. Change the platform outline, paint, place
modules, and define new ground footprints for your own composition.

The `pieces/` folder contains reusable scenes:

| Scene | Contents |
| --- | --- |
| `DigiLab.tscn` | Blue roof, facade, base, service anchor |
| `Market.tscn` | Orange roof, facade, base, service anchor |
| `MarketCounter.tscn` | Complete counter and its angled base |
| `DataTerminalA.tscn` | Complete console, base, interaction |
| `DataDisplay.tscn` | Complete district display, base, map interaction |
| `Fountain.tscn` | Basin, fountain, rim and solid base |
| `ArrivalPlaza.tscn` | Clipped plaza floor ornament |

Place these directly under `Depth`, move the parent, and retain its children.
Art, ground base and interaction anchors then move together. Keep parent scale
at 1 and rotation at 0; the art layers already use integer 2× scale and Nearest.
Use pixel snapping, normally 16 pixels; an intentional 8-pixel offset can align
isometric half-cell anchors. Do not stretch or rotate native pixel art to force
an incorrect module to fit.

`CityTiles.tres` has a square **8×8** tile grid, zero margin and zero separation:

* Source **0** contains complete curated modules and materials. Their cells can
  be painted or rearranged individually.
* Source **1**, **Native 8x8 source cells**, exposes all **3,825** valid cells from
  the supplied city atlas. The empty tail is excluded. Use these for new walls,
  borders, details and modules; larger atlas chunks are not complete objects.

For a custom solid object, add a `Node2D` under `Depth`, paint child TileMapLayers
using `CityTiles.tres` at scale 2, and add a hidden `Footprint` Polygon2D following
its base on the ground. The controller queries that polygon for collision and
uses the actual painted bounds for front/back depth. Roof pixels never define
collision. Use F3 to check clearance and bases after each composition change.
Foreign TileSets are left untouched by the private atlas preview tools.

The narrow green-topped column cells are **platform supports**, not streetlights.
They remain available in the raw catalogue but are not scattered through the
plaza. The test city has two functional consoles in one court, a market counter,
a fountain circuit, and a broad arrival area.

`Rebuild Tiles` replaces hand-painted cells with brush metadata. Save a copy
before using it. `bake_scene.gd` regenerates the initial city, catalogue modules
and shared TileSet; it is not an operation to run over your authored scenes.

## Controls and local validation

WASD/arrows move, Shift runs, E interacts, E/Esc closes dialogue, Tab shows the
district, F3 shows collision, R resets, and F4 tests the walking circuit. Compact
windows show the scene-local touch controls. NPCs and facade interactions do not
modify the normal roster or open its services.

```powershell
./experiments/darkmoon_sandbox/validate_local.ps1
./experiments/darkmoon_sandbox/validate_local.ps1 -Capture
# Or use another Godot 4.7 executable:
./experiments/darkmoon_sandbox/validate_local.ps1 -Godot "C:/Tools/Godot.exe"
```

Logic checks run locally headless using the real atlas when present. `-Capture`
uses a hidden local GPU window because the headless dummy renderer cannot
produce screenshots. Logs, screenshots and test user data stay in ignored `.tmp/`.

Checks cover native pixel equality, raw atlas coverage, safe scene serialization,
eight directions, the full district route, frontal/diagonal collision, tunneling,
outer edges, roof clearance, angled-object depth and NPC pause/resume. Local
Chromium tests select the actual supplied ZIP through the published page's picker,
reject invalid files, assert no outgoing asset upload, and check movement,
collision and four canvas sizes. Private screenshots are never CI inputs.

The regular Web export remains `index.html`. `create_preview.py` generates the
sandbox entry point and forks only the exported package's main-scene setting.
JavaScript/Wasm are shared; source `project.godot` is unchanged. Both desktop
and browser use `CityAtlas.gd` and the same scene/controller code.
