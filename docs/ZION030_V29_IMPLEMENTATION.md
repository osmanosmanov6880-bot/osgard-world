# ZION-030 v29 | CINEMATIC CITY | Five development waves

## Scope and status

This branch develops the **existing** ZION-030 WebGL game in the OSGARD World repository. It does not replace the v26 city-cooling puzzle, does not claim a native Unreal Engine export, and does not claim GTA-scale asset fidelity. The goal is an expanded, testable, mobile-friendly vertical slice with a more complete adventure loop.

### Wave 1: responsive on-foot controls
- `walkStep` uses acceleration, inertial slowdown, axis-separated swept collision, stamina and gravity-based jumping.
- Walk/run animation now responds to speed, and keyboard/onscreen Jump use the same gameplay path.
- Camera modes: cinematic chase, shoulder and first-person; follow camera avoids original collision volumes.
- New V, Space and touch controls, with preserved WASD/Shift/E/F bindings.

### Wave 2: driving and physical world rules
- Electric vehicle now has actual charge depletion, braking regeneration and three physical charging locations.
- Garage supports speed, wet-road grip and energy-efficiency upgrades; each has a distinct rules effect.
- Rain modifies steering and acceleration; vehicles detect ambient traffic conflicts rather than simply ghosting through.
- Battery and stamina are visible in the HUD. Single-player credits come from in-game tasks only.

### Wave 3: five scripted dispatch missions
- Five selectable quests across the existing district, each with at least two ordered checkpoints.
- One mission is car-only with parking requirements; others require the player to exit the vehicle.
- GPS can select the cooling story, city contracts, or currently selected dispatch assignment.
- Dispatch progress, reputation, garage upgrades and rewards are persisted to the same local v28 profile key using a backward-compatible v2 schema.
- Completing steps out of range, in the wrong mode, at nonzero parking speed or after finishing a mission awards nothing.

### Wave 4: denser environmental storytelling
- Instanced meshes add streetlights, benches, trees and charging kiosks without creating hundreds of draw calls.
- 3D district signage and live dispatch markers distinguish the urban areas and quest destinations.
- District arrival announcements and a simple radio dialogue panel explain where the player is and why the objective matters.
- Existing climate hotspots, traffic, navigation and buildings remain present and authoritative.

### Wave 5: premium UX, responsive support and QA
- Mission journal, accessible focusable controls, a pause menu, mini-map focus mode, career HUD and an upgrade garage.
- Dedicated layouts for desktop/mobile and reduced-motion users with a legible dark palette.
- Deterministic v29 rules tests: profile upgrade from v28, waypoint reachability, earned-credit caps, mission idempotence, physics and charge behavior.
- Chromium user scenarios for both device classes, plus existing v25/v28 regression contracts.

## Important product boundaries

- Gameplay statistics and environmental temperatures are **simulations**, not meteorological measurements.
- Vehicle behavior is an original simplified arcade model, not a full rigid-body simulator.
- Geometry and scenery are optimized procedural meshes, not photogrammetry/PBR assets comparable to commercial AAA releases.
- Progress is saved in browser local storage and is not synchronized to accounts.
- In production, the original 3-hotspot placement game remains playable if the optional 3D scene cannot start.

## Quality acceptance gates

1. `node scripts/zion-open-city-v28-smoke.mjs` and `node scripts/zion-open-city-v29-smoke.mjs` must pass.
2. `npm run qa:zion-local` and `npm run build` must pass within the repository.
3. Full Chromium desktop/mobile workflows must complete without runtime exceptions, mission regressions, inaccessible UI, or resource exhaustion.
4. A clean PR merge must precede automatic SSH publication.
5. The GitHub deployment job must verify byte-identical ZION assets and production HTTP routes; source merge alone is not production proof.

## Next production phases (not yet implemented)

- Motion-captured character rigs, authored animations, AAA-quality licensed scenery and facial dialogue.
- Full physical vehicles and traffic AI with navigable interiors, pedestrians who react to the player, and fine road geometry.
- Voice acting, localized subtitles, robust save accounts, accessible controller support, art-direction approval.
- Separate native PC/console production track in Unreal Engine when a native rendering budget and high-quality asset pipeline are available.