# NEBULA R19 — Local GPU clusters and real practical-light budget

R19 is a performance optimization of the existing real Godot project, not a
replacement demo. Mission logic, the ten-mission Helios storyline, combat,
the player's ship, missiles, escorts, credit purchases and saved data remain
unchanged. No Stripe configuration or payment processing is modified.

## Previous bottlenecks in R18

- The remaining `premium_architecture.gd` facade fins (1440 instances)
  and luxury roof terraces (360 instances) each occupied one **world-spanning**
  MultiMesh, even though the core 360 skyscrapers were already sharded in R18.
- `orbital_industry_r9.gd` used eight independent but **world-spanning**
  industrial MultiMesh groups: 24 pressure vessels plus collars, pipes,
  ladders, handrails, indicator panels and safety machinery.
- Twelve real industrial work lights were receiving changing energy values
  every frame irrespective of proximity to the player. All twelve mechanical
  loader booms were also animated globally at display FPS.

## Implemented in R19

1. **Premium architecture (1,800 original instances):** six 240-fin
   and six 60-roof GPU clusters in locally translated district coordinates.
   Collision and color/size of each tower remain unchanged. The historical
   `PremiumFacadeFins` and `LuxuryRoofTerraces` scene paths are retained
   as parent nodes so old references can still find the group.
2. **Industrial R9:** eight original world-wide categories now render as
   48 sector-local GPU clusters. No geometry is removed and the original
   scene group names remain. The tank collision bodies are untouched.
3. **Light budget:** all 12 original no-shadow OmniLights remain available,
   but only lights within 480 metres of the ship are switched on; ECO
   suppresses those practical lights entirely. The visibility checks run
   about three times per second, not every rendered frame.
4. **Loader movement:** only booms within 480 metres animate.
5. **Graphics control:** existing F3 MAX/HIGH/ECO, plus F11 measured automatic
   adaptation, adjusts facade, roof and industry LOD as one system.

| Visible microgeometry | MAX | HIGH | ECO |
| --- | ---: | ---: | ---: |
| Premium facade fins | 1180 m | 820 m | 460 m |
| Roof mechanical terraces | 1550 m | 1100 m | 600 m |
| Industrial silos & detail | 1020 m | 690 m | 420 m |
| Practical industrial OmniLights | 480 m | 480 m | none |

**Important:** These are Godot visibility settings with fade margins, not
real hardware measurements. Some objects have wide GPU group bounds, so
actual visible distances also depend on geometry and camera position.

## Native acceptance

- 1,440 facade fins and 360 roof instances survive exactly: six GPU
  subbatches of 240/60 each, physically localized.
- The original 24 R9 pressure tanks and 8 global industrial groups remain:
  48 GPU subbatches, all total original instances preserved.
- At the original Aurora spawn, only **2 of 12** practical industrial lights
  are enabled; all 12 are disabled by ECO.
- F3 ECO shortens all R19 ranges, F3 MAX restores them.
- The complete R16–R18 runtime smoke, Godot 4.7.2 import, WebAssembly export
  and isolated rollback-capable SSH deployment must pass before release.

## Physical GPU acceptance

Open `https://osgard.world/games/remix/arena-v2/nebula-3d/?r19=1`
and use Ctrl+Shift+R. Fly Aurora -> Neon District -> Citadel along the
same path and profile as R18.

- F6 — live FPS/draw calls.
- F7 — benchmark (warm-up and 20-second real frame samples).
- F9 — JSON with actual performance results.
- F10 — real screenshot PNG for comparing graphics.
- F3 — MAX/HIGH/ECO. F11 — automatic quality.

A lower rendered geometry workload is expected, **but R19 has no real-device
FPS result or confirmed photorealistic AAA screenshot**. Chromium
SwiftShader hosted canvas capture remains unreliable: its last R18 visual
run failed; a native Godot smoke test is not a substitute for that test.
