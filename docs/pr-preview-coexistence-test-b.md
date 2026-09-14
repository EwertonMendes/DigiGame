# PR preview coexistence test B

This file exists only to create a second deployable pull request while PR #94 remains open.

Expected result after CI deploys this PR:

- `/pr-94/` remains available.
- this PR gets its own `/pr-<number>/` preview.
- deploying either preview must not remove the other one.

This change has no runtime/gameplay effect.
