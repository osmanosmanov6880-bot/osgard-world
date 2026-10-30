#!/usr/bin/env python3
"""G7 synthetic acceptance tests, NOT human studies or source-bound game exports."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import human_playtest_g7 as g7

class PlaytestGateTests(unittest.TestCase):
    S = "a"*40

    def setUp(self):
        t = tempfile.TemporaryDirectory()
        self.addCleanup(t.cleanup)
        self.root = Path(t.name)
        self.bundle = "b"*64
        self.zip = self.root/"synthetic.not-a-game"
        self.zip.write_bytes(b"SYNTHETIC ONLY")
        self.dir = self.root/"evidence"
        self.dir.mkdir()

    def run_gate(self):
        with patch.object(g7.vault,"verify_archive",
                          return_value={"verified":True, "source_sha":self.S}) as fn:
            result = g7.assess(self.zip,self.S,self.bundle,self.dir)
            fn.assert_called_once_with(self.zip,self.S,self.bundle)
            return result

    def fixture(self, count=20):
        actors=[]
        for n in range(count):
            actors.append({
                "id":"P-%012x"%(n+1), "consent_claimed":True, "withdrawn":False,
                "locale":"ru" if n%2==0 else "en",
                "platform":("windows","android","ios")[n%3],
                "acts":[{"act":name,"completed":True,"duration_seconds":180+n,
                         "restarts":n%3} for name in g7.ACTS],
                "ratings":{k:4 for k in g7.METRICS},
                "feedback_code":"synthetic_%02d"%n
            })
        packet={"schema":g7.SCHEMA, "source_sha":self.S,
                "bundle_sha256":self.bundle,
                "privacy":"anonymous_codes_only", "manual_claims_only":True,
                "production_approved":False,"participants":actors,"bugs":[],
                "independent_review_requested":True}
        self.write(packet)
        return packet

    def write(self, packet):
        (self.dir/"trials.json").write_text(json.dumps(packet),encoding="utf-8")

    def test_01_no_players_hard_hold(self):
        out=self.run_gate()
        self.assertEqual(out["status"],"RELEASE_HOLD")
        self.assertFalse(out["human_participants_independently_verified"])

    def test_02_complete_synthetic_packet_is_only_review_ready(self):
        self.fixture()
        out=self.run_gate()
        self.assertEqual(out["status"],"READY_FOR_INDEPENDENT_REVIEW",out["errors"])
        self.assertEqual(out["claimed_completed_three_acts"],20)
        self.assertFalse(out["commercial_release_allowed"])
        self.assertFalse(out["human_participants_independently_verified"])

    def test_03_fake_user_and_private_identifier(self):
        p=self.fixture()
        p["participants"][1]["email"]="should-not-be-collected@example.test"
        self.write(p)
        self.assertIn("unknown field",self.run_gate()["errors"][0])

    def test_04_fake_consent_or_withdrawal(self):
        p=self.fixture()
        p["participants"][0]["withdrawn"]=True
        self.write(p)
        self.assertIn("withdrawn",self.run_gate()["errors"][0])

    def test_05_duplicate_player_codes_rejected(self):
        p=self.fixture()
        p["participants"][1]["id"]=p["participants"][0]["id"]
        self.write(p)
        self.assertIn("duplicate",self.run_gate()["errors"][0])

    def test_06_missing_language_or_act(self):
        p=self.fixture()
        for v in p["participants"]: v["locale"]="en"
        self.write(p)
        self.assertIn("language",self.run_gate()["errors"][0])
        p=self.fixture()
        p["participants"][0]["acts"][2]["act"]="GRID"
        self.write(p)
        self.assertIn("duplicate act",self.run_gate()["errors"][0])

    def test_07_unresolved_p0_or_p1_blocks(self):
        p=self.fixture()
        p["bugs"]=[{"id":"BUG-001","severity":"P0","state":"open",
                    "reproduced":True,"regression_test":False}]
        self.write(p)
        self.assertIn("critical blockers",self.run_gate()["errors"][0])
        p["bugs"][0].update({"state":"verified","regression_test":True})
        self.write(p)
        self.assertEqual(self.run_gate()["status"],"READY_FOR_INDEPENDENT_REVIEW")

    def test_08_20_completed_and_80_percent_required(self):
        p=self.fixture(24)
        for v in p["participants"][:5]:
            v["acts"][1]["completed"]=False
        self.write(p)
        self.assertIn("80%",self.run_gate()["errors"][0])
        p=self.fixture(20)
        p["participants"][0]["acts"][1]["completed"]=False
        self.write(p)
        self.assertIn("20 complete",self.run_gate()["errors"][0])

    def test_09_release_binding_and_forged_go(self):
        p=self.fixture()
        p["bundle_sha256"]="f"*64
        self.write(p)
        self.assertEqual(self.run_gate()["status"],"RELEASE_HOLD")
        p=self.fixture()
        p["production_approved"]=True
        self.write(p)
        self.assertIn("production",self.run_gate()["errors"][0])

    def test_10_json_duplicates_and_nan(self):
        p=self.dir/"trials.json"
        p.write_text('{"schema":"A","schema":"B"}',encoding="utf-8")
        self.assertIn("duplicate",self.run_gate()["errors"][0])
        p.write_text('{"schema":NaN}',encoding="utf-8")
        self.assertIn("nonfinite",self.run_gate()["errors"][0])

    def test_11_empty_template_never_certifies(self):
        with patch.object(g7.vault,"verify_archive",
                          return_value={"verified":True,"source_sha":self.S}):
            target=g7.init(self.zip,self.S,self.bundle,self.dir)
        p=json.loads(target.read_text())
        self.assertEqual(p["participants"],[])
        self.assertFalse(p["independent_review_requested"])
        self.assertEqual(self.run_gate()["status"],"RELEASE_HOLD")

if __name__=="__main__":
    unittest.main(verbosity=2)
