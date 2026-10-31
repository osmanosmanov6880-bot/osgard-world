# IRON PULSE WORLD G14 — REAL CAMERA ACCESSIBILITY

Date: October 30, 2026. Technical baseline: G13 mobile HUD (draft PR #706, staged on G12). This release only changes original physical camera input and on-device presentation. It does not create accounts, player activity, missions, pricing, multiplayer services or production infrastructure.

## Actual implementation: keyboard F10 / mobile touch / native pause

**Three mutually exclusive native presets:**
- STANDARD: exact previous angular sensitivity 0.0021, standard up/down and left/right.
- GENTLE: real camera input speed reduced to 0.00125, preserving original angular signs.
- INVERT Y: original 0.0021 sensitivity with reversed vertical camera axis only.

These modes are implemented by new original IPLookComfort.gd source, an allowlisted enum and bounded input function. Mouse relative motion, right-side mobile drag and mapped gamepad right stick all still reach the same existing true Godot _look() camera function. The original CharacterBody3D transforms and Camera3D rotation are updated only by a player-driven event, never an automated yaw target or macro.

A dedicated native F10 handler cycles settings; a 51px LOOK control occupies the unused 111px middle-column touch slot between native PAUSE and movement/plan controls. The 52px native pause menu has a matching look-mode control and bilingual RU/EN labels. Changes persist only in a separate local user://iron_pulse_look_comfort_g14.cfg containing schema and a three-value string enum; invalid modes reject without modifying original default. Game checkpoint, financial, social identity, device model and customer telemetry remain outside scope.

**Safety:** Never write simulated gameplay events, score, victory, mission progress, player identity, telemetry or personal fingerprint. Existing F6 contrast, F7 motor settings, G13 responsive HUD, MAP, G5 Release Vault and G6–G9 release holds remain unchanged.

## Mandatory proof

Native Godot test:
- check exact original camera sensitivity, all three angular response profiles, horizontal preservation under Y inversion, rejecting fake automated modes and safe local persistence.
- load actual Main.tscn; physically dispatch original F10 key events and InputEventScreenDrag to the real camera/controller, ensure the source scene changes yaw/pitch and mission history/choices remain unchanged.
- verify original touch LOOK and PAUSE bounds on 390×844 and 320×720 and 44px+ hit targets; ensure mobile camera control never obstructs adjacent plan/pause buttons.
- ensure pause camera settings cannot advance or complete any crisis and real resume restores touch control.

Independent actual WebGL browser test:
- build true Windows x64 and WebGL from exact commit.
- Chromium desktop: real F10 and real mouse move update native player and Camera3D yaw; restore original default.
- Chromium 390px touch: tap actual native LOOK and PAUSE/RESUME rectangles, exercise all modes and verify game actions unchanged, preserve actual captured pixels and SHA-256.
- Verify portal RU/EN on desktop and 320/390 px. Keep full previous V1–V18 and G1–G13, G5 archive and G6–G9 production gates.

## Honest release verdict

**Draft / G14 CI pending / RELEASE HOLD.** Browser mobile emulation is not real Android Chrome, iOS Safari, or hardware gamepad acceptance. This control feature is not universal remapping or accessibility certification. Independent tests of device performance, player comfort and inclusive experiences remain required.

## Next operations blocks

**G15** independent physical Windows/Android/iPhone/mobile-controller QA with real FPS/thermal measurement, 30-minute input endurance, crash restoration and motor/vision user checks.

**G16** 20-person external playtest through complete GRID/HEAT/AIR mission and honest independent AAA visuals/audio/UX review; fix severity P0/P1, no fabricated retention or players.

**G17** review IP/music/fonts and licenses, signing, legal/privacy obligations by jurisdiction, actual staging+rollback rehearsal, real operator GO, then monitored and supported international release. Commercial rights, recurring revenue, active users or global production launch are not established by G14 CI alone.
