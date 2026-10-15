# OSGARD Entertainment — Global Hub

## Localized routes
- RU: `https://osgard.world/entertainment/`
- EN: `https://osgard.world/entertainment/en/`
- AR / RTL: `https://osgard.world/entertainment/ar/`

## Features
- Accessible locale switch with active language state.
- Canonical/hreflang metadata, localized Open Graph/Twitter metadata and CollectionPage JSON-LD.
- Static Open Graph image at `/entertainment/og.svg`.
- Sitemap and desktop/mobile production route-matrix coverage.
- `qa:entertainment-locales` in the SSH deploy workflow.

The game routes retain their existing language support. ELBRUS remains a concept preview and does not accept real orders or payments. Publication is confirmed only after SSH deployment and public route checks succeed.

## Release gate (2026-10-15)

Before calling this release live, require all of the following: `npm ci`, `npm run qa:entertainment-locales`, `npm run qa:elbrus-case`, production desktop/mobile route matrix, verified SSH archive checksum and successful remote activation. A failed or stale deploy must not be reported as success. The social image and the new hubs are static public assets.
