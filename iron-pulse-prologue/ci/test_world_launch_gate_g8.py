#!/usr/bin/env python3
"""G8 synthetic launch gate unit tests; NO certification, real users or deployment."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import world_launch_gate_g8 as g8

class GlobalLaunchGateTests(unittest.TestCase):
    S="a"*40
    B="b"*64

    def setUp(self):
        t=tempfile.TemporaryDirectory()
        self.addCleanup(t.cleanup)
        self.root=Path(t.name)
        self.archive=self.root/"synthetic.not-real-game"
        self.archive.write_bytes(b"SYNTHETIC INPUT")
        self.folder=self.root/"privacy-safe"
        self.folder.mkdir()

    def make_packet(self):
        g8dir=self.folder/"g8"
        g8dir.mkdir(exist_ok=True)
        for name in ("g6","g7","g9"):
            (self.folder/name).mkdir(exist_ok=True)
        packet={"schema":g8.SCHEMA, "source_sha":self.S, "bundle_sha256":self.B,
                "production_approved":False,"release_go_granted":False,
                "manual_claims_only":True,"privacy":"roles_and_boolean_claims_only",
                "evidence_review_requested":True,
                "checks":{group:{flag:True for flag in values}
                          for group,values in g8.CATEGORIES.items()}}
        self.write(packet)
        return packet

    def write(self,packet):
        (self.folder/"g8"/"checklist.json").write_text(json.dumps(packet))

    def run_gate(self,upstream_status="READY_FOR_INDEPENDENT_REVIEW",
                 upstream_production=False):
        child={"status":upstream_status,
               "production_approved":upstream_production,
               "commercial_release_allowed":False}
        with patch.object(g8.vault,"verify_archive",
                          return_value={"verified":True,"source_sha":self.S}) as archive, \
             patch.object(g8.g6,"evaluate",return_value=child) as dev, \
             patch.object(g8.g7,"assess",return_value=child) as human, \
             patch.object(g8.g9,"assess",return_value=child) as ops:
            result=g8.assess(self.archive,self.S,self.B,self.folder,"c"*64)
            archive.assert_called_once_with(self.archive,self.S,self.B)
            return result

    def test_01_missing_evidence_hard_hold(self):
        x=self.run_gate()
        self.assertEqual(x["status"],"RELEASE_HOLD")
        self.assertFalse(x["commercial_release_allowed"])

    def test_02_perfect_synthetic_packet_is_only_audit_ready(self):
        self.make_packet()
        out=self.run_gate()
        self.assertEqual(out["status"],"READY_FOR_INDEPENDENT_LAUNCH_AUDIT",out["errors"])
        self.assertFalse(out["production_approved"])
        self.assertFalse(out["human_launch_authorization_authenticated"])
        self.assertFalse(out["real_host_rollout_verified_by_code"])
        self.assertFalse(out["deployment_performed"])

    def test_03_empty_license_check_fails(self):
        p=self.make_packet()
        p["checks"]["rights_and_legal"]["music_voice_and_sound_rights_reviewed"]=False
        self.write(p)
        self.assertIn("rights_and_legal",self.run_gate()["errors"][0])

    def test_04_missing_real_device_gate_fails(self):
        self.make_packet()
        result=self.run_gate(upstream_status="RELEASE_HOLD")
        self.assertEqual(result["status"],"RELEASE_HOLD")
        self.assertEqual(set(result["upstream_statuses"]),{"G6","G7","G9"})

    def test_05_upstream_forged_production_is_rejected(self):
        self.make_packet()
        out=self.run_gate(upstream_production=True)
        self.assertEqual(out["status"],"RELEASE_HOLD")
        self.assertTrue(any("invalid evidence" in e for e in out["errors"]))

    def test_06_unapproved_signoff_required(self):
        p=self.make_packet()
        p["evidence_review_requested"]=False
        self.write(p)
        self.assertEqual(self.run_gate()["status"],"RELEASE_HOLD")
        p=self.make_packet()
        p["release_go_granted"]=True
        self.write(p)
        self.assertEqual(self.run_gate()["status"],"RELEASE_HOLD")

    def test_07_correct_source_and_bundle_bound(self):
        p=self.make_packet()
        p["source_sha"]="d"*40
        self.write(p)
        self.assertEqual(self.run_gate()["status"],"RELEASE_HOLD")
        p=self.make_packet()
        p["bundle_sha256"]="e"*64
        self.write(p)
        self.assertEqual(self.run_gate()["status"],"RELEASE_HOLD")

    def test_08_private_identifiers_not_accepted(self):
        p=self.make_packet()
        p["reviewer_email"]="PRIVATE"
        self.write(p)
        self.assertEqual(self.run_gate()["status"],"RELEASE_HOLD")

    def test_09_duplicate_and_nonfinite_json(self):
        self.make_packet()
        p=self.folder/"g8"/"checklist.json"
        p.write_text('{"schema":"a","schema":"b"}')
        self.assertTrue(any("duplicate" in x for x in self.run_gate()["errors"]))
        p.write_text('{"schema":NaN}')
        self.assertTrue(any("nonfinite" in x for x in self.run_gate()["errors"]))

    def test_10_init_is_denial_by_default(self):
        with patch.object(g8.vault,"verify_archive",
                          return_value={"verified":True,"source_sha":self.S}):
            path=g8.init(self.archive,self.S,self.B,self.folder)
        packet=json.loads(path.read_text())
        self.assertFalse(packet["evidence_review_requested"])
        self.assertFalse(packet["production_approved"])
        self.assertTrue(all(not any(values.values())
                            for values in packet["checks"].values()))
        self.assertEqual(self.run_gate()["status"],"RELEASE_HOLD")

    def test_11_release_archive_integrity_mandatory(self):
        self.make_packet()
        with patch.object(g8.vault,"verify_archive",
                          side_effect=g8.vault.VaultError("tampered binary")):
            with self.assertRaisesRegex(g8.vault.VaultError,"tampered"):
                g8.assess(self.archive,self.S,self.B,self.folder)

if __name__=="__main__":
    unittest.main(verbosity=2)
