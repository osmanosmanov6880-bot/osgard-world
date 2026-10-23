# OSGARD Ω — REAL-MONEY STORE / UK Stripe merchant

## STATUS (as authored)

**PAYMENTS DISABLED / NOT CONNECTED.** Game UI, Checkout backend, signed webhook and entitlement database are implemented in this branch. Nothing is deployed and no Live Stripe purchase link has been created. The Stripe connector could not identify an eligible linked account; only an earlier sandbox was observed. The connected Supabase session listed **zero projects**. Never present this as a currently functioning payment service.

This branch is independent from the rendering PR: base \`feat/omega-horizon-r5-cinematic-native-qa\`, parent [PR #223](https://github.com/osmanosmanov6880-bot/osgard-world/pull/223). No changes to main/master or the public server.

## Purpose and UK merchant ownership

Customers pay **the legal UK merchant operating the Stripe account**, not automatically the person who built or commissioned the game. Funds appear in that Stripe account and are paid out according to its configured bank and payout settings. If this is a friend's business, obtain written consent, clarify who is the seller of record, ownership of goods, refunds/taxes and how revenue reaches you. Do not use a friend's account to hide the actual owner or bypass geographic/KYC restrictions. For direct payouts to another legally authorised seller, use the appropriate Stripe Connect architecture, not account-sharing.

## Actual game purchase catalogue (GBP — staged, NOT ACTIVE)

| SKU | Customer-facing product | Price | Delivered effect |
|---|---|---:|---|
| \`crimson_paint\` | Crimson GT Finish | £2.99 | Permanent red metallic paint |
| \`aurora_paint\` | Aurora GT Finish | £4.99 | Permanent turquoise paint |
| \`founder_gold\` | Founders Gold Finish | £9.99 | Permanent golden founder paint |

All cosmetics are **one-time, no gambling/random boxes**, and do not alter car performance or gameplay currency. Stored per verified Supabase user, not in \`GameState.wallet\`. Game's garage button is visible even while offline, and clearly shows that real payments are not activated.

## Production activation — owner actions required

1. **Restore access to the correct Stripe Live UK merchant:** ChatGPT Settings → Plugins → Stripe → Reconnect/Manage accounts, authorise the legal owner and verify the account's country, live access, \`charges_enabled\` and \`payouts_enabled\`. The Stripe API key must belong to the *same* account. The linked ChatGPT plugin alone does not inject an API key into your game's backend.
2. **Choose or create a Supabase project** (currently none is linked). If paid compute is required, review and approve the project's price before provisioning.
3. In the correct Stripe Dashboard, **Live** mode, create three separate one-time products at the GBP amounts above. Record their exact \`price_...\` identifiers. Creating Stripe products/prices does not charge anyone.
4. Run the migration \`supabase/migrations/20261023000000_omega_stripe_store.sql\` on the chosen Supabase project. Review four RLS tables and two service-only RPC functions; run security advisors.
5. In the Supabase SQL editor, after validating each Stripe Live \`price_\` belongs to the intended merchant and equals GBP amount, set IDs:
   \`\`\`sql
   update public.omega_store_catalog set stripe_price_id = '<price-id-299-GBP>'
     where sku = 'crimson_paint' and price_pence = 299;
   update public.omega_store_catalog set stripe_price_id = '<price-id-499-GBP>'
     where sku = 'aurora_paint' and price_pence = 499;
   update public.omega_store_catalog set stripe_price_id = '<price-id-999-GBP>'
     where sku = 'founder_gold' and price_pence = 999;
   \`\`\`
   **Keep \`active=false\`** until all integrations, seller details, refunds, webhook and buyer support are operational.
6. Set production Edge Function secrets using Supabase **Dashboard only**, based on \`supabase/store-secrets.example\`:
   \`STRIPE_SECRET_KEY\` (prefer a scoped \`rk_live_\` restricted key), \`STRIPE_WEBHOOK_SIGNING_SECRET\`, \`MERCHANT_STRIPE_ACCOUNT_ID\`, \`STRIPE_MODE=live\`, \`STORE_MERCHANT_LEGAL_NAME\`, \`STORE_TERMS_URL\`, \`STORE_REFUND_URL\`, \`STORE_SUCCESS_URL\`, \`STORE_CANCEL_URL\` and \`STORE_ALLOWED_ORIGINS\`.
   **Never paste any keys or \`whsec_\` into ChatGPT, GitHub, .godot or screenshots.**
7. Deploy **both** Supabase Edge Functions \`osgard-store\` and \`osgard-stripe-webhook\` with \`verify_jwt=false\`. This is safe only because \`osgard-store\` verifies the Supabase bearer token via Auth and the webhook checks raw Stripe signatures.
8. Configure Stripe webhook endpoint as \`https://<project>.supabase.co/functions/v1/osgard-stripe-webhook\`. Subscribe to \`checkout.session.completed\`, \`checkout.session.async_payment_succeeded\`, \`checkout.session.async_payment_failed\`, \`checkout.session.expired\`, \`charge.refunded\` and \`charge.dispute.created\`; copy **that endpoint's** signing secret to Supabase.
9. Configure Supabase Authentication email OTP template to contain \`{{ .Token }}\` (not the default magic-link-only template); set up SMTP/delivery and verified domains. Configure appropriate privacy notice.
10. Configure the game's **public** values in \`godot/empire-omega/scripts/omega_store_config.gd\` or through Windows environment variables \`OSGARD_SUPABASE_URL\` and \`OSGARD_SUPABASE_PUBLISHABLE_KEY\`. These are not Stripe secrets.
11. Run CI and a non-production end-to-end payment test with Stripe test-mode **on a separate test database**. Test duplicate webhook delivery, refund, invalid price, rejected auth, callback navigation and entitlement recovery after restart.
12. Only after the merchant and fulfillment checks pass, set catalog \`active=true\` for the approved Live products. Verify one authorised real purchase end-to-end, customer support/refund workflow, recipient bank and settlement reporting. Then deploy the Windows build/website **with the merchant's approval**.

> **Distributions:** Check the rules of any distribution store before using external Stripe payments for in-app digital goods. The proposed architecture targets a directly distributed Windows/Web build, not Apple/Google/console store bypasses.

## Architecture / attack surface

\`\`\`
Godot shop -> Supabase email OTP -> verified JWT -> /osgard-store/checkout
                  |                                |
                  |                          Stripe hosted Checkout (UK merchant)
                  |                                |
                  |                         signed webhook (raw body)
                  |                                |
                  +-> /osgard-store/entitlements <-- atomic service-only grant/revoke
\`\`\`

No authority in a client success page, checkout URL, email or local GameState save. The checkout backend independently checks UK merchant account ID/country, payouts/charges capability, live-mode key and price ID's exact GBP amount. Only Stripe's signed \`paid\` webhook can grant cosmetics, recorded atomically and idempotently in Postgres; full refunds/disputes revoke. Partial refund needs manual seller review; support must honour applicable laws. Offline clients can be modified (as all local games can), but cannot mint server-verified purchase records. Store sessions intentionally stay in memory; email OTP login is required after restarting the game.

## Technical verification

Native parser/game UI: \`godot --headless --path godot/empire-omega --script res://tests/v30_omega_store_security.gd\`.
Static security: \`python3 -m unittest discover -s commerce/tests -p "test_*.py" -v\`.
Edge type check: \`deno check supabase/functions/osgard-store/index.ts supabase/functions/osgard-stripe-webhook/index.ts\`.
CI workflow: \`.github/workflows/omega-stripe-commerce-security.yml\` — no live charges, no deployment, no API key, does not enable products.

## Outstanding Live blockers

- No verified \`Мага Англия\` Stripe Live account in tools (connector error: eligible linked account missing).
- No connected Supabase project or deployed signing webhook.
- No confirmed product/price IDs, merchant payout bank, legal seller details or refund/TOS URLs.
- No real payment has been accepted or attributed to the game's owner.

**Never claim checkout is taking money until the first real merchant-authorised transaction and webhook grant are verified.**
