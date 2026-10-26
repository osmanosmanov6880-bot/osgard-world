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

    def fake_git(self, change=CHANGED, core_changed=False, wrong_head=False):
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
            with self.assertRaisesRegex(ValueError, "HEAD SHA"):
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
            with self.assertRaisesRegex(ValueError, "source"):
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
