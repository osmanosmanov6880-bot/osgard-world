# IRON PULSE WORLD — G0 MAINLINE CONSOLIDATION + G1 GENUINE GAMEPLAY ONBOARDING

Date: 2026-10-29. All referenced claims below are SOURCE HISTORY; this document is NOT a claim that the G0 PR was merged or production launched.

## Current topology / problem solved

- Repository: `osmanosmanov6880-bot/osgard-world`.
- Existing verified V18 game snapshot: `ad2338834313c37d5a15b0c25879e74ec0a35582`, GitHub Actions [#40788969325](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40788969325), full Godot/Windows/WebGL/Chromium PASS.
- Inspected actual `master`: `2c97fd2805e4dc6a9ff3b828ec36fd739e195735`.
- Comparing V18 to master showed **diverged** history: V18 was 365 commits ahead and 134 behind master, against a common ancestor `1fbf16ff6ef97f382ab66afc358ed513c15305cf`. Blindly merging the entire V18 branch into master would import numerous unrelated projects.
- **G0 approach:** create `integration/iron-pulse-world-g0-mainline-20261029` directly from the inspected master SHA. Use Git data tree grafting, not rebase/mass cherry-pick, to transplant the *exact* `iron-pulse-prologue/` V18 tree object `90979b38840c5eace09f8e57e03d75b51ba9e711` and only its exact CI workflow blob `cb5ac673dc4ccdc033607cecf5219bbb42480f88`.
- The first graft commit `f9aa1432be5fe5558b160b8d01318bdd3157e594` is one descendant of the actual master parent. The resulting tree has 53 root entries (master had 52) and 187 workflow files (master had 186). Existing `city-reign-preview-live-integrity.yml`, `deploy-frontend.yml`, `cloudflare-pages.yml` are retained, unchanged.
- A GitHub compare of master and this integration candidate showed **ahead=1, behind=0** immediately after the transplant, with only the IRON PULSE paths added. Subsequent G1 changes must stay within those paths.

This creates a real **candidate to join** the currently active repository mainline. It is not production. Do not merge without human review and green exact-head QA. Do not combine hundreds of unrelated branch commits.

## G1 first-mission accessibility that actually changes gameplay experience

`scripts/IPOperatorGuide.gd` reads the **real** `IPCrisisEngine.objective_id()` and real power/oxygen/heat/crew conditions, not a mock score. Three requested hint levels are available for each real stage:
1. What the player is currently trying to do (SCAN, REPAIR, CHARGE, OVERRIDE, EXIT).
2. Where/how to operate the existing real 3D terminal, how E/Q or power routing works.
3. Genuine costs and prerequisites: HEAT rapid cooling hurts crew/resources; AIR rapid patch leaves a leak; DOOR needs real charge; override requires both COOLANT+LIFE, heat below 85°C and oxygen >=20%.

The hint surface is **opt-in** and never grants a reward, warps the player, creates an artificial event, pauses the timer or alters a game save. Keyboard `F1` reveals the next hint, `ESC` closes; gamepad BACK has an equivalent mapping subject to physical QA. Genuine 51px+ `GUIDE / ?` and `NAV / H` touch buttons are now available on small screens. NAV/H toggles the **existing real 3D wayfinder**, no fake overlay. Original save format `IRON_PULSE_CAMPAIGN_V6` and source session values are unchanged. Real language toggle RU/EN updates the open tutorial.

The read-only browser QA mirror includes the current stage, hint tier, real event count and actual Control rectangles. It is not an API for remote player commands.

## Requirements and acceptance / hard gate

- `tests/test_g1_operator_onboarding.gd`: independently verify GRID, HEAT, AIR stage guidance, 3 hint tiers, no synthetic success, no real game mutation, pause/restart, language, real Godot touch controls and V6/V9 save compatibility.
- Existing **all V1–V18 native tests** must continue passing on the exact integration SHA. New G1 test integrated in `.github/workflows/iron-pulse-blackout-slice.yml`.
- `ci/browser_webgl_acceptance.py` must prove the true Godot canvas responds to keyboard `F1`, ESC, mobile GUIDE / NAV and correctly reports stage data. True WebGL screenshot must not be replaced by generative visuals.
- Windows/WebGL exported from exact head, source-bound SHA manifest verified and actual RU/EN portal at 320/390px passes browser QA. Physical devices are NOT inferred from emulation.
- Additional review before any merge: root CI path isolation, all non-IRON PULSE build systems remain untouched, scenario campaigns playable, no unlicensed media, no manufactured users, real rollback and staged deploy.
- Consolidation verdict is **HOLD** until exact-head CI PASS, repo review and production plan. Even after merge, physical-device, AAA art, player-study, licensing and release gates G2–G8 remain open.

## Next execution after integration G0

1. Stop producing parallel game branches. Preserve one mainline and short isolated PRs for new features.
2. Test the first 90 seconds with real new players; use observed stumbling to improve narrative/wayfinding.
3. Expand the actual authored spaces and dialogue while maintaining scenario differentiation; rights-clear original assets.
4. Benchmark genuine Windows GPU / Android / iOS devices and gamepads, not headless simulation.
5. Complete localization, security, marketing/legal and staged release + rollback, then consider a limited public beta.
6. Approve commercial production only after verifiable objective evidence for all gates.

Master roadmap: `docs/WORLD_RELEASE_MASTER_PLAN_2026.md`.
