#!/usr/bin/env python3
"""W75 fully offline red-team QA of honest release gate: no fake approvals."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from release_gate import (
    BASE_W74_SHA, REPORT_SCHEMA, SCHEMA,
    _artifact, blank_manifest, evaluate,
)


class W75NoFalseRelease(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.m = blank_manifest()

    def tearDown(self):
        self.tmp.cleanup()

    def proof(self, path="evidence/sample.log", data=b"actual fixture bytes"):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return path, hashlib.sha256(data).hexdigest()

    def test_01_blank_source_bound_manifest_never_approves(self):
        report = evaluate(self.m, self.root)
        self.assertEqual(report["schema"], REPORT_SCHEMA)
        self.assertEqual(report["evidence_completeness"], "INCOMPLETE")
        self.assertEqual(report["next_state"], "PRODUCTION_HOLD")
        self.assertFalse(report["production_release_authorized_by_software"])
        self.assertFalse(report["master_branch_merge_authorized_by_software"])
        self.assertEqual(report["statistics"]["evidence_checked_first_time_sessions"], 0)

    def test_02_changed_source_is_explicitly_rejected(self):
        self.m["source_sha"] = "0" * 40
        report = evaluate(self.m, self.root)
        self.assertFalse(report["checks"]["exact_source_sha"])
        self.assertEqual(report["machine_audit"], "FAIL")
        self.assertEqual(report["next_state"], "PRODUCTION_HOLD")

    def test_03_real_file_bytes_hashed_not_claims(self):
        f, digest = self.proof()
        self.assertTrue(_artifact(self.root, f, digest))
        self.assertFalse(_artifact(self.root, f, "0" * 64))
        self.assertFalse(_artifact(self.root, "nonexistent", digest))
        self.assertFalse(_artifact(self.root, f, "not_a_hash"))

    def test_04_path_traversal_never_opened(self):
        outside = self.root.parent / "not_in_qa_folder.log"
        f, digest = self.proof()
        self.assertFalse(_artifact(self.root, "../not_in_qa_folder.log", digest))
        self.assertFalse(_artifact(self.root, outside.as_posix(), digest))
        self.assertFalse(_artifact(self.root, "./../../file", digest))
        self.assertFalse(_artifact(self.root, "", digest))

    def test_05_symlink_out_of_root_never_opened(self):
        with tempfile.TemporaryDirectory() as external:
            content = Path(external) / "outside.log"
            content.write_text("outside")
            link = self.root / "attacker-symlink.log"
            try:
                link.symlink_to(content)
            except (OSError, NotImplementedError):
                self.skipTest("OS does not permit symlinks")
            self.assertFalse(_artifact(
                self.root, link.name,
                hashlib.sha256(content.read_bytes()).hexdigest()))

    def test_06_synthetic_twelve_player_records_do_not_count(self):
        f, digest = self.proof()
        for n in range(12):
            self.m["first_time_playtests"].append({
                "session_id": f"fixture_{n}",
                "participant_code": f"pseudonym_{n}",
                "source_sha": BASE_W74_SHA,
                "duration_seconds": 730,
                "confusion_events": 0,
                "synthetic": True,
                "completed": True,
                "first_time_player": True,
                "explicit_consent": True,
                "observed_by_real_human": True,
                "independent_observer_code": "SYNTHETIC_ONLY",
                "local_evidence_file": f,
                "local_evidence_sha256": digest,
            })
        report = evaluate(self.m, self.root)
        self.assertEqual(report["statistics"]["submitted_sessions"], 12)
        self.assertEqual(report["statistics"]["evidence_checked_first_time_sessions"], 0)
        self.assertFalse(report["checks"]["human_playtests"])

    def test_07_duplicate_pseudonyms_not_counted_twice(self):
        self.m["privacy"]["collected_with_express_consent"] = True
        f, digest = self.proof()
        base = {
            "session_id": "native_1", "participant_code": "code_1",
            "source_sha": BASE_W74_SHA,"duration_seconds": 710,
            "confusion_events": 0,"synthetic": False,
            "completed": True,"first_time_player": True,
            "explicit_consent": True,"observed_by_real_human": True,
            "independent_observer_code":"observer_fixture",
            "local_evidence_file":f, "local_evidence_sha256":digest,
        }
        self.m["first_time_playtests"] = [
            base, {**base, "session_id":"native_2"},
            {**base, "participant_code":"code_3"},
        ]
        report = evaluate(self.m,self.root)
        self.assertEqual(
            report["statistics"]["evidence_checked_first_time_sessions"],1)
        self.assertFalse(report["checks"]["enough_unique_real_observed_sessions"])

    def test_08_personally_identifying_emails_not_allowed_as_codes(self):
        f, digest = self.proof()
        self.m["first_time_playtests"] = [{
            "session_id":"session01","participant_code":"person@example.com",
            "source_sha":BASE_W74_SHA,"duration_seconds":700,
            "confusion_events":0,"synthetic":False,"completed":True,
            "first_time_player":True,"explicit_consent":True,
            "observed_by_real_human":True,
            "independent_observer_code":"observer01",
            "local_evidence_file":f, "local_evidence_sha256":digest,
        }]
        report=evaluate(self.m,self.root)
        self.assertEqual(report["statistics"]["evidence_checked_first_time_sessions"],0)

    def test_09_hardware_ci_fps_never_counts_as_physical_device(self):
        f, digest = self.proof()
        self.m["physical_device_tests"] = [{
            "device_class":"desktop_windows",
            "physical_device_used":False,
            "human_observer_confirmed":True,
            "synthetic":False,"device_model":"CI SwiftShader",
            "gpu_name":"Software only","source_sha":BASE_W74_SHA,
            "observed_fps_median":400,"observed_p95_frame_ms":1,
            "native_render_samples":99999,
            "local_evidence_file":f,"local_evidence_sha256":digest,
        }]
        report=evaluate(self.m,self.root)
        self.assertFalse(report["checks"]["real_hardware"])
        self.assertEqual(
            report["statistics"]["evidence_checked_physical_device_classes"],[])

    def test_10_owner_click_cannot_auto_publish_without_proof(self):
        self.m["owner_release_consent"]["explicit_go"]=True
        report=evaluate(self.m,self.root)
        self.assertFalse(report["checks"]["actual_explicit_owner_go_document"])
        self.assertFalse(report["production_release_authorized_by_software"])
        self.assertEqual(report["next_state"],"PRODUCTION_HOLD")

    def test_11_invalid_art_law_attestation_never_implies_rights(self):
        self.m["art_direction"].update({
            "independent_reviewer_code":"in_test_only",
            "approved_environment":True,"approved_animation":True,
            "approved_audio":True,"approved_narrative":True,
            "asset_rights_reviewed":True,
        })
        self.m["legal"].update({
            "final_distinct_name":"ONLY_A_TEST_STRING",
            "trademark_clearance_reviewed":True,
            "assets_and_audio_license_cleared":True,
            "jurisdiction_reviewed":["ONLY_TEST"],
        })
        report=evaluate(self.m,self.root)
        self.assertFalse(report["checks"]["independent_original_art_signoff"])
        self.assertFalse(report["checks"]["original_name_and_licenses_cleared"])

    def test_12_third_party_data_malformed_or_oversized_is_safe(self):
        self.m["first_time_playtests"] = "not a list"
        self.m["physical_device_tests"] = [None,{},False]
        self.m["art_direction"] = "yes"
        self.m["legal"] = ["no"]
        self.m["privacy"] = None
        report=evaluate(self.m,self.root)
        self.assertEqual(report["next_state"],"PRODUCTION_HOLD")
        self.assertTrue(len(report["findings"])>=4)

    def test_13_protect_case_fake_negative_and_nonfinite_timings(self):
        self.m["first_time_playtests"]=[{
            "session_id":"case","participant_code":"p1",
            "duration_seconds":float("nan"),
            "confusion_events":0,
            "synthetic":False,
            "completed":True,
        }]
        self.m["physical_device_tests"]=[{
            "device_class":"android",
            "physical_device_used":True,
            "human_observer_confirmed":True,
            "synthetic":False,
            "observed_fps_median":float("inf"),
            "observed_p95_frame_ms":-1,
            "native_render_samples":999999,
        }]
        report=evaluate(self.m,self.root)
        self.assertFalse(report["checks"]["real_hardware"])
        self.assertFalse(report["checks"]["human_playtests"])

    def test_14_fake_json_or_fake_native_binary_cannot_pass_build(self):
        a,hash_a=self.proof("build/W74_SOURCE_AUDIT.json",b'not a valid source audit JSON')
        b,hash_b=self.proof("build/evidence.json",b'fabricated JSON placeholder')
        self.m["build"].update({
            "source_verification_file":a,
            "source_verification_sha256":hash_a,
            "webgl_export_manifest_file":b,
            "webgl_export_manifest_sha256":hash_b,
            "webgl_binary_file":"build/missing.wasm",
            "webgl_binary_sha256":"1"*64,
            "webgl_pck_file":"build/missing.pck",
            "webgl_pck_sha256":"2"*64,
        })
        report=evaluate(self.m,self.root)
        self.assertFalse(report["checks"]["build_evidence"])
        self.assertFalse(report["checks"]["local_source_audit_file_hash"])
        self.assertFalse(report["checks"]["local_native_webgl_manifest_hash"])
        self.assertFalse(report["checks"]["human_playtests"])
        self.assertEqual(report["next_state"],"PRODUCTION_HOLD")
        self.assertFalse(report["steam_or_public_domain_publish_authorized_by_software"])


if __name__=="__main__":
    unittest.main(verbosity=2)
