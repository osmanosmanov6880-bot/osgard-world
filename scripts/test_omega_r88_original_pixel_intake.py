#!/usr/bin/env python3
"""R88: local synthetic fixtures exercise rejection; NEVER counterfeit real GO."""
import base64
import copy
import json
import struct
import sys
import unittest
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import omega_r88_original_pixel_intake as r88


def chunk(tag: bytes, body: bytes) -> bytes:
    return (struct.pack(">I", len(body)) + tag + body +
            struct.pack(">I", zlib.crc32(tag + body) & 0xffffffff))


def fixture_png(width: int, height: int) -> bytes:
    # Structurally valid non-interlaced RGB synthetic test image only.
    # This is NOT an actual game image and may NEVER be release evidence.
    row = b"\x00" + (bytes(range(256)) * ((width * 3 + 255) // 256))[:width * 3]
    filtered = row * height
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (bytes.fromhex("89504e470d0a1a0a") +
            chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(filtered)) +
            chunk(b"IEND", b""))


def fake_original_report():
    specs = []
    for project, (width, height) in (
            ("desktop-chromium", (960, 540)),
            ("touch-phone-chromium", (390, 844))):
        attachment = {
            "name": "godot-real-world-initial.png",
            "contentType": "image/png",
            "body": base64.b64encode(fixture_png(width, height)).decode(),
        }
        specs.append({
            "tests": [{
                "projectName": project, "status": "expected",
                "results": [{"status": "passed", "retry": 0,
                             "attachments": [attachment]}],
            }]
        })
    return {"suites": [{"specs": specs}], "stats": {
        "expected": 2, "skipped": 0, "unexpected": 0, "flaky": 0}}


class OriginalFrameTests(unittest.TestCase):
    def setUp(self):
        self.report = fake_original_report()

    def test_two_original_shapes_decode_but_are_not_release_attestation(self):
        value = r88.original_png_attachments(self.report)
        self.assertEqual(set(value), set(r88.FRAMES))
        self.assertTrue(all(raw.startswith(bytes.fromhex("89504e470d0a1a0a"))
                            for raw in value.values()))
        # Only 'export_verified_frames' runs the ORIGINAL R83/R50 provenance.
        self.assertFalse(hasattr(r88.original_png_attachments, "production_go"))

    def test_reject_missing_touch_project(self):
        self.report["suites"][0]["specs"].pop()
        with self.assertRaisesRegex(ValueError, "both original"):
            r88.original_png_attachments(self.report)

    def test_reject_duplicate_project(self):
        specs = self.report["suites"][0]["specs"]
        specs.append(copy.deepcopy(specs[0]))
        with self.assertRaisesRegex(ValueError, "duplicate original"):
            r88.original_png_attachments(self.report)

    def test_reject_retry_even_if_passed(self):
        self.report["suites"][0]["specs"][0]["tests"][0]["results"][0]["retry"] = 1
        with self.assertRaisesRegex(ValueError, "zero-retry"):
            r88.original_png_attachments(self.report)

    def test_reject_failing_test_even_if_png_embedded(self):
        self.report["suites"][0]["specs"][0]["tests"][0]["results"][0]["status"] = "failed"
        with self.assertRaisesRegex(ValueError, "passed"):
            r88.original_png_attachments(self.report)

    def test_reject_fake_png_base64(self):
        attachment = self.report["suites"][0]["specs"][0]["tests"][0]["results"][0]["attachments"][0]
        attachment["body"] = "@" * 200
        with self.assertRaisesRegex(ValueError, "base64"):
            r88.original_png_attachments(self.report)

    def test_reject_wrong_portrait_dimensions(self):
        attachment = self.report["suites"][0]["specs"][1]["tests"][0]["results"][0]["attachments"][0]
        attachment["body"] = base64.b64encode(fixture_png(320, 568)).decode()
        with self.assertRaisesRegex(ValueError, "390x844"):
            r88.original_png_attachments(self.report)

    def test_reject_wrong_desktop_ratio(self):
        attachment = self.report["suites"][0]["specs"][0]["tests"][0]["results"][0]["attachments"][0]
        attachment["body"] = base64.b64encode(fixture_png(960, 600)).decode()
        with self.assertRaisesRegex(ValueError, "proportion"):
            r88.original_png_attachments(self.report)

    def test_reject_missing_attachment(self):
        self.report["suites"][0]["specs"][0]["tests"][0]["results"][0]["attachments"] = []
        with self.assertRaisesRegex(ValueError, "missing/duplicated"):
            r88.original_png_attachments(self.report)

    def test_reject_mislabelled_media(self):
        attachment = self.report["suites"][0]["specs"][0]["tests"][0]["results"][0]["attachments"][0]
        attachment["contentType"] = "image/jpeg"
        with self.assertRaisesRegex(ValueError, "missing/duplicated"):
            r88.original_png_attachments(self.report)

    def test_reject_oversized_inline_source(self):
        attachment = self.report["suites"][0]["specs"][0]["tests"][0]["results"][0]["attachments"][0]
        attachment["body"] = "A" * (r88.MAX_PNG_BYTES * 4 // 3 + 32)
        with self.assertRaisesRegex(ValueError, "too large"):
            r88.original_png_attachments(self.report)

    def test_symlink_untrusted_report_is_rejected_by_original_gate(self):
        # R83 original bounded loader itself rejects symlink proof.
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            real = Path(tmp) / "original.json"
            alias = Path(tmp) / "alias.json"
            real.write_text(json.dumps(self.report))
            alias.symlink_to(real)
            with self.assertRaisesRegex(ValueError, "linked"):
                r88.r83.load_original_browser_report(alias)


if __name__ == "__main__":
    unittest.main(verbosity=2)
