# DigiGame CI

The Web workflow is optimized for short feedback without reducing the quality gates used by the project.

## Pipeline shape

1. **Validate and build Web** runs the asset checks, Godot import, headless gameplay regressions, data validation, and one release Web export.
2. The exported build is uploaded once and reused by four browser suites that run in parallel:
   - `desktop`: hub movement, responsive desktop layouts, debug toggle, pointer facing, camera pan/zoom and keyboard camera input;
   - `combat`: attack targeting, Techniques submenu/focus hierarchy, CT progression and enemy AI;
   - `mobile`: hub touch movement/dialogue, portrait/landscape layout, touch selection, pan, pinch and zoom controls;
   - `vfx`: combat windup/impact plus data-driven VFX/audio presentation events.
3. The Pages artifact combines the multilingual project landing page at `/` with the exact tested game build at `/play/`. The landing page deliberately does not link to `/play/` before the vertical-slice release gate passes.
4. A separate landing-page smoke validates English, Portuguese, Spanish, the closed-playtest message, disclaimer, responsive overflow, and availability of the nested game build. Desktop and mobile full-page screenshots are uploaded for visual review.
5. GitHub Pages deploys only from `master` and only after the build, every game browser suite, and the landing-page smoke pass.

## Performance safeguards

- The Godot executable and only the Web export templates are cached by engine version; unused desktop/mobile export templates are not restored on every run.
- Only `.godot/imported` payloads are cached using project/source/scene/resource/asset content hashes. Godot UID/editor metadata is deliberately rebuilt every run so stale identity data cannot leak between revisions.
- `godot --import` still runs on every build and remains a hard validation gate.
- Playwright's npm downloads are cached; Chromium is not downloaded because the GitHub runner Chrome installation is used.
- Browser startup waits on `[Hub] READY` and `[Battle] READY` runtime markers instead of fixed multi-second sleeps.
- `concurrency.cancel-in-progress` stops obsolete runs when a newer commit is pushed to the same PR/ref.

## Benchmarking

Measure wall-clock feedback from the start of **Validate and build Web** to completion of the slowest browser suite. A cold-cache run validates the fallback installation path; a following documentation-only commit provides a representative warm-cache run without changing game/source hashes.

Screenshots remain diagnostic artifacts per browser suite. `digigame-web-build` contains only the tested exported game; `digigame-pages-site` contains the deployable landing page plus that same build under `/play/`.
