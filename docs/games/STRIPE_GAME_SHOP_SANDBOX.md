# OSGARD GAME SHOP — Stripe SANDBOX

Catalog at /games/store/ . Checkout requires user login and existing Core Commerce config. Connected account is Osa AI sandbox (test only). No production activation.

Server env uses existing OSGARD_COMMERCE_ENABLED, OSGARD_STRIPE_API_KEY, OSGARD_STRIPE_WEBHOOK_SECRET, OSGARD_STRIPE_ACCOUNT_ID, OSGARD_COMMERCE_PUBLIC_ORIGIN, OSGARD_STRIPE_LIVEMODE, OSGARD_COMMERCE_MERCHANT_USER_ID. Keep livemode=0.

Configure signed Stripe webhook to https://your-domain/api/core/game-shop/webhook for checkout.session.completed, checkout.session.async_payment_succeeded, charge.refunded, charge.dispute.created. Always use a separate endpoint signing secret. Only server-confirmed paid sessions grant items; return URL never does. Refunds and disputes revoke. Buyer, currency, amount, sku, payment intent and Stripe mode validated. Event IDs deduplicated in SQLite.

**Not complete yet:** Actual game inventory must call authenticated API game-shop/owned; a publicly downloadable Godot PCK does not securely protect paid content. Game-shop-entitlements.js is client adapter, not server authorization. Before launch: merchant live approval, end-to-end purchase/refund tests, tax/VAT, support, durable storage, retry/reconciliation and HTTPS operations.
