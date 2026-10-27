# LAST FRONTIER / ПОСЛЕДНИЙ РУБЕЖ

## W60: approved name, honest product boundary

The user approved the name **ПОСЛЕДНИЙ РУБЕЖ / LAST FRONTIER** for the OSGARD game project. The Godot application title is updated in this isolated branch. This is a **brand migration proposal**, not a claim that the current six-mission simulation is a commercial story-driven action game.

### Verified current scope
- Godot 4.4.1 project at `w33-godot-native/project.godot`.
- Six offline simulated diagnostic missions; no real machine drivers.
- Software-only W58 source baseline `ef570cf6c406cc14ec180585ee2c5d64c667c658` (9/9 CI).
- W58 public software-only prerelease remains labeled OSGARD and is **not** silently replaced.

### Brand migration checklist (not yet completed)
- [x] Rename Godot `config/name` in isolated branch.
- [x] Preserve old code and release provenance.
- [ ] Inspect all in-game menu, mission, credits and localization strings; migrate display copy without modifying mission logic.
- [ ] Update Windows export metadata and filenames with new reproducible build.
- [ ] Update RU/EN screenshots and human visual approval.
- [ ] Verify third-party trademark/name availability before commercial distribution.
- [ ] Complete exact-head CI, real device acceptance, rollback and explicit release GO.
- [ ] Decide separately whether to rename GitHub repository and external domains (not authorized by this PR).

### Path to a commercial game: quality gates, not promises

**Phase A: playable product definition.** Determine genre, player role, world, enemies/conflicts, core loop, controls, fail/win states and why six diagnostic missions are compelling. Conduct 10 blind user tests. Exit gate: 8/10 understand objective unaided, 7/10 want to play again (targets, not achieved metrics).

**Phase B: vertical slice.** Build one 10–15 minute polished level with compelling decision-making, cinematic art direction, original audio, onboarding and save/resume. Exit gate: stable native GPU + web play, meaningful completion and retention measures.

**Phase C: production.** Create content pipeline, art bible, accessibility, localization, gameplay telemetry, QA matrix, release automation, build budget and milestone costs. Scope based on real playtest data, not AAA marketing claims.

**Phase D: market validation.** Distinct title/trademark clearance, Steam page, playable demo, wishlists, trailer, creators, pricing tests and community feedback. A world blockbuster is an uncertain market outcome, not a software certification.

### HOLD
No master merge, production publish, rename of live website, DNS/CDN/VPS/SSH or hardware certification. Original W58 acceptance does not transfer automatically to the new commit. The W59 hardware-evidence PR is a separate independent review track.
