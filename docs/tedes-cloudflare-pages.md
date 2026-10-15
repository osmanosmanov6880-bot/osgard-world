# TEDES on Cloudflare Pages

TEDES is a static part of the `osgard-world` Vite build, not a separate Vite project. Keep it inside the main repository so shared navigation and the Development case remain intact.

## Cloudflare Pages settings

- **Project name:** `osgard-world` (must match `wrangler.jsonc` and the workflow)
- **Production branch:** `master`
- **Root directory:** repository root
- **Build command:** `npm run build`
- **Build output directory:** `dist`
- **Node.js:** 20 (same as CI)
- **Environment variables for the static build:** none required by TEDES
- **Deploy credentials:** GitHub Actions secrets `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`; do not put these in Vite variables, source files, or `.env` files.

Use the repository's GitHub Actions workflow for deployment. Do not also enable a second automatic Git integration deployment unless intentionally changing the release process.

## Routes that must survive deployment

- `/tedes/` — studio and configurator
- `/tedes/catalog/` — concept catalog
- `/tedes/collections/` — collections
- `/tedes/product/` — product detail route
- `/tedes/materials/` — finishes/materials
- `/tedes/project/` — local project workspace
- `/tedes/print/` — print view
- `/development/tedes/` — portfolio case

The project workspace saves in the browser and exports locally. It does not require a server environment variable or claim to submit orders to a CRM.

## CI and deploy flow

1. A push to `master` builds the full site and runs `npm run qa:cloudflare-pages`.
2. The preflight verifies the Pages config, security headers/redirects, required TEDES HTML/data/controller files, both WebP assets, file count, per-file size, and absence of common secret-file names in `dist`.
3. To deploy a preview, open **Actions → OSGARD Cloudflare Pages → Run workflow**, choose branch `master`, and target `preview`. It deploys to the Pages branch `cf-preview`.
4. After checking the preview, run the same workflow on `master` with target `production`.

The workflow intentionally does not publish to production on every push. A successful CI preflight proves the artifact is ready; only a successful Wrangler deploy proves Cloudflare accepted the release.

## First-time Cloudflare checklist

- Create the Pages project named `osgard-world` in the intended Cloudflare account.
- Create a scoped API token with Cloudflare Pages deployment permissions for that account.
- Add the account ID and token as repository Actions secrets.
- Run preview first and check TEDES pages, image assets, browser console, and mobile layout.
- Promote to production only after preview review.
- If the main domain is already served by another origin, do not move DNS just for TEDES: it currently uses paths on the shared site, so the whole `osgard.world` static build is what Pages receives.

## Important boundary

Cloudflare Pages hosts the static frontend. Existing API, WebSocket, SSE, or game-session services are not converted to Pages Functions by this change. Keep their current origin/proxy routing in place until it has been tested independently.
