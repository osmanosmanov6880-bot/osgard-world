# EUROMOTORS — Cloudflare Pages bundle

Standalone, static multilingual showcase prepared from the EUROMOTORS portfolio concept.

## Deployment target
Cloudflare Pages project name: `euromotors-showcase`

## Deploy using Wrangler
Run from the repository root after authenticating Wrangler and selecting the intended Cloudflare account:

```sh
npx wrangler pages deploy cloudflare/euromotors --project-name euromotors-showcase
```

This uploads only this directory, not the full OSGARD WORLD application. The bundle has no build step and no runtime server requirement.

## Git-connected deployment
In Cloudflare Dashboard → Workers & Pages → Create → Pages → Connect to Git, select this repository and configure:
- Production branch: `master`
- Root directory: `cloudflare/euromotors`
- Build command: leave empty
- Build output directory: `.`

Cloudflare account permissions, project creation, and domain/DNS binding must be completed in the Cloudflare account.

## Routes
- `/` — Russian
- `/en/` — English
- `/ar/` — Arabic / RTL
- `/og.svg` — social preview artwork

## Before binding a custom domain
Replace placeholder/current OSGARD references only if the business owner wants this concept to become a standalone production brand. Add canonical URLs and update the Open Graph URL to the final domain after the domain is known. Until then, the pages are explicitly a concept showcase, not a live dealer inventory or transactional site.

## Scope
This is a static showcase. Live inventory, verified prices, CRM, financing, and working lead delivery are not connected. Do not advertise those as active features.
