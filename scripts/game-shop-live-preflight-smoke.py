#!/usr/bin/env python3
"""Unit tests for read-only LIVE eligibility; no Stripe network calls."""
import importlib.util
import os
import sys
import unittest
from pathlib import Path
p=Path(__file__).resolve().parent/"game-shop-live-preflight.py"
spec=importlib.util.spec_from_file_location("game_shop_preflight",p)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Verification(unittest.TestCase):
 def env(self):
  return dict(OSGARD_GAME_SHOP_ENABLED="1",OSGARD_GAME_SHOP_LIVE_APPROVED="1",
   OSGARD_GAME_SHOP_EXPECTED_ACCOUNT_ID="acct_verified_123",
   OSGARD_GAME_SHOP_WEBHOOK_SECRET="whsec_mock_signature_not_real")
 def conf(self):
  return type("Config",(),dict(enabled=True,livemode=True,account_id="acct_verified_123"))()
 def account(self):
  return dict(id="acct_verified_123",country="GB",charges_enabled=True,
              payouts_enabled=True,details_submitted=True,
              requirements={"currently_due":[],"disabled_reason":None})
 def test_eligible_flags_do_not_certify_manual_business_requirements(self):
  result=m.evaluate(self.conf(),self.account(),self.env())
  self.assertTrue(result["safeToConsiderActivation"])
  self.assertEqual(len(result["operatorMustStillVerify"]),5)
 def test_wrong_country(self):
  account=self.account();account["country"]="RU"
  self.assertFalse(m.evaluate(self.conf(),account,self.env())["safeToConsiderActivation"])
 def test_wrong_account(self):
  env=self.env();env["OSGARD_GAME_SHOP_EXPECTED_ACCOUNT_ID"]="acct_wrong"
  self.assertFalse(m.evaluate(self.conf(),self.account(),env)["safeToConsiderActivation"])
 def test_payouts_not_ready(self):
  account=self.account();account["payouts_enabled"]=False
  self.assertFalse(m.evaluate(self.conf(),account,self.env())["safeToConsiderActivation"])
 def test_disabled_reason(self):
  account=self.account();account["requirements"]["disabled_reason"]="requirements.past_due"
  self.assertFalse(m.evaluate(self.conf(),account,self.env())["safeToConsiderActivation"])
 def test_no_webhook(self):
  env=self.env();env.pop("OSGARD_GAME_SHOP_WEBHOOK_SECRET")
  self.assertFalse(m.evaluate(self.conf(),self.account(),env)["safeToConsiderActivation"])
 def test_live_opt_in_required(self):
  env=self.env();env.pop("OSGARD_GAME_SHOP_LIVE_APPROVED")
  self.assertFalse(m.evaluate(self.conf(),self.account(),env)["safeToConsiderActivation"])
if __name__=="__main__":unittest.main()
