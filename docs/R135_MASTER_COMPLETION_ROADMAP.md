# R135 SERVICE LAB — implementation roadmap through independently accepted public release

**Last reviewed:** 2026-10-25. The statuses below refer to actual source or release evidence, not aspirational AAA claims.

## Release baseline: W11 (complete, software-certified)
- [x] Godot 4.4.1 original HERO/ECO 3D rig; moving service machinery, mission and three simulated diagnostics, simulated safety interlock in advanced challenges.
- [x] W11 responsive operator HUD and optical 3D label visibility; original viewport Chromium screenshots and brightness acceptance.
- [x] Independent ZIP + eight-file SHA-256 verification, immutable GitHub Release and known-good W6.4 rollback.
- [x] Protected production SSH release, in-container SHA check, public manifest/WASM/PCK acceptance and 214 public-route regression: [#40161354306](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40161354306).
- [x] Further successful production health watch: [#40162157582](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40162157582).
- [ ] No physical Android/iPhone GPU, thermal, battery or input latency certification. No AAA or 8K claim.

## W12 — prove every diagnostic case (PR #364, in review)
- [x] Implemented real keyboard + Pixel-emulated touch Chromium walkthrough of optical, cooling and interlock faults, each through ordered 5-step gameplay, no direct state injection.
- [x] Reject unsafe open/restart and wrong inspection views, verify active in-world 3D marker inside current camera.
- [x] Save original screenshots and per-device three-case evidence, retain native Godot, W11 brightness, original GLB, signed archive and Nginx range acceptance.
- [x] Implement raw, visible-document requestAnimationFrame interval pacing, slowest 1% callback average, P95/P99 and raw Godot FPS with exact published W11 manifest/source hash and SHA-256 of screenshot; never claim true GPU 1% lows.
- [ ] Full latest-commit W12 native/WebGL/browser candidate SUCCESS.
- [ ] Human inspect every original emitted active-case screenshot and record any captions/controls outside viewport.
- [ ] Merge QA-only PR only after evidence; do NOT change published W11 on a source-only merge.

## W13 — safety-first introductory mission (stacked PR #370, in review)
- [x] Replace unsafe "open hatch then stop drive" novice lesson with stop → open → close → restart.
- [x] Reject opening hatch with running simulated drive in both novice and advanced challenge modes.
- [x] Reject restart before ordered checkpoints and before real simulated hatch movement reaches fully closed.
- [x] Reset simulated hatch target and pose between scenarios. Add native and real Chromium keyboard/touch tests.
- [ ] All latest SHA safety/native/real WebGL QA green; review portrait and desktop pictures before merging.
- [ ] Merge only after W12, and label as source changes until a new game release is actually deployed.

**Critical safety note:** Pausing the *simulated* drive is not physical energy isolation. This game is not a real equipment service procedure. Real work requires authorized equipment-specific lockout/tagout and verification of zero energy.

## W14 — fault-by-fault learner history (PR #386, implemented code; CI pending)
- [x] Actual Godot local-only schema V2 for each of 3 simulated faults: attempt counts, best scores, fastest successful time, cumulative mistakes and persisted completion flags.
- [x] Migrates V1 global best/clear flags without inventing missing per-fault results; malformed numeric arrays are sanitized with deterministic clamps/defaults.
- [x] Completed-case UI now displays its own best score and attempts. Native headless Godot test checks actual save, reload, legacy migration and corrupt entries.
- [ ] Entire W14 native/WebGL/Chromium/Nginx pipeline succeeds on exact latest SHA, original screenshots reviewed, merge only after W12/W13.
- [ ] Interactive onboarding explaining faults, accessible case picker, player-confirmed data reset and retry remain unimplemented. Physical browser reload persistence needs independent user-session evidence.

## W15 — premium visual and accessibility acceptance (not started)
- [ ] Original source material improvements to service rig/stage; maintain original HERO/ECO, dynamic camera and W11 lighting without hiding actions.
- [ ] Viewport matrix desktop 1366x768 / 1920x1080, portrait 360x780 / 390x844, landscape 932x430; screen-safe 3D labels and touch controls.
- [ ] Responsive legibility, scene luminance and reduced-motion/test focus state; unmodified screenshots visually reviewed.
- [ ] Distinguish cinematographic polish from independently verified AAA quality. Avoid unvalidated 8K or GPU claims.

## W16 — performance and actual device evidence (not started)
- [ ] Reproducible cold/warm WebGL load and original JS/WASM/PCK sizes; candidate and public Nginx gzip/range/cache/manifest SHA proof.
- [ ] Physical authorized Android Chrome sessions for ECO/HERO, touch routes, both orientations, raw callback frame intervals, device model/OS and battery/thermal observation method.
- [ ] Independent real iPhone Safari hands-on tests; Android CDP and Chromium/SwiftShader are not substitutes.
- [ ] Agree FPS/pacing/memory and touch acceptance budgets **before** testing, publish raw data and confidence bounds, record failures honestly.

## W17 — international educational product (not started)
- [ ] Correct contextual RU/EN learning content, readable type, simulation-only/real-equipment isolation warning, keyboard and touch instructions.
- [ ] Accessible feedback, proper audio rights, mute/reduced-motion compatibility and transparent user privacy.
- [ ] Independent product-user sessions: time to first successful diagnosis, failure understanding, per-case completion and 7-day return before marketing world-class claims.

## W18 — separately verified next playable production game release (not started)
- [ ] Build a new version with correct W13+ gameplay SHA, no re-use of W11 version string or binary while claiming a new product.
- [ ] Produce immutable Release ZIP + release.json with exact reviewed source SHA and each file SHA; re-download and reverify originals.
- [ ] Godot native, actual Chromium desktop/Pixel 3-case gameplay, screenshot luminance/label/controls, Nginx WASM compression/PCK HTTP 206 and all frontend/security regression checks green.
- [ ] Preserve immutable W11 as known-good rollback, stage via atomic SSH with source/version/manifest SHA check *inside active Nginx before commit* and public same-origin API/game smoke; auto-rollback on failure.
- [ ] Record exact live release source + run URL and distinguish software release acceptance from the separate physical-device gate.

## Non-negotiable rules
No unverified feature claims, no secret SSH credentials in docs, no CI-bypass merge, no fake phone FPS, no textual screenshots substituted for working game mechanics. Each block closes only with actual source, executable tests and cited release evidence. Work on R135 must not disrupt neighboring OSGARD games.
