#!/usr/bin/env python3
"""Negative-only fixtures. A unit test passing NEVER counts as W19 production QA."""
import importlib.util
import hashlib
import tempfile
import unittest
from pathlib import Path

GATE = Path(__file__).with_name("r135-w19-promotion-qa.py")
spec = importlib.util.spec_from_file_location("r135_w19_gate", GATE)
assert spec and spec.loader
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def example_pin() -> dict:
    return {
        "version": gate.VERSION,
        "source_commit": "a" * 40,
        "manifest_sha256": "b" * 64,
        "archive_sha256": "c" * 64,
        "artifact_id": 456,
        "artifact_run_id": 123,
        "artifact_name": "osgard-r135-optimized-web-qa",
        "reviewed_luxury_desktop": True,
        "reviewed_luxury_mobile": True,
        "reviewed_no_overlap": True,
        "reviewed_ru_en": True,
        "browser_three_fault_cases": True,
        "physical_phone_fps_verified": False,
        "photorealistic_aaa_certified": False,
        "screenshots_sha256": {
            name: hashlib.sha256(("original-" + name).encode()).hexdigest()
            for name in gate.FRAMES
        },
    }


class W19Guard(unittest.TestCase):
    def test_strict_13_images_contract(self):
        self.assertEqual(len(gate.FRAMES), 13)
        self.assertIsNone(gate.verify_pin(example_pin()))

    def test_w18_and_arbitrary_source_rejected(self):
        pin = example_pin()
        pin["version"] = "r135-premium-learning-w18-candidate-20261025"
        with self.assertRaisesRegex(ValueError, "version"):
            gate.verify_pin(pin)
        pin = example_pin()
        pin["source_commit"] = "main"
        with self.assertRaisesRegex(ValueError, "SHA"):
            gate.verify_pin(pin)

    def test_duplicate_screenshot_or_missing_mobile_welcome_rejected(self):
        pin = example_pin()
        pin["screenshots_sha256"].pop("w19-mobile-390-russian-luxury-welcome.png")
        with self.assertRaisesRegex(ValueError, "13"):
            gate.verify_pin(pin)
        pin = example_pin()
        pin["screenshots_sha256"][gate.FRAMES[-1]] = pin["screenshots_sha256"][gate.FRAMES[0]]
        with self.assertRaisesRegex(ValueError, "duplicated"):
            gate.verify_pin(pin)

    def test_missing_human_review_rejected(self):
        for flag in ("reviewed_luxury_desktop", "reviewed_luxury_mobile",
                     "reviewed_no_overlap", "reviewed_ru_en", "browser_three_fault_cases"):
            pin = example_pin()
            pin[flag] = False
            with self.assertRaisesRegex(ValueError, "review"):
                gate.verify_pin(pin)

    def test_forged_gpu_and_aaa_claims_rejected(self):
        pin = example_pin()
        pin["physical_phone_fps_verified"] = True
        with self.assertRaisesRegex(ValueError, "SwiftShader"):
            gate.verify_pin(pin)
        pin = example_pin()
        pin["photorealistic_aaa_certified"] = True
        with self.assertRaisesRegex(ValueError, "AAA"):
            gate.verify_pin(pin)

    def test_wrong_artifact_provenance_rejected(self):
        pin = example_pin()
        pin["artifact_name"] = "arbitrary-files"
        with self.assertRaisesRegex(ValueError, "artifact"):
            gate.verify_pin(pin)
        pin = example_pin()
        pin["artifact_run_id"] = 0
        with self.assertRaisesRegex(ValueError, "artifact_run_id"):
            gate.verify_pin(pin)
        pin = example_pin()
        pin["archive_sha256"] = "changed"
        with self.assertRaisesRegex(ValueError, "SHA"):
            gate.verify_pin(pin)

    def test_no_actual_godot_artifact_is_hold(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, "archive missing"):
                gate.review(example_pin(), Path(temp))


if __name__ == "__main__":
    unittest.main()
