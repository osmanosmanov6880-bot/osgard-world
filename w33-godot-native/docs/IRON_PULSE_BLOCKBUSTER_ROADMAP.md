# IRON PULSE — Blockbuster Roadmap (proposal, not shipped)

## Baseline (verified 2026-10-27)
- Game: Godot 4.4.1 fictional reactor simulation, six mission scenarios, three camera views, RU/EN, HERO/ECO, WebGL/Windows exports in historical W58.
- Approved name: IRON PULSE, branding PR #577 head 83d94893313fcb800124dacb36879248ef621d64. Exact-head branding CI must finish; original W58 9/9 does not certify a renamed binary.
- Hardware, visual human approval, 30-min thermal stability, integration and live publishing: HOLD.
- No evidence of player demand, retention, market validation, AAA-quality art or commercial launch.

## Stage A: release-safe foundation (1-3 weeks, estimate)
1. Fix all branding regression assertions; require exact-head native 6 missions, desktop WebGL + Win64 export, RU/EN 390px responsive screenshots.
2. Preserve W57/W58 immutable archives and historical OSGARD internal identifiers; version a **new** IRON PULSE prerelease only after green evidence.
3. Physical GPU/Android/iPhone, accessibility, real frame times, visual signoff and rollback dry-run. Production GO remains separate.
Exit: complete and auditable playtest build; not yet a blockbuster.

## Stage B: vertical slice / core fun (6-10 weeks, estimate)
- Single explorable reactor level with player controller, third-person or first-person camera, locomotion, 2-3 interactive machines, a systemic incident, NPC radio character, environmental storytelling, checkpoint/save, mission win/lose.
- 15-25 minute uninterrupted playable arc with tension, meaningful decisions, clear consequences, subtitles RU/EN, gamepad/mouse/keyboard.
- One impressive reveal and one repeatable signature mechanic: reroute power between critical systems, with trade-offs affecting hazards, routes and characters.
- Playtest with >=20 independent target players, capture onboarding, completion, first-failure explanation, replay intent and bugs; no fabricated results.
Exit: >=70% finish slice, >=60% explain failure correctly, >=40% want more (targets, not achievements).

## Stage C: production prototype (3-6 months, estimate)
- 3 distinct interconnected zones, 4-6 core systems, 8-12 varied scenarios, at least 2 character arcs, cinematics, soundscape, accessibility, QA automation, performance budgets.
- Content pipeline and telemetry with privacy controls, source asset licenses, localization and controller compliance.
- External competitor/Steam audience review and wishlist conversion experiment before funding full production.
Exit: validated retention and production cost per minute of content.

## Stage D: full commercial game (12-30+ months, contingent)
- Coherent 4-8h premium campaign or smaller polished 2-4h indie release, differentiated mechanical depth, professional audio/animation/art, narrative, robust save and QA, marketing trailer/demo, storefront and legal checks.
- Budget/staffing depends on target fidelity and verified audience; no promise of GTA/AAA results with current scope.
Exit: critical-path feature complete, release candidate passes real-device QA, external player feedback and storefront requirements.

## Current hard priorities
1. Close naming CI regression and generate **new** IRON PULSE binaries.
2. Conduct first external playtests; avoid building massive open world before fun is proven.
3. Design and prototype the power-routing crisis loop as separate opt-in gameplay branch, never destabilizing the accepted W58 source.
4. No master merge or public production deploy without independent GO.
