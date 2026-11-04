# NEBULA R43 — real failure, hangar repair and mission retry

**Status:** R43 merged, built, released, and public HTTPS exact-byte parity verified on 2026-11-04; physical phone acceptance pending. **Date:** 2026-11-04.

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

- [x] Godot native scene parse and test — CI #41851169153
- [x] WebAssembly browser control/flight — PR CI #41849503005
- [x] Mobile touch emulation, including sortie controls — PR CI #41849503005
- [x] Preservation of local v1 schema and unchanged server-paid entitlement logic — covered by native smoke and commerce CI; no actual paid-user migration was run
- [x] Safe staging/production exact-byte promotion — deployment #41851783164 (second attempt) and public check #41852899805
- [ ] Human Android/iPhone device test — NOT PERFORMED

**Not implemented:** realistic crash animation and explosion debris, salvage persistence, differentiated boss mechanics, chapter 11+. These remain separate development work.

## Canonical production release notes
See [R43-OWNER-RELEASE-20261104.md](R43-OWNER-RELEASE-20261104.md) for source SHA, exact asset identities, failed first SSH attempt, successful second activation and independently verified public HTTPS R43 evidence. The 7-second respawn enemy-fire grace period and re-launched actual Godot Button emulation are included in this release.
