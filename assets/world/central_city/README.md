# Central City terrace presentation

Stair treads, risers, landings, bridge slabs, handrails, and canal banks are constructed from authored transition data using batched meshes. There are no generated PNG sprites in the terrace renderer.

The small paintable paving pattern remains independent of the 64 by 32 placement grid. The main material matches the city's light gray pavement; the editor brush supports an optional custom base color.

Canal water uses `shaders/city_canal_water.gdshader` across authored water regions. The authoring scene remains the source of truth for transition positions and sizes.
