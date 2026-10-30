#!/usr/bin/env python3
"""G9 SYNTHETIC incident and operator-packet tests. No real hosting or incidents."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import operations_g9 as g9

class OfflineOperationsTests(unittest.TestCase):
    SOURCE="a"*40
    BUNDLE="b"*64

    def setUp(self):
        t=tempfile.TemporaryDirectory()
        self.addCleanup(t.cleanup)
        self.root=Path(t.name)
        self.folder=self.root/"private"
        self.folder.mkdir()
        self.archive=self.root/"NOT-A-REAL-GAME.zip"
        self.archive.write_bytes(b"FICTIONAL SYNTHETIC UNIT TEST INPUT")
        self.fake={"verified":True,"source_sha":self.SOURCE}

    def verify(self,head=None):
        with patch.object(g9.vault,"verify_archive",return_value=self.fake):
            return g9.assess(self.archive,self.SOURCE,self.BUNDLE,self.folder,head)

    def init(self):
        with patch.object(g9.vault,"verify_archive",return_value=self.fake):
            g9.init(self.archive,self.SOURCE,self.BUNDLE,self.folder)
        return self.packet()

    def packet(self):
        return json.loads((self.folder/"ops.json").read_text())

    def write(self,data):
        (self.folder/"ops.json").write_text(json.dumps(data))

    def enable(self):
        data=self.packet()
        data["checks"]={k:True for k in g9.CHECKS}
        data["independent_review_requested"]=True
        self.write(data)

    def drill(self,incident="DRILL-0001"):
        head="none"
        for step in g9.STEPS:
            head=g9.append(self.folder,self.SOURCE,self.BUNDLE,incident,
                           step,"SYNTHETIC_STEP",head)
        return head

    def test_01_missing_evidence_hard_hold(self):
        x=self.verify()
        self.assertEqual(x["status"],"RELEASE_HOLD")
        self.assertFalse(x["commercial_release_allowed"])

    def test_02_blank_operator_packet_is_safe(self):
        p=self.init()
        self.assertEqual(set(p["checks"]),set(g9.CHECKS))
        self.assertFalse(any(p["checks"].values()))
        self.assertFalse(p["production_approved"])
        self.assertEqual(g9.verify_events(self.folder,self.SOURCE,self.BUNDLE)["event_count"],0)
        self.assertEqual(self.verify()["status"],"RELEASE_HOLD")

    def test_03_full_drill_can_only_request_human_review(self):
        self.init()
        self.enable()
        head=self.drill()
        x=self.verify(head)
        self.assertEqual(x["status"],"READY_FOR_INDEPENDENT_REVIEW",x["errors"])
        self.assertEqual(x["completed_offline_drills"],1)
        self.assertEqual(x["event_count"],5)
        self.assertFalse(x["independent_operator_authenticated"])
        self.assertFalse(x["real_production_incidents_observed"])
        self.assertFalse(x["commercial_release_allowed"])

    def test_04_chain_tamper_is_detected(self):
        self.init()
        self.drill()
        path=self.folder/"incidents.jsonl"
        rows=path.read_text().splitlines()
        event=json.loads(rows[0])
        event["note_code"]="TAMPERED"
        rows[0]=json.dumps(event)
        path.write_text("\n".join(rows)+"\n")
        with self.assertRaisesRegex(g9.OpsError,"digest mismatch"):
            g9.verify_events(self.folder,self.SOURCE,self.BUNDLE)

    def test_05_wrong_CAS_blocks_replay(self):
        self.init()
        old=g9.append(self.folder,self.SOURCE,self.BUNDLE,
                      "DRILL-0001","OPEN","SYNTHETIC_STEP","none")
        with self.assertRaisesRegex(g9.OpsError,"CAS mismatch"):
            g9.append(self.folder,self.SOURCE,self.BUNDLE,
                      "DRILL-0001","TRIAGE","SYNTHETIC_STEP","none")
        self.assertEqual(g9.verify_events(self.folder,self.SOURCE,self.BUNDLE)["head_sha256"],old)

    def test_06_illegal_transition_blocks(self):
        self.init()
        with self.assertRaisesRegex(g9.OpsError,"state transition"):
            g9.append(self.folder,self.SOURCE,self.BUNDLE,
                      "DRILL-0001","CLOSE","SYNTHETIC_STEP","none")
        self.assertEqual((self.folder/"incidents.jsonl").stat().st_size,0)

    def test_07_missing_external_hash_is_only_hold(self):
        self.init()
        self.enable()
        self.drill()
        self.assertEqual(self.verify()["status"],"RELEASE_HOLD")
        self.assertEqual(self.verify("f"*64)["status"],"RELEASE_HOLD")

    def test_08_no_forged_production_or_private_fields(self):
        self.init()
        self.enable()
        head=self.drill()
        data=self.packet()
        data["production_approved"]=True
        self.write(data)
        self.assertEqual(self.verify(head)["status"],"RELEASE_HOLD")
        data["production_approved"]=False
        data["operator_email"]="PRIVATE"
        self.write(data)
        self.assertEqual(self.verify(head)["status"],"RELEASE_HOLD")

    def test_09_incomplete_drill_blocks(self):
        self.init()
        self.enable()
        head=g9.append(self.folder,self.SOURCE,self.BUNDLE,
                       "DRILL-0001","OPEN","SYNTHETIC_STEP","none")
        self.assertEqual(self.verify(head)["status"],"RELEASE_HOLD")

    def test_10_cannot_reopen_closed_drill(self):
        self.init()
        self.drill()
        head=g9.verify_events(self.folder,self.SOURCE,self.BUNDLE)["head_sha256"]
        with self.assertRaisesRegex(g9.OpsError,"state transition"):
            g9.append(self.folder,self.SOURCE,self.BUNDLE,
                      "DRILL-0001","OPEN","SYNTHETIC_STEP",head)

    def test_11_different_source_breaks_evidence(self):
        self.init()
        self.drill()
        with self.assertRaisesRegex(g9.OpsError,"mismatch"):
            g9.verify_events(self.folder,"c"*40,self.BUNDLE)

    def test_12_invalid_note_not_PII(self):
        self.init()
        with self.assertRaisesRegex(g9.OpsError,"private note"):
            g9.append(self.folder,self.SOURCE,self.BUNDLE,
                      "DRILL-0001","OPEN","someone@example.test","none")

if __name__=="__main__":
    unittest.main(verbosity=2)
