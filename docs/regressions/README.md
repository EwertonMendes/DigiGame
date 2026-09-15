# Persistent regression records

This directory is the durable ledger for bugs that are intermittent, platform-specific, repeatedly misdiagnosed, or likely to return after future refactors.

A persistent regression record is not a replacement for an issue or pull request. It records the engineering knowledge that must survive after the PR is merged: the observable signature, the real root cause, the invariants that were violated, discarded hypotheses, and the automated guard that prevents recurrence.

## When a record is required

Create or update a record when at least one of these is true:

- the bug is intermittent or timing-dependent;
- the bug reproduces only on a specific runtime such as Web/WASM or mobile;
- more than one attempted fix was needed before the root cause was isolated;
- a fix touches lifecycle, ownership, persistence, save data, scene transitions, input, rendering, or other cross-cutting behavior;
- the same symptom has returned in more than one PR.

## Definition of done for a persistent regression

A fix is complete only when all of the following are true:

1. The record identifies a concrete root cause, not only the symptom.
2. The code change restores a clear invariant or ownership boundary.
3. A regression test exercises that invariant at the lowest practical level.
4. Platform-specific QA still covers the original reproduction path when applicable.
5. Temporary logging, renderer experiments, timing changes, and unrelated hardening introduced during diagnosis are removed unless they independently protect a documented contract.
6. The final PR diff contains only the fix, its regression guard, and durable documentation.
7. All relevant CI checks are green on the final cleaned head.

## Naming and index

Use `REG-YYYY-NNN-short-slug.md` and never delete resolved records. Resolved entries remain useful because they explain why apparently redundant ownership or lifecycle rules exist.

| ID | Status | Area | Symptom | Guard |
| --- | --- | --- | --- | --- |
| [REG-2026-001](REG-2026-001-web-battle-startup-oob.md) | Resolved | Battle UI / Web | Intermittent `memory access out of bounds` entering battle | `battle-ui-lifecycle` headless regression + browser QA |

## Record template

```md
# REG-YYYY-NNN — Short title

- Status: Investigating / Resolved / Monitoring
- First observed: date / PR / commit
- Introduced by: PR / commit, when known
- Affected runtimes: Web, desktop, mobile, headless, etc.
- Fixed by: PR / commit

## Observable signature

Exact error, log boundary, reproduction path, and what makes the bug intermittent.

## Root cause

The concrete ownership/lifecycle/data/rendering invariant that was violated.

## Why earlier hypotheses were wrong

List discarded theories and the evidence that ruled them out. This prevents future debugging from repeating the same dead ends.

## Resolution

Describe the final design, not every experiment made on the way there.

## Invariant to preserve

A short rule a future refactor must continue to satisfy.

## Regression guard

Name the automated test/workflow and what it proves. Include platform QA when the failure only appears on a specific runtime.

## Relevant files

List the small set of files that encode the invariant.
```
