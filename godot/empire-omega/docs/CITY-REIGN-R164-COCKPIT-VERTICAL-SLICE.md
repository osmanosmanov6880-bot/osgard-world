# CITY REIGN R164 — REAL COCKPIT / CAMERA
Basis: published R163 SHA c2daff6b501be16fd292f9dc06989e4e02736dd0.
Engine: original Godot 4.4.1 GL Compatibility / HTML5.
Camera cycle: STREET -> CLASSIC -> PANORAMA -> COCKPIT -> STREET (keyboard V, joypad D-Pad right, phone Quick Actions).
All existing preferences and RU/EN/ZH are preserved.

## Source reality
- One original Camera3D only, positioned by an actual driver seat offset transformed through the physical vehicle global_transform.
- One original procedural cockpit scene (Node3D) with THREE real PBR/vertex-color MeshInstance3D surfaces: dashboard, steering wheel, speed needle.
- Actual steering and vehicle speed drive the wheel and needle, respectively. No fake dials driven by scripted timers.
- In cockpit only, temporarily hide the otherwise opaque exterior canopy/windshield; restore them on foot or in Street/Classic/Panorama. The collision body remains unchanged.
- Camera does not add physics casts beyond those already used by original chase cameras; no new lights/shadows, expensive shaders, audio, texture downloads, money or saved-game writes.
- Lower-motion camera behavior is stable with no extra shake. Smartphone vertical projection uses the existing portrait fit and restrained 73-degree POV.
- The original R160 three exterior camera modes, city management focus, interior transitions and reduced-motion behavior retain priority.

## Acceptance
- v141 authentic cockpit scene, vehicle shell restore, real wheel/speed telemetry, 4 saved camera options, no GameState mutation.
- v142 100 camera transitions, 3 cached mesh objects without allocation or collision shape changes, stable mobile/desktop and car yaw.
- v133 historical camera test updated for fourth mode, original old settings and save preservation tests unchanged otherwise.
- Existing v138/v139/v140/v136/v137/v134/v135/v129/v68/v72 inherited.
- CI: strict Godot native import, original HTML/WASM/PCK build with SHA256, real Chromium original camera and public-style WebGL2 test.
- R164 remains unshipped until source-locked isolated SSH release and public browser proof pass. Real Android/iPhone GPU frame-rate not yet asserted.
