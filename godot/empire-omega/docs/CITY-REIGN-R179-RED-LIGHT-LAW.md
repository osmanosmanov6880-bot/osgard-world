# CITY REIGN R179 — PHYSICALLY VERIFIED RED-LIGHT LAW

**Parent:** R178 true 16-junction right-of-way source, itself descending from confirmed green R177.

## 1. Physical evidence, not a proximity-based fake fine
The local \`city_reign_red_light_evidence.gd\` reads the REAL player's successive Godot \`VehicleController.global_position\`, current physical yaw and forward speed, plus two exact samples of the ORIGINAL existing \`TrafficSignalGrid.elapsed\` clock. A citation requires all of:
- Continuous short (max 0.41 s) observed foreground moving-vehicle interval, physically plausible (max 16 metres) forward movement, no reversing/drift/yaw mismatch/teleport/elevation spike.
- Same road lane (within 4.75m of one of the 16 **actual** junctions), crossing the exact 8m-before-center painted stop bar.
- ORIGINAL signal must be RED at BOTH recorded sample endpoints. Amber, green, a phase switch during the sample, missed samples, paused menus, exiting/re-entering a car, reset/load or walking are deliberately excluded.
- No history of positions, plate numbers, camera data, device IDs, account identifiers or network transmission is ever persisted.

## 2. Original city law and actual money
One and only one new legal code, \`red_light\` (first-stage fine 115 game credits), is added to the existing validated \`city_law.gd\` offense dictionary. This uses all existing authoritative mechanisms: escalation at later heat levels, the original 18-second cooldown, city patrol heat, historical legal record, strict JSON save-validation, municipal fine collection and wallet/treasury debit. NO new money system, game currency, mission, background spy-system or AI enforcement policy. The player has full native control.

## 3. Real playable scene and HUD
\`main.gd\` now samples physical stop-line crossing once per existing 4Hz driver-awareness tick, rather than testing distance or clicking a menu. Verified law events use \`GameState.register_traffic_offence("red_light")\` and the existing localized HUD announcement. The last physical sample resets on load/reset and entering/exiting the car, and on inactive/blocked game states. The original 12 NPC cars, 34 residents, 40 missions and R178 traffic infrastructure remain unchanged.

## Independent QA
- \`v186\` true finite-safe red/green/amber, lane, reverse, drift, teleport, out-of-range, long sample and phase switch witness tests.
- \`v187\` full original CityLaw source penalty + cooldown/escalation + strict saved law schema + real fine payment wallet-to-treasury.
- \`v188\` actual full original native 3D scene, moving player car physical crossing, genuine legal infraction, amber refusal, reset, economy/mission invariants.
- All inherited R178–R169 native source and WebGL/real Chromium camera/drive exact SHA checks.
- Commercial/AAA graphics, certified traffic law, human enjoyability, native phone FPS and live production deployment **not claimed**. Draft HOLD until independent 2/2 full CI green and manual review.
