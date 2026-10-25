#!/usr/bin/env python3
"""Unit tests for R135 W6 compatibility and W11 independent SHA-pinned staging.

Synthetic ZIP content is only a contract fixture. It never pretends to be
actual Godot binary artifacts or production acceptance evidence.
"""
from __future__ import annotations

import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

script = Path(__file__).with_name("r135-release-stage.py")
spec = importlib.util.spec_from_file_location("r135_release_stage", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class W11ReleaseStageContracts(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.archive = self.dir / "mock.zip"
        self.manifest = self.dir / "manifest.json"
        self.pin = self.dir / "reviewed-pin.json"
        self.dest = self.dir / "dest"
        self.source = "b" * 40

    def fixture(self) -> None:
        # Small synthetic HTML/JS/WASM and 10 MB highly compressible fake PCK
        # exercise size + SHA + safe extraction without requesting actual game.
        data = {
            "index.html": b"<html><canvas id='canvas'></canvas><script src='index.js'></script></html>",
            "index.js": b"console.log('unit-test only')",
            "index.wasm": b"w" * 4096,
            "index.pck": b"q" * 10_000_010,
        }
        data["index.wasm.gz"] = gzip.compress(data["index.wasm"])
        manifest = {
            "version": "r135-web-legibility-w11-20261024",
            "source_commit": self.source,
            "engine": "Godot 4.4.1",
            "optimized_pck_bytes": len(data["index.pck"]),
            "native_tests": "passed",
            "webgl_browser_software_smoke": "passed",
            "original_glbs_preserved": True,
            "files": {
                name: {
                    "sha256": hashlib.sha256(contents).hexdigest(),
                    "size_bytes": len(contents),
                } for name, contents in data.items()
            },
        }
        encoded = json.dumps(manifest, sort_keys=True, indent=2).encode() + b"\n"
        self.manifest.write_bytes(encoded)
        with zipfile.ZipFile(self.archive, "w", compression=zipfile.ZIP_DEFLATED) as z:
            for name, contents in data.items():
                z.writestr(name, contents)
            z.writestr("release.json", encoded)
        self.pin.write_text(json.dumps({
            "version": manifest["version"],
            "source_commit": self.source,
            "manifest_sha256": hashlib.sha256(encoded).hexdigest(),
        }), encoding="utf-8")

    def test_explicit_w11_pin_allows_verified_staging(self) -> None:
        self.fixture()
        module.stage(self.archive, self.manifest, self.dest, self.pin)
        self.assertEqual((self.dest / "index.pck").stat().st_size, 10_000_010)
        self.assertEqual((self.dest / "index.html").read_text()[:5], "<html")
        self.assertEqual(self.dest.stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.dest / "index.html").stat().st_mode & 0o777, 0o644)

    def test_no_pin_still_rejects_w11_under_w6_default(self) -> None:
        self.fixture()
        with self.assertRaisesRegex(SystemExit, "manifest digest"):
            module.stage(self.archive, self.manifest, self.dest)

    def test_manifest_tamper_rejected_before_overwriting_old_content(self) -> None:
        self.fixture()
        self.dest.mkdir()
        (self.dest / "known-good.txt").write_text("W6 protected")
        self.manifest.write_bytes(self.manifest.read_bytes() + b" ")
        with self.assertRaisesRegex(SystemExit, "manifest digest"):
            module.stage(self.archive, self.manifest, self.dest, self.pin)
        self.assertEqual((self.dest / "known-good.txt").read_text(), "W6 protected")

    def test_pin_can_never_switch_to_arbitrary_version(self) -> None:
        self.fixture()
        pin = json.loads(self.pin.read_text())
        pin["version"] = "r135-web-fake-999"
        self.pin.write_text(json.dumps(pin))
        with self.assertRaisesRegex(SystemExit, "validated R135 W11"):
            module.stage(self.archive, self.manifest, self.dest, self.pin)

    def test_changed_source_commit_rejected(self) -> None:
        self.fixture()
        pin = json.loads(self.pin.read_text())
        pin["source_commit"] = "a" * 40
        self.pin.write_text(json.dumps(pin))
        with self.assertRaisesRegex(SystemExit, "source commit"):
            module.stage(self.archive, self.manifest, self.dest, self.pin)


if __name__ == "__main__":
    unittest.main()
