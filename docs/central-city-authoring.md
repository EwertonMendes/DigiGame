# Central City visual authoring

The editable source of truth for Central City is:

`res://scenes/world/central_city_authoring.tscn`

The 2D viewport is WYSIWYG: the visible city is rebuilt by the same runtime builders used by gameplay (ground batching, micro-paver shader, road meshes, civic surfaces, 2.5D elevation, retaining walls, stairs, bridges, buildings, props, landscaping, lighting and world backdrop). Editor controls are drawn separately on top and are never exported as gameplay nodes.

## Central City toolbar

Opening the authoring scene enables the **Central City** toolbar in the 2D editor.

- **Select** — direct selection/movement of authored objects.
- **Road** — direct road editing.
- **+ Road** — click a start and end point to create a snapped road.
- **Ground** — paint base-floor material with the mouse; right-click erases paint.
- **Surface** — select/move/resize plaza, court and forecourt polygons.
- **Transition** — select/move/resize stair, bridge and void footprints.
- **Level** — edit the terrace/level boundary.
- **Building / Prop / Landscape** — click the corresponding world content and drag it.
- **Snap** — 1, 1/2 or 1/4 logical tile. Hold **Alt** while dragging to temporarily bypass snap.
- **Surface palette** — applies to Ground paint and, when appropriate, the selected road/region.
- **Handles** — shows/hides the clean editing handles without replacing the runtime art.
- **Validate** — checks structural authoring errors, including road graph connectivity.
- **Duplicate / Delete** — scene-safe object actions with editor undo history.
- **Bake** — writes `assets/resources/world/central_city_baked.tres` from the current scene.

Normal Godot **Ctrl+Z / Ctrl+Shift+Z** works for plugin road, ground, object and region operations.

## Roads

Do not edit the raw `Line2D` handles from Godot's generic line tool. The raw Line2D is intentionally hidden because it exists on the logical collision plane while Upper Civic renders 48 px higher.

Choose **Road** in the Central City toolbar. Roads appear as thin orange controls exactly on top of the rendered roads.

- Drag a yellow endpoint to lengthen/shorten the road.
- The endpoint is constrained to the original isometric axis automatically.
- **Shift** while dragging allows a free-angle point when deliberately needed.
- Connected endpoints move together, so an intersection does not open a seam.
- The renderer also accepts temporary off-axis connected segments, so a road can no longer disappear merely because a junction is being edited.
- Drag the road body to move the complete segment.
- Drag the cyan width handle to resize the road visually.
- Change the toolbar **Surface** (or Inspector Surface) to change road paving.
- **+ Road** creates a new snapped, axis-correct road with two clicks.

The plugin works in logical grid coordinates but presents all handles at the real rendered elevation, so pulling a handle outward always means visually extending the same end of the road.

## Ground paint

Choose **Ground**, select a material in the Surface palette, and left-drag over the city. Painting is stored in the `GroundPaint` authoring node and overrides the normal base floor for those logical cells.

Right-drag erases authored paint. `void` removes rendered ground and walking for that painted cell. Ground paint is baked back into the same runtime ground batching system; it does not add one runtime Sprite/Node per painted cell.

## Surfaces

Choose **Surface**, then click a plaza/forecourt/court region. The selected region gets green outline + corner handles.

- Drag inside it to move the complete region.
- Drag a corner to edit the polygon.
- Change the Surface palette to change material.
- Snap is applied in logical isometric grid space.

## Stairs, bridges and voids

Choose **Transition** and click the relevant structure. Transition regions use rectangular authoring bounds because the runtime structure is generated from those bounds.

- Drag the body to move the structure.
- Drag a corner to resize it.
- Rectangular integrity is preserved automatically.
- The runtime preview immediately rebuilds the real stair/bridge/void from the changed footprint.

This means the user edits one architectural entity instead of independently repairing wall cuts, walkability and visual geometry.

## Level boundary

Choose **Level**. The boundary appears in purple.

- Drag an endpoint to extend/retract the retaining boundary.
- Drag the line body to move the boundary and its lower-level threshold together.
- Snap keeps it aligned to the city grid.

Level elevation itself remains an explicit property under **Levels** (for example Upper Civic = 48 px), while the boundary tool controls where the level changes.

## Buildings, props and landscaping

Choose the matching toolbar mode and click/drag.

Building anchors drive the actual runtime service: foundation, collision, entrance/door threshold, shadow and lighting follow the authored anchor. Props and landscape markers are likewise re-resolved through the normal runtime placement/topology rules.

Use **Duplicate** for another authored object and **Delete** to remove the selected authored node.

## Runtime preview and lighting

The `CentralCityAuthoring` root still exposes:

- **Show Runtime Preview** — normally on.
- **Auto Refresh Preview** — normally on.
- **Preview Hour** — uses the real gameplay lighting system; 12 for day, around 18 for sunset, 21 for night.

The plugin keeps the old raw authoring overlay disabled. Only purpose-built handles are drawn over the exact runtime preview.

## Bake/runtime contract

The editable scene remains the level-design source. A bake produces `central_city_baked.tres` containing the normalized snapshot used by the runtime systems. Runtime can use a valid baked snapshot directly; when no bake exists it falls back to parsing the authoring scene once.

The live game still uses the optimized batched ArrayMesh ground/road presentation. Editor gizmos, plugin controls and authoring nodes are not retained as gameplay content.

The Core Headless regression checks that a committed bake, when present, matches the authoring scene, and that roads remain renderable while editor junctions are temporarily off-axis.

## Legacy JSON

The old Central City layout/topology JSON files remain compatibility/reference data for old tooling. They are no longer the intended hand-editing workflow. Map composition should be changed in the Godot authoring scene.
