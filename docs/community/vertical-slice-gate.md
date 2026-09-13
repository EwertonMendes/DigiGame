# Vertical-slice release gate

Do not actively distribute the playable Web build until every required item is checked. A technical Pages build may exist for CI and review, but the public landing page must not link to it before this gate passes.

## Required player flow

- [ ] A new player can complete a coherent 20–30 minute loop: hub → preparation → mission → tactical battle → reward → hub.
- [ ] The player can prepare and use a team of up to three Digimon.
- [ ] At least one positioning or Link-related decision has a visible effect on the battle result.
- [ ] At least one digivolution or degeneration route works in the DigiLab.
- [ ] Controls and tutorial copy are understandable without live developer guidance.
- [ ] Development-only shortcuts and temporary tools are outside the normal player path.
- [ ] The build page clearly says prototype, lists the build identifier, and shows known issues.

## Platform quality

- [ ] Desktop browser smoke tests pass with no blocker.
- [ ] Android browser smoke tests pass in portrait and landscape with no blocker.
- [ ] The main flow is manually completed once on a desktop browser.
- [ ] The main flow is manually completed once on a real Android device.
- [ ] Save/progression behavior expected for the test is documented.
- [ ] A fallback contact path exists if Discord is unavailable.

## Closed test

- [ ] Recruit 10–20 opt-in testers through Discord.
- [ ] Run the first one-week round and triage all blockers.
- [ ] Publish a “You said → I observed → changed → not changing yet because…” update.
- [ ] Run the second one-week round on the corrected build.
- [ ] At least 70% of testers who start the second build complete the main flow.
- [ ] No known blocker remains open.
- [ ] At least eight complete sessions and ten actionable feedback items have been collected across the rounds.

## Public opening

Only after every section above passes:

1. Remove the landing page's `noindex` instruction when discoverability is desired.
2. Add one clear **Play in browser** CTA to the landing page and README.
3. Publish the build number, expected session length, controls, and known issues.
4. Post first in the owned Discord community.
5. Then post to r/playmygame with a direct free-play link and to only one additional external community that week.
6. Keep a rollback-ready copy of the last stable public build.

## Decision record

| Date | Build | Closed testers started | Completed | Completion rate | Blockers | Actionable feedback | Decision |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| | | | | | | | |

