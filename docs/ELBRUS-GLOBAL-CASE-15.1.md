# ELBRUS Global Case — release 15.1

## Public case pages
- Russian: https://osgard.world/entertainment/elbrus/
- English: https://osgard.world/entertainment/elbrus/en/
- Arabic (RTL): https://osgard.world/entertainment/elbrus/ar/

Each static page has its own canonical URL, reciprocal hreflang links, localized title/description/social metadata and CreativeWork JSON-LD. The Arabic page uses `lang=ar`, `dir=rtl`, RTL-aware layouts and loads Noto Naskh Arabic only on that route.

## Performance and accessibility
- Preloads the hero/background image with high fetch priority.
- Applies `content-visibility:auto` with intrinsic size hints to below-the-fold sections.
- Adds a keyboard skip link, visible focus states, mobile layout and reduced-motion support.
- These are implementation-level optimizations, not measured Lighthouse/Core Web Vitals claims. Measure after deploying.

## Catalogue and integration boundaries
- Menu items and prices are demonstration content.
- The case preview never submits orders, reserves tables or calls the restaurant API.
- Do not enable real ordering without owner-approved menu, prices, ingredients/allergens, contacts and privacy notice, plus production release gates.

## Publication pathway
The existing `.github/workflows/deploy-frontend.yml` triggers on `public/entertainment/**` and runs `npm run qa:elbrus-case` plus production route checks before SSH deployment. This release adds three locale routes to the route matrix and smoke test. Verify the GitHub Actions run after merging to `master`; a commit alone is not proof of public availability.
