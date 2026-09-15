# REG-2026-001 — Web battle startup `memory access out of bounds`

- Status: Resolved
- First observed: PR #118 investigation on 2026-09-15
- Introduced by: PR #112, during the global Digi UI V2 migration
- Affected runtimes: Web/WASM primarily; timing-sensitive by nature
- Fixed by: PR #118

## Observable signature

Entering the test battle from the Hub could intermittently crash the Web build with:

`memory access out of bounds`

The most useful log boundary was consistent: the scene reached `[Battle] READY`, then failed before the first stable battle-intro marker. Desktop and mobile browser runs reproduced it more often than native/headless execution.

Because the symptom appeared during Hub → Battle transition, several renderer and loading paths initially looked suspicious. The failure was intermittent, so successful individual runs were not sufficient evidence that a theory was correct.

## Root cause

`DigitalTransitionBattleHUD._build_escape_ui()` called `EscapeBattleHUD._build_escape_ui()` first. The base implementation created the legacy flee-confirmation subtree and retained references such as `_escape_modal_panel`, `_escape_title`, `_escape_question`, `_escape_confirm`, and `_escape_cancel` for later layout/input work.

The V2 override then removed that base-owned subtree from the scene tree and queued it for deletion while the base HUD still owned those references. Later in the same startup sequence, `refresh_from_controller()` / `_layout_dock()` reached `_layout_escape_ui()`, which dereferenced controls that were already removed or pending deletion.

That is a lifecycle/ownership violation: a subclass destroyed nodes still owned and referenced by its base class. Native timing often hid the mistake; Web/WASM exposed it as an intermittent out-of-bounds memory failure during the first battle render/startup.

A second bug was found while cleaning the fix: `DigiConfirmationModal` hides itself before emitting `confirmed`, so reusing the legacy `_on_escape_confirmed()` handler would silently return on its `visible` guard and never call `attempt_flee()`.

## Why earlier hypotheses were wrong

The following paths were investigated because they happened near the crash, but none was the root cause and none belongs in the final fix:

- Camera intro tweens / Camera2D transform updates.
- Web-specific battle-camera virtualization.
- `RenderingServer.frame_post_draw` synchronization.
- Digital transition reveal/shader timing.
- Disabling transition rendering after the scene swap.
- DigiGlass framebuffer sampling / blur fallback.
- DigiUiRuntime decoration/restyling churn.
- Headless-only audio cleanup.
- `ResourceLoader.load_threaded_request(..., use_sub_threads)` as the primary cause.

Some experiments changed reproduction frequency, which made them useful diagnostically, but the crash remained until the stale flee-modal ownership was corrected.

## Resolution

The final design keeps ownership boundaries explicit:

- `EscapeBattleHUD` keeps its legacy confirmation subtree intact because its inherited layout still owns references to those controls.
- `DigitalTransitionBattleHUD` creates the V2 flee confirmation as an independent overlay instead of deleting and partially replacing base-owned nodes.
- Battle input is blocked while the V2 modal is open without reassigning the base class's legacy layout references.
- V2 confirmation uses a dedicated handler that calls `attempt_flee()` directly after the modal emits `confirmed`.
- No camera, renderer, transition, shader, loading, music, reward, or progression workaround is required by this fix.

## Invariant to preserve

**A subclass must not free or replace a UI subtree while a base class still retains references to nodes inside that subtree.**

If a legacy surface is later removed completely, the base class must first be refactored so construction, layout, input, and cleanup ownership move together. Partial pointer replacement is not safe.

For confirmation components, also preserve this contract:

**Handlers must not assume the modal is still visible when a `confirmed` signal is emitted unless the component explicitly guarantees that ordering.**

## Regression guard

`tools/test_battle_ui_lifecycle_regression.tscn` is executed as the `battle-ui-lifecycle` job in the headless regression matrix. It verifies that:

- the inherited flee controls are still valid after battle startup;
- forcing the inherited flee layout does not dereference stale controls;
- the V2 flee modal has independent ownership;
- safe `NO` focus is preserved;
- confirming the V2 modal invokes `attempt_flee()` exactly once even though the modal hides before emitting `confirmed`.

The existing Web browser QA remains the platform-level guard for the original Hub → Battle reproduction path on desktop, mobile, and combat/VFX flows.

## Relevant files

- `src/EscapeBattleHUD.gd`
- `src/DigitalTransitionBattleHUD.gd`
- `src/ui/components/DigiConfirmationModal.gd`
- `tools/test_battle_ui_lifecycle_regression.gd`
- `.github/workflows/headless-regressions.yml`
