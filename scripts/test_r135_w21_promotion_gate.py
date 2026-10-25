#!/usr/bin/env python3
"""Negative-only W21 test data. PASS here never means the artifact was reviewed."""
import importlib.util
import hashlib
import tempfile
import unittest
from pathlib import Path

path = Path(__file__).with_name("r135-w21-promotion-qa.py")
spec = importlib.util.spec_from_file_location("r135_w21_release_gate", path)
assert spec and spec.loader
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def sample() -> dict:
    return {
        "version": gate.VERSION, "source_commit": "a" * 40,
        "archive_sha256": "b" * 64, "manifest_sha256": "c" * 64,
        "artifact_id": 110, "artifact_run_id": 111, "native_run_id": 112,
        "artifact_name": "osgard-r135-optimized-web-qa",
        "reviewed_luxury_desktop": True,
        "reviewed_luxury_mobile": True,
        "reviewed_settings_desktop": True,
        "reviewed_settings_mobile": True,
        "reviewed_settings_persistence": True,
        "reviewed_coach_desktop": True,
        "reviewed_coach_mobile": True,
        "reviewed_real_causal_errors": True,
        "reviewed_no_overlap": True,
        "reviewed_ru_en": True,
        "browser_three_fault_cases": True,
        "physical_phone_fps_verified": False,
        "photorealistic_aaa_certified": False,
        "screenshots_sha256": {
            name: hashlib.sha256(("real-frame-" + name).encode()).hexdigest()
            for name in gate.FRAMES
        },
    }


class W21FailClosed(unittest.TestCase):
    def test_17_real_original_frame_contract(self):
        self.assertEqual(len(gate.FRAMES), 17)
        self.assertIsNone(gate.verify_pin(sample()))

    def test_wrong_versions_and_native_run_id(self):
        pin = sample()
        pin["version"] = "r135-player-settings-w20-candidate-20261025"
        with self.assertRaisesRegex(ValueError, "version"):
            gate.verify_pin(pin)
        pin = sample()
        pin["native_run_id"] = 0
        with self.assertRaisesRegex(ValueError, "native_run_id"):
            gate.verify_pin(pin)

    def test_missing_mobile_coach_or_duplicate_frame_rejected(self):
        pin = sample()
        pin["screenshots_sha256"].pop("w21-mobile-390-explainable-course.png")
        with self.assertRaisesRegex(ValueError, "17"):
            gate.verify_pin(pin)
        pin = sample()
        pin["screenshots_sha256"][gate.FRAMES[0]] = pin["screenshots_sha256"][gate.FRAMES[1]]
        with self.assertRaisesRegex(ValueError, "duplicated"):
            gate.verify_pin(pin)

    def test_unreviewed_real_settings_rejected(self):
        for required in ("reviewed_settings_desktop", "reviewed_settings_mobile",
                         "reviewed_settings_persistence", "reviewed_coach_desktop",
                         "reviewed_coach_mobile", "reviewed_real_causal_errors",
                         "reviewed_no_overlap",
                         "reviewed_ru_en", "browser_three_fault_cases"):
            pin = sample()
            pin[required] = False
            with self.assertRaisesRegex(ValueError, "review"):
                gate.verify_pin(pin)

    def test_hardware_and_aaa_not_auto_certified(self):
        pin = sample()
        pin["physical_phone_fps_verified"] = True
        with self.assertRaisesRegex(ValueError, "SwiftShader"):
            gate.verify_pin(pin)
        pin = sample()
        pin["photorealistic_aaa_certified"] = True
        with self.assertRaisesRegex(ValueError, "AAA"):
            gate.verify_pin(pin)

    def test_missing_real_binary_is_hold(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "archive missing"):
                gate.review(sample(), Path(folder))


if __name__ == "__main__":
    unittest.main()
