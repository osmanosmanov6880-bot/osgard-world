# NEBULA R22 — AURORA GOLDEN HOUR / REAL GODOT GAME WORLD

**This is a real gameplay release, not an image or static backdrop.**

User-selected visual target: the second screenshot showing orange sunlight,
deep urban density, varied window illumination, atmospheric cloud decks,
suspended roads, flying civilian traffic, machined engine thrusters and the
existing premium Russian HUD. The target is **a reference**, not a claim that
Godot's WebGL compatibility renderer equals offline photoreal rendering.

## Implemented directly in playable source

### Dense 3D skyline, not an invented image

`scripts/aurora_scenic_r22.gd` creates:
- **18 original multi-part architectural towers** along the first Aurora
  flight approach, with darker steel cores, metallic setbacks, deep edges,
  roof machinery, metal rails and a distinct silhouette. The original
  **360 city skyscrapers remain**; nothing was deleted.
- More than **2,000 separate window instances**, divided across dark glass,
  warm occupied windows and cyan-lit windows. Real 3D instancing and
  dedicated material properties—not a rendered wallpaper.
- **18 StaticBody3D building colliders**; the model geometry isn't fake.
- **3 physical overhead skybridges** with modeled rails and lane beacons
  plus collision shapes. They are above the initial ship corridor.
- **16 moving non-combat city spacecraft** with real meshes, body, wings
  and navigation lights. Updates use a 20 Hz budget and skip distant craft.
- **4 actual cloud-bank mesh ribbons** at low altitude with restrained
  transparent materials. They are geometry, *not* photo-textured clouds or
  a full volumetric simulation.

### Lighting and cinematic visual quality

- `cinematic_lighting_r12.gd` now defaults to a **golden-hour sun**:
  warmer low-angle key light, deep-blue upper sky, orange cloud-height
  horizon, warm fog and cool fill lighting, with carefully limited bloom.
  F12 still toggles a second cooler look.
- Rooftop caps use less artificial cyan emission. PBR metal has more
  realistic roughness; imported 384px/512px maps stay intact.
- On the existing genuine **NX-08 glTF hull**, R22 adds **9 detailed
  machined nozzle elements**, **6 tapered transparent physical flame meshes**
  and a single non-shadow engine fill light. Exhaust geometry responds to
  real ship throttle/velocity. Original cannon/wing meshes remain.

### Input and playable first flight

- The production HTML canvas receives explicit keyboard focus after
  opening/loading, tapping/clicking the WebGL canvas or returning to tab.
  Prior versions set `tabindex` but did not actually focus the canvas,
  which could explain why W/A/S/D appeared not to work.
- The first **non-combat** beacon mission no longer takes pirate damage,
  letting players learn flying before hostile encounters begin. From the
  next mission, normal enemy damage resumes.
- The R21 real-physics movement, player spawn collision rescue, camera
  collision check and multi-finger mobile controls remain active.

### GPU budgets and mobile quality

- F3/F11 MAX, HIGH and ECO control new urban microgeometry, civilian
  traffic and cloud ranges.
- ECO hides animated civilian traffic and reduces cloud rendering range.
- No unsupported Lumen/Nanite/RTGI promise; WebGL Compatibility remains the
  target. We explicitly do not equate procedural Godot geometry to an
  actual AAA asset library.

## Independent verification

The native Godot runtime smoke verifies:
- Exactly **18** new structural towers, **3** bridges, **21 physical
  building/road solids**, **16** moving craft and **4** cloud meshes.
- More than 2,000 instanced 3D windows.
- Physical collisions, actual movement of the air traffic, 9 engine nozzle
  details, 6 ion plumes, and an actual engine OmniLight3D.
- Warm sunset atmosphere is loaded and material quality responds to ECO/MAX.
- The prior real 37-physics-frame ship flight, 3-finger multitouch,
  R15 commerce gates, R16 guided rockets, R17/R20 baked original PBR
  textures, R18/R19 city batching, missions and saved progress still pass.
- CI verifies patched output HTML contains `nebula-r22-keyboard-focus`.

CI main-branch WebAssembly export + checksum verified production SSH/Nginx
must pass before saying it is deployed. Native CI is **not** a real GPU
FPS benchmark. Physical browser screenshots (F10), JSON (F9), performance
test (F7) and inspection of fidelity against the image are the next
acceptance steps.

No Stripe changes. No real payments enabled.
