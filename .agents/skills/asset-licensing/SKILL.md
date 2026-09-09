# Skill: External Asset Licensing and Reproducibility

Use this skill before adding terrain, UI art, sound, music, fonts, icons, effects, or any other third-party asset.

## Selection policy

Prefer assets in this order:

1. Original project-owned assets.
2. CC0/public-domain assets.
3. Assets with an explicit license that permits redistribution and the intended project use.

Do not treat "free download" as a license.

## Required provenance record

For every new third-party asset set, record:

- asset pack name
- author or publisher
- license
- official source URL when available
- mirror/distribution URL if used by CI
- pinned version or commit when practical
- exact files used
- whether attribution is required

## CI-fetched binaries

When an asset is downloaded during CI:

- Pin the source to an immutable version/commit instead of a moving branch.
- Verify integrity after download.
- Fail the build when integrity verification fails.
- Keep the fetch script small and readable.
- Keep license/provenance documentation in the repository even if the binary itself is generated during CI.

## Proprietary franchise assets

Do not autonomously add ripped proprietary Digimon sprites, music, sound effects, logos, or other copyrighted assets from commercial games. Existing legacy prototype assets may remain until the user chooses a replacement strategy.

Environment and interface assets should favor clearly licensed reusable sources so the project can evolve without avoidable licensing debt.
