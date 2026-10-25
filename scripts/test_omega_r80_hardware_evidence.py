#!/usr/bin/env python3
"""Synthetic contract fixtures for R80. NEVER real smartphone evidence."""
import hashlib
import json
import math
import tempfile
import unittest
from pathlib import Path

import omega_r80_hardware_evidence as r80


class HardwareEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = "a" * 40
        self.metrics = {
            "schema": r80.BENCHMARK_SCHEMA,
            "status": "complete", "engine": "Godot 4.4.1",
            "metric_source": "Godot render-frame _process(delta), actual in-game Performance renderer counters",
            "platform_reported_by_engine": "Web",
            "physical_hardware_attested": False,
            "device_model_verified": False,
            "source_sha_verified": False,
            "graphics_quality": "standard",
            "viewport_width": 390, "viewport_height": 844,
            "frame_count": 1200, "warmup_s": 2.0, "capture_s": 20.0,
            "p50_frame_ms": 16.0, "p95_frame_ms": 32.0,
            "p99_frame_ms": 40.0,
            "r48_max_render_frame_ms": 60.0,
            "r48_over_30fps_frame_budget": 100,
            "r48_over_60fps_frame_budget": 200,
            "r48_stutter_frame_percent_30fps": 100.0 * 100 / 1200,
            "mean_observed_fps": 60.0, "r48_p95_fps_equivalent": 31.25,
            "p95_draw_calls": 120.0, "maximum_draw_calls": 160,
            "dropped_invalid_or_capacity": 0,
        }
        self.report = {
            "schema": r80.SCHEMA, "source_commit": self.source,
            "os_family": "android", "physical_device": True,
            "model": "Synthetic test device", "os_version": "Android TEST",
            "browser": "Chrome TEST", "operator": "QA synthetic",
            "capture_utc": "2026-10-25T15:00:00Z",
            "warmup_s": 2.0, "capture_s": 20.0, "frame_count": 1200,
            "p95_frame_ms": 32.0, "p99_frame_ms": 40.0,
            "viewport_width": 390, "viewport_height": 844,
            "benchmark_file": "original-godot-benchmark.json",
            "recording_file": "physical-session.webm",
        }
        self.persist()

    def persist(self):
        benchmark = json.dumps(self.metrics, sort_keys=True).encode()
        self.report["benchmark_sha256"] = hashlib.sha256(benchmark).hexdigest()
        (self.root / self.report["benchmark_file"]).write_bytes(benchmark)
        video = b"\x1a\x45\xdf\xa3" + b"synthetic-test-only-" * 180
        self.report["recording_sha256"] = hashlib.sha256(video).hexdigest()
        (self.root / self.report["recording_file"]).write_bytes(video)
        self.write_report()

    def write_report(self):
        (self.root / "hardware.json").write_text(json.dumps(self.report), encoding="utf-8")

    def verify(self):
        self.write_report()
        return r80.validate_physical_run(self.root / "hardware.json", self.source)

    def reject(self, expression=None):
        self.write_report()
        if expression:
            with self.assertRaisesRegex(r80.EvidenceError, expression):
                self.verify()
        else:
            with self.assertRaises(r80.EvidenceError):
                self.verify()

    def test_synthetic_consistency_is_not_proof_of_real_hardware(self):
        self.assertEqual(self.verify(), "android")
        self.report["os_family"] = "ios"
        self.report["model"] = "Synthetic iPhone sample"
        self.assertEqual(self.verify(), "ios")

    def test_fake_emulator_rejected(self):
        self.report["physical_device"] = False
        self.reject("not a physical phone")

    def test_wrong_game_source_rejected(self):
        self.report["source_commit"] = "b" * 40
        self.reject("does not match public")

    def test_unknown_engine_metric_schema_rejected(self):
        self.metrics["schema"] = "fake"
        self.persist()
        self.reject("ORIGINAL Godot R36")

    def test_injected_forged_engine_attestation_rejected(self):
        self.metrics["physical_hardware_attested"] = True
        self.persist()
        self.reject("forged engine")

    def test_metrics_device_percentiles_must_match(self):
        self.report["p95_frame_ms"] = 25.0
        self.reject("mismatched original")

    def test_metrics_duration_must_match(self):
        self.report["capture_s"] = 23.0
        self.reject("mismatched original")

    def test_original_viewport_tampering_rejected(self):
        self.report["viewport_width"] = 400
        self.reject("viewport differs")

    def test_frame_count_must_match_original(self):
        self.report["frame_count"] = 1000
        self.reject("frame count differs")

    def test_missing_benchmark_file_rejected(self):
        (self.root / self.report["benchmark_file"]).unlink()
        self.reject("missing, linked or external")

    def test_benchmark_checksum_tampering_rejected(self):
        original = (self.root / self.report["benchmark_file"]).read_bytes()
        (self.root / self.report["benchmark_file"]).write_bytes(original[:-1] + bytes([original[-1] ^ 1]))
        self.reject("SHA-256 mismatch")

    def test_benchmark_symlink_rejected(self):
        orig = self.root / self.report["benchmark_file"]
        alt = self.root / "alternate.json"
        alt.write_bytes(orig.read_bytes())
        orig.unlink()
        orig.symlink_to(alt)
        self.reject("missing, linked or external")

    def test_metrics_impossible_percentile_order_rejected(self):
        self.metrics["p50_frame_ms"] = 45.0
        self.persist()
        self.reject("percentile ordering")

    def test_impossible_stutter_count_rejected(self):
        self.metrics["r48_over_30fps_frame_budget"] = 1300
        self.persist()
        self.reject("slow-frame counts")

    def test_forged_mean_fps_rejected(self):
        self.metrics["mean_observed_fps"] = 45.0
        self.persist()
        self.reject("observed FPS")

    def test_wrong_original_video_format_rejected(self):
        (self.root / self.report["recording_file"]).write_bytes(b"not a webm" * 200)
        video = (self.root / self.report["recording_file"]).read_bytes()
        self.report["recording_sha256"] = hashlib.sha256(video).hexdigest()
        self.reject("container header")

    def test_video_checksum_tampering_rejected(self):
        with (self.root / self.report["recording_file"]).open("ab") as stream:
            stream.write(b"extra")
        self.reject("SHA-256 mismatch")

    def test_metadata_utc_is_required(self):
        self.report["capture_utc"] = "2026-10-25T15:00:00"
        self.reject("timezone-aware UTC")

    def test_negative_nan_percentile_rejected(self):
        self.report["p99_frame_ms"] = math.nan
        self.reject("invalid numeric")

    def test_unverified_engine_build_required(self):
        self.metrics["source_sha_verified"] = True
        self.persist()
        self.reject("forged engine")

    def test_no_traversal_from_benchmark_filename(self):
        self.report["benchmark_file"] = "../fraud.json"
        self.reject("unsafe")

    def test_no_boolean_fake_frame_count(self):
        self.report["frame_count"] = True
        self.reject("invalid integer")

    def test_wrong_graphics_quality_rejected(self):
        self.metrics["graphics_quality"] = "ultra-hologram"
        self.persist()
        self.reject("graphics preset")


if __name__ == "__main__":
    unittest.main(verbosity=2)
