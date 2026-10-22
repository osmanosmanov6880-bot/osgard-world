# ZION-030 v32 — Civic Landmark Architecture & Vehicle Atelier

## Scope and intent
This adds modeled, instanced objects directly to the playable Three.js city. These are not prerendered images or Unreal Engine assets. The v26 cooling puzzle, v28-v31 contracts, vehicle physics, and saved progress remain authoritative and unchanged.

## Landmark architecture
Six spatially separated occupied rooftops receive different recognizable prefabs:

1. **Civic observatory:** circular stone podium, windowed glass dome, radial metal ribs and antenna.
2. **Rooftop greenhouse:** volumetric glazing, architectural ribs, planting benches and terraces.
3. **Athenian column hall:** five modeled cylindrical columns, capitals, a stepped podium and triangular roof.
4. **Solar observation lab:** angled solar arrays, supporting pylons and storage enclosure.
5. **Clock-and-signal tower:** stone shaft, metallic circular clock frames and a beacon.
6. **Cooling turbine pavilion:** raised industrial fans, circular ducts, protective rail and indicator lights.

Their rooftop cells and exact heights come from the authoritative game grid. New meshes do not alter collisions or block access to the mission hotspots.

## Additional high-detail families
- **Facades and rooftops:** stone cornices, edge coping, real downpipes, solar support frames, rooftop HVAC housings, garden planters and flowering foliage.
- **City furniture:** street-light housings and lens geometry, solar shade tops, drainage grates, low benches and planted traffic islands.
- **City Runner EV:** bumper, lamp enclosures, sculptural windscreen trim, colored body fittings, actual cylinder-shaped wheel rims and a dozen tire-tread features per wheel, batched by material rather than emitted as individual GPU draw calls.
- **Player outfit:** attached safety/equipment accents, small metal fasteners and footwear geometry on the walking avatar.

## Performance design
- Three deterministic tiers: ULTRA desktop, MOBILE and LITE software WebGL/reduced-motion.
- Shared Three.js primitive geometries and shared materials. World objects are GPU-instanced by material/shape and split into base/high detail layers.
- Vehicle trim uses instanced per-car material batches. Fine trim is disabled in ECO mode.
- Geometry counts and draw-call batches are asserted in the unit test, but those metrics must **not** be misrepresented as a measured FPS benchmark.
- Night light emissive levels and rain visibility are driven by the game's existing time/weather controls.

## Acceptance / release gates
- `scripts/zion-open-city-v32-smoke.mjs`: authentic rules grid, six hero roof structures, nonzero detailed street props, valid instance transforms, three performance tiers, rain/ECO behavior, and car/avatar attachment.
- `scripts/zion-v32-browser.spec.mjs`: actual running Chromium game on desktop and phone, entry/exit, texture/scene state, original cooling puzzle, rain/night toggles, and screenshot evidence.
- The original v26-v31 gameplay regression tests remain enabled.
- `scripts/zion-030-live-assets.mjs` compares **ten** production HTTPS assets byte-for-byte with the GitHub release after SSH activation.

**Release is not accepted until both required CI and actual SSH/HTTPS verification succeed.** Procedural stylized geometry is not equivalent to photogrammetric AAA art or a native Unreal production build.
