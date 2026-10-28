# IRON PULSE WORLD — genuine WebGL portal (V9)

This is **a real, bilingual launch shell** around the original Godot 4.4.1 game — not a replacement for its rendering, physics or campaign. There is no mock player, video-based substitute or fake worldwide leaderboard.

## Build layout

The GitHub CI workflow assembles a `build/world-preview` tree:

- `index.html`, `styles.css`, `app.js` — original responsive RU/EN portal
- `assets/gameplay-proof.png` — **unedited actual Godot 1366×768 screenshot** from this exact source commit's Chromium verification
- `play/index.html`, `play/index.js`, `play/index.wasm`, `play/index.pck` — real matching Godot WebGL game export
- `manifest.webmanifest`, `sw.js`, `assets/iron-pulse-mark.svg` — optional progressive install shell

After extracting the verified CI artifact, serve the folder over HTTP (WebAssembly is not guaranteed to run from `file://`):

```sh
cd world-preview
python3 -m http.server 8787
```

Open `http://127.0.0.1:8787/`. On Windows, use Python `py -m http.server 8787` if it is installed.

## Integration & user truth

- Selecting GRID, HEAT or AIR changes the **real launch URL** to `play/index.html?scenario=<id>&lang=<ru|en>`.
- The original Godot game validates the URL against explicit scenario/language allowlists and opens the correct real scenario, without starting or falsifying it.
- Winning a real in-engine mission earns one permanent **offline career result**, with a best grade/time and an actual next-operation button.
- Career data stays in Godot's user storage, independent from V6+ checkpoints. No cloud account, sync, analytics, ads or pretend global ranking. A player's data may not survive clearing browser/site storage.
- The service worker caches the **small site shell only**; it never silently caches large WASM/PCK or promises the playable game works offline.
- The hand-coded CSS reactor motif on the landing screen is decorative artwork, **not portrayed as game footage**. The separate gameplay-proof PNG is from Chromium and is directly linked to the exact CI source SHA.

## Product/QA gates

1. All historical Godot V1–V8.6 regressions + new V9 campaign, launch config and native UI tests pass.
2. Exact SHA Windows/WebGL exports and per-file SHA-256 manifest match.
3. Chromium desktop/touch runs old player controls, selects real scenarios, and confirms native campaign profile on initial state.
4. A second Playwright check exercises real RU/EN portal, actual scenario URL, actual Godot deep link, responsive layout and source screenshot.
5. Physical Windows GPU, Android/iOS, gamepad, accessibility audit, performance testing and independent 20-player game research remain open.
6. **Production HOLD.** This is a software preview artifact, not a final AAA release. No automatic GitHub Pages production publish or master merge.

## Attribution

The portal contains original source CSS/SVG and actual gameplay proof only. The reference aesthetic is industrial/cinematic minimalism; no third-party protected 3D models or assets are copied.
