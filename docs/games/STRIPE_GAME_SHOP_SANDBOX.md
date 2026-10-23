# OSGARD GAME SHOP — Stripe SANDBOX

Catalog at /games/store/ . Checkout requires user login and existing Core Commerce config. Connected account is Osa AI sandbox (test only). No production activation.

Server env uses existing OSGARD_COMMERCE_ENABLED, OSGARD_STRIPE_API_KEY, OSGARD_STRIPE_WEBHOOK_SECRET, OSGARD_STRIPE_ACCOUNT_ID, OSGARD_COMMERCE_PUBLIC_ORIGIN, OSGARD_STRIPE_LIVEMODE, OSGARD_COMMERCE_MERCHANT_USER_ID. Keep livemode=0.

Configure signed Stripe webhook to https://your-domain/api/core/game-shop/webhook for checkout.session.completed, checkout.session.async_payment_succeeded, charge.refunded, charge.dispute.created. Always use a separate endpoint signing secret. Only server-confirmed paid sessions grant items; return URL never does. Refunds and disputes revoke. Buyer, currency, amount, sku, payment intent and Stripe mode validated. Event IDs deduplicated in SQLite.

**Not complete yet:** Actual game inventory must call authenticated API game-shop/owned; a publicly downloadable Godot PCK does not securely protect paid content. Game-shop-entitlements.js is client adapter, not server authorization. Before launch: merchant live approval, end-to-end purchase/refund tests, tax/VAT, support, durable storage, retry/reconciliation and HTTPS operations.

## Independent game shop release gates
- OSGARD_GAME_SHOP_ENABLED=1 is required in addition to OSGARD_COMMERCE_ENABLED=1.
- For live charges, OSGARD_GAME_SHOP_LIVE_APPROVED=1 and OSGARD_GAME_SHOP_EXPECTED_ACCOUNT_ID=<actual authorized acct_...> must match the configured merchant account. A separate, valid OSGARD_GAME_SHOP_WEBHOOK_SECRET is mandatory for this webhook endpoint.
- Never switch the shop to live merely because another Commerce module is live. The merchant account owner must authorize sales, tax/VAT handling and refunds. A third party's Stripe account receives funds as merchant of record; connecting it does not transfer payouts to the game developer.
- Stripe redirection alone does not prove paid entitlement. Out-of-order refunds/disputes cannot re-grant purchases. Concurrent checkout calls use one pending order and stable provider idempotency key.

## How to verify the UK merchant before real charges
On the protected backend host run `python3 scripts/game-shop-live-preflight.py` with *vault-provided* restricted Stripe LIVE credentials, never in GitHub or game files. This is read-only. It verifies account ID, GB country, `charges_enabled`, `payouts_enabled`, and submitted account details. A passing result is still not a live launch sign-off: verify real webhook delivery, inventory and fulfillment, UK merchant's permission, refunds, consumer rights, and tax obligations.
The Stripe plugin connection in ChatGPT does **not** install an API key in the game backend.
