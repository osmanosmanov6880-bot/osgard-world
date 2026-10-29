# CITY REIGN R170 — FIRST SIX / PLAYABLE EPISODE DIRECTOR
Based on the exact R169 source `8ea20f1b7699a9595800298a5acae6190d4871d2`, real Godot 4.4.1 and original real city.

## Engineering block 1 — Authoritative journey
Six original player-input missions are now treated as ONE accessible playable chapter:
E enter real original car; F deliver at real market; B purchase business; Tab/N advance actual city turn; F accept a real commercial contract; physically drive its cargo route and stop/F to unload.
All events and payments STILL happen solely in `MissionManager`, `ContractManager` and `GameState`. `city_reign_episode_sequence.gd` has no mutating methods and derives every mission step from the existing v4 save `mission` index. No extra save key, fabricated score, instant delivery, timers, jumps, hidden shortcuts or duplicate currency. When interrupted at the delivery stage, it offers a real next pickup objective without prematurely completing the mission.

## Engineering block 2 — Direct player-facing integration
The existing original CITY REIGN journal now hosts a compact, scrollable six-step mission panel with localized RU/EN/ZH instructions and real active pickup/dropoff positions. It does not add a new full-screen modal or obstruct the already space-constrained phone HUD. Original 46px mission detail button, 40-mission logbook, R169 audio, original source-car/traffic and existing 3D roadside objectives are preserved. Each legitimate original MissionManager completion event announces the next real stage with source-truth progress.

## Engineering block 3 — Release and recovery
v159 projects all six mission states + valid/missing cargo/role/language without touching original saves; v160 real native journal and source-root UI state/controls; v161 original 3D playable world and genuine six-action mission manager integration. Inherited R169 through R164, 40 original missions/corruption, real Chromium WebGL2 and original compiled SHA accepted ONLY after passing QA.

**Production acceptance still outstanding:** verified human 5–10 minute playthrough, retry usability and real physical phone frame time. The 5–10-minute runtime is a TARGET, not measured gameplay. Shipping this episode requires independent QA and the same protected SSH process as R169.
