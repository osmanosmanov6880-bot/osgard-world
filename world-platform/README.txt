LAST FRONTIER / WORLD OPERATIONS - playable review package
=================================================================
Product: real Godot 4.4.1 3D game inside a premium standalone local
web platform. Source game: W74 accepted commit
73ef81b54cb42831cafd9ac8fa69c5807cd8dc8d.
Public commercial release: NOT authorized. Trademark: NOT cleared.

WINDOWS:
1. Extract the full ZIP. Do not double-click index.html.
2. Double-click START_WINDOWS.bat. Python 3 is needed.
3. Open http://127.0.0.1:8765/ if a browser did not open.
4. Press LAUNCH GAME. The actual WASM engine loads (large binary).
5. Click FOCUS GAME before sending keyboard commands.
6. Use W/A/S/D movement, P first person, Y real three-mechanic mission,
   G direct physics-ray interaction, E inspect, F5 save, F9 restore,
   F3 actual frame-time diagnostics and L game-language switch.

MAC / LINUX:
Open Terminal in this directory and run:
  sh START_LINUX_MAC.sh
Then browse to http://127.0.0.1:8765/

WORLD PLATFORM:
- RU/EN language switching affects the surrounding web application;
  press L in the Godot game to switch the game's own text.
- All reactor readings and mission stages are sourced from actual
  Godot engine DOM-provided read-only state, NOT random fake numbers.
- LAB requires voluntary consent and a currently running real game.
  It collects actual observed local engine events, elapsed session
  time and optional self-report. Data is never sent to any server.
  Manual export is not independent playtest proof.
- SYSTEM: SHA-256 checks original exported file bytes against verified
  local Godot export. Opt-in service-worker offline caching only on
  browsers supporting localhost secure contexts. It may require space
  for over 45 MB of game files.
- There are no real cloud accounts, multiplayer, payment systems,
  platform-wide rankings or remote telemetry in this release.

BUILD INTEGRITY:
- release-manifest.json includes the actual original Godot binary
  filenames, byte sizes and SHA-256 digests.
- game/evidence.json is the original Godot export's own SHA audit.
- WORLD_BUILD_PROOF.json summarizes local game byte verification.
- Do not replace the game index.wasm or index.pck with placeholders.
- Source of the software is in the GitHub PR for W76.
- Offline and browser tests in CI are software tests, not physical
  GPU benchmarks or commercial certification.

SAFETY:
- Entirely fictional offline industrial puzzle. No real-world
  industrial devices are connected or controlled.
- The working title LAST FRONTIER is not cleared for sale.
- No public distribution, Steam release or merge to production
  branches occurs automatically.
