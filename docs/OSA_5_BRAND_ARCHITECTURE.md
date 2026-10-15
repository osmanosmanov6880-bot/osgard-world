# OSGARD WORLD × OSA 5.0 — brand architecture

## Audit: existing portals and routes

| Surface | Route | Implementation and role |
|---|---|---|
| OSA Intelligence | `/` | React + TypeScript; editorial AI learning, evidence and decisions |
| OSGARD WORLD ecosystem | `/portal` | React App; seven selectable product worlds, AURUM, TimeCoin and Passport/progress |
| AI Academy | `/academy` | React; learning paths, local progress and project Studio |
| OSA Original | `/osa-cinema` | React interactive film; scene choices, saved answers and act navigation |
| SkillCred | `/skillcred/` | Independent static HTML/CSS/JS plus same-origin API |
| OSGARD PLAY | `/games/` | Independent static game catalog and player/session logic |
| Legacy entertainment catalog | `/entertainment` | Static HTML catalog with links into existing game routes |
| Individual games | `/games/*`, `/play/*`, `/games/time` | Standalone HTML/JS, Godot Web export, Unity WebGL or React route |

The React entry is `src/main.tsx`. Route dispatch is unchanged. Static games and SkillCred remain independent apps. The seven-world selector, Passport/progress controls, game input/session logic, course state, same-origin API and existing SEO documents remain in place.

## OSA 5.0 identity

The custom vector is implemented as `src/OSAMark.tsx` and mirrored in `/brand/osa-5-mark.svg` for static pages and favicon use. One open angular frame surrounds integrated O/S/A strokes; an offset point gives the silhouette a small precision detail. Symbol-only and lockup variants share the same geometry. The OSGARD signature keeps the OSGARD name and adds `WORLD / OSA 5.0`.

## Product design profiles

- **OSGARD WORLD:** obsidian, editorial display type and restrained champagne accents; keep the interactive seven-world map and spatial storytelling.
- **OSA Intelligence:** blue-black and silver-blue, editorial typography and an explicit OSA 5.0 signature. The hero uses a brand plate and a clear Model → Evidence → Decision strip instead of decorative orbital clutter.
- **AI Academy:** preserve mint/green study cues, learning controls and the practical workspace; the shared signature is supporting branding.
- **OSA Original:** preserve scene-specific cinematic art and the red/blue narrative palette; use the common mark in its compact header.
- **SkillCred:** preserve black/lime, credential-artifact detail and protocol-first data hierarchy; add only a compact return link to OSGARD.
- **OSGARD PLAY:** preserve cyan/graphite and distinct game identities; share the mark without cloning each game's layout.
- **Standalone games:** keep mechanics, palettes, save state, input logic and canvases untouched.

## Motion and navigation

`/brand/osa-transition.js` adds a short non-interactive transition only after an eligible same-origin navigation between recognised product profiles. Modified clicks, downloads, external targets, same-page anchors, unrelated routes and stale session tokens are ignored. The one-shot token contains only the intended destination and timestamp. The overlay is removed within 460 ms, or 100 ms when reduced motion is requested. It does not fake data loading.

The OSGARD intro is shown once per session, lasts about 0.91 seconds before a 0.26 second fade, has a visible skip action, and is skipped on repeat visits, for reduced-motion users, and in the mini-app. The old five-second blocking timer and non-functional sound toggle have been removed.

## Release guardrails

This branch does not modify Nginx, secrets, host files or production data. It does not deploy. The isolated design-validation workflow runs TypeScript, a production build and the existing product smoke suites. Before release, review screenshots at wide desktop, laptop, tablet and mobile widths and check keyboard/reduced-motion behavior on a preview environment.
