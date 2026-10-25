#!/usr/bin/env python3
"""Synthetic-negative W25 tests: no synthetic record counts as a phone."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("r135_w25_gate",
      Path(__file__).with_name("r135-w25-physical-evidence.py"))
assert spec and spec.loader
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

SOURCE = "a" * 40


def fake_draft():
    # SYNTHETIC UNIT FIXTURE, not a claim about any existing phone.
    return {
        "schema": gate.SCHEMA, "status": "UNVERIFIED_PHONE_MEASUREMENT_DRAFT",
        "source_commit": SOURCE, "engine": "Godot 4.4.1",
        "scene_ready": True, "simulation_only": True,
        "physical_hardware_attested": False, "reviewer_confirmed": False,
        "visual_review_approved": False, "screen_recording_approved": False,
        "uploads_sent": False, "user_agent_trusted": False,
        "no_synthetic_emulation_claim": False, "platform_claim": "android",
        "orientation": "portrait", "viewport_width": 390, "viewport_height": 844,
        "quality": 0, "loaded_model": "service_spine_eco.glb",
        "cleared_case_count": 3, "WebGL_context_lost": False,
        "capture_utc": "2026-10-25T17:10:00Z",
        "capture_ms": 30000.0, "frame_count": 600,
        "frames_ms": [50.0] * 600, "p50_frame_ms": 50.0,
        "p95_frame_ms": 50.0, "p99_frame_ms": 50.0,
    }


class OriginalEvidenceGateTests(unittest.TestCase):
    def test_parser_consistency_does_not_attest_hardware(self):
        result = gate.validate_capture(fake_draft(), SOURCE)
        self.assertEqual(result["frame_count"], 600)
        self.assertNotIn("hardware_fps_certified", result)

    def test_falsified_phone_autocertification_rejected(self):
        for key in ("physical_hardware_attested", "reviewer_confirmed",
                    "visual_review_approved", "screen_recording_approved",
                    "uploads_sent", "user_agent_trusted",
                    "no_synthetic_emulation_claim"):
            x = fake_draft()
            x[key] = True
            with self.assertRaises(gate.EvidenceError, msg=key):
                gate.validate_capture(x, SOURCE)

    def test_wrong_source_and_software_qualifiers_rejected(self):
        for key, replacement in (
            ("source_commit", "b" * 40),
            ("engine", "Fake Engine"),
            ("scene_ready", False),
            ("simulation_only", False),
            ("platform_claim", "unknown"),
            ("orientation", "landscape"),
            ("loaded_model", "fake.glb"),
            ("WebGL_context_lost", True),
            ("capture_ms", 12000.0),
        ):
            x = fake_draft()
            x[key] = replacement
            with self.assertRaises(gate.EvidenceError, msg=key):
                gate.validate_capture(x, SOURCE)

    def test_raw_frames_disallow_fabricated_p95(self):
        x = fake_draft()
        x["p95_frame_ms"] = 12.0
        with self.assertRaisesRegex(gate.EvidenceError, "differs"):
            gate.validate_capture(x, SOURCE)

    def test_duration_and_frame_count_must_be_original(self):
        x = fake_draft()
        x["frames_ms"] = [50.0] * 250
        x["frame_count"] = 250
        with self.assertRaisesRegex(gate.EvidenceError, "not consistent"):
            gate.validate_capture(x, SOURCE)
        x = fake_draft()
        x["frame_count"] = 601
        with self.assertRaisesRegex(gate.EvidenceError, "frame-time array"):
            gate.validate_capture(x, SOURCE)

    def test_no_evidence_always_hold(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(gate.EvidenceError):
                gate.review_bundle(Path(folder), SOURCE)
            with self.assertRaisesRegex(gate.EvidenceError, "source"):
                gate.review_bundle(Path(folder), "last-tag")

    def test_symlinks_traversal_and_empty_media_not_accepted(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            outside = root.parent / "outside-nonexistent-file"
            with self.assertRaisesRegex(gate.EvidenceError, "unsafe"):
                gate.checked_file(root, "../fake.mp4", "a" * 64, ".mp4")
            link = root / "linked.mp4"
            link.symlink_to(outside)
            with self.assertRaises(gate.EvidenceError):
                gate.checked_file(root, link.name, "a" * 64, ".mp4")

    def test_video_header_cannot_be_fake_extension(self):
        with tempfile.TemporaryDirectory() as folder:
            bad = Path(folder) / "wrong.mp4"
            bad.write_bytes(b"not a movie")
            with self.assertRaisesRegex(gate.EvidenceError, "container"):
                gate.verify_video(bad)


if __name__ == "__main__":
    unittest.main()
