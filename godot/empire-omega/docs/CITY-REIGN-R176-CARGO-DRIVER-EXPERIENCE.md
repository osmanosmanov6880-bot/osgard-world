# CITY REIGN R176 — REAL FREIGHT COCKPIT / 3D CARGO

**Parent:** R175 playable economic city source; R174 is last independently verified green predecessor at time of initial R176 authoring.
**Purpose:** make ACTUAL existing freight condition and physical odometer progress immediately understandable in a premium real 3D car while retaining original GameState/ContractManager settlement authority.

## 1. Original cargo sculpture, same three source physical crates
Original \`cargo_visual.gd\` now reuses ONE authored closed 3D case mesh for all three original crates. The shared mesh has real source-machined corner caps, straps, vertex normals and source color in a 0.72×0.48×0.85m envelope. All three original mesh nodes and local positions stay. LOW swaps the very same nodes back to the original simple BoxMesh; no new collision, physics mass, remote media, money or inventories.

## 2. Genuine physical trip telemetry
\`city_reign_freight_telemetry.gd\` is a strictly read-only projection of \`CargoLogistics.completion_fraction()\`, \`CargoLogistics.ready()\` and validated saved \`cargo_progress\`. Existing genuine odometer meters / required meters and cargo condition have accurate RU/EN/ZH labels. New native progress-frame and fill are actual MeshInstance3D inside the ORIGINAL car, not canvas mockups. Premium display is two lines, LOW is a short source-condition string. Zero per-frame mesh allocation. Telemetry does not grant delivery, success, currency, XP or new contracts.

## 3. Original gameplay compatibility
The actual original \`ContractManager.interact\` still accepts, rejects and pays solely through \`GameState\`. A driver must meet original same-car, speed, true traveled distance, correct destination requirements; the new bar merely shows real physical progress. Legacy cargo remains governed by unchanged old-save compatibility, and corrupt/incomplete cargo progress displays no fake completion. No new saves, mission milestones, contracts or economy fields. Existing original game Main._apply_visual_budget now calls this visual module's shared source LOD.

## Original real-source QA
- v177 = pure authoritative cargo route/quality/legacy/corrupt, true 3D model normals and source envelope
- v178 = real native CargoVisual 6-node GPU and LOW/CINEMATIC source assets plus read-only state
- v179 = original main Godot scene; genuine active ContractManager pickup, actual car attachment, source-required odometer, real payout refusal, original 12 vehicles + 34 citizens.
- Inherited R175–R169 native and full original WebGL2 Chromium, three real camera / drive scenarios and exact source-SHA verification.
- Draft HOLD until independent CI success and human/device QA. Does not claim native physical phone FPS or commercial AAA fidelity.
