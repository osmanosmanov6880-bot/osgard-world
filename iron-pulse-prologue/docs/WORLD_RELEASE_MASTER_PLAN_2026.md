# IRON PULSE WORLD — MASTER PLAN TO INTERNATIONAL RELEASE
Version: planning baseline 2026-10-29 · Source: GitHub V17 exact SHA `2ef1686a79324184a7d82e2f06e72dcd300ecf6a` · V17 CI PASS #40777590228.

## The actual product and the finish line

**Product:** a polished, original single-player 3D emergency-action/puzzle game in the fictional A7 reactor environment, with a credible RU/EN website, Windows distribution and supported web play. *Global* means verifiably playable, legally distributable and supported in chosen regions, **not** that it has world-scale users or AAA graphics already. A social/metaverse platform, multiplayer, real equipment interface, fake esports/leaderboard, or banking backend are **outside this release**.

**Definition of Done (launch):** tagged reproducible release from a consolidated mainline; all CI and device matrices pass; no severity-1/2 security or crash defects; 3 original operations with stable replayability; independently approved visual/UX/accessibility quality; rights-cleared content and legal/privacy materials; staged production build on the agreed public domain; reversible deployment and monitoring; a small real tester cohort has completed the full campaign; actual adoption is reported separately from demo metrics.

**Proven today:** previous V17 draft [PR #664](https://github.com/osmanosmanov6880-bot/osgard-world/pull/664) and exact-head CI [#40777590228](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40777590228) completed successfully (Godot/Windows/WebGL, browser touch emulation, local 16-record archive). **Not proven:** physical phone/GPU FPS, certification, pricing, global audience, licensing, 20-player playtest, actual public V17 deployment. V17, V16 etc. remain unmerged draft PRs; staging is not production.

## BLOCK 0 — Unify the code lineage, protect the source of truth

**Work:** treat V17 verified SHA as the continuation base; make V18 a short-lived single PR; audit dependencies from older PRs and produce a safe consolidation/merge order rather than leaving many incompatible parallel masters. Ensure no hidden fixture ships as player data, no stale preview links, no duplicate features across branches. CI must use exact commit SHA, deterministic Godot 4.4.1 and pinned browser versions.

**Gate G0:** merge plan reviewed, every change traceable, no conflicts, full V1–V18 baseline rerun on final mainline, save migration V6/V9 verified with genuine old snapshots. **HOLD:** do not auto-merge draft PRs if older branch history diverges.

## BLOCK 1 — Product gameplay / first 15 minutes

**Work:** make the first encounter clear within 90 seconds: readable mission objective, active 3D scanner, consequences of the two power buses, real first-success and failure feedback. Keep GRID/HEAT/AIR **mechanically distinct** and a three-act campaign whose choices matter. Make training contextual and optional, not a pass-button or simulated victory. Retain existing V15 true engine forecast, V16 black box, V17 personal records.

**Gate G1:** new players in an observed study can identify the next objective without staff intervention; all three original scenario rules and endings pass CI; no soft locks; every completed run writes a truthful local record; failures cannot grant victory or progress.

## BLOCK 2 — Depth, worldbuilding and replay value

**Work:** add *authored* places, varied tasks, original character dialogue and high-stakes resource decisions (not more menu cards). Build an environmental storytelling bible: reactor, service spine, evacuation lock, signed visual language, readable dangers and clear wayfinding. Plan alternative solutions that remain physically reachable, with recorded consequences. Avoid claiming "100 hours" before measuring.

**Gate G2:** all chapters beatable with at least two player-tested strategic approaches; at least three independent full-campaign runs with no dead ends or lost progress; average completion time measured from actual sessions. Add content only after players find the core loop meaningful.

## BLOCK 3 — Visual and audio AAA-quality acceptance

**Work:** direction = OBSIDIAN INDUSTRIAL / BLACK TITANIUM: dark metal and restrained cyan/amber/red hazard signaling. Replace placeholder geometry deliberately with original, rights-cleared PBR assets, polished lighting, physically plausible layouts, camera/animation/sound mixing, accessibility contrasts. Use side-by-side **real in-engine captures** at locked camera positions; no AI hero image or Porsche picture pretending to be gameplay.

**Gate G3:** independent art review passes material consistency, geometry/readability, control legibility, frame pacing and audio. All relevant licenses and attributions documented. "AAA" remains an aspirational quality bar until independent review.

## BLOCK 4 — Cross-device controls, comfort and measured performance

**Work:** extend V12 true local frame timing with V18 opt-in, reversible AUTO graphics policy; preserve G manual HERO/ECO, no baked-in FPS claims. Add accessibility for 320px small screens, touch targets >=44 CSS px, gamepad mapping, mouse capture/release, reduced motion, scalable text, sound mute. Build an *actual physical-device* matrix: Windows low/mid/high GPU, at least three Android classes, iPhone Safari/browser WebGL, keyboard/mouse/controller. Browser emulation is NOT device certification.

**Gate G4:** real 30-minute capture per supported physical target; documented median, 95th percentile frame time, hangs, temperature/battery where permissible; no gameplay correctness regression under ECO/HERO/AUTO; no crash or unresponsive touch control. Targets to be chosen per device tier and benchmarked, not fabricated. Do not advertise platform support for untested devices.

## BLOCK 5 — Reliable release engineering and data privacy

**Work:** local saves remain offline by default; check old V6/V9 save import, atomic write, corrupt-data protection, explicit delete, privacy disclosure. Code-sign production Windows artifacts after ownership and certificates exist; never call a SHA manifest a vendor signature. Add release provenance, dependency audit, secret scanning, reproducible pipeline and independent snapshot backups. The site shell can cache modest assets; **do not** claim giant Godot WebGL binaries work fully offline unless actually tested.

**Gate G5:** public release build reproducible from tagged source; security/privacy review and restore/rollback tests pass; no unprotected secrets, tracking without consent, invented cloud services or invisible file deletion.

## BLOCK 6 — International interface and accessibility

**Work:** keep RU/EN source-consistent now; add target locales only after translation budget and native-language review (candidate ES/DE/PT depending real demand). Externalize every display string including input hints, accessibility labels, gamepad prompts, error states and licensing copy. Test text overflow on desktop, 320/390px web and genuine devices. Ensure keyboard-only access to pause, records, forecast and debrief.

**Gate G6:** no unlocalized critical objective or clipped operation button; genuine human/qualified review on each launched language; rights-cleared font support and browser/OS fallback.

## BLOCK 7 — Human playtesting and honest economics

**Work:** independently recruit at least 20 consented testers across skill levels and supported devices; observe full campaigns and intro runs. Record completion rates, stuck points, bugs, comfort issues and optional feedback without covert analytics. Validate why people would pay; do not invent store ratings, buyers, retention or wishlists. Try a small public demo/limited beta before committing to full market spend.

**Gate G7:** predeclared product thresholds based on observed feedback; no critical blockers; enough real evidence to decide GO/PIVOT/HOLD. Measure results with date, sample size and uncertainty.

## BLOCK 8 — Distribution, marketing, legal and launch

**Work:** pick channels after requirements review (direct web, itch.io, Steam/Windows as feasible). Secure brand/domain/trademark screening, original asset/music licensing, accessibility and age-rating requirements, terms/privacy/refund/support workflows, tax/merchant arrangements. Build concise genuine gameplay trailer from captured build; publish PC and web only for verified supported targets. Stage under separate URL and use atomic upload with checksums, link checks and rollback.

**Gate G8:** production release approval by owner, platform and legal checks completed, staged smoke tests on real devices, signed/tagged source and rollback rehearsed, real purchase/support flow tested where applicable. Publish only after GO.

## BLOCK 9 — Post-launch product operations / next 90 days

**Work:** daily check of real crash/error signals and voluntarily reported user issues, triage by severity, hotfix protocol, compatibility updates, clear patch notes and user support. Keep player saves safe. Measure honest traffic and conversion only after lawful analytics consent; distribute translated versions only after human checks. Do not add multiplayer/cloud/accounts until evidence shows they are worth ongoing costs and security obligations.

**Gate G9:** stable releases and incident response, actual users serviced, data retention documented, operational costs understood; roadmap updated from observed behavior rather than popularity claims.

## Release sequence, ownership, dependencies

| Phase | Prerequisite | Owner role | Accept/reject evidence |
|---|---|---|---|
| G0 codebase | verified V17 + V18 PR | Lead developer | Exact SHA, clean merge, backward save QA |
| G1 core | consolidated build | Game designer + QA | Player task runs, three scenarios |
| G2 content | G1 approved | Level/story designer | Independent full runs, alternate solutions |
| G3 visual | G2 representative world | Art/audio lead | In-engine captures, asset licenses, art signoff |
| G4 device | baseline art/assets frozen | Engine/perf + device QA | Genuine physical device table and metrics |
| G5 security | near-final binaries | Release/security owner | Backup/restore, provenance, privacy review |
| G6 translation | stable strings | Localization/accessibility QA | Human-reviewed languages, device UI |
| G7 beta | G1–G6 substantial pass | Research/producer | 20+ real players, documented decisions |
| G8 launch | all blocking gates passed | Product/release owner | Staging, rollback, distro/legal approval |
| G9 operations | G8 live | Support/engineering | Incident and support history |

**Critical path:** code consolidation → engaging, winnable game → substantial authored world → performance on real devices → rights/legal + player feedback → staging → limited release → broader availability. Visual polish and real device QA will require people/hardware/asset resources; automatic CI cannot substitute.

## Concrete next engineering batch (V18)

1. Real opt-in frame-pacing AUTO controller over existing HERO/ECO, with hysteresis, no fake FPS, an explicit K shortcut and pause-menu touch button.
2. Keep manual G behavior and existing save schema. Display local p95 + current mode in native HUD, make diagnostics and Chromium QA read-only.
3. Native scenario tests for slowdown, recovery, pause, malformed frame samples, manual overrides and source-engine immutability; real WebGL keyboard and pause-screen touch verification.
4. Verify exact-head Windows/WebGL builds, tests and screenshots; keep PR draft/PRODUCTION HOLD until full green CI.

## Hard NO-GO

Any of: broken old saves, impossible campaign state, unverified downloaded build, failing CI, fake business/player numbers, unresolved rights, unsafe data erasure, broken touch on supported phones, unacceptable measured frame stability, missing rollback plan, or significant unresolved playtest confusion. A compiler PASS alone does not clear any of these.

**Conservative current verdict:** V17 = technically verified preview; global commercial release = NOT YET APPROVED. V18 must improve the code and evidence, not relabel the product as finished.
