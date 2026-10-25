#!/usr/bin/env python3
"""R86 honest private evidence and source protection regressions (no fake release)."""
import json
import os
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import omega_r86_private_field_kit as kit


class R86Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.manifest = self.base / "release.json"
        self.source = "a" * 40
        self.manifest.write_text(json.dumps({
            "source_commit": self.source,
            "engine": "Godot 4.4.1",
            "source_path": "godot/empire-omega",
            "artifact_kind": "native-Godot-HTML5-export",
            "files": {str(n): {} for n in range(7)}
        }))
        self.root = self.base / "private"
        self.assertEqual(kit.initialize(self.root, self.manifest)["production_go"], False)

    def test_empty_kit_cannot_be_evidence(self):
        self.assertEqual(json.loads((self.root / "players/operator-metadata.template.json").read_text())["sessions"], [])
        with self.assertRaisesRegex(ValueError, "twenty ACTUAL"):
            (self.root / "players/operator-metadata.json").write_text(json.dumps({
                "schema": kit.INTAKE_SCHEMA, "source_commit": self.source, "sessions": []}))
            kit.sessions(self.root, self.manifest)
        self.assertFalse((self.root / "players/twenty-sessions.json").exists())

    def test_source_pin_rejects_replacement(self):
        old = json.loads(self.manifest.read_text())
        old["source_commit"] = "b" * 40
        self.manifest.write_text(json.dumps(old))
        with self.assertRaisesRegex(ValueError, "release manifest changed"):
            kit.pin_source(self.root, self.manifest)

    def test_existing_private_root_never_overwritten(self):
        with self.assertRaisesRegex(ValueError, "replace an existing workspace"):
            kit.initialize(self.root, self.manifest)

    def test_manifest_symlink_rejected(self):
        alias = self.base / "alias.json"
        alias.symlink_to(self.manifest)
        with self.assertRaisesRegex(ValueError, "symlink"):
            kit.manifest_source(alias)

    def test_invalid_recording_rejected(self):
        p = self.root / "players"
        (p / "fake.mp4").write_bytes(b"bad")
        with self.assertRaises(ValueError):
            kit.checked_video_hash(p, "fake.mp4")
        with self.assertRaises(ValueError):
            kit.checked_video_hash(p, "../fake.mp4")

    def test_linked_recording_rejected(self):
        outside = self.base / "outside.mp4"
        outside.write_bytes(b"0000ftyp" + b"x" * 2000)
        (self.root / "players/linked.mp4").symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "linked"):
            kit.checked_video_hash(self.root / "players", "linked.mp4")

    def test_private_permission_rejected(self):
        if os.name != "posix":
            self.skipTest("POSIX only")
        self.root.chmod(0o755)
        with self.assertRaisesRegex(ValueError, "permissions too broad"):
            kit.pin_source(self.root, self.manifest)

    def test_report_cannot_overwrite(self):
        player = self.root / "players"
        (player / "twenty-sessions.json").write_text("protected")
        original = (player / "twenty-sessions.json").read_text()
        # Even a malformed intake cannot replace protected evidence.
        (player / "operator-metadata.json").write_text("{}")
        with self.assertRaises(ValueError):
            kit.sessions(self.root, self.manifest)
        self.assertEqual((player / "twenty-sessions.json").read_text(), original)

    def test_field_audit_always_needs_original_evidence(self):
        # R83 requires local original game files; a private kit is never GO.
        with patch.object(kit.r83, "run", return_value={
            "source_commit": self.source, "status": "HOLD",
            "production_go": False, "technical_web_ready": False,
            "missing_evidence": list(kit.r83.REQUIRED_CHECKS)
        }):
            verdict = kit.audit(self.root, self.manifest)
        self.assertFalse(verdict["production_go"])
        self.assertEqual(verdict["status"], "HOLD")

    def test_fake_go_refused(self):
        with patch.object(kit.r83, "run", return_value={
            "source_commit": self.source, "status": "GO", "production_go": True
        }):
            with self.assertRaisesRegex(ValueError, "fail-closed"):
                kit.audit(self.root, self.manifest)


if __name__ == "__main__":
    unittest.main(verbosity=2)
