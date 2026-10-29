# IRON PULSE WORLD — G2 PHYSICAL FIELD PROTOCOLS

Date: 2026-10-29 · stacked directly on verified G0/G1 integration commit `61bebe36c99383e050169a36765d57a6d8e739b0` (CI [#40797100938](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40797100938): full Godot/WebGL/Chromium/portal PASS).

## Why G2 is a real gameplay expansion

The existing game has an authentic first-person 3D corridor, GRID / HEAT / AIR, E/Q repairs, physical power buses and two-of-three rescue relays. G2 adds **two authored, physically reachable field consoles** in distinct map sectors:

| True 3D field location | Real player action | One-time effect | Continuing simulation effect |
|---|---|---|---|
| HEAT SINK / SERVICE SPINE (`-4.2, 1.0, -32.5`) | Walk to console after scanner; press E/USE | 9 simulated seconds, heat −16°C, oxygen −8% (plus natural resource flow during the 9 s) | Heat −0.18°C/s compared with otherwise identical simulation |
| AIR BUFFER / EVACUATION LOCK (`4.2, 1.0, -49.0`) | Walk to console after scanner; press E/USE | 11 simulated seconds, oxygen +16%, heat +7°C, crew −5% (plus natural flow during 11 s) | Oxygen +0.22%/s before cap/other leakage rules |

**Only one protocol can be activated per actual run**, after a genuine scan, before override. Reject invalid commands and attempts to double-activate. Player may also skip both options. No automatic pathing, fake outcomes or real-equipment procedures. Balance values are design rules, not claims about real-world operations.

## Engineering implementation

- `scripts/CrisisEngine.gd`: the same deterministic physics/mission state advances for the costs. `field_protocol` is an optional, validated field in the existing `IRON_PULSE_ENGINE_V6` save; unknown/malformed values are atomically rejected; old saves without the key default to unused.
- `scripts/Main.gd`: real Godot MeshInstance3D/Label3D consoles, actual world positions, proximity-selected E interactions, read-only current player state and physically visible material status changes. No mock HTML interaction.
- `scripts/IPStoryDirector.gd`: fresh original MARA radio lines RU/EN, real engine event source, journal persistence.
- `scripts/IPCampaignFlow.gd`: optional field result in actual campaign record with a small prior-shift heat/oxygen carryover. Existing V9 campaign entries without the key remain valid.
- `scripts/IPAfterActionReview.gd` + `scripts/IPRunArchive.gd`: log the real field decision in mission black box and bounded personal history, validating new field values and retaining old entries.
- `scripts/IPOperatorGuide.gd`: F1 tier-3 contextual hint exposes the optional strategy without operating either console for the player.
- `world/*`: bilingual premium low-noise explanatory panel, no fake numbers/user statistics, no generated hero images.

## Automated acceptance / no shortcuts

- `tests/test_g2_physical_field_protocols.gd`: six source-engine completion branches (3 scenarios × 2 protocols), resource costs, mutual exclusion, all preconditions, persistent simulation effects, corrupt save atomicity, legacy V6/V9/V17 data, actual physical 3D station positions and E action, MARA localization, black box, and campaign carryover.
- `ci/browser_webgl_acceptance.py`: read-only actual exported Godot scene identifies both physically authored terminals at their true coordinates; no pre-scanned or preselected rewards; existing player input and mobile scripts remain mandatory.
- Exact-source native, Windows x64, WebGL, Chromium desktop + touch-emulated, RU/EN portal 320/390px, SHA manifest; strong **NO-GO** if any test fails. Physical device performance, actual human players, AAA art signoff and distribution approval not claimed.

## Honest release status

G2 is a content candidate stacked above a green G0/G1 source line. It is NOT merged into master, is NOT deployed, and is NOT a complete international game. G2 product acceptance still requires three independent full human campaign runs, multiple genuinely observed strategies and measured completion times. Further G3–G9 gates remain open (art/audio rights, hardware, 20 player research, legal/staging and operations).
