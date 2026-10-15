# ELBRUS TABLE OS concept preview — 15.2

## Implemented in this case
The public ELBRUS case now includes a localized concept demo in Russian, English and Arabic/RTL:
- guest count bounded to 1–8;
- per-guest demo budget tiers of 500 / 800 / 1200 RUB;
- occasion selection (family, celebration, explore);
- deterministic sample set with estimated total and per-guest amount;
- copyable text plan and accessible textarea fallback;
- responsive layout, visible focus, live announcements and reduced-motion support.

## Explicit boundary
This is a local single-browser simulation. It does not create a real multi-device table session, send invites, persist a draft, call an API, create a real order or reserve a table. All displayed dishes/prices are sample data and are not a restaurant offer. Ingredient/allergen/availability claims are intentionally omitted.

A real TABLE OS release needs an authenticated session API with expiring/rotatable join tokens, server-authoritative prices, concurrency/version handling, ordering cutoff rules, privacy/retention, abuse limits, production integration tests and written owner approval before live orders are enabled.

## Deployment
Files live in `public/entertainment/elbrus/`; the existing `.github/workflows/deploy-frontend.yml` trigger on `public/entertainment/**` runs `npm run qa:elbrus-case` before SSH deployment. Confirm the PR check and post-merge deploy run before declaring public availability.
