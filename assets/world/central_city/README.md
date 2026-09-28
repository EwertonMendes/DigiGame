# Central City terrace kit

This is original DigiGame artwork for the 64×32 isometric world grid.
The visible paving stays at four small stones per gameplay cell; the world
grid is only the placement coordinate system and remains paintable in Godot.

- `terrace_post.svg` is a reusable 20×30 pixel bridge and stair parapet post. Its bottom-center pixel is the placement foot.
- Stair treads, risers, landings, bridge slabs, parapet beams, canal banks, and road edging are assembled from the authored transition and paint shapes in batched meshes. Their dimensions follow the scene geometry instead of fixed map coordinates.
- Canal water is batched across the authored regions using `shaders/city_canal_water.gdshader`; it does not use repeated water block sprites.

Keep new kit pieces aligned to the same isometric grid and dark steel/cyan material palette. Add distinct orientation artwork only when a piece cannot be built from the shared geometry without distortion.
