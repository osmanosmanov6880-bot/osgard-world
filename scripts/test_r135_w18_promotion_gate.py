#!/usr/bin/env python3
"""Negative W18 promotion tests: synthetic fixtures NEVER count as screenshots/phones."""
from __future__ import annotations
import hashlib
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

SOURCE = Path(__file__).with_name("r135-w18-promotion-qa.py")
SPEC = importlib.util.spec_from_file_location("r135_w18_gate", SOURCE)
gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gate)

def fake_pin():
    return {
        "version": gate.VERSION,
        "source_commit": "a" * 40,
        "manifest_sha256": "b" * 64,
        "archive_sha256": "c" * 64,
        "artifact_run_id": 12345,
        "artifact_id": 789,
        "artifact_name": "osgard-r135-optimized-web-qa",
        "reviewed_portrait": True,
        "reviewed_desktop": True,
        "reviewed_ru_en": True,
        "browser_three_fault_cases": True,
        "physical_phone_fps_verified": False,
        "screenshots_sha256": {
            name: hashlib.sha256(name.encode()).hexdigest()
            for name in gate.REQUIRED_FRAMES
        },
    }

class Contract(unittest.TestCase):
    def test_contract_accepts_well_formed_pin_but_does_not_certify_it(self):
        self.assertIsNone(gate.verify_pin(fake_pin()))

    def test_w14_label_cannot_masquerade_as_w18(self):
        pin = fake_pin()
        pin["version"] = "r135-case-progress-w14-20261025"
        with self.assertRaisesRegex(ValueError, "version"):
            gate.verify_pin(pin)

    def test_missing_source_sha_or_partial_original_frames_rejected(self):
        pin = fake_pin()
        pin["source_commit"] = "latest"
        with self.assertRaisesRegex(ValueError, "source SHA"):
            gate.verify_pin(pin)
        pin = fake_pin()
        pin["screenshots_sha256"].pop("w8-hud-932x430.png")
        with self.assertRaisesRegex(ValueError, "11 original"):
            gate.verify_pin(pin)

    def test_duplicate_screenshots_are_not_independent(self):
        pin = fake_pin()
        pin["screenshots_sha256"]["w17-mobile-ru-operator.png"] = pin["screenshots_sha256"]["w17-desktop-ru-operator.png"]
        with self.assertRaisesRegex(ValueError, "duplicate"):
            gate.verify_pin(pin)

    def test_software_renderer_cannot_claim_physical_phone_fps(self):
        pin = fake_pin()
        pin["physical_phone_fps_verified"] = True
        with self.assertRaisesRegex(ValueError, "physical GPU"):
            gate.verify_pin(pin)

    def test_no_candidate_archive_means_hold_not_pass(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaisesRegex(ValueError, "candidate files missing"):
                gate.review(fake_pin(), Path(d))

    def test_screenshot_filename_and_bytes_alone_do_not_certify(self):
        with tempfile.TemporaryDirectory() as d:
            bad = Path(d) / "w17-mobile-ru-operator.png"
            bad.write_bytes(b"not a png" * 5000)
            with self.assertRaisesRegex(ValueError, "invalid PNG"):
                gate.verify_png(bad, hashlib.sha256(bad.read_bytes()).hexdigest())

    def test_zip_traversal_is_rejected_even_with_declared_hash(self):
        with tempfile.TemporaryDirectory() as d:
            archive = Path(d) / "not-a-release.zip"
            contents = {name: name.encode() for name in
                ("index.html", "index.js", "index.wasm", "index.wasm.gz", "index.pck", "../escape")}
            contents["release.json"] = b"{}"
            with zipfile.ZipFile(archive, "w") as z:
                for name, data in contents.items():
                    z.writestr(name, data)
            manifest = {"files": {
                name: {"size_bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                for name, data in contents.items() if name != "release.json"}}
            with self.assertRaisesRegex(ValueError, "unsafe ZIP"):
                gate.verify_archive(archive, manifest)

if __name__ == "__main__":
    unittest.main()
