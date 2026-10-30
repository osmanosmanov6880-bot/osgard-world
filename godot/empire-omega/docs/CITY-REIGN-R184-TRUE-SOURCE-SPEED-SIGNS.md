# CITY REIGN R184 — TRUE SOURCE 90 KM/H ROAD SIGNS & PLAYER LAW

Parent R183 \`ffad20f0dba902b37f1b5a5fcbd05bb5fb7c2e1d\`, **2 independent complete original Godot 4.4.1 + Chromium/WebGL2 CI SUCCESS**.

## Real game improvement, not artwork for a presentation

The original player was fined for **speed above 25 m/s for 4 seconds** through the original CityLaw, but there was no clearly communicated in-world sign that this is the *in-game* regulation. R184 makes the existing rule understandable while deliberately keeping the existing 90-credit fine, cooldown and strict JSON save the same.

### Block A — one authoritative law/physics/driver warning
\`city_reign_speed_limit_policy.gd\` centralises the **exact former original** 25 m/s = 90 km/h city threshold, 4 seconds sustained and 2× safe-speed decay. Now the ORIGINAL \`main.gd\` uses that rule directly in the same existing player driving+law transaction; it does **not** add a second law, token economy, police system, wallet or punishments. A long browser frame is bounded to avoid false instant 4-second citation. The original R162 real driver-awareness HUD surfaces a concise RU/EN/ZH 90km/h warning near the actual source legal threshold (90% of limit), **only when no more urgent red signal, walker or vehicle risk is present**. No extra panel on phones. Normal legal speeds do not raise false alarms.

### Block B — original premium physical 3D roadside speed infrastructure
64 physical speed-limit signs (two directional approach signs per X/Z axis at each of the original 16 road junctions) are authored in native Godot source on the existing world footprint. Each has a sculpted original pole, pale round face, red circular rim and **geometric 7-segment raised 90 digits** drawn through native \`SurfaceTool\`, not external font, photo, generated mockup, CSS or billboard. Four shared \`MultiMeshInstance3D\` GPU batches (64 instances each) reuse each sign part. No new physics colliders, shadows, raycasts, city roads or network requests. Visible in LOW; nighttime material emission uses the original city's saved day/night and municipal energy; quality changes preserve original time. The source geometry asserts \`displayed_limit == 90\` and remains located inside original 9×9 road grid.

### Block C — original 3D game QA and legality
- \`v201\`: finite source speed 25m/s threshold, exactly 4 sec real-offence gate, browser frame spike rejection, truthful 90km/h display, RU/EN/ZH source warning; original first 90-credit fine, 18sec cooldown, strict JSON save.
- \`v202\`: actual 16-junction original 3D traffic scene, 64 * 4 GPU instances, native sculpted 7-segment numerals rather than font/textures; bounded on real roads, real power/night/LOW and no collision objects.
- \`v203\`: original full real playable \`main.tscn\`, actual player vehicle / 12 original NPC cars / 34 residents / 384 zebra stripes and WALK/WAIT; real original game speed 26mps / four seconds => real authoritative existing CityLaw citation; preserves original wallet, economy, missions and inventory.
- Complete inherited R183–R169 Godot native regression including 40 missions, save, physics, voice, traffic, original WebGL2 and real source-SHA Chromium desktop + mobile-sized driving/camera checks.

**Not real municipal traffic advice**; only existing game's deliberately simplified law. DRAFT until independently confirmed 2/2 exact SHA full CI; public live SSH version unchanged. Native mobile FPS, human playtesting and commercial AAA visual quality are not attested.
