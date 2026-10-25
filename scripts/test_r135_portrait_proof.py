#!/usr/bin/env python3
"""Unit contracts only, NEVER release evidence: WebGL screenshot provenance."""
from __future__ import annotations

import hashlib
import json
import runpy
import tempfile
import unittest
from pathlib import Path

verify = runpy.run_path(str(Path(__file__).with_name("r135-w10-release-readiness.py")))["portrait_capture_proof"]


class PortraitProofContract(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.image = Path(self.temp.name) / "real-browser-screenshot-fixture.png"
        # A unit-test byte fixture; never accepted as a release screenshot.
        self.image.write_bytes(b"test fixture screenshot bytes")
        self.record = Path(self.temp.name) / "live-geometry-fixture.json"
        self.data = {
            "source": "unit-test fixture, not a captured browser",
            "capture_method": "chromium-cdp",
            "screenshot_pixels": [412, 839],
            "screenshot_sha256": hashlib.sha256(self.image.read_bytes()).hexdigest(),
            "css_viewport": [412, 839],
            "device_pixel_ratio": 2.625,
            "canvas_pixels": [1081, 2202],
            "canvas_css": [412, 839],
            "scene_ready": True,
            "view": 2,
            "camera_target_visible": True,
            "fault_label_visible_count": 1,
            "active_caption_depth_override": True,
            "loading_failures": 0,
        }

    def validate(self, record=None):
        self.record.write_text(json.dumps(record if record is not None else self.data), encoding="utf-8")
        return verify(self.record, self.image, 412, 839)

    def test_cdp_css_pixel_capture_is_accepted_only_with_genuine_geometry_proof(self):
        result = self.validate()
        self.assertEqual(result["canvas_pixels"], [1081.0, 2202.0])
        self.assertEqual(result["capture_coordinates"], "css")
        self.assertEqual(result["capture_method"], "chromium-cdp")

    def test_sha_mismatch_rejected(self):
        data = {**self.data, "screenshot_sha256": "0" * 64}
        with self.assertRaisesRegex(ValueError, "sha256 mismatch"):
            self.validate(data)

    def test_opaque_image_dimensions_rejected(self):
        data = {**self.data, "screenshot_pixels": [600, 1200]}
        with self.assertRaisesRegex(ValueError, "PNG header"):
            self.validate(data)

    def test_fake_quality_or_unready_scene_rejected(self):
        for change in (
            {"scene_ready": False}, {"view": 0},
            {"camera_target_visible": False},
            {"fault_label_visible_count": 0},
            {"active_caption_depth_override": False},
            {"loading_failures": 1},
        ):
            with self.subTest(change=change):
                with self.assertRaisesRegex(ValueError, "active readable Godot"):
                    self.validate({**self.data, **change})

    def test_invalid_dpr_canvas_or_viewport_rejected(self):
        for change in (
            {"device_pixel_ratio": 1},
            {"canvas_pixels": [100, 100]},
            {"canvas_pixels": [412, 839]},
            {"canvas_css": [99, 839]},
        ):
            with self.subTest(change=change):
                with self.assertRaises(ValueError):
                    self.validate({**self.data, **change})

    def test_capture_method_must_be_real_browser_path(self):
        with self.assertRaisesRegex(ValueError, "trusted WebGL"):
            self.validate({**self.data, "capture_method": "generated-image"})

    def test_render_target_screenshot_also_allowed(self):
        data = {
            **self.data, "capture_method": "chromium-canvas-readback",
            "screenshot_pixels": [1081, 2202]
        }
        self.record.write_text(json.dumps(data), encoding="utf-8")
        result = verify(self.record, self.image, 1081, 2202)
        self.assertEqual(result["capture_coordinates"], "render_target")


if __name__ == "__main__":
    unittest.main()
