# OSGARD UNIFIED — Five-wave release candidate

**Scope:** OSGARD World, Play, OSA Intelligence, Academy, Development, Entertainment, plus the existing game/learning services.  
**Branch:** `integration/osgard-unified-six-surfaces-20261022`  
**Pull request:** [#181](https://github.com/osmanosmanov6880-bot/osgard-world/pull/181)  
**Release policy:** No direct production writes. A successful CI is not proof that auth, payments, WebGL2 or multiplayer are live.

## Why a single integration branch

The six reviewed designs were produced independently in PRs [#174](https://github.com/osmanosmanov6880-bot/osgard-world/pull/174), [#175](https://github.com/osmanosmanov6880-bot/osgard-world/pull/175), [#176](https://github.com/osmanosmanov6880-bot/osgard-world/pull/176), [#177](https://github.com/osmanosmanov6880-bot/osgard-world/pull/177), [#178](https://github.com/osmanosmanov6880-bot/osgard-world/pull/178) and [#179](https://github.com/osmanosmanov6880-bot/osgard-world/pull/179). They share routing, Playwright, product navigation and styling. Independently green PRs do not establish compatibility. The unified branch keeps the new Empire game revision and Time Omega preview from the later master.

## WAVE 1 — Source integrity and regression gate

Implemented `scripts/osgard-unified-release-smoke.mjs`, exposed as `npm run qa:unified` and required by `.github/workflows/frontend-check.yml`.

Checks include:

- Presence of all six real React/archive destinations, SPA launchers and original lesson URLs.
- Matching 19 game IDs and lightweight titles; self-hosted 19 individual WebP covers with nonzero length.
- Play cinematic provider, real filterable catalog, NASA Blue Marble fallback and Development screenshot cases.
- Academy local progress, resume and safe backup file picker; Intelligence review and authentic NIST source.
- Seven legacy Entertainment games and four public cases in each of RU, EN, AR, with a clear link to full Play.
- Recent Empire browser build and Time Omega preview from master; no accidental deletion of shipped games.

## WAVE 2 — Unified command

Implemented `src/OsgardCommandPalette.tsx` plus `src/osgardCommandPalette.css` and included the trigger in `BrandShell.tsx`.

- Open with toolbar control, Ctrl+K or ⌘K. Close with Escape or the visible close button.
- Modal focus, keyboard traversal, scroll restoration and route navigation without invented auth flows.
- Render the modal into `document.body` to avoid clipping behind the cinematic header.
- Keep pre-existing local product navigation, motion preference control, footer and browser history.

## WAVE 3 — Useful real search

The command searches the actual 19 Play worlds via `playGameTitles.ts`, ordinary product destinations, the OSA course, learning progress and the original case routes. It supports Arrow Up/Down, Enter and keyboard focus restoration. Queries do not leave the browser and are not sent to a telemetry endpoint.

Implemented `scripts/unified-navigation-browser.spec.mjs` and included it in the desktop/mobile Playwright matrix. It opens the command from World, Intelligence, Academy, Play, Development and Entertainment, searches a real game, checks empty results, keyboard focus, history and horizontal overflow.

## WAVE 4 — Context and resilience

- When started from Play, the command highlights the full catalog, actual favorites/recent routes and the seven-game static archive.
- When started from Development, four cases and their true statuses come from `featuredCases.ts`.
- From OSA, prioritize courses, lessons, progress and assessment.
- Keep the modal responsive, screen-reader labelled, focus outlined and reduced-motion compatible.
- Don't change existing local game saves, OSA learning keys, checkout disclosures or protected accounts.

## WAVE 5 — Release gates

The release candidate must pass **all** workflow families on its **latest head SHA**, not just the earlier PR commits:

1. Frontend validation with `qa:unified`, TypeScript, production build and all Playwright desktop/mobile tests.
2. OSA design validation with completed desktop/tablet/mobile screenshot capture.
3. OSA Learning quality gates (including monetization honesty: no fake checkout).
4. REMIX launcher safety and recovery.
5. Cloudflare Pages build preflight; **check-only** on PR.
6. Release readiness; deployment verification necessarily remains pending until deployed.

Commands for local development:

```bash
npm ci
npm run qa:unified
npm run check
npm run build
npx playwright test --config playwright.ecosystem.config.mjs
```

For browser screenshots, use the artifacts produced by the OSA design validation workflow. Review key layouts at approximately 390px, 768px and 1440px, plus the playable detail screens.

### Do not merge if

- Any newest-SHA workflow fails, is still running or is skipped unexpectedly.
- The hero or command modal causes horizontal overflow, CLS > 0.1 in the mobile laboratory, trapped background focus, lost input, or broken keyboard game controls.
- Game assets disappear, course/learning progress changes schema, monetization starts implying payments are already live, or the static archive masks the canonical Play route.
- New commits land in master without a reviewed update to the unified candidate.
- No rollback path or production verification authority exists.

### Deployment boundary and rollback

A push to `master` starts `.github/workflows/deploy-frontend.yml`. That workflow may update **Core API and REMIX Guard as well as the website**, so use one coordinated release, not a parallel SSH upload. Before merging, read the current deployment workflow, identify the last successful release and verify backups. Capture the pre-release commit SHA and deployment artifacts. After deployment inspect:

- `/`, `/play`, `/intelligence`, `/academy`, `/development`, `/entertainment`;
- all 19 game details, legacy Archive in RU/EN/AR, all four Development cases;
- search + keyboard, progressive image loading, navigation history, mobile performance;
- core account sign-in, API health, real Godot/WebGL and actual multiplayer (these cannot be certified by UI CI alone).

If post-deploy checks fail, run the established rollback mechanism from the deployment runbook, then verify page delivery, static game resources and API. Do not claim rollback until the environment confirms it.

**Completion standard:** green newest-SHA CI, review approval, approved deployment, successful production smoke and a verified rollback option. Before that this is an integration release candidate, **not a published release**.
