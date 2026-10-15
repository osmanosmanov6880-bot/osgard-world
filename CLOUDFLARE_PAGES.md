# Cloudflare Pages deployment — OSGARD WORLD

This repository is a Vite + React frontend with additional static HTML pages under **public/**. Cloudflare Pages can host the generated static frontend from **dist/**.

## Build settings

- Project name: **osgard-world**
- Production branch: **master**
- Build command: **npm run build**
- Build output directory: **dist**
- Node.js: 20 or newer
- Config file: **wrangler.jsonc**

The build first runs **scripts/sync-swarm-assets.mjs**. The source folder beside this repository is optional; when absent (as it is in a Cloudflare build), the checked-in SWARM assets are retained. Do not remove the static assets tracked in **public/games/swarm/**.

The Pages output includes **public/_headers** and **public/_redirects**. Run **npm run qa:cloudflare-pages** after building to check important routes, headers, redirects, file count and per-file size. The preflight uses Cloudflare's Free-plan limits (20,000 files and 25 MiB per file); increase **CLOUDFLARE_PAGES_MAX_FILES** only when the target account/project has the relevant paid-plan capability.

## Deploy through GitHub Actions

The repository workflow **.github/workflows/cloudflare-pages.yml** runs the build and Cloudflare-specific preflight on pushes. A manual **workflow_dispatch** can upload a preview deployment or the production branch with Wrangler.

Before the first manual deployment:

1. Create a **Pages Direct Upload** project named **osgard-world**, with production branch **master**. The project name must match **wrangler.jsonc**. Do not choose Git integration if you intend to keep deploying through the Wrangler workflow; Cloudflare does not let a Direct Upload project be converted into a Git-integrated project later.
2. In GitHub repository Settings → Secrets and variables → Actions, add **CLOUDFLARE_ACCOUNT_ID** and **CLOUDFLARE_API_TOKEN**. The token should have the minimum account-level Cloudflare Pages edit permission needed to deploy.
3. Open Actions → **OSGARD Cloudflare Pages** → Run workflow. Start with **preview**. Verify the generated ***.osgard-world.pages.dev** deployment before using the production target.

No Cloudflare credentials are stored in this repository. Never commit a token or account secret into **wrangler.jsonc**.

## Critical: static hosting is not the entire production stack

The current production site also relies on the VPS Nginx/container stack for dynamic endpoints, including:

- **/api/v1/*** — game/account/analytics API;
- **/api/remix/*** — REMIX backend;
- SWARM session endpoints such as **/rooms**, **/health**, **/ready**, **/metrics**, **/matches** and **/players**, plus WebSocket/SSE upgrades.

Cloudflare Pages static assets do **not** replace these services or the Nginx reverse proxy. The preview can validate the static presentation and public pages, but those dynamic features will not work on Pages until a Cloudflare Worker/Pages Function or another backend origin routes the requests to the existing services and CORS/origin policy is configured.

**Do not point osgard.world or www.osgard.world at this Pages project yet.** Attaching the production hostname before the proxy is implemented and tested would risk breaking logins, game sessions, analytics and REMIX. Keep the current VPS routing in place while checking the Pages preview. A production migration needs a separate API/WebSocket proxy plan, origin TLS, smoke tests, and rollback steps.

## Official references

- Pages build settings: https://developers.cloudflare.com/pages/configuration/build-configuration/
- Pages response headers: https://developers.cloudflare.com/pages/configuration/headers/
- Pages redirects: https://developers.cloudflare.com/pages/configuration/redirects/
- Wrangler Pages commands: https://developers.cloudflare.com/workers/wrangler/commands/pages/
- Pages limits: https://developers.cloudflare.com/pages/platform/limits/
