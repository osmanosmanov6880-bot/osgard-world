# NEBULA R43 — real failure, hangar repair and mission retry

**Status:** source candidate stacked on R42; never confuse a PR with a production release. **Date:** 2026-11-04.

## Player-facing flow

1. Pilot launches a real mission from Aurora garage.
2. Hull is damaged by enemy fire or collision. At zero hull, the current sortie fails; ship is not silently teleported back into the same battle.
3. Engine clears active mission targets (not ambient civilian traffic), stops autopilot and weapons, returns the player to a collision-checked safe Aurora launch point and restores hull/shield/boost.
4. Garage explains **ВЫЛЕТ НЕ УДАЛСЯ** and displays a retry of the **same mission**. No campaign XP or mission completion reward is granted.
5. On restart, the mission spawns from scratch. A successful completion still opens the next mission normally.

### Economy and exploit resistance

- Combat drones tied to a mission grant provisional kill bounties (45 CR per enemy) only after that mission is successfully completed.
- Crashing resets provisional earnings, so repeatedly destroying enemies and intentionally crashing cannot farm credits.
- Other ambient encounters retain their prior reward behavior.
- Existing credits, unlocks, paid assets, commander selection and saved mission index remain intact; failed sorties do not impose the old automatic 220 CR penalty.
- The optional `r41_last_debrief.status` records `success` or `failed`, maintaining v1 save backward compatibility.

## Actual code

- `godot/nebula-3d/scripts/world.gd`: explicit failure outcome, mission-only cleanup, bounded repair, banked-on-success mission bounty.
- `godot/nebula-3d/scripts/garage_hub_r39.gd`: failure report and retry message.
- `godot/nebula-3d/tests/runtime_smoke.gd`: actual `ship.take_damage(10000)`, zero progress/credits upon failed sortie, escrow handling, repaired hull, saved failure status, and retry.

## Acceptance gates

- [ ] Godot native scene parse and test
- [ ] WebAssembly browser control/flight
- [ ] Mobile touch emulation, including sortie controls
- [ ] Preservation of all local and server-paid entitlements
- [ ] Safe staging/production exact-byte promotion
- [ ] Human Android/iPhone device test not yet performed

**Not implemented:** realistic crash animation and explosion debris, salvage persistence, differentiated boss mechanics, chapter 11+. These remain separate development work.
