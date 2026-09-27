# Central City visual authoring

The editable source of truth for Central City is:

`res://scenes/world/central_city_authoring.tscn`

The 2D viewport is WYSIWYG: the visible city is rebuilt by the same runtime builders used by gameplay (ground batching, painted road cells, micro-paver shader, civic surfaces, 2.5D elevation, retaining walls, stairs, bridges, buildings, props, landscaping, lighting and world backdrop). Editor controls are drawn separately on top and are never exported as gameplay nodes.

## World Authoring toolbar

Opening `central_city_authoring.tscn` enables the reusable **World Authoring** toolbar in the 2D editor.

The toolbar belongs to the **edited authoring scene**, not to the selected node. Selecting a building, tree, prop, transition, polygon, the root, or nothing at all must not hide or collapse it. Only the explicit **Hide Tools** button collapses the controls; the compact **Show World Tools** button restores them.

- **Select** — click authored content directly in the viewport and drag it. You do not need to select `CentralCityAuthoring` first.
- **Paint** — paint logical world cells by holding/dragging the left mouse button.
- **Road Brush** — switches to Paint, selects the dedicated `road` surface, and chooses a 3×3 brush. Roads are ordinary painted cells: no endpoints, graph, linked segments, or propagated geometry.
- **Brush** — 1×1, 3×3 or 5×5 paint footprint.
- **Surface** — material to paint. Right-drag erases authored paint.
- **Transition** — keeps transition/boundary editing available for stairs, bridges and voids.
- **Level** — edits the terrace/level boundary.
- **Snap** — applies to moved authored objects and structural handles; paint itself always targets whole logical cells.
- **Handles** — shows/hides clean editing handles without replacing the runtime artwork.
- **Validate** — checks the scene data, paint-cell keys and structural authoring nodes.
- **Duplicate / Delete** — scene-safe actions with Godot undo history.
- **Bake** — writes `assets/resources/world/central_city_baked.tres`.

Normal Godot **Ctrl+Z / Ctrl+Shift+Z** works for paint, object movement and region edits.

### Direct viewport selection

Selection is handled by the authoring scene itself rather than by whether the root is currently selected in the Scene dock. Visible buildings, props, landscapes and polygon regions can be clicked directly in the WYSIWYG preview. Empty clicks may clear the selected object, but they do not disable or hide the toolbar.

The authoring plugin reads a small `get_world_authoring_context()` contract from the scene root. New world-authoring scenes can expose the same contract and reuse the same toolbar instead of receiving a one-off editor plugin.

## Painted roads and ground

Roads are no longer `Line2D` corridors and there is no road graph in the editor. The previous Central City road network was migrated into `GroundPaint.cells` as the dedicated `road` surface.

Choose **Road Brush** and drag. Each painted cell is independent, so changing one road tile never changes a neighboring road or another segment. Intersections are created simply by painting intersecting cells. Use the normal **Paint** mode with another Surface value to compose plazas, paving, grass, dark floor, district materials or future map surfaces with the same interaction.

Right-drag removes authored paint from the brush footprint. `void` removes rendered ground and walking for those cells. Painted cells are still rendered through the existing batched ground pipeline, so this simpler authoring model does not create one runtime node per cell.

The `road` surface intentionally uses the approved dark street material while remaining semantically identifiable as a route for placement rules. Runtime no longer builds a second procedural road mesh above the ground.

## Surfaces

Existing polygon-based surfaces remain useful for large authored shapes such as forecourts or district plazas. In **Select**, click the polygon and drag it; selected polygons expose vertex handles for manual reshaping. The Surface palette can still change a selected region's material when not in Paint mode.

## Stairs, bridges and voids

Choose **Transition** and click the relevant structure. Transition regions remain structural entities because they control more than appearance: elevation crossing, collision/walkability and the generated stair/bridge architecture.

- Drag the body to move the complete structure.
- Drag a corner to resize it.
- Rectangular integrity is preserved automatically.
- The WYSIWYG preview rebuilds the real runtime structure after edits.

## Level boundary

Choose **Level**. The boundary appears in purple.

- Drag an endpoint to extend/retract the retaining boundary.
- Drag the line body to move the boundary and its lower-level threshold together.
- Snap keeps it aligned to the city grid.

Level elevation itself remains an explicit property under **Levels**; the boundary controls where the level changes.

## Buildings, props and landscaping

Use **Select** and click the visible content directly. Building anchors drive the actual runtime service, so foundation, collision, entrance threshold, shadow and lighting follow the authored building position. Props and landscape markers are resolved through the normal runtime placement/topology rules.

Use **Duplicate** for another authored object and **Delete** to remove the selected authored node.

## Runtime preview and lighting

The `CentralCityAuthoring` root still exposes:

- **Show Runtime Preview** — normally on.
- **Auto Refresh Preview** — normally on.
- **Preview Hour** — uses the real gameplay lighting system; 12 for day, around 18 for sunset, 21 for night.

The plugin keeps the old raw authoring overlay disabled. Only purpose-built handles are drawn over the exact runtime preview.

## Bake/runtime contract

The editable scene remains the level-design source. A bake produces `central_city_baked.tres` containing the normalized snapshot used by the runtime systems. Runtime can use a valid baked snapshot directly; when no bake exists it falls back to parsing the authoring scene once.

The live game still uses the optimized batched ArrayMesh ground presentation. Painted roads are part of that same batch; editor gizmos, plugin controls and authoring nodes are not retained as gameplay content.

The Core Headless regression checks that a committed bake, when present, matches the authoring scene, that painted road cells survive the authoring/runtime contract, and that no duplicate procedural road mesh is created.

## Legacy JSON

The old Central City layout/topology JSON files remain compatibility/reference data for old tooling. They are no longer the intended hand-editing workflow. Map composition should be changed in the Godot authoring scene.
