#!/usr/bin/env python3
"""Read-only ZION live Stripe readiness check. NEVER creates a payment.

Execute inside the deploy container with the explicit live Compose override.
No secret, PII, bank account or card data is printed, even on failure.
"""
import argparse
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))
from core_game_store import Config
from core_commerce import StripeProvider

def fail(message):
    print(json.dumps({"ready": False, "reason": message}, ensure_ascii=False))
    return 1

def main():
    parser = argparse.ArgumentParser(description="Read-only live Stripe merchant readiness")
    parser.add_argument("--check-stripe", action="store_true",
                        help="Fetch authenticated account metadata without creating a charge")
    args = parser.parse_args()
    if os.getenv("OSGARD_GAME_STORE_ENABLED") != "1":
        return fail("Store not explicitly enabled")
    if os.getenv("OSGARD_STRIPE_LIVEMODE") != "1":
        return fail("Store is not configured for live mode")
    try:
        cfg = Config.from_env()
        if not cfg.enabled or not cfg.livemode:
            return fail("Live config not active")
        result = dict(ready=False,mode="live",accountId=cfg.account_id,
                      publicOrigin=cfg.public_origin,webhookConfigured=True,
                      restrictedKey=cfg.api_key.startswith("rk_live_"),
                      stripeAccountChecked=False,chargesEnabled=None,payoutsEnabled=None)
        if args.check_stripe:
            provider = StripeProvider(cfg)
            provider.verify_account()
            obj = provider.client.v1.accounts.retrieve_current()
            get = lambda key: obj.get(key) if hasattr(obj,"get") else getattr(obj,key,None)
            result["stripeAccountChecked"] = True
            result["chargesEnabled"] = bool(get("charges_enabled"))
            result["payoutsEnabled"] = bool(get("payouts_enabled"))
            result["merchantCountry"] = get("country")
            if not result["chargesEnabled"]:
                return fail("Stripe account is not currently enabled for charges")
            if not result["payoutsEnabled"]:
                return fail("Stripe account is not currently enabled for payouts")
        result["ready"] = bool(args.check_stripe and result["chargesEnabled"]
                                and result["payoutsEnabled"])
        print(json.dumps(result,ensure_ascii=False,sort_keys=True))
        return 0 if result["ready"] else 2
    except Exception:
        # Stripe SDK exceptions may contain API request context: do not print them.
        return fail("Live Stripe secrets, merchant account, or read permissions did not validate")

if __name__ == "__main__":
    raise SystemExit(main())
