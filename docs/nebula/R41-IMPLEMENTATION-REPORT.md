# NEBULA R41 — Implementation and verification record

Date: 2026-11-04. This document is a source-change record, **not** a production deployment certificate.

## Delivered in branch `feature/nebula-r41-campaign-loop-20261104`

- 10 authored Russian narrative briefing entries (`godot/nebula-3d/scripts/campaign_story_r41.gd`).
- Garage shows narrator, story introduction, real current objective and last mission reward/reveal.
- During initial garage startup, active mission and enemies are not started.
- `_r39_launch_sortie()` explicitly initializes the mission only after the player chooses to fly.
- Mission completion adds credits/XP exactly once, records result in save v1's **optional** `r41_last_debrief`, clears mission-specific drones, returns ship to a collision-checked safe start, opens the garage again.
- Saves remain backward compatible: existing credits, unlocks, weapons and premium rights are not rewritten by a new save version.
- Native smoke assertions test briefing, locked garage, no duplicate award, preserved summary.
- Full roadmap with five story acts and 30 planned missions is in `docs/nebula/NEBULA-AAA-GAME-BIBLE-RU.md`. Missions 11–30 are **not yet implemented**.

## CI observations / limitations

- First GitHub CI run `41825349144` found a real GDScript parse problem in the `new_result` type inference. The code was corrected in a subsequent commit using `var new_result: bool`.
- Later review prevented the empty initial `r41_last_debrief` from appearing as a false result, and limited cleanup to mission-group drones.
- The final R41 head requires a **new successful native CI and browser QA run**. Do not mark passed merely because a GitHub PR exists.
- Physical Android/iPhone testing has not been performed by this implementation.
- The existing production allowlist is pinned to exact **R39** Godot web assets. Until CI builds new four-file artifacts, approves the correct hashes through a reviewed release record, and SSH deployment passes its production health-check, **R39 must remain the live version**.

## Release checklist

- [ ] Native GDScript parse + scene import (Godot pinned by workflow)
- [ ] Native `runtime_smoke.gd` passes
- [ ] Web export succeeds
- [ ] Browser flight and portrait/landscape touch checks pass
- [ ] R41 artifact hashes and owner-directed release decision recorded; no implied hardware attestation
- [ ] Explicit production allowlist update for verified Web binaries
- [ ] Isolated SSH publish with rollback + Nginx route checks
- [ ] Production gameplay confirmation including actual user controls
- [ ] Physical-device acceptance separately recorded

**Never present a pull request, build log, or a successful HTTP 200 as proof that R41 gameplay is available on osgard.world.**
