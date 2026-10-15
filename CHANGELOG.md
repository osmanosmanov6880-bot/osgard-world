# Changelog

## Entertainment global hub — RU / EN / AR (2026-10-15)

- Added static English and Arabic hub routes at `/entertainment/en/` and `/entertainment/ar/`; Arabic uses RTL layout and an Arabic-capable font.
- Added accessible language selection, reciprocal canonical/hreflang, localized social metadata, and CollectionPage JSON-LD.
- Added a static Open Graph SVG, sitemap entries, production route checks and a locale smoke test to the SSH deployment workflow.
- All locales retain the ELBRUS case. ELBRUS remains a concept preview; live restaurant ordering and payments are not enabled.



## ELBRUS case 15.2 — TABLE OS preview
- Added a RU / EN / AR (RTL) local-only table-set concept with bounded guests, demo budgets, occasion presets and estimated totals.
- Added clipboard plan export with accessible manual-copy fallback.
- Added responsive styles, keyboard focus, aria-live result and reduced-motion support.
- Expanded the ELBRUS case smoke test to require assets and prove the feature makes no API calls or persistence writes.
- No real order, reservation, invitation or cross-device session is created. Menu/prices remain demo content.
