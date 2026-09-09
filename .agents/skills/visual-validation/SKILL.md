# Skill: Visual and Responsive Validation

Use this skill whenever changing terrain, backgrounds, shaders, camera behavior, UI layout, sprite scale, effects, viewport settings, or other presentation.

## Visual goals

- Preserve clear isometric tactical readability.
- Keep units visually distinct from terrain.
- Avoid random visual noise that makes the grid difficult to read.
- Prefer coherent terrain regions and controlled variation.
- Keep animated backgrounds subtle enough that they do not compete with battle information.
- Ensure the Web canvas uses the browser viewport correctly while Godot preserves the intended world proportions.

## Required checks

After a visual change:

1. Run the Web pipeline.
2. Confirm the browser smoke test passes.
3. Inspect `build/web-smoke.png` from the workflow artifact.
4. Check for clipped canvas edges, unexpected page margins, stretching, letterboxing that wastes large areas, off-screen units, HUD overlap, broken z-order, excessive shader brightness, or unreadable tile highlights.
5. If the composition is wrong, fix it and repeat the loop rather than merging a merely buildable result.

## Responsive behavior

Use a stable logical base resolution and Godot stretch settings that preserve proportions while allowing additional visible area when aspect ratios differ. The test should assert that the HTML canvas fills essentially the entire browser viewport.

Do not confuse browser page fill with the browser's security-gated Fullscreen API.

## Tactical readability

Terrain variation should communicate regions or gameplay meaning. Movement and targeting overlays must be more visually salient than decorative details. Animated background motion should be slow, low-frequency, and behind all game information.
