#!/usr/bin/env python3
"""Synthetic-only R83 test fixtures. Never real player, phone or AAA evidence."""
import hashlib
import json
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

import omega_r83_release_gate as g


def chunk(kind, body):
    return (struct.pack(">I", len(body)) + kind + body +
            struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))


def original_format_test_png(width, height, tint):
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    row = b"\x00" + bytes([tint, 50, 100, 255]) * width
    return (g.r73.PNG_SIGNATURE + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(row * height)) + chunk(b"IEND", b""))


class ReleaseClosureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = "a" * 40

    def save(self, name, payload):
        path = self.root / name
        path.write_bytes(payload)
        return hashlib.sha256(payload).hexdigest()

    def test_empty_field_proof_is_hold(self):
        x = g.summarise(self.source, {k: False for k in g.REQUIRED_CHECKS}, [])
        self.assertEqual(x["status"], "HOLD")
        self.assertEqual(len(x["missing_evidence"]), 6)
        self.assertFalse(x["production_go"])
        self.assertFalse(x["technical_web_ready"])

    def test_technical_pass_not_aaa_release(self):
        marks = {k: k == "source_bound_public_webgl" for k in g.REQUIRED_CHECKS}
        x = g.summarise(self.source, marks, [])
        self.assertEqual(x["status"], "HOLD")
        self.assertTrue(x["technical_web_ready"])
        self.assertFalse(x["aaa_quality_certified"])
        self.assertFalse(x["independent_human_verification_complete"])
        self.assertFalse(x["production_go"])

    def test_even_all_submitted_evidence_never_auto_go(self):
        x = g.summarise(self.source, {k: True for k in g.REQUIRED_CHECKS}, [])
        self.assertEqual(x["status"], "READY_FOR_INDEPENDENT_HUMAN_SIGNOFF")
        self.assertEqual(x["missing_evidence"], [])
        self.assertFalse(x["production_go"])
        self.assertFalse(x["aaa_quality_certified"])

    def test_forged_boolean_or_missing_gate_rejected(self):
        sample = {k: True for k in g.REQUIRED_CHECKS}
        sample["physical_ios_original_telemetry"] = 1
        result = g.summarise(self.source, sample, [])
        self.assertEqual(result["status"], "HOLD")
        del sample["physical_ios_original_telemetry"]
        with self.assertRaisesRegex(g.FieldError, "missing or extra"):
            g.summarise(self.source, sample, [])

    def test_invalid_game_source_rejected(self):
        marks = {k: False for k in g.REQUIRED_CHECKS}
        with self.assertRaisesRegex(g.FieldError, "invalid source SHA"):
            g.summarise("not-a-commit", marks, [])

    def sessions(self):
        records = []
        for i in range(20):
            name = f"test-user-{i:02d}.webm"
            video = bytes.fromhex("1a45dfa3") + bytes([i]) * 2100
            digest = self.save(name, video)
            records.append({
                "session_id": f"session-{i:02d}",
                "participant_code": f"anon-user-{i:02d}",
                "observer": "QA simulated reviewer",
                "recording_consent": True, "actually_played": True,
                "captured_utc": "2026-10-25T15:00:00Z",
                "duration_s": 600, "outcome": "completed",
                "feedback": "Synthetic contract test only",
                "recording_file": name, "recording_sha256": digest
            })
        data = {
            "schema": "empire-omega-r83-20-sessions-v1",
            "source_commit": self.source, "sessions": records
        }
        p = self.root / "twenty-sessions.json"
        p.write_text(json.dumps(data), encoding="utf-8")
        return p, data

    def test_20_distinct_synthetic_sessions_pass_integrity_not_human_authenticity(self):
        path, _ = self.sessions()
        self.assertIsNone(g.human_sessions(path, self.source))

    def test_duplicate_player_rejected(self):
        path, data = self.sessions()
        data["sessions"][1]["participant_code"] = data["sessions"][0]["participant_code"]
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(g.FieldError, "duplicated"):
            g.human_sessions(path, self.source)

    def test_missing_recording_consent_rejected(self):
        path, data = self.sessions()
        data["sessions"][5]["recording_consent"] = False
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(g.FieldError, "unconsented"):
            g.human_sessions(path, self.source)

    def test_swapped_game_source_rejected(self):
        path, data = self.sessions()
        data["source_commit"] = "b" * 40
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(g.FieldError, "another game"):
            g.human_sessions(path, self.source)

    def test_fabricated_video_bytes_even_with_matching_digest_rejected(self):
        path, data = self.sessions()
        fake = b"fake video" * 200
        data["sessions"][3]["recording_sha256"] = self.save("test-user-03.webm", fake)
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(g.FieldError, "not an original WebM"):
            g.human_sessions(path, self.source)

    def test_missing_video_rejected(self):
        path, data = self.sessions()
        (self.root / data["sessions"][2]["recording_file"]).unlink()
        with self.assertRaises(g.r80.EvidenceError):
            g.human_sessions(path, self.source)

    def art(self):
        frames = []
        for i, (w, h) in enumerate([(960, 540), (390, 844), (320, 568), (844, 390)]):
            name = f"test-original-frame-{i}.png"
            sha = self.save(name, original_format_test_png(w, h, i + 1))
            frames.append({"viewport": ["1366x768", "390x844", "320x568", "844x390"][i],
                           "file": name, "sha256": sha})
        obj = {
            "schema": "empire-omega-r83-original-art-v1",
            "source_commit": self.source, "reviewer": "Synthetic reviewer",
            "real_godot_frames_reviewed": True,
            "assets": [{"asset_id": "scene-bridge", "origin": "Test fixture",
                        "licence": "Original test asset", "review_notes": "Synthetic QA sample"}],
            "screenshots": frames
        }
        path = self.root / "art-review.json"
        path.write_text(json.dumps(obj), encoding="utf-8")
        return path, obj

    def test_original_four_decodable_pngs_review_ready_not_aaa(self):
        path, _ = self.art()
        self.assertIsNone(g.art_and_licences(path, self.source))

    def test_mislabelled_original_viewport_rejected(self):
        path, obj = self.art()
        obj["screenshots"][2]["viewport"] = "844x390"
        path.write_text(json.dumps(obj))
        # Either dimension mismatch or duplicate viewport is an equally
        # valid first refusal for this intentionally forged input.
        with self.assertRaisesRegex(g.FieldError, "duplicate original|dimensions mismatch"):
            g.art_and_licences(path, self.source)

    def test_wrong_mobile_pixel_dimensions_rejected(self):
        path, obj = self.art()
        other = original_format_test_png(300, 568, 9)
        name = obj["screenshots"][1]["file"]
        obj["screenshots"][1]["sha256"] = self.save(name, other)
        path.write_text(json.dumps(obj))
        with self.assertRaisesRegex(g.FieldError, "dimensions mismatch"):
            g.art_and_licences(path, self.source)

    def test_reused_png_frame_rejected(self):
        path, obj = self.art()
        first = obj["screenshots"][0]
        second = obj["screenshots"][1]
        payload = (self.root / first["file"]).read_bytes()
        second["sha256"] = self.save(second["file"], payload)
        path.write_text(json.dumps(obj))
        with self.assertRaises(g.FieldError):
            g.art_and_licences(path, self.source)

    def test_image_without_license_rejected(self):
        path, obj = self.art()
        obj["assets"] = []
        path.write_text(json.dumps(obj))
        with self.assertRaisesRegex(g.FieldError, "licence inventory"):
            g.art_and_licences(path, self.source)

    def test_report_invalid_utf_and_symlink_rejected(self):
        path, _ = self.sessions()
        alias = self.root / "linked.json"
        alias.symlink_to(path)
        with self.assertRaisesRegex(g.FieldError, "missing, linked"):
            g.load_object(alias)


    def _original_browser(self, size: int = 0):
        """Synthetic format ONLY; never presented as a real Chromium run."""
        path = self.root / "original-playwright.json"
        data = {"stats": {"expected": 0, "unexpected": 0, "flaky": 0},
                "suites": [], "padding": "x" * size}
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def test_realistic_multimegabyte_browser_json_loads_but_not_certified(self):
        path = self._original_browser(3 * 1024 * 1024)
        report = g.load_original_browser_report(path)
        self.assertEqual(report["stats"]["flaky"], 0)
        self.assertGreater(path.stat().st_size, 1024 * 1024)
        # File size alone CANNOT certify desktop/touch; R50 still rejects
        # this synthetic no-project reporter after R85 parses it safely.
        with self.assertRaises(ValueError):
            g.read_r50_module().validate_browser(report)

    def test_original_browser_report_still_has_finite_size_limit(self):
        path = self.root / "original-playwright.json"
        with path.open("wb") as f:
            f.truncate(g.MAX_ORIGINAL_PLAYWRIGHT_JSON_BYTES + 1)
        with self.assertRaisesRegex(g.FieldError, "oversized original Playwright"):
            g.load_original_browser_report(path)

    def test_original_browser_symlink_refused(self):
        original = self._original_browser()
        linked = self.root / "browser-link.json"
        linked.symlink_to(original)
        with self.assertRaisesRegex(g.FieldError, "linked original Playwright"):
            g.load_original_browser_report(linked)

    def test_original_browser_requires_real_report_shape(self):
        path = self.root / "original-playwright.json"
        path.write_text(json.dumps({"stats": {}, "not_suites": [],
                                    "padding": "x" * 150}),
                        encoding="utf-8")
        with self.assertRaisesRegex(g.FieldError, "requires stats and test suites"):
            g.load_original_browser_report(path)

    def test_private_field_forms_keep_one_megabyte_limit(self):
        path = self._original_browser(2 * 1024 * 1024)
        with self.assertRaisesRegex(g.FieldError, "oversized JSON"):
            g.load_object(path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
