# NEBULA R42 — Captains with real gameplay consequences

Date: 2026-11-04. Scope: Godot 4.7.2 command-hub improvement; **candidate, not evidence of production deployment**.

## User-facing changes

The first screen includes three individually selectable commanders inside the Russian garage. Each character has an explicit role and bonus. All are free and immediately available:

| Commander | Role | Effect applied |
|---|---|---|
| Ada Vale | Tactician | Incoming damage ×0.90, shields and collision damage included |
| Kai Ren | Ace | Acceleration ×1.08; the existing speed cap is unchanged |
| Leya Knox | Engineer | +12% credits on a **successfully completed** mission; no bonus for an unfinished flight |

Buttons have 44+ px touch targets and a selected state; input remains locked until the sortie button is pressed. This does not add a fake 3D portrait or falsely claim a player rank.

## Implementation

- `scripts/captain_roster_r42.gd`: allowlisted commander IDs, deterministic effects and reward function.
- `scripts/garage_hub_r39.gd`: 3 real Godot Button signals, dynamic selected state and perk descriptions.
- `scripts/ship.gd`: bounded damage/thrust multipliers used by existing physics and actual damage calculations, default 1.0.
- `scripts/world.gd`: commander selection only in garage; applies perk when leaving garage, adds earned mission credit bonus after success, persists optional `captain_r42` in v1 save.
- `tests/runtime_smoke.gd`: assertions for UI signal, invalid commander rejection, real flight perk, deterministic bonus and saved selection.

## Save / monetization safety

- Existing save version remains 1 and all existing fields are preserved. When `captain_r42` is absent, default to Ada. Unknown IDs fail closed to Ada.
- No command-side writes or changes to verified Stripe entitlements.
- Commander bonuses have no real-money purchase requirement.
- R39/R41 physical-device evidence remains **NOT PERFORMED**. All browser-touch tests are emulation until manually checked.

## Release gate

- [ ] Godot parse/import + native runtime smoke green
- [ ] Real browser WebAssembly flight and mobile emulation green
- [ ] Exact Web export built from verified source with four SHA pins
- [ ] Explicit owner-directed release policy + rollback + health check
- [ ] Actual hardware Android/iPhone QA as separate evidence
