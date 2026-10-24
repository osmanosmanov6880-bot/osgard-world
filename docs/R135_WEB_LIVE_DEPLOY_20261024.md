# OSGARD R135 — verified WebGL launch and deployment contract (2026-10-24)

## Product surface
- OSGARD PLAY game ID: `r135-service`.
- User route: `/play/r135-service` (React game detail/player iframe).
- Native Web runtime route: `/games/r135-service/`.
- Original editor source: `godot/osgard-r135-standalone/`. R136 files are untouched.

## Source and optimization
- Engine: Godot 4.4.1, Compatibility, WebGL 2.
- Exact source GLB SHA-256: ECO `c6bbc41c53e596d5048371e639a662cd2a75d58a02f75c9df93ffced7685533b`; HERO `8ef33e28534c7c41d4adaceee4e479e38da92287a99bbd5fd53b9fc9318c0078`.
- Original `index.pck`: 118,659,392 bytes.
- Exclude only redundant standalone authored PBR PNGs from Web export (PBR maps remain embedded inside the original GLBs). Optimized PCK: 90,329,968 bytes (23.87% reduction).
- Official source and full R135 original 3D assets remain separately downloadable: https://github.com/osmanosmanov6880-bot/osgard-world/releases/tag/r135-standalone-20261024.
- Optimized Web runtime release: https://github.com/osmanosmanov6880-bot/osgard-world/releases/tag/r135-web-optimized-20261024.

## Checks and server delivery
1. GitHub Actions produces a genuine Godot Web runtime and runs actual Chromium on desktop and emulated mobile, using software SwiftShader WebGL.
2. Screenshots showed original portrait clipping and undersized UI; a revised camera framing, adaptive controls, and industrial grounding stage are tracked in the same PR and must pass a new visual check before deployment.
3. `deploy-frontend.yml` fetches the two optimized release assets over the GitHub API and stages only CRC-valid and SHA-256-verified entries in `dist/games/r135-service` with `scripts/r135-release-stage.py`. Build cannot silently install a missing, oversized, or tampered pack.
4. Existing OSGARD archive/SSH pipeline publishes this directory as part of the atomic frontend release. This retains rollback and prevents subsequent site redeploys from deleting R135.
5. Nginx serves the exact same-origin HTML/JS/WASM/PCK assets with correct MIME types; no SPA fallback for missing engine files. HTML/manifest are no-store; binary pack cache revalidates.
6. `scripts/r135-production-smoke.mjs` verifies the actual public HTML, source release ID, MIME, content length, and partial `206` PCK response before the deployment can be marked successful.

## Evidence limits
- Software-emulated Chromium desktop/mobile is **not** a real phone/device GPU benchmark; no verified FPS claim is made.
- Godot service-spine models remain a simulated industrial demonstration, not a finished AAA game.
- The complete pre-R135 R134 source remains unavailable; this is a separately executable, original-asset R135 reconstruction.
- Do not mark the public route as live until deployment SSH action and production smoke both succeed.
