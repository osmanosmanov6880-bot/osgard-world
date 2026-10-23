# ZION-030 — enabling REAL Stripe payments (Maga England or another authorized merchant)

**State: code/configuration ready for review; production live payments NOT enabled.**
The live account and its payout rights MUST be verified first. Connecting Stripe to
ChatGPT is not equivalent to provisioning the game backend with a restricted key.

## 1. Confirm who receives the money

- Sign into the **merchant-owned or explicitly authorized** Stripe account, not a sandbox.
- Confirm the legal merchant has completed onboarding, has `charges_enabled = true`
  and `payouts_enabled = true`, a valid GBP/EUR settlement configuration, customer
  support details, terms of sale, privacy/refund policy, and a valid bank payout route.
- If the merchant is **Maga England** owned by someone else, the money goes to
  *that Stripe merchant*, not automatically to the game's developer. Obtain
  documented authorization/revenue-share arrangements. This game currently
  implements single-merchant Checkout, NOT Stripe Connect split payouts.
- Verify handling of digital-services VAT/sales tax with the merchant accountant.
  This integration deliberately does not enable `automatic_tax` without
  confirming an applicable Stripe Tax registration.

## 2. Create production-limited credentials (never paste keys into chat or Git)

In the merchant's **Live mode** Stripe Dashboard:
1. Find the exact `acct_...` ID. Set it as the deployment-host environment
   variable `OSGARD_STRIPE_ACCOUNT_ID`. The backend verifies that its API key
   belongs to this exact account using Stripe's account endpoint.
2. Generate a **live restricted key** (`rk_live_...`) with the minimum required
   permissions to create/retrieve Checkout Sessions and read the current account,
   PaymentIntents and Charges. Keep the key on the deployment host in a root-
   managed secret file, not a JS bundle or GitHub source.
3. Add a **Live event destination** for
   `https://osgard.world/api/core/game/webhook` using webhook API version
   `2026-08-26.dahlia`. Subscribe to:
   `checkout.session.completed`,
   `checkout.session.async_payment_succeeded`,
   `checkout.session.async_payment_failed`,
   `checkout.session.expired`,
   `charge.refunded`,
   `refund.created`,
   `refund.updated`,
   `refund.failed`,
   `charge.refund.updated`.
4. Store the **live** signing secret (`whsec_...`) in a *different* host secret
   file. Do not use the secret from Stripe CLI/test mode.
5. Set webhooks to use **the same merchant account**, not another Connect account.
   Never accept events from another account. Do not rely on the success URL to
   grant items; it only returns players to their game.

## 3. Deployment-host configuration (secure, explicit opt-in)

The repository includes `docker-compose.zion-live-payments.yml`. It is
intentionally **not** included in normal `docker compose` commands and is
not automatically activated by ChatGPT or a GitHub merge. It reads merchant
credentials using external Docker secrets.

On the production host (not in ChatGPT), after placing appropriately protected
files outside the repository in a secret vault / protected folder:

```bash
export OSGARD_STRIPE_ACCOUNT_ID='acct_REPLACE_WITH_VERIFIED_LIVE_MERCHANT'
export OSGARD_ZION_LIVE_KEY_FILE='/secure/absolute/path/zion-restricted-live.key'
export OSGARD_ZION_LIVE_WEBHOOK_FILE='/secure/absolute/path/zion-live-webhook.whsec'
export OSGARD_GAME_STORE_PUBLIC_ORIGIN='https://osgard.world'

docker compose -f docker-compose.production.yml \
  -f docker-compose.zion-live-payments.yml config --quiet
docker compose -f docker-compose.production.yml \
  -f docker-compose.zion-live-payments.yml up -d --build core-api
```

Do **not** enter dummy account IDs or test API keys on production. The live
override requires both secret files and refuses to start when settings are missing.

The read-only authentication preflight runs within the live Core container, and
never creates a charge:

```bash
docker compose -f docker-compose.production.yml \
  -f docker-compose.zion-live-payments.yml exec -T core-api \
  python - --check-stripe < scripts/zion-live-stripe-preflight.py
```

Preflight checks backend configuration, the exact merchant ID, live credentials,
`charges_enabled` and `payouts_enabled`, without printing secrets.

## 4. Gate before allowing real buyers

- CI: `python3 scripts/core-game-store-smoke.py` must be green. All its
  purchases/refunds are **fake-provider fixtures** using real local HTTP and
  SQLite; they do not move money.
- Direct same-origin smoke:
  `GET https://osgard.world/api/core/game/store` must reply JSON with
  `enabled: true` and `mode: "live"`.
- An unauthenticated `POST /api/core/game/checkout` must be rejected.
- Stripe Dashboard should show the event destination enabled, with zero
  delivery failures; invalid signatures must be rejected with 4xx.
- Review EUR product prices: ONYX €4.99, AURORA €6.99, COPPER €3.99,
  AFTERGLOW €7.99, FOUNDER €14.99. The server alone sets amounts.
- Perform an approved small **real** purchase with a merchant-authorized
  test buyer and confirm the actual live charge, Stripe webhook, buyer
  entitlement and a controlled refund. Do not conduct real test charges
  without the merchant's approval or a responsible refund plan.
- Verify the game front end points at the same server/API as the webhook.
- For customer service, provide a visible support contact, sale terms, privacy
  policy, refund and delivery instructions before inviting public payments.

## Security and failure guarantees

- **Disabled by default.** The source code and ChatGPT account connector do
  not grant live access. A separate, explicit production override is required.
- Player identity uses existing OSGARD Core bearer sessions.
- The backend validates SKU/prices, client reference, merchant account ID, live
  mode, currency, amount, PaymentIntent and Charge before unlocking cosmetics.
- Server deduplicates Checkout requests with a persisted Stripe idempotency key.
- Webhook signature (raw body, timestamp, HMAC) and replay IDs are checked.
- Signed refund events revoke fully refunded paid cosmetics and bundles.
- The game cannot unlock products from `?checkout=returned`,
  `localStorage`, an altered URL or a client-side flag.
- If the merchant account, live key, webhook, or server cannot be verified,
  **do not enable taking money**. Revenue is not proven until a genuine live
  charge and settlement are visible in the merchant Dashboard.
