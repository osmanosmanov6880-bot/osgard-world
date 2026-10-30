# CITY REIGN R186 — AUTHENTIC JUNCTION BOX CLEARANCE

Parent R185 exact \`d8de9ca66ef4e625f4497245c889e50b0b2a280b\`: independently **2/2 SUCCESS** native Godot 4.4.1 source, all original mission/save/physical-vehicle tests, WebGL2 export, real Chromium input/camera and exact source-SHA runtime.

## Real-world-style CITY REIGN gameplay instead of adding pictures
The original physical 12 traffic NPCs already have R185 actual right-side ±2m road lanes, R163 following, R178 red light stop lines, R180 genuine pedestrian signals, R182 physical pedestrian crossing yielding and collision-capable \`CharacterBody3D\` chassis. A stopped vehicle in the far-side EXIT could still let another enter a green junction and block its middle; R163 sees only aligned forward cars, not perpendicular cross traffic. R186 supplies proper in-game *don't block the box* behavior using the real existing NPCs.

### Major block A — true physical original 16-junction clearance model
New pure finite-safe \`city_reign_junction_box_clearance.gd\` sources its single stopbar from the very same original R178 \`approach()\`, and uses the original +2m R185 lane; it never invents a signal, sidewalk, alternate traffic route, road closure or saved flag. When the NEXT intersection is within 28m of its actual stop line, the real car checks up to 16 existing neighbor Node3D vehicles (12 ambient, optional physical patrols) and ONLY yields to:
1. A genuinely stationary physical other car 6.5–19m after the actual source junction on the **same** outbound +2m right-hand lane, leaving insufficient space to clear the box.
2. A real other car already in the physical 12.8m source intersection box, while excluding a parallel passing car safely moving along its separate lane.
3. A genuine perpendicular other car whose existing \`CharacterBody3D.velocity\` predicts entering that SAME box within the original driver's stop-line arrival horizon (bounded 1.6s).

No cross-village/parallel street or harmless opposite-lane phantom stops. Cars already beyond the original 8m stopbar are not held stationary inside the box. A new conflict can only **lower** original \`TrafficSafety.safe_speed\` (wet braking and R178 stop bar), never grant a right-of-way or bypass original car raycasts, road closures, red lights, 34 live pedestrian safety scans, B62 civic calm speed or R163 convoy following. Source-only real activation and hold seconds are volatile, never saved or uploaded.

### Major block B — compact actual player driver awareness
The existing real player R162 4Hz risk sensor can show "JUNCTION OCCUPIED" / "ПЕРЕКРЁСТОК ЗАНЯТ" / "路口被占用" in the original compact RU/EN/ZH HUD if the real physics-backed existing cars occupy the source box. An urgent red lamp, pedestrian or car alert ALWAYS outranks it. The player remains in control: no assisted steering, police fine or camera lock. R184 legal 90kmh hint remains a lower-priority fallback. No additional HUD panel.

### Major block C — opt-in metrics, native world tests and browser release gates
The original R183 explicit local 20s benchmark JSON now also includes ONLY aggregate source-observed junction-yield counts and longest hold. Same 2Hz observations, same privacy, 12 genuine ambient cars, no new timer, no raw individual car positions, player identities, network or device claims.

- \`v207\`: source-locked pure real 16-junction stopbar, occupied box, blocked right-hand 2m exit, perpendicular moving car prediction; exclude safe parallel/opposite lane, remote cross street, impossible input, false stationary traffic; wet braking and no freeze after stop line.
- \`v208\`: actual full playable Godot \`main.tscn\` with all 12 original physics cars, original 34 residents, 64 physical R184 signs and 384 true R182 road stripes; physically moving one existing NPC to source exit and another into box controls native \`TrafficAgent._physics_process\` braking and true yield transitions, with saved 40-mission economy unchanged.
- \`v209\`: full original RU/EN/ZH compact safety awareness and explicit 20s local-only 2Hz real-source aggregate, no invented phone FPS, privacy and previously working 40-mission UI preserved.
- All inherited R185–R169 native Godot 4.4.1 source regressions, 40 missions, player save, WebGL2 export and genuine Chromium desktop/mobile-sized input/camera SHA-locked source verification, with 2 independent CI required.

**No claim of certified legal road behavior, formal collision-free proof, physical device FPS, uncoached human testing or GTA-level photorealism.** New PR stays DRAFT; public SSH source untouched until actual independent CI acceptance.
