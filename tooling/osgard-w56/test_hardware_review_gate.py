#!/usr/bin/env python3
"""Synthetic-only W56 QA review regressions. NOT real GPU/mobile evidence."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hardware_review_gate as g

SHA = "a" * 40


def win(sha=SHA):
    return {
        "schema": "OSGARD_W56_LOCAL_WINDOWS_GPU_PREFLIGHT_V1",
        "build_source_sha": sha, "app_sha256_valid": True,
        "process_started": True, "hardware_60fps_certified": False,
        "video_cards": [{"model": "SYNTHETIC_TEST_FIXTURE_NOT_REAL_HARDWARE"}],
        "manual_checks": {name: "PASS_MANUAL" for name in g.WINDOWS_CHECKS},
    }


def browser(sha=SHA):
    return {
        "schema": "OSGARD_W56_LOCAL_WEBGL_PHYSICAL_GPU_QA_V1",
        "source_commit": sha, "session_kind": "real_engine_dom_read_only",
        "hardware_fps_certified": False, "physical_device_signoff": False,
        "all_modes_sufficient": True, "renderer_status": "GPU_REPORTED_NOT_CERTIFIED",
        "modes": {mode: {
            "sample_count": 35, "observed_seconds": 40,
            "frames_advanced": 100, "median_engine_fps": 33.3,
            "median_total_draw_calls": 200,
        } for mode in ("hero", "eco")},
    }


def phone(platform, sha=SHA):
    return {
        "schema": "OSGARD_W56_LOCAL_PHONE_MANUAL_REVIEW_V1",
        "platform": platform, "source_commit": sha,
        "manual_checks": {name: "PASS_MANUAL" for name in g.PHONE_CHECKS},
    }


class FailClosedContract(unittest.TestCase):
    def test_no_reports_never_publish(self):
        out = g.review(SHA)
        self.assertEqual(out["status"], "HOLD")
        self.assertEqual(len(out["missing"]), 4)
        self.assertFalse(out["allow_master_merge"])

    def test_everything_looks_good_still_requires_independent_review(self):
        out = g.review(SHA, win(), browser(), phone("android"), phone("ios"))
        self.assertEqual(out["decision"], "HUMAN_HARDWARE_REVIEW_REQUIRED")
        self.assertFalse(out["independent_physical_device_certified"])
        self.assertFalse(out["production_approved"])
        self.assertFalse(out["published_to_production"])

    def test_wrong_source_rejected(self):
        with self.assertRaisesRegex(ValueError, "stale"):
            g.review(SHA, win(sha="b"*40))

    def test_no_partial_source_sha(self):
        with self.assertRaisesRegex(ValueError, "exact"):
            g.review("bad")

    def test_malformed_windows_manual_rejected(self):
        report = win()
        del report["manual_checks"]["all_six_missions_playable"]
        with self.assertRaisesRegex(ValueError, "Missing"):
            g.review(SHA, windows=report)

    def test_fake_fps_certification_rejected(self):
        report = win()
        report["hardware_60fps_certified"] = True
        with self.assertRaisesRegex(ValueError, "self-certify"):
            g.review(SHA, windows=report)

    def test_webgl_stale_report_rejected(self):
        with self.assertRaisesRegex(ValueError, "stale"):
            g.review(SHA, webgl=browser(sha="b"*40))

    def test_webgl_fps_self_certification_rejected(self):
        report = browser()
        report["hardware_fps_certified"] = True
        with self.assertRaisesRegex(ValueError, "Self-asserted"):
            g.review(SHA, webgl=report)

    def test_fake_sufficient_webgl_samples_rejected(self):
        report = browser()
        report["modes"]["eco"]["frames_advanced"] = 1
        with self.assertRaisesRegex(ValueError, "Insufficient"):
            g.review(SHA, webgl=report)

    def test_partial_webgl_evidence_is_not_a_go(self):
        report = browser()
        del report["modes"]["hero"]
        report["all_modes_sufficient"] = False
        result = g.review(SHA, webgl=report)
        self.assertEqual(result["status"], "HOLD")
        self.assertFalse(result["reports"]["webgl"]["sufficient_hero_and_eco"])
        self.assertFalse(result["allow_master_merge"])

    def test_wrong_phone_os_rejected(self):
        report = phone("android")
        with self.assertRaisesRegex(ValueError, "platform mismatch"):
            g.review(SHA, ios=report)

    def test_phone_incomplete_remains_hold(self):
        report = phone("ios")
        report["manual_checks"]["ru_en_text_readable"] = "NOT_TESTED"
        result = g.review(SHA, ios=report)
        self.assertFalse(result["reports"]["ios"]["manual_checklist_complete"])
        self.assertEqual(result["decision"], "MISSING_DEVICE_REPORTS")


if __name__ == "__main__":
    unittest.main()
