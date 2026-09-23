# World area runtime

The campaign overworld starts in `scenes/world/world_root.tscn`. The existing `hub.tscn` remains a developer-only integration laboratory.

## Runtime contract

- `WorldRoot` owns the persistent player, camera, followers, HUD and service host for the current large area.
- Each large explorable region is one scene. Central City is `scenes/world/central_city_area.tscn`.
- `WorldAreaScene` builds every authored section before gameplay begins. Sections organize authoring data only; they are never streamed, queued, popped in or unloaded while the player walks.
- `WorldAreaSection` owns local terrain, collision, props, buildings and interactables inside the already-loaded area scene.
- `InteractionSystem` resolves world interactions centrally by explicit priority and distance.
- `WorldServiceHost` composes the existing DigiLab, Training, Hospital and Digimon screens without inheriting the legacy Hub gameplay chain.
- `WorldState` persists region, area, exact player position, facing and world-state dictionaries. The existing spatial-cell field remains serialized for save compatibility, but it no longer controls rendering.
- Battle return is contextual: normal gameplay returns to the current world area, while battles deliberately launched from the developer Hub return there.

## Area boundaries

Streaming is intentionally not used inside a large area. A future transition from Central City to another major region such as Green Sector should load a different area scene at an authored gate/transport boundary. That is the correct place for a loading transition, resource handoff and save checkpoint.

Small and medium interiors remain seamless. Service entrances keep the persistent player/camera and use the existing zoom + digital wash transition without changing scenes. While inside, the already-loaded exterior is hidden and its processing is paused; it is restored before the interior transition reveals the city again.

## Central City

`assets/resources/world/central_city.json` defines the 5×5 authoring grid used to compose the complete Central City scene: Central Plaza, DigiLab, Hospital, Training, Data Market, Archive, canals, gardens, residences and city gates.

All 25 sections are present before `[World] READY`. Central City is back on the same **64×32** isometric gameplay grid as the rest of the overworld. The 1024×1024 Devil's Work.shop files remain high-resolution source art; their top faces are sampled onto the runtime diamond. The exterior ground is globally batched: one seam-protection base mesh plus one detail mesh per curated surface type. Area construction yields after small batches of sections behind the opaque loading screen, keeping the first frame responsive without terrain pop-in.

Walking across section boundaries only changes district/title metadata; it never mutates the scene tree. This prevents mobile traversal from paying terrain construction/destruction costs and removes visible terrain pop-in.

Central City uses the project-supplied `assets/world/devilsworkshop/assets_1024x1024/` collection for its floor language. Interior cells sample only each block's authored top face onto an exact 64×32 diamond; perimeter cells additionally render the original block side faces so the island edge has real authored depth instead of ending as a flat cut. The primary neutral/buildable lot floor is source 0072, source 0054 is the canonical pavement/sidewalk material, the Data Market uses 0009, and source 0064 forms the central digital-water pool plus canal accents. The city remains an octagonal digital island with clipped corners, but its internal plan is now explicitly urban: a main cross-city promenade, repeatable block sidewalks along every 14×14 authoring section, rectangular district lots, paved service crosses, a central civic plaza, park blocks and a bridged canal. District materials fill contiguous lots instead of being selected cell-by-cell.

MCBlocks has been removed from the project. DigiLab now uses the dedicated `assets/world/tblack/digilab.png` exterior, positioned against its 0054 forecourt with the seamless interior threshold anchored to the visible front door. Hospital, Training, Data Market and Archive remain accessible through labeled service pads until their dedicated structure artwork is authored. All seamless interiors continue to use Devil's Work.shop surfaces, so no runtime dependency on the retired atlas remains.

## Adding a major area

Add a dedicated area scene and its data file, register the data in `WorldAreaCatalog`, and load that scene only at a major-region boundary. Do not introduce proximity streaming inside the area. Large-area loading is expected to happen once at the transition; exploration afterwards must be stable.

## Developer Hub

The old prototype Hub is not the normal application entry point. Development builds expose a **TEST HUB** action in the Developer Toolkit. Automated Web QA can use `?debug=1&test_hub=1`; the route is rejected when developer tools are unavailable.


## Performance contract

Central City treats authoring sections as data boundaries, never rendering boundaries. The octagonal island currently renders 4,341 authored ground cells; clipped corner cells are true non-walkable digital void rather than hidden floor. Ground draw calls are bounded by the small curated surface palette instead of section count, and the area regression keeps the runtime node budget below its existing limit.

Static world collision is represented by the authored walkability grid instead of duplicating every blocked cell into PhysicsServer shapes. Player clearance samples preserve collision margins; dynamic bodies and doorway Area2D triggers remain engine-native physics objects.

Tree canopy sway is shader-driven. Leaf particles are only emitted in the player's nearby section neighborhood, managed by one area-level cadence rather than per-tree GDScript processing.

World interaction candidates use a registry updated by SceneTree add/remove events and player movement instead of scanning the `world_interactable` group every frame.

Area-title banners are reserved for major authored locations and explicit story events. Crossing an internal authoring section never displays a banner or forces an immediate save.
