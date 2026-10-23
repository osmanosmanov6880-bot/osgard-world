"""Strict static security gates for payment integration; cannot assert real Stripe livemode."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / "supabase/migrations/20261023000000_omega_stripe_store.sql").read_text()
SHOP = (ROOT / "supabase/functions/osgard-store/index.ts").read_text()
HOOK = (ROOT / "supabase/functions/osgard-stripe-webhook/index.ts").read_text()
GAME = (ROOT / "godot/empire-omega/scripts/omega_real_money_shop.gd").read_text()
CONFIG = (ROOT / "godot/empire-omega/scripts/omega_store_config.gd").read_text()
MAIN = (ROOT / "godot/empire-omega/scripts/main.gd").read_text()

class PaymentSafety(unittest.TestCase):
    def test_real_prices_start_inactive(self):
        self.assertIn("299,'gbp',false", SQL)
        self.assertIn("499,'gbp',false", SQL)
        self.assertIn("999,'gbp',false", SQL)
        self.assertIn("active boolean not null default false", SQL)

    def test_unique_intents_and_events(self):
        for x in ["stripe_session_id text unique", "stripe_payment_intent_id text unique",
                  "stripe_event_id text primary key", "omega_one_pending_checkout_per_sku"]:
            self.assertIn(x, SQL)

    def test_only_server_can_grant_or_revoke(self):
        self.assertIn("revoke all on function public.omega_grant_paid_order",SQL)
        self.assertIn("revoke all on function public.omega_revoke_paid_order",SQL)
        self.assertIn("to service_role",SQL)
        self.assertNotIn("grant insert on public.omega_store_entitlements to authenticated",SQL)

    def test_rls_authorizes_per_user_not_role_only(self):
        for table in ("omega_store_orders","omega_store_entitlements","omega_store_catalog","omega_store_events"):
            self.assertIn(f"alter table public.{table} enable row level security",SQL)
        self.assertIn("user_id = (select auth.uid())",SQL)

    def test_webhook_never_trusts_json_without_signature(self):
        self.assertIn('const raw = await request.text()',HOOK)
        self.assertIn("constructEventAsync(raw, signature, signingSecret",HOOK)
        self.assertIn("Stripe.createSubtleCryptoProvider()",HOOK)
        self.assertIn('event.livemode !== (mode === "live")',HOOK)
        self.assertIn('account.id !== expectedAccount || account.country !== "GB"',HOOK)

    def test_webhook_fulfills_paid_only_and_matches_catalog(self):
        for x in ["session.payment_status !== \"paid\"", "session.amount_total !== order.amount_pence",
                  "session.line_items?.data.length !== 1", "firstLine?.price?.id !== item.stripe_price_id",
                  "session.client_reference_id !== userId", "omega_grant_paid_order"]:
            self.assertIn(x,HOOK)

    def test_early_refund_and_dispute_prevent_late_grant(self):
        for x in ["charge.refunded", "charge.dispute.created", "paymentIntents.retrieve(intent)",
                  "omega_revoke_paid_order", "v_order.status in ('refunded','disputed')"]:
            self.assertIn(x,HOOK+SQL)

    def test_signed_in_before_checkout(self):
        for x in ['db.auth.getUser(token)', '!user.email_confirmed_at',
                  'part === "checkout"', "Already owned", "merchant.charges_enabled",
                  "merchant.payouts_enabled", "price.unit_amount !== item.price_pence",
                  "price.livemode !== (mode === \"live\")"]:
            self.assertIn(x,SHOP)

    def test_secret_keys_are_not_in_game(self):
        self.assertNotRegex(CONFIG,re.compile(r"sk_(?:live|test)_[A-Za-z0-9]{8,}"))
        self.assertNotRegex(GAME,re.compile(r"sk_(?:live|test)_[A-Za-z0-9]{8,}"))
        self.assertNotIn("service_role",GAME)
        self.assertIn("OSGARD_SUPABASE_URL",CONFIG)
        self.assertIn("SUPABASE_PUBLISHABLE_KEY",CONFIG)

    def test_game_store_wired_to_actual_gameplay(self):
        for x in ["REAL_MONEY_SHOP.new()", "paid_store.bind_car(car)",
                  "paid_store.is_open()", "add_child(paid_store)"]:
            self.assertIn(x,MAIN)
        self.assertIn('OS.shell_open(link)',GAME)
        self.assertIn('vehicle.horizon_visual.call("set_paint",paint)',GAME)
        self.assertIn('if not owned.has(sku)',GAME)

    def test_no_money_pretend_state_in_game(self):
        self.assertNotIn('GameState.data["wallet"]',GAME)
        self.assertNotIn("GameState.buy_vehicle(",GAME)
        self.assertNotIn("Payment succeeded",GAME)
        self.assertIn("Checkout",GAME)

    def test_live_cannot_launch_without_owner_legal_name(self):
        for x in ['STORE_MERCHANT_LEGAL_NAME','STORE_TERMS_URL','STORE_REFUND_URL',
                  'MERCHANT_STRIPE_ACCOUNT_ID','STRIPE_SECRET_KEY','STRIPE_MODE']:
            self.assertIn(x,SHOP)

if __name__ == "__main__":
    unittest.main(verbosity=2)
