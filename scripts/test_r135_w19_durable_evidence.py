#!/usr/bin/env python3
"""Synthetic archive security fixtures; NEVER considered playable W19 evidence."""
from __future__ import annotations
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

mod_path = Path(__file__).with_name("r135-w19-extract-durable-evidence.py")
spec = importlib.util.spec_from_file_location("w19_durable", mod_path)
assert spec and spec.loader
lib = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lib)


def valid_fixture(archive: Path, extras: dict | None = None) -> None:
    members = {
        "r135-w10-release-evidence.json": b"{}",
        "r135-screens/w12-desktop-1366-three-case-evidence.json": b"{}",
        "r135-screens/w12-mobile-390-three-case-evidence.json": b"{}",
    }
    for i in range(13):
        members[f"r135-screens/synthetic-browser-fixture-{i:02d}.png"] = b"test fixture"
    members.update(extras or {})
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as writer:
        for name, content in members.items():
            writer.writestr(name, content)


class DurableW19(unittest.TestCase):
    def test_extract_only_as_unreviewed_preflight(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            valid_fixture(root / "archive.zip")
            result = lib.unpack(root / "archive.zip", root / "safe")
            self.assertEqual(result["files"], 13)
            self.assertFalse(result["fully_certified"])
            self.assertEqual(result["status"], "UNREVIEWED_EXTRACTED_FOR_REVALIDATION")
            self.assertTrue((root/"safe"/"r135-w10-release-evidence.json").is_file())
            with self.assertRaisesRegex(ValueError, "previously extracted"):
                lib.unpack(root / "archive.zip", root / "safe")

    def test_reject_traversal_and_unsupported_extension(self):
        for bad in ("../escape.png", "r135-screens/../../escape.png",
                    "/root/evil", "r135-screens/nested/evil.png",
                    "r135-screens/script.sh", "r135-screens\\bad.png"):
            with self.subTest(bad=bad), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                valid_fixture(root / "archive.zip", {bad: b"not authentic"})
                with self.assertRaisesRegex(ValueError, "unsafe"):
                    lib.unpack(root / "archive.zip", root / "out")

    def test_reject_missing_actual_report_or_original_images(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with zipfile.ZipFile(root/"archive.zip", "w") as writer:
                writer.writestr("r135-w10-release-evidence.json", "{}")
                writer.writestr("r135-screens/one.png", b"1")
            with self.assertRaisesRegex(ValueError, "13 original"):
                lib.unpack(root/"archive.zip", root/"out")

    def test_reject_duplicate_members_and_encryption_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with zipfile.ZipFile(root/"archive.zip", "w") as writer:
                for i in range(13):
                    writer.writestr(f"r135-screens/f-{i:02d}.png", b"fake")
                writer.writestr("r135-w10-release-evidence.json", "{}")
                writer.writestr("r135-screens/w12-desktop-1366-three-case-evidence.json", "{}")
                writer.writestr("r135-screens/w12-desktop-1366-three-case-evidence.json", "{}")
            with self.assertRaisesRegex(ValueError, "duplicate"):
                lib.unpack(root/"archive.zip", root/"out")


if __name__ == "__main__":
    unittest.main()
