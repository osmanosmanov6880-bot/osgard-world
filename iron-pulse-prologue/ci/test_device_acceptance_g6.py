#!/usr/bin/env python3
"""SYNTHETIC ONLY: G6 contract/security tests, NOT actual device results."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import device_acceptance_g6 as g6

class GateTests(unittest.TestCase):
    SHA = "a" * 40

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.zip = self.root / "synthetic.zip"
        self.zip.write_bytes(b"TEST ONLY NOT AN ACTUAL GAME")
        self.bundle = hashlib.sha256(self.zip.read_bytes()).hexdigest()
        self.folder = self.root / "private"
        self.folder.mkdir()
        (self.folder / "reports").mkdir()
        self.counter = 0

    def audit(self):
        with patch.object(g6.vault, "verify_archive",
                          return_value={"source_sha": self.SHA, "verified": True}) as spy:
            ans = g6.evaluate(self.zip, self.SHA, self.bundle, self.folder)
            spy.assert_called_once_with(self.zip, self.SHA, self.bundle)
            return ans

    def report(self, quality):
        self.counter += 1
        avg = 15.0 if quality == "hero" else 25.0
        data = {
            "schema": g6.G4, "format": g6.G4, "status": "complete",
            "source": "actual_current_client_main_loop_delta",
            "main_thread_proxy_not_gpu_profiler": True,
            "frames_captured": int(180000/avg),
            "stored_frame_samples": int(180000/avg),
            "sample_truncated": False, "active_seconds": 180.0,
            "median_ms": 13.0 if quality == "hero" else 21.0,
            "p95_ms": 15.1 if quality == "hero" else 27.1,
            "p99_ms": 18.9 if quality == "hero" else 32.0,
            "average_ms": avg, "estimated_fps": round(1000/avg, 1),
            "hitches_over_50ms": 0, "stalls_over_250ms": 0,
            "paused_frames_excluded": 0,
            "background_interruption_count": 0, "invalid_deltas_excluded": 0,
            "quality_start": quality, "quality_end": quality,
            "quality_changed": False, "viewport_start": [1280,720],
            "viewport_end": [1280,720], "viewport_changed": False,
            "locale_start": "en", "auto_stopped_at_10min": False,
            "comparable_local_run": True, "hardware_physically_verified": False,
            "independent_hardware_certification": False,
            "telemetry_uploaded": False, "account_ids_collected": False,
            "device_fingerprint_collected": False,
        }
        name = "reports/synthetic_%03d.json" % self.counter
        path = self.folder / name
        # Never confuse fixture with physical hardware evidence.
        data["interpretation"] = "SYNTHETIC TEST ONLY"
        path.write_text(json.dumps(data), encoding="utf-8")
        return {"path": name,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    def packet(self):
        data = {"schema": g6.SCHEMA, "source_sha": self.SHA,
                "bundle_sha256": self.bundle, "privacy": "coarse_classes_only",
                "manual_claims_only": True, "production_approved": False,
                "devices": {}}
        for name, (platform, runtime, quality, _) in g6.CLASSES.items():
            data["devices"][name] = {
                "platform": platform, "runtime": runtime, "quality": quality,
                "checks": {flag: True for flag in g6.MANUAL_FLAGS},
                "runs": [{"act": act, "iteration": n,
                          "report": self.report(quality)}
                         for act in g6.ACTS for n in (1,2)],
                "soak": [self.report(quality) for _ in range(10)],
            }
        self.write(data)
        return data

    def write(self, data):
        (self.folder/"evidence.json").write_text(json.dumps(data), encoding="utf-8")

    def test_01_no_hardware_means_hold(self):
        x = self.audit()
        self.assertEqual(x["status"], "RELEASE_HOLD")
        self.assertFalse(x["commercial_release_allowed"])

    def test_02_complete_synthetic_input_never_certifies(self):
        self.packet()
        x = self.audit()
        self.assertEqual(x["status"], "READY_FOR_INDEPENDENT_REVIEW", x["errors"])
        self.assertEqual(x["validated_g4_reports"], 80)
        self.assertFalse(x["physical_hardware_independently_verified"])
        self.assertFalse(x["production_approved"])

    def test_03_iphone_required(self):
        x = self.packet()
        del x["devices"]["iphone_safari"]
        self.write(x)
        self.assertEqual(self.audit()["status"], "RELEASE_HOLD")

    def test_04_integrity_required(self):
        x = self.packet()
        x["devices"]["windows_integrated"]["runs"][0]["report"]["sha256"] = "f"*64
        self.write(x)
        self.assertIn("SHA-256", self.audit()["errors"][0])

    def test_05_independent_samples_required(self):
        x = self.packet()
        a = x["devices"]["android_entry"]["runs"]
        a[1]["report"] = a[0]["report"]
        self.write(x)
        self.assertIn("reused", self.audit()["errors"][0])

    def test_06_controls_required(self):
        x = self.packet()
        x["devices"]["iphone_safari"]["checks"]["controls_pass"] = False
        self.write(x)
        self.assertEqual(self.audit()["status"], "RELEASE_HOLD")

    def test_07_performance_gate(self):
        x = self.packet()
        ref = x["devices"]["windows_discrete"]["runs"][0]["report"]
        path = self.folder/ref["path"]
        data = json.loads(path.read_text())
        data["p95_ms"] = 38
        data["p99_ms"] = 49
        path.write_text(json.dumps(data))
        ref["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.write(x)
        self.assertIn("p95", self.audit()["errors"][0])

    def test_08_forged_device_certification(self):
        x = self.packet()
        ref = x["devices"]["iphone_safari"]["runs"][0]["report"]
        path = self.folder/ref["path"]
        data = json.loads(path.read_text())
        data["hardware_physically_verified"] = True
        path.write_text(json.dumps(data))
        ref["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.write(x)
        self.assertIn("certification", self.audit()["errors"][0])

    def test_09_path_traversal(self):
        x = self.packet()
        x["devices"]["iphone_safari"]["soak"][0]["path"] = "../secrets.json"
        self.write(x)
        self.assertIn("path", self.audit()["errors"][0])

    def test_10_private_identifiers_forbidden(self):
        x = self.packet()
        x["devices"]["android_entry"]["serial"] = "PRIVATE"
        self.write(x)
        self.assertIn("unknown field", self.audit()["errors"][0])

    def test_11_source_and_bundle_bound(self):
        x = self.packet()
        x["source_sha"] = "b"*40
        self.write(x)
        self.assertEqual(self.audit()["status"], "RELEASE_HOLD")
        x["source_sha"] = self.SHA
        x["bundle_sha256"] = "b"*64
        self.write(x)
        self.assertEqual(self.audit()["status"], "RELEASE_HOLD")

    def test_12_duplicate_json_and_nan(self):
        self.packet()
        path = self.folder/"evidence.json"
        path.write_text('{"schema":"A","schema":"B"}')
        self.assertIn("duplicate", self.audit()["errors"][0])
        path.write_text('{"schema":NaN}')
        self.assertIn("nonfinite", self.audit()["errors"][0])

    def test_13_short_soak(self):
        x = self.packet()
        x["devices"]["windows_integrated"]["soak"] = (
            x["devices"]["windows_integrated"]["soak"][:7])
        self.write(x)
        self.assertIn("30 active", self.audit()["errors"][0])

    def test_14_fake_production_go(self):
        x = self.packet()
        x["production_approved"] = True
        self.write(x)
        self.assertEqual(self.audit()["status"], "RELEASE_HOLD")

    def test_15_symlinked_report(self):
        x = self.packet()
        ref = x["devices"]["windows_integrated"]["runs"][0]["report"]
        path = self.folder/ref["path"]
        elsewhere = self.root/"test.json"
        path.replace(elsewhere)
        try:
            path.symlink_to(elsewhere)
        except OSError:
            self.skipTest("symlink unavailable")
        self.write(x)
        self.assertIn("symlink", self.audit()["errors"][0])

    def test_16_empty_template(self):
        with patch.object(g6.vault, "verify_archive",
                          return_value={"source_sha": self.SHA, "verified": True}):
            path = g6.initialize(self.zip, self.SHA, self.bundle, self.root/"empty")
        x = json.loads(path.read_text())
        self.assertTrue(all(not any(v["checks"].values())
                            for v in x["devices"].values()))
        self.assertTrue(all(not v["soak"] for v in x["devices"].values()))

    def test_17_noncomparable_capture(self):
        x = self.packet()
        ref = x["devices"]["iphone_safari"]["runs"][0]["report"]
        path = self.folder/ref["path"]
        data = json.loads(path.read_text())
        data["sample_truncated"] = True
        path.write_text(json.dumps(data))
        ref["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.write(x)
        self.assertIn("incomparable", self.audit()["errors"][0])

if __name__ == "__main__":
    unittest.main(verbosity=2)
