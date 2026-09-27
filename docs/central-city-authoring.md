# Central City visual authoring

Central City is authored visually in Godot through:

`res://scenes/world/central_city_authoring.tscn`

This scene is the source of truth for map layout and now uses a **WYSIWYG runtime preview**. The editor preview is built by the same Central City runtime builders used by the game: the same ground batching, micro-paver shader, roads, civic surfaces, 2.5D elevation, terrace structures, buildings, landscaping and street furniture. Authoring handles are a separate overlay and are hidden by default.

The preview is editor-only. It is never persisted into the scene and is removed from the game runtime, so editor convenience does not turn Central City into thousands of live runtime nodes.

## Authoring tree

- **Sections** — the 5×5 logical districts and their themes/titles.
- **Levels** — named 2.5D presentation levels and their visual elevation.
- **Boundaries** — editable level-break lines.
- **Roads** — editable `Line2D` road paths. Drag their points in the 2D editor.
- **Surfaces** — editable `Polygon2D` plaza/forecourt/court regions.
- **GroundOverrides** — editable `Polygon2D` regions for painted base-floor surfaces such as the civic pool and North Canal.
- **Transitions** — editable `Polygon2D` stair, bridge and void footprints.
- **Buildings** — editor markers for DigiLab, Training Center, Hospital, Data Market and Digital Archive. The three large service buildings show their real sprites in the editor.
- **Landscapes** — editor markers for the existing tree/canteiro composition.
- **Props** — editor markers for lamps and benches; their real sprites are previewed in the editor.

The authoring subtree is removed when the game runs. Runtime systems parse it once and generate the same optimized terrain, roads, collision, lighting and 2.5D structures used before this migration.

## Editor preview controls

Select the **CentralCityAuthoring** root node in the Scene tree.

- **Show Runtime Preview** should normally stay enabled. This is the real game-built city presentation.
- **Show Edit Overlays** is disabled by default. Enable it only while selecting/moving authoring geometry.
- **Auto Refresh Preview** rebuilds the runtime preview after you stop dragging/editing for a short moment.

The edit overlay never tries to imitate the final road/building/tree art. It only shows thin handles over the real runtime preview, so visual defects can be judged against the same presentation the game uses.

## Editing a road

1. Open `central_city_authoring.tscn`.
2. Select **CentralCityAuthoring** and enable **Show Edit Overlays**.
3. Expand **Roads**.
4. Select a road node.
5. In the 2D viewport, use the normal Godot `Line2D` point handles to move its endpoints. The authoring line is intentionally thin; the real road remains visible below it.
6. In the Inspector:
   - **Width Grid** changes road width.
   - **Surface** changes its paved surface.
   - **Tint** adjusts the selected surface without changing the base city floor.
   - **Level Id** chooses the presentation level.
7. Wait a fraction of a second after the edit. The runtime preview rebuilds from the unsaved editor state, so you can inspect the real result before running the game.
8. Save the scene and run the project when satisfied.

Connected road endpoints should continue to meet at the same point. The headless regression checks graph connectivity, so accidentally separating a required connection will fail CI instead of silently shipping a broken route.

## Changing road material without moving it

To test a visibly different road floor, select a road and change **Surface** from `dark` to `stone_soft` in the Inspector. The editor line preview updates immediately; after running the game the runtime baker uses that surface in the same batched micro-paver renderer.

## Editing paved regions

Select a child of **Surfaces** or **GroundOverrides**. Godot exposes normal `Polygon2D` vertex handles in the 2D editor. Move vertices or change the **Surface** dropdown in the Inspector.

`GroundOverrides` affect the base field. `Surfaces` are authored overlays such as service forecourts and district courts.

## Moving a building

Select the corresponding Marker2D under **Buildings** and drag it. Service buildings use their marker as their logical door/pad anchor. Collision, foundation, light and interior threshold are rebuilt around that anchor at runtime.

The building may cross a section boundary; runtime ownership is resolved from the marker position rather than from the old JSON district assumption.

## Moving props and trees

Drag a marker under **Props** or **Landscapes**. Props can cross section boundaries. Landscape markers are snapped to the logical gameplay cell when the runtime city is built, then validated against roads, buildings, stairs, bridges and voids.

## Editing stairs, bridges and future-water voids

The children under **Transitions** are standard `Polygon2D` nodes:

- `kind = stairs` — polygon bounds define stair width and travel span.
- `kind = bridge` — polygon bounds define the bridge deck footprint.
- `kind = void` — polygon bounds remove the base ground and block normal walking.

The runtime still derives the final batched architectural presentation from these authored footprints.

## Compatibility data

The legacy JSON files remain in the repository as compatibility/reference data for older tooling. Central City runtime layout prefers the Godot authoring scene. Do not manually edit the JSON to change map layout.

Asset catalogs such as lamp/bench texture metadata may remain data-driven because they describe reusable asset properties rather than map placement.

## Performance contract

The authoring scene is editor-only presentation data:

1. runtime loads/parses it once;
2. the existing batched `ArrayMesh` ground/road renderer is generated;
3. the authoring subtree is removed from the live scene tree;
4. mobile lighting/performance budgets remain unchanged.

This preserves the optimized runtime while allowing normal Godot scene editing.
