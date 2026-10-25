#!/usr/bin/env python3
"""Synthetic fixtures solely for the caption pixel-detector contract.

No generated fixture may be substituted for an authentic Chromium screenshot
during release acceptance.
"""
from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path
from PIL import Image, ImageDraw

spec = importlib.util.spec_from_file_location(
    "r135_caption_gate", str(Path(__file__).with_name("r135-w11-caption-gate.py")))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CaptionGateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)

    def fixture(self, width: int, height: int, caption: bool) -> Path:
        image = Image.new("RGB", (width, height), (10, 10, 10))
        if caption:
            if height > width:
                rect = (.45, .23, .57, .245)
            else:
                rect = (.53, .30, .65, .32)
            ImageDraw.Draw(image).rectangle(
                (int(width * rect[0]), int(height * rect[1]),
                 int(width * rect[2]), int(height * rect[3])),
                fill=(210, 155, 55),
            )
        path = Path(self.temp.name) / ("visual.png" if caption else "blank.png")
        image.save(path)
        return path

    def test_missing_caption_must_be_rejected_in_both_orientations(self):
        self.assertFalse(module.check(self.fixture(412, 839, False), True)["passes"])
        self.assertFalse(module.check(self.fixture(1366, 768, False), False)["passes"])

    def test_colored_caption_in_expected_safe_band_detected(self):
        self.assertTrue(module.check(self.fixture(412, 839, True), True)["passes"])
        self.assertTrue(module.check(self.fixture(1366, 768, True), False)["passes"])

    def test_noncredible_image_dimensions_rejected(self):
        with self.assertRaises(ValueError):
            module.check(self.fixture(250, 250, True), True)
        with self.assertRaises(ValueError):
            module.check(self.fixture(250, 250, True), False)


if __name__ == "__main__":
    unittest.main()
