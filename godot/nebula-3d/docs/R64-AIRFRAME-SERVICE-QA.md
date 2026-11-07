# NEBULA R64 — five real airframe systems, engine thermals & service

**DRAFT SOURCE — not public.** R63 source is already merged in GitHub and has its own protected release PR #775. The previous independently verified public game is R62 via [HTTPS 4/4 #42325861667](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42325861667).

## Five complete implementation blocks

1. **Real hull-to-service degradation.** New deterministic `airframe_service_r64.gd` owns independent condition for NX-08, NX-12 and NX-21. It validates save inputs, rejects unknown ships/components, and converts only real shield-penetrating hull damage into controlled engine, steering and armor wear. Cosmetic hits on a shield and garage damage cannot accrue service debt. It never edits credits or premium entitlements.
2. **Real flight physics penalties.** `ship.gd` emits a real `hull_penetration_r64` signal only after the actual physics/damage routine loses hull. Engine condition changes true forward acceleration, steering wear changes yaw/pitch response, and plating weakness increases only hull-penetrating damage. Limits prevent completely immobilizing a pilot.
3. **Real afterburner thermal loop.** Boost builds engine heat; at 100% a real hysteresis lock disables afterburner until cooled below 38%. Cooling works in normal flight and while docked. Normal thrust still works; no artificial input or duplicate boost toggles.
4. **Paid maintenance for each owned aircraft.** Workshop has three genuine Russian CR repair controls, bound to real condition and a deterministic quote. One click repairs one component and debits CR once; no insufficient-funds/hidden-shop/double-click exploit. Local save version 1 is backward-compatible; per-airframe state survives restarts, and previously saved fleet/pilot/mission/premium state remains intact.
5. **True 3D diagnostics and accessible live HUD.** Six actual MeshInstance3D bezels/lenses show green/amber/red engine, steering and plating status on the real flight aircraft and its isolated hangar model, updated without rebuilding per frame. The original responsive flight HUD now displays real service percentage and heat on desktop/phone, not a fabricated screenshot. Compact 320/390px retains a single line rather than adding touch-blocking overlays.

## Native and browser acceptance gates

- Godot 4.7.2 native runtime smoke **must** emit `NEBULA_R64_FIVE_REAL_SYSTEMS_WEAR_PHYSICS_HEAT_PAID_SERVICE_3D_SAVE_SUCCESS`. Tests verify actual hull hit, zero wallet/XP mint, no garage wear, true 3D models, single exact service debit, insufficient funds, hidden-shop guard, save/reload across purchased craft, and heat lock/cooldown.
- Real WebAssembly Chromium keyboard flight, cruise, collision, 390×844 touch and frontend/launcher readiness must pass on exact source HEAD, without bypassing safety checks.
- This R64 PR does not merge/ship until 5/5 source CI. Then a separate **post-merge native Godot export**, protected exact four-blob provenance/release PR, rollback-safe SSH and independent 4/4 public HTTPS match are mandatory.
- Physical Android and iPhone hardware QA: **NOT_PERFORMED**; hosted SwiftShader is not physical GPU, AAA/8K graphics or measured FPS certification.
