# ESSENTIA — Cloudflare Pages

Standalone static export of the ESSENTIA storefront. This directory is the **Cloudflare Pages output directory**; it does not depend on the OSGARD application build.

## Included
- `index.html` — responsive Russian storefront
- `store.css` — styles
- `store.js` — client-side catalog, search/filter/sort, favourites, cart, promo code and demo checkout
- `og.svg` — social preview image
- `_headers` — baseline security and caching headers
- `_redirects` — canonical index route
- `wrangler.toml` — Wrangler Pages project configuration

## Deploy with Cloudflare Pages

1. In Cloudflare Dashboard, open **Workers & Pages → Create → Pages → Connect to Git** and select the repository, or use Wrangler below.
2. If connecting this repository, set **Root directory** to `cloudflare/essentia`, **Build command** to empty / none, and **Build output directory** to `.`. No build step is required.
3. For CLI deployment, from this directory run:

```bash
npx wrangler login
npx wrangler pages project create essentia-store
npx wrangler pages deploy . --project-name essentia-store
```

If the Pages project already exists, skip the project-create command. Wrangler may ask you to confirm the production branch on first setup.

## Before connecting a custom domain

- Add the domain in **Workers & Pages → essentia-store → Custom domains** and follow Cloudflare's DNS instructions.
- After choosing the final domain, add a canonical URL and make `og:image` an absolute URL (for example `https://your-domain.example/og.svg`). They are intentionally not hard-coded to osgard.world because this is a standalone deployment.
- Test the site on desktop and mobile, including cart, favourites and checkout demo.
- Replace demo product descriptions, prices, imagery and policies with the real merchant's approved content before selling.

## Important functional boundary

This is a **front-end demo**, not a production shop. Cart and favourites are stored in the visitor's browser. Checkout does not create or transmit orders and does not charge a payment method. No database, inventory, account system, email delivery, analytics, or payment provider is connected. Do not present demo checkout as a real order confirmation.

## Assets and privacy

Product/hero photos are loaded from Unsplash and web fonts from Google Fonts, so those services are contacted by the visitor's browser. If you need fully self-hosted assets, download properly licensed images and font files and update the references. Review third-party provider terms and your privacy disclosures before public commercial use.
