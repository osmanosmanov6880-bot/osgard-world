#!/usr/bin/env python3
"""Read-only Stripe LIVE merchant readiness; does not enable checkout or charge cards.

Run only in the backend environment, where account keys are protected by a vault.
Never print keys, customer data, webhook secrets, or provider exception bodies.
"""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"server"))
from core_commerce import Config, StripeProvider, secret

def evaluate(config, account, env):
    expected=getattr(config,"account_id","")
    requirements=account.get("requirements") or {}
    due=requirements.get("currently_due") or []
    checks={
        "commerce_enabled":bool(config.enabled),
        "livemode_configured":bool(config.livemode),
        "game_shop_enabled":env.get("OSGARD_GAME_SHOP_ENABLED")=="1",
        "live_opt_in":env.get("OSGARD_GAME_SHOP_LIVE_APPROVED")=="1",
        "expected_merchant_id_set":bool(env.get("OSGARD_GAME_SHOP_EXPECTED_ACCOUNT_ID")),
        "expected_merchant_matches":bool(expected and env.get("OSGARD_GAME_SHOP_EXPECTED_ACCOUNT_ID")==expected),
        "stripe_id_matches":bool(account.get("id") and account.get("id")==expected),
        "account_country_gb":account.get("country")=="GB",
        "stripe_charges_enabled":account.get("charges_enabled") is True,
        "stripe_payouts_enabled":account.get("payouts_enabled") is True,
        "merchant_details_submitted":account.get("details_submitted") is True,
        "stripe_no_disabled_reason":not requirements.get("disabled_reason"),
        "stripe_no_currently_due":not due,
        "separate_webhook_secret_set":(env.get("OSGARD_GAME_SHOP_WEBHOOK_SECRET","").startswith("whsec_")
                                     or bool(env.get("OSGARD_GAME_SHOP_WEBHOOK_SECRET_FILE"))),
    }
    return {"safeToConsiderActivation":all(checks.values()),"checks":checks,
            "accountCountry":account.get("country","unknown"),
            "stripeIdSuffix":str(account.get("id",""))[-4:],
            "operatorMustStillVerify":["Merchant's informed authorization and payout ownership",
                "Public HTTPS game-shop webhook verified with a genuine Stripe LIVE event",
                "Paid item actually appears in each game and refunds revoke it",
                "Tax/VAT registrations and digital-goods consumer protections",
                "Customer support/refund process and production observability"]}

def main():
    try:
        config=Config.from_env()
    except Exception:
        print(json.dumps({"safeToConsiderActivation":False,"reason":"Commerce configuration missing or invalid"}))
        return 2
    if not config.enabled or not config.livemode:
        print(json.dumps({"safeToConsiderActivation":False,"reason":"No configured live merchant; no Stripe calls were made"}))
        return 2
    try:
        provider=StripeProvider(config)
        raw=provider.client.v1.accounts.retrieve_current()
        acct=raw.to_dict() if hasattr(raw,"to_dict") else dict(raw)
        # Exact merchant verification also takes place at each Checkout.
        report=evaluate(config,acct,os.environ)
    except Exception:
        print(json.dumps({"safeToConsiderActivation":False,"reason":"Merchant API verification failed; inspect restricted server logs without printing credentials"}))
        return 2
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return 0 if report["safeToConsiderActivation"] else 2

if __name__=="__main__":
    raise SystemExit(main())
