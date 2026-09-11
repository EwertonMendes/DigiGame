# DigiGame CI

The Web workflow is optimized for short feedback without reducing the quality gates used by the project.

## Pipeline shape

1. **Validate and build Web** runs the asset checks, Godot import, headless gameplay regressions, data validation, and one release Web export.
2. The exported build is uploaded once and reused by four browser suites that run in parallel:
   - `desktop`: hub movement, responsive desktop layouts, debug toggle, pointer facing, camera pan/zoom and keyboard camera input;
   - `combat`: attack targeting, Techniques submenu/focus hierarchy, CT progression and enemy AI;
   - `mobile`: hub touch movement/dialogue, portrait/landscape layout, touch selection, pan, pinch and zoom controls;
   - `vfx`: combat windup/impact plus data-driven VFX/audio presentation events.
3. GitHub Pages deploys only from `master` and only after the build and every browser suite pass.

## Performance safeguards

- Godot and export templates are cached by engine version.
- `.godot` imports are cached using project/source/scene/resource/asset content hashes and still run through `godot --import` on every build.
- Playwright's npm downloads are cached; Chromium is not downloaded because the GitHub runner Chrome installation is used.
- Browser startup waits on `[Hub] READY` and `[Battle] READY` runtime markers instead of fixed multi-second sleeps.
- `concurrency.cancel-in-progress` stops obsolete runs when a newer commit is pushed to the same PR/ref.

Screenshots remain diagnostic artifacts per browser suite, while the playable Web artifact contains only the exported game.