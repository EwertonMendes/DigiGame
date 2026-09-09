# Skill: Godot Web and GitHub CI

Use this skill for Godot runtime changes, export configuration, CI failures, GitHub Pages deployment, or cross-platform behavior.

## Supported baseline

- Godot 4.7.x.
- GDScript only.
- GL Compatibility renderer.
- Web and desktop use the same gameplay code path.

Do not add Godot C# runtime code because the Web target is a core requirement.

## Validation loop

1. Commit the focused change to a working branch.
2. Let `.github/workflows/web.yml` run.
3. Confirm asset-fetch/provenance steps succeed when external assets are used.
4. Confirm Godot import succeeds.
5. Confirm Web export succeeds.
6. Confirm the Chromium smoke test succeeds.
7. For visual changes, inspect the screenshot artifact.
8. If a job fails, read the exact job log and correct the root cause.
9. Merge only after the relevant workflow is green.
10. On `master`, verify GitHub Pages deployment for playable changes.

## Web compatibility rules

- Avoid platform-specific filesystem assumptions.
- Avoid browser-incompatible native extensions unless there is a validated Web build path.
- Prefer Godot APIs supported by the Web export.
- Do not rely on browser Fullscreen API calls at startup; browsers generally require a user gesture. Make the canvas fill the available page/viewport correctly instead.
- Keep responsive scaling controlled by Godot project settings and test it in Chromium.

## CI design

The CI should be able to reconstruct a clean checkout. If a required third-party asset is not stored in the repository, fetch it deterministically before Godot import and verify integrity.

A green export alone is not enough. The smoke test should start the generated HTML build in a real browser and fail on startup/runtime errors.
