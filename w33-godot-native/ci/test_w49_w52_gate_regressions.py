#!/usr/bin/env python3
"""Pure standard-library negative acceptance checks for W49/W52 release gates.

These synthetic fixtures validate that *invalid* evidence is rejected, not
that any fake artifact is a Godot render or a releasable executable. Real
Godot/Chromium/Windows evidence stays mandatory in the upstream CI pipeline.
"""
import hashlib
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

import w49_source_contract as source_gate
import w52_release_gate as release_gate

BASE = source_gate.W47_PINNED_SHA
HEAD = "a" * 40
UNCHANGED_BLOB = "f" * 40
CHANGED = ("w33-godot-native/scripts/OSGARDObsidianStage.gd\n"
           "w33-godot-native/tests/test_w48_ring_instancing.gd")


class GitSourceGateTests(unittest.TestCase):
    """Never change six original missions just to make visual tests green."""

    def fake_git(self, change=CHANGED, core_changed=False, wrong_head=False,
                 tampered_gameplay=False, tampered_w56=False):
        def call(*args):
            if args == ("rev-parse", "HEAD"):
                return "b" * 40 if wrong_head else HEAD
            if args[:1] == ("cat-file",):
                return ""
            if args[:1] == ("merge-base",):
                return BASE
            if args[:2] == ("diff", "--name-only"):
                return change
            if args[0] == "rev-parse" and len(args) == 2 and ":" in args[1]:
                ref, path = args[1].split(":", 1)
                if core_changed and path == "w33-godot-native/scripts/OSGARDCore.gd":
                    return "1" * 40 if ref == HEAD else UNCHANGED_BLOB
                if ref == HEAD and path in source_gate.REVIEWED_W56_CRITICAL_BLOBS:
                    return ("1" * 40 if tampered_w56 else
                            source_gate.REVIEWED_W56_CRITICAL_BLOBS[path])
                if ref == HEAD and path == source_gate.REVIEWED_GAMEPLAY_PATH:
                    return ("1" * 40 if tampered_gameplay else
                            source_gate.REVIEWED_GAMEPLAY_BLOB)
                return UNCHANGED_BLOB
            raise AssertionError("Unrecognized synthetic Git call: " + repr(args))
        return call

    def test_exact_original_source_contract_accepts_scope_only(self):
        with patch.object(source_gate, "git", side_effect=self.fake_git()), patch.object(source_gate.subprocess, "run") as run:
            proof = source_gate.verify(BASE, HEAD)
        self.assertEqual(proof["status"], "PASS")
        self.assertTrue(proof["production_source_unchanged"])
        self.assertEqual(len(proof["scope_changed_paths"]), 2)
        run.assert_called_once()

    def test_allows_only_explicit_w53_mobile_touch_qa_changes(self):
        changed = (CHANGED + "\n"
                   "w33-godot-native/ci/mobile_touch_acceptance.py\n"
                   "w33-godot-native/tests/test_w53_mobile_edge_swipe.gd\n"
                   ".github/workflows/osgard-w53-mobile-touch-acceptance.yml")
        with patch.object(source_gate, "git", side_effect=self.fake_git(change=changed)), patch.object(source_gate.subprocess, "run"):
            proof = source_gate.verify(BASE, HEAD)
        self.assertEqual(proof["status"], "PASS")
        self.assertTrue(proof["production_source_unchanged"])
        self.assertEqual(len(proof["scope_changed_paths"]), 5)

    def test_accepts_w55_text_only_native_and_browser_visual_qa_paths(self):
        changed = (CHANGED + "\n"
                   "w33-godot-native/scripts/OSGARDMain.gd\n"
                   "w33-godot-native/tests/test_w55_readable_protocol_copy.gd\n"
                   "w33-godot-native/ci/w55_visual_typography_acceptance.py\n"
                   ".github/workflows/osgard-w55-real-mobile-glyph-acceptance.yml")
        with patch.object(source_gate, "git", side_effect=self.fake_git(change=changed)), patch.object(source_gate.subprocess, "run"):
            proof = source_gate.verify(BASE, HEAD)
        self.assertEqual(proof["status"], "PASS")
        self.assertTrue(proof["production_source_unchanged"])
        self.assertEqual(len(proof["scope_changed_paths"]), 6)

    def test_rejects_unreviewed_font_or_production_payload_from_w55(self):
        changed = (CHANGED + "\n"
                   "w33-godot-native/scripts/OSGARDMain.gd\n"
                   "w33-godot-native/assets/unreviewed-font.ttf")
        with patch.object(source_gate, "git", side_effect=self.fake_git(change=changed)), patch.object(source_gate.subprocess, "run"):
            with self.assertRaisesRegex(ValueError, "Unauthorized"):
                source_gate.verify(BASE, HEAD)

    def test_accepts_reviewed_browser_gameplay_timeout_only_blob(self):
        changed = CHANGED + "\n" + source_gate.REVIEWED_GAMEPLAY_PATH
        with patch.object(source_gate, "git", side_effect=self.fake_git(change=changed)), patch.object(source_gate.subprocess, "run"):
            proof = source_gate.verify(BASE, HEAD)
        self.assertEqual(proof["status"], "PASS")
        self.assertEqual(proof["reviewed_browser_gameplay_ci_blob_sha"],
                         source_gate.REVIEWED_GAMEPLAY_BLOB)
        self.assertIn(source_gate.REVIEWED_GAMEPLAY_PATH,
                      proof["scope_changed_paths"])

    def test_rejects_unreviewed_browser_gameplay_qa_changes(self):
        changed = CHANGED + "\n" + source_gate.REVIEWED_GAMEPLAY_PATH
        with patch.object(source_gate, "git", side_effect=self.fake_git(change=changed, tampered_gameplay=True)), patch.object(source_gate.subprocess, "run"):
            with self.assertRaisesRegex(ValueError, "Unreviewed six-mission browser QA driver change"):
                source_gate.verify(BASE, HEAD)

    def test_accepts_reviewed_fail_closed_w56_tooling(self):
        w56 = "\n".join(sorted(source_gate.W56_PATHS))
        changed = CHANGED + "\n" + w56
        with patch.object(source_gate, "git", side_effect=self.fake_git(change=changed)), patch.object(source_gate.subprocess, "run"):
            proof = source_gate.verify(BASE, HEAD)
        self.assertEqual(proof["status"], "PASS")
        self.assertEqual(proof["reviewed_w56_gate_blob_shas"],
                         source_gate.REVIEWED_W56_CRITICAL_BLOBS)
        self.assertEqual(len(proof["scope_changed_paths"]), 2 + len(source_gate.W56_PATHS))

    def test_rejects_tampered_w56_reviewed_verifier_and_workflow_blobs(self):
        changed = CHANGED + "\n" + "\n".join(sorted(source_gate.W56_PATHS))
        with patch.object(source_gate, "git", side_effect=self.fake_git(change=changed, tampered_w56=True)), patch.object(source_gate.subprocess, "run"):
            with self.assertRaisesRegex(ValueError, "Unreviewed W56 fail-closed evidence gate change"):
                source_gate.verify(BASE, HEAD)

    def test_rejects_partial_w56_evidence_checker_without_review_workflow(self):
        changed = CHANGED + "\n" + "tooling/osgard-w56/hardware_review_gate.py"
        with patch.object(source_gate, "git", side_effect=self.fake_git(change=changed)), patch.object(source_gate.subprocess, "run"):
            with self.assertRaisesRegex(ValueError, "Partial W56 evidence checker"):
                source_gate.verify(BASE, HEAD)

    def test_rejects_changed_native_mission_core(self):
        with patch.object(source_gate, "git", side_effect=self.fake_git(core_changed=True)), patch.object(source_gate.subprocess, "run"):
            with self.assertRaisesRegex(ValueError, "source changed"):
                source_gate.verify(BASE, HEAD)

    def test_rejects_unauthorized_production_script(self):
        changed = CHANGED + "\n.github/workflows/deploy-production.yml"
        with patch.object(source_gate, "git", side_effect=self.fake_git(change=changed)), patch.object(source_gate.subprocess, "run"):
            with self.assertRaisesRegex(ValueError, "Unauthorized"):
                source_gate.verify(BASE, HEAD)

    def test_rejects_mismatched_checkout(self):
        with patch.object(source_gate, "git", side_effect=self.fake_git(wrong_head=True)), patch.object(source_gate.subprocess, "run"):
            with self.assertRaisesRegex(ValueError, "head SHA"):
                source_gate.verify(BASE, HEAD)

    def test_rejects_moving_w47_baseline(self):
        with self.assertRaisesRegex(ValueError, "baseline unexpectedly moved"):
            source_gate.verify("b" * 40, HEAD)

    def test_rejects_truncated_candidate_sha(self):
        with self.assertRaisesRegex(ValueError, "full lowercase SHA"):
            source_gate.verify(BASE, "abc")

    def test_rejects_w47_non_ancestor(self):
        def fake_git(*args):
            if args == ("rev-parse", "HEAD"):
                return HEAD
            if args[0] == "cat-file":
                return ""
            if args[0] == "merge-base":
                return "e" * 40
            raise AssertionError(args)
        with patch.object(source_gate, "git", side_effect=fake_git):
            with self.assertRaisesRegex(ValueError, "not a descendant"):
                source_gate.verify(BASE, HEAD)


class W57ExactHeadPhysicalGateTests(unittest.TestCase):
    """Never launder a W56 physical HOLD report from a different source SHA."""

    def good_hold(self):
        return {
            "schema": "OSGARD_W56_FAIL_CLOSED_PHYSICAL_REVIEW_V1",
            "source_sha": HEAD, "status": "HOLD",
            "decision": "MISSING_DEVICE_REPORTS", "reports": {},
            "missing": ["windows", "webgl", "android", "ios"],
            "independent_physical_device_certified": False,
            "cinematic_signoff": False, "production_approved": False,
            "allow_master_merge": False, "published_to_production": False,
        }

    def test_valid_w56_exact_source_hold_must_remain_hold(self):
        result = release_gate.validate_w56_hold(self.good_hold(), HEAD)
        self.assertEqual(result["status"], "HOLD")
        self.assertFalse(result["production_approved"])
        self.assertTrue(result["manual_hardware_review_required"])

    def test_rejects_missing_w56_review_file(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "Missing exact CI evidence"):
                release_gate.read_json(Path(folder) / "missing-w56.json")

    def test_rejects_stale_w56_source_sha(self):
        report = self.good_hold()
        report["source_sha"] = "b" * 40
        with self.assertRaisesRegex(ValueError, "different source SHA"):
            release_gate.validate_w56_hold(report, HEAD)

    def test_rejects_fake_w56_release_go(self):
        report = self.good_hold()
        report["status"] = "PASS"
        report["decision"] = "PRODUCTION_GO"
        with self.assertRaisesRegex(ValueError, "cannot authorise"):
            release_gate.validate_w56_hold(report, HEAD)

    def test_rejects_forged_physical_device_observations(self):
        report = self.good_hold()
        report["reports"] = {"windows": {"GPU": "fake"}}
        report["missing"] = ["android", "ios"]
        with self.assertRaisesRegex(ValueError, "must not invent"):
            release_gate.validate_w56_hold(report, HEAD)

    def test_rejects_any_forged_device_or_release_flag(self):
        for flag in ("independent_physical_device_certified",
                     "cinematic_signoff", "production_approved",
                     "allow_master_merge", "published_to_production"):
            with self.subTest(flag=flag):
                report = self.good_hold()
                report[flag] = True
                with self.assertRaisesRegex(ValueError, "fail closed"):
                    release_gate.validate_w56_hold(report, HEAD)

    def test_rejects_partial_or_missing_w56_schema(self):
        report = self.good_hold()
        report["schema"] = "bogus"
        with self.assertRaisesRegex(ValueError, "schema"):
            release_gate.validate_w56_hold(report, HEAD)


class ReleaseGateEvidenceTests(unittest.TestCase):
    """Never accept missing/tampered artifacts as real native evidence."""

    def test_original_png_integrity_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            blob = bytes((137, 80, 78, 71, 13, 10, 26, 10)) + b"synthetic-png-fixture"
            (root / "frame.png").write_bytes(blob)
            release_gate.pngs(root, [{"image": "frame.png", "sha256": hashlib.sha256(blob).hexdigest()}])

    def test_rejects_tampered_original_png_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "frame.png").write_bytes(bytes((137, 80, 78, 71, 13, 10, 26, 10)) + b"tampered")
            with self.assertRaisesRegex(ValueError, "altered native screenshot"):
                release_gate.pngs(root, [{"image": "frame.png", "sha256": "0" * 64}])

    def test_rejects_png_path_traversal(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "unsafe or nested"):
                release_gate.pngs(Path(directory), [{"image": "../image.png", "sha256": "0" * 64}])

    def test_rejects_invalid_frame_magic(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data = b"NOTANIMAGE"
            (root / "frame.png").write_bytes(data)
            with self.assertRaisesRegex(ValueError, "not original PNG"):
                release_gate.pngs(root, [{"image": "frame.png", "sha256": hashlib.sha256(data).hexdigest()}])

    def test_rejects_missing_candidate_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "candidate ZIP absent"):
                release_gate.candidate_zip(Path(directory) / "missing.zip", HEAD)

    def test_rejects_corrupt_candidate_zip(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "invalid.zip"
            archive.write_bytes(b"not-a-zip")
            with self.assertRaises(zipfile.BadZipFile):
                release_gate.candidate_zip(archive, HEAD)

    def test_rejects_candidate_wrong_head(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "candidate.zip"
            payload = {"source_commit": "b" * 40,
                       "godot": "4.4.1", "candidate_only": True, "production_modified": False}
            with zipfile.ZipFile(archive, "w") as output:
                output.writestr("CANDIDATE_MANIFEST.json", json.dumps(payload))
            with self.assertRaisesRegex(ValueError, "not exact PR HEAD"):
                release_gate.candidate_zip(archive, HEAD)

    def test_rejects_candidate_archive_escape_path(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "unsafe.zip"
            with zipfile.ZipFile(archive, "w") as output:
                output.writestr("../escape.txt", "x")
                output.writestr("CANDIDATE_MANIFEST.json", "{}")
            with self.assertRaisesRegex(ValueError, "unsafe ZIP path"):
                release_gate.candidate_zip(archive, HEAD)

    def test_rejects_duplicate_zip_members(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "duplicate.zip"
            with zipfile.ZipFile(archive, "w") as output:
                output.writestr("copy.bin", "a")
                output.writestr("copy.bin", "b")
            with self.assertRaisesRegex(ValueError, "duplicate entry"):
                release_gate.candidate_zip(archive, HEAD)


    def _create_w42_attestation_fixture(self, root, source=HEAD):
        """Small synthetic negative-test fixture, NEVER a real Godot build."""
        zip_path = root / ("OSGARD_OBSIDIAN_" + source + ".zip")
        zip_path.write_bytes(b"synthetic-test-bytes-only")
        digest = hashlib.sha256(zip_path.read_bytes()).hexdigest()
        sums = root / "SHA256SUMS.txt"
        sums.write_text(digest + "  candidate-output/" + zip_path.name + "\n", encoding="utf-8")
        report = root / "build-report.json"
        report.write_text(json.dumps({
            "result": "PASS", "source_sha": source,
            "size_bytes": zip_path.stat().st_size,
            "zip_sha256": digest, "windows_os_boot_verified": True,
            "has_art": True,
        }), encoding="utf-8")
        return zip_path, sums, report

    def test_accepts_consistent_independent_w42_checksum_triplet(self):
        with tempfile.TemporaryDirectory() as folder:
            archive, sums, report = self._create_w42_attestation_fixture(Path(folder))
            proof = release_gate.validate_w42_checksum_attestations(archive, sums, report, HEAD)
            self.assertTrue(proof["w42_checksum_file_verified"])
            self.assertEqual(proof["candidate_head_sha"], HEAD)

    def test_rejects_tampered_w42_zip_even_if_filename_unchanged(self):
        with tempfile.TemporaryDirectory() as folder:
            archive, sums, report = self._create_w42_attestation_fixture(Path(folder))
            archive.write_bytes(b"changed-after-W42-attestation")
            with self.assertRaisesRegex(ValueError, "digest or byte size"):
                release_gate.validate_w42_checksum_attestations(archive, sums, report, HEAD)

    def test_rejects_replaced_w42_build_report_digest(self):
        with tempfile.TemporaryDirectory() as folder:
            archive, sums, report = self._create_w42_attestation_fixture(Path(folder))
            data = json.loads(report.read_text(encoding="utf-8"))
            data["zip_sha256"] = "f" * 64
            report.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "digest or byte size"):
                release_gate.validate_w42_checksum_attestations(archive, sums, report, HEAD)

    def test_rejects_replaced_w42_sha256sums_digest(self):
        with tempfile.TemporaryDirectory() as folder:
            archive, sums, report = self._create_w42_attestation_fixture(Path(folder))
            sums.write_text("f" * 64 + "  candidate-output/" + archive.name + "\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "SHA256SUMS digest mismatch"):
                release_gate.validate_w42_checksum_attestations(archive, sums, report, HEAD)

    def test_rejects_w42_sha256sums_wrong_archive_filename(self):
        with tempfile.TemporaryDirectory() as folder:
            archive, sums, report = self._create_w42_attestation_fixture(Path(folder))
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            sums.write_text(digest + "  candidate-output/another.zip\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "different archive or path"):
                release_gate.validate_w42_checksum_attestations(archive, sums, report, HEAD)

    def test_rejects_w42_sha256sums_multiple_entries(self):
        with tempfile.TemporaryDirectory() as folder:
            archive, sums, report = self._create_w42_attestation_fixture(Path(folder))
            sums.write_text(sums.read_text(encoding="utf-8") * 2, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "exactly one"):
                release_gate.validate_w42_checksum_attestations(archive, sums, report, HEAD)

    def test_rejects_w42_build_report_wrong_head(self):
        with tempfile.TemporaryDirectory() as folder:
            archive, sums, report = self._create_w42_attestation_fixture(Path(folder))
            data = json.loads(report.read_text(encoding="utf-8"))
            data["source_sha"] = "b" * 40
            report.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "wrong commit"):
                release_gate.validate_w42_checksum_attestations(archive, sums, report, HEAD)

    def test_rejects_w42_report_without_real_windows_boot(self):
        with tempfile.TemporaryDirectory() as folder:
            archive, sums, report = self._create_w42_attestation_fixture(Path(folder))
            data = json.loads(report.read_text(encoding="utf-8"))
            data["windows_os_boot_verified"] = False
            report.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "omitted Windows boot"):
                release_gate.validate_w42_checksum_attestations(archive, sums, report, HEAD)


if __name__ == "__main__":
    unittest.main(verbosity=2)
