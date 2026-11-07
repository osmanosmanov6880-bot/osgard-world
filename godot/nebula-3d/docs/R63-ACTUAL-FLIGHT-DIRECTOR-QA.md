# NEBULA R63 — genuine mission planning and 3D flight corridor

**STATUS: Draft source. R63 is not live.** Public R62 remains independently verified: [public HTTPS four-file parity #42325861667](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42325861667).

## Implemented gameplay systems

1. **True preflight dossier:** Calculates real first campaign objective from all 14 missions or all true R57 contract waypoints, R58 risk unlock/time limits, R42 captain bonus, R54 academy effect, true rockets/wingmen, route distance, indicative ETA at 70m/s and earned-on-success CR/XP. Freeflight is explicitly 0 CR/XP. No fake payout, no bypass of mission/career gate. The Russian *МИССИИ* panel has a detailed briefing, and *ФЛОТ* shows a compact next-flight route preview.
2. **Physical non-colliding flight corridor:** Three shared ArrayMesh/MeshInstance3D ring guides are placed along the live physical objective at the existing HUD update cadence, including staged and moving targets. It cannot collide or damage the craft. Quality tier 1 keeps 2 gates, mobile low-power tier 2 keeps 1; no guide in garage, wreck state, freeflight, near goal or locked state.
3. **Real signed HUD navigation:** Ship forward and real waypoint vector determine left/right bearing and distance. Short Russian \`КУРС ВПРАВО / ВЛЕВО / ПРЯМО\`; ETA is approximate and only appears when real measured speed is >=8m/s; mobile HUD avoids long seconds line. Real Chromium WebAssembly QA must observe the true guide count, physical distance and bearing after a genuine sortie.
4. **Last actual flight report:** R61 one-time sortie closure now captures pilot, mode, success/failure, true traveled distance and elapsed seconds, without CR/XP mint. Additive, backwards compatible v1 save field \`r63_last_sortie\` with strict bounded decoding (finite 0–250,000m and 0–36,000s), pilot/mode/outcome allowlists, no forged saves or extra entitlement. Report appears in real mission dossier.
5. **Native + browser regression:** Godot 4.7.2 editor parsing, real city scene, actual campaign mission briefing 350CR/150XP, locked elite risk fallback, freeflight no payout, non-colliding shared 3D gates, mobile quality, real sortie launch/guidance, safe R61 report save roundtrip, zero CR change from planning. Mandatory \`NEBULA_R63_ACTUAL_MISSION_PLANNING_NO_MINT_AND_GEOMETRY_SUCCESS\`. Actual Playwright PC WebAssembly flight/autopilot, 390x844 real CDP mobile touch and frontend must pass.

## Release discipline

This branch must pass all latest-head source CI before merging. A subsequent production release must use a post-merge Godot Web export, separate exact-four-Git-blob protected PR, rollback-safe SSH activation and independent public HTTPS four-file parity.

Hosted SwiftShader image capture is nondeterministic: original R62 source CI obtained a genuine 1280x720 framebuffer image; separate R62 export CI did not reproduce one. Do not misrepresent this as hardware graphics/FPS, AAA or 8K certification. Physical Android/iPhone device QA: **NOT_PERFORMED**.
