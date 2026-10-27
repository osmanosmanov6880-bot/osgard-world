# ПОСЛЕДНИЙ РУБЕЖ / LAST FRONTIER — W61 product and quality dossier

> 27 October 2026. **WORKING TITLE ONLY / NOT TRADEMARK CLEARED.** This is not an AAA release or a physical industrial-machine controller.

## A. The game that is actually implemented

Godot 4.4.1, one original procedural A7 reactor facility with three cameras and six offline diagnostic challenges. Missions 01–03 investigate **optics, cooling, contacts**. Missions 04–06 are the corresponding advanced incident shifts, unlocked by the earlier missions. This is a solo engineering-puzzle/diagnostics simulation, not currently a shooter, online co-op game, open-world RPG or story campaign.

Current observable loop: choose a scenario, stop the **simulated** drive, wait for safe rotor speed (below 80 RPM), open the simulated hatch, choose the proper camera, align two virtual parameters until the signal stabilizes, scan, close hatch, restart the fictional drive and review your performance. Advanced shifts can disturb accepted calibration. All real industrial guidance is explicitly disclaimed. Scores and accessibility settings are stored locally.

Software reference: the original W58 exact-head 9/9 GitHub Actions #40549670648, **source** `ef570cf6c406cc14ec180585ee2c5d64c667c658`. W60 branched from that evidence but changes the Godot app title; W61 adds native display improvements. **Neither new source SHA inherits the 9/9 verdict.**

## B. What W61 actually adds

- **RU/EN native game identity**: localized header, responsive smartphone header, room subtitle, safety footer, accessible WebGL spoken status.
- **Five real phase indicators** embedded inside the Godot 3D HUD, driven directly by the actual local simulation snapshot. Active progress, idle and error are visibly different. The segments are pointer-transparent, with no new commands.
- **Real native Godot acceptance**: run 320/390/1366px, both locales, all six original mission buttons, phase readout and after starting mission 01.
- **Fail-closed W61 source gate**: compare exact Git history to W60, whitelist only UI/l10n/test/docs files, pin original scene, core, rig and W49/W52 safety files, reject gameplay-method edits and tampered RU/EN instruction text.
- **Isolated W61 CI**: source gate, synthetic tamper regressions, actual Godot 4.4.1 import and native cases, full six-mission exported WebGL Chromium gameplay, original RU/EN browser frames. This is software evidence, **not real phone/GPU certification**.

## C. Commercial design direction (PROPOSAL — not implemented)

**High concept:** You are a last-shift diagnostic operator inside A7, a remote research facility whose containment protocols are failing. Every switch repairs one subsystem but may change the environment elsewhere. Keep the technology fictional; this is an accessible high-stakes **systemic puzzle thriller**, not real equipment instruction.

**Differentiation hypothesis:** decisions under pressure, visible cause and effect, and escalating failure cascades are more compelling than simply adjusting a dial and following the same procedure six times. This must be verified by players; it is **not** a market fact.

### Proposed 12-minute vertical slice (new work, not shipped)

| Segment | Target duration | Observable objective |
|---|---:|---|
| Cold open: A7 responds to first fault | 1.0 min | Understand why the facility is in danger |
| First diagnosis: optics | 3.0 min | Learn camera, lock, tuning and scan |
| Reactor response and new conflicting telemetry | 2.0 min | See a system consequence, not random punishment |
| Escalation: cooling and an incident shift | 4.0 min | Choose a sequence, recover from wrong diagnosis |
| Cinematic resolution, grade and preview of next challenge | 2.0 min | Feel mastery and desire to return |

### Before investing in full production

Run at least 12 blind first-time playtests (target cohort, not performed yet). Measure: start-to-first-safe-action time, completion and abandonment, where players misunderstand safety rules, number of unprompted strategy discoveries, intent to replay, crash rate, stability per device and objective legibility in both languages. Target thresholds **to test**, not achieved facts: at least 10/12 can describe the objective without help, 9/12 complete the slice, 7/12 ask to try another mission.

## D. What remains to become a commercial standout

1. **Product clarity:** story, role, real stakes, understandable win/loss feedback, tension versus frustration.
2. **Gameplay depth:** one exciting repeatable systemic choice, meaningful failures and alternative approaches, controlled difficulty curve.
3. **Distinct art:** environments, animated reactions, UI identity, camera staging, custom assets, lighting, a performant low-end mode.
4. **Sound and performance:** original audio palette, controller/audio mix, 30-minute sessions, native GPU/phone 1% low frame-time results, accessibility.
5. **Production pipeline:** game content architecture, save migration, protected source/build pipeline, reproducible Windows/WebGL packages, rollback rehearsal.
6. **Distribution:** title clearance, original screenshots and trailer, Steam page, real playtest feedback, sustainable budget and marketing funnel.

**Legal naming risk discovered:** the name `Last Frontier` is already used by a game listed on Steam (app/2809380), and `Последний Рубеж` is already a live Russian game at lastfrontier.ru. Do not advertise a cleared brand or ship paid products until legal search and an internationally distinctive final name are approved. The current name is a temporary internal project label.

## E. Non-negotiable acceptance and integration

W61 is a separate review branch from W60, itself a DRAFT stacked on W58. The base game's historical binary output names, source `OSGARD` class identifiers and Playwright DOM selectors remain intentionally stable; **renaming filenames/identifiers blindly would break old saves, manifest validation and CI**. Those can migrate later using explicit byte-level compatibility checks and a verified new release format.

Current release state is **PRODUCTION HOLD**. No master integration, release automation, osgard.world DNS/hosting changes, new hardware claims, AAA certification, or physical industrial hardware control is authorized by these code improvements.
