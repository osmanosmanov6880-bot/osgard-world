#!/usr/bin/env python3
"""Synthetic negative tests for W18 long-term evidence recovery; no real hardware claims."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

FILE = Path(__file__).with_name("r135-w18-release-recover.py")
spec = importlib.util.spec_from_file_location("r135_w18_recover", FILE)
recover = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recover)

# Exactly 11 original image NAMES and 7 additional reports/captures.
FRAMES = (
    "desktop-1366.png", "w6-portrait-optical-active.png",
    "w17-desktop-ru-operator.png", "w17-mobile-ru-operator.png",
    "w8-hud-360x780.png", "w8-hud-430x932.png", "w8-hud-932x430.png",
    "w12-desktop-1366-fault-2-active.png",
    "w12-desktop-1366-fault-3-active.png",
    "w12-mobile-390-fault-2-active.png",
    "w12-mobile-390-fault-3-active.png",
)
EXTRA = (
    "r135-screens/mobile-390.png",
    "r135-screens/w6-desktop-optical-active.png",
    "r135-screens/r135-portrait-capture-proof.json",
    "r135-screens/w12-desktop-1366-three-case-evidence.json",
    "r135-screens/w12-mobile-390-three-case-evidence.json",
    "r135-w10-release-evidence.json", "r135-w11-readability-evidence.json",
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fixture():
    names = [("r135-screens/" + x) for x in FRAMES] + list(EXTRA)
    # Plain synthetic fixture content; never treat these as genuine PNGs.
    data = {name: (name + ":fake-test-evidence").encode() * 2 for name in names}
    game = {"version": recover.VERSION, "source_commit": recover.SOURCE,
            "screenshots_sha256": {
                name: sha(data["r135-screens/" + name]) for name in FRAMES}}
    full = {"schema": recover.SCHEMA, "version": recover.VERSION,
            "source_commit": recover.SOURCE,
            "members": {name: {"bytes": len(raw), "sha256": sha(raw)}
                        for name, raw in data.items()}}
    return data, game, full


def archive(path: Path, data: dict, duplicated: str | None = None,
            symlink: str | None = None):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as output:
        for name, raw in data.items():
            item = zipfile.ZipInfo(name)
            item.compress_type = zipfile.ZIP_DEFLATED
            if name == symlink:
                item.create_system = 3
                item.external_attr = (stat.S_IFLNK | 0o777) << 16
            output.writestr(item, raw)
        if duplicated:
            output.writestr(duplicated, data[duplicated])


class SourcePreservingRecoveryTests(unittest.TestCase):
    def test_exact_18_member_synthetic_recovery(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data, game, pins = fixture()
            z = root / "synthetic.zip"
            archive(z, data)
            paths = [root / "pin.json", root / "source.json"]
            paths[0].write_text(json.dumps(game))
            paths[1].write_text(json.dumps(pins))
            result = recover.restore(paths[0], paths[1], z, root / "output")
            self.assertEqual(result["original_verified_members"], 18)
            self.assertFalse(result["physical_phone_certified"])
            for name, raw in data.items():
                self.assertEqual((root / "output" / name).read_bytes(), raw)

    def test_swapped_report_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data, game, pins = fixture()
            key = "r135-w11-readability-evidence.json"
            # Preserve exact original byte LENGTH to exercise the stronger
            # SHA-256 tampering guard instead of the earlier size guard.
            data[key] = b"x" * len(data[key])
            archive(root / "changed.zip", data)
            with self.assertRaisesRegex(ValueError, "substituted"):
                recover.verified_members(game, pins, root / "changed.zip")
            self.assertFalse((root / "r135-screens").exists())

    def test_wrong_source_cannot_adopt_reviewed_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data, game, pins = fixture()
            archive(root / "source.zip", data)
            game["source_commit"] = "a" * 40
            with self.assertRaisesRegex(ValueError, "source/version"):
                recover.verified_members(game, pins, root / "source.zip")

    def test_reviewed_pin_cannot_include_traversal(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data, game, pins = fixture()
            selected = "r135-screens/mobile-390.png"
            raw = data.pop(selected)
            data["../escape.png"] = raw
            pins["members"].pop(selected)
            pins["members"]["../escape.png"] = {"sha256": sha(raw), "bytes": len(raw)}
            archive(root / "malicious.zip", data)
            with self.assertRaisesRegex(ValueError, "unsafe ZIP"):
                recover.verified_members(game, pins, root / "malicious.zip")

    def test_duplicate_zip_entry_cannot_pass_set_comparison(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data, game, pins = fixture()
            duplicate = next(iter(data))
            archive(root / "duplicate.zip", data, duplicated=duplicate)
            with self.assertRaisesRegex(ValueError, "unknown, duplicate"):
                recover.verified_members(game, pins, root / "duplicate.zip")

    def test_missing_real_report_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data, game, pins = fixture()
            data.pop("r135-w10-release-evidence.json")
            archive(root / "missing.zip", data)
            with self.assertRaisesRegex(ValueError, "unknown, duplicate"):
                recover.verified_members(game, pins, root / "missing.zip")

    def test_zip_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data, game, pins = fixture()
            archive(root / "symlink.zip", data,
                    symlink="r135-w10-release-evidence.json")
            with self.assertRaisesRegex(ValueError, "encrypted, linked"):
                recover.verified_members(game, pins, root / "symlink.zip")

    def test_false_size_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data, game, pins = fixture()
            archive(root / "wrong-size.zip", data)
            key = "r135-screens/mobile-390.png"
            pins["members"][key]["bytes"] += 1
            with self.assertRaisesRegex(ValueError, "size/provenance"):
                recover.verified_members(game, pins, root / "wrong-size.zip")

    def test_fake_hardware_claim_is_not_created_by_restore(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data, game, pins = fixture()
            archive(root / "fixture.zip", data)
            raw = recover.verified_members(game, pins, root / "fixture.zip")
            self.assertEqual(len(raw), 18)
            self.assertNotIn("physical_phone_certified", game)
            self.assertFalse(game.get("physical_phone_certified", False))


if __name__ == "__main__":
    unittest.main()
