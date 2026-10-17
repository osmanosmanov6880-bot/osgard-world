"""Real filesystem regressions for export/source binding and gzip delivery.

These reject tampered candidate fixtures. Actual Godot rendering and inputs are
checked separately by the Chromium acceptance matrix after a real Web export.
"""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("godot_builder", ROOT / "scripts/build-null-shift-godot.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class GodotExportBindingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project = self.root / "source"
        self.project.mkdir()
        (self.project / "main.gd").write_text("extends Node3D\n")
        override = patch.object(BUILDER, "PROJECT", self.project)
        override.start()
        self.addCleanup(override.stop)
        self.output = self.root / "web"
        self.output.mkdir()
        for name, data in {"index.html": b"<canvas></canvas>", "index.js": b"void 0;", "index.wasm": b"\x00asm\x01\x00\x00\x00", "index.pck": b"GDPC test fixture"}.items():
            (self.output / name).write_bytes(data)
        self.info = {"schemaVersion": 1, "engineVersion": BUILDER.LOCK["engineVersion"],
                     "toolchainLockSha256": BUILDER.sha256(BUILDER.LOCK_PATH),
                     "sourceSha256": BUILDER.source_digest(BUILDER.source_index()),
                     "sourceFiles": len(BUILDER.source_index()), "runtimeSmoke": "passed",
                     "files": BUILDER.export_records(self.output)}
        self.save()

    def save(self):
        (self.output / "build-info.json").write_text(json.dumps(self.info))

    def package(self):
        path = self.output / "index.wasm"
        original = path.read_bytes()
        path.write_bytes(gzip.compress(original, mtime=0))
        self.info["files"] = BUILDER.export_records(self.output)
        self.info["packaging"] = {"target": "cloudflare-pages", "wasm": {
            "path": "index.wasm", "contentEncoding": "gzip", "uncompressedBytes": len(original),
            "uncompressedSha256": hashlib.sha256(original).hexdigest()}}
        self.save()

    def test_original_and_losslessly_packaged_bytes_verify(self):
        BUILDER.verify_export(self.output)
        self.package()
        BUILDER.verify_export(self.output)

    def test_source_edit_rejects_a_previously_valid_export(self):
        (self.project / "main.gd").write_text("extends Node\n")
        with self.assertRaisesRegex(ValueError, "current source tree"):
            BUILDER.verify_export(self.output)

    def test_changed_runtime_cannot_reuse_its_metadata(self):
        (self.output / "index.js").write_text("throw new Error('different runtime');")
        with self.assertRaisesRegex(ValueError, "bytes differ"):
            BUILDER.verify_export(self.output)

    def test_added_or_missing_runtime_files_are_rejected(self):
        (self.output / "unexpected.js").write_text("void 0")
        with self.assertRaisesRegex(ValueError, "bytes differ"):
            BUILDER.verify_export(self.output)
        (self.output / "unexpected.js").unlink()
        (self.output / "index.pck").unlink()
        with self.assertRaisesRegex(ValueError, "missing required"):
            BUILDER.verify_export(self.output)

    def test_mismatched_toolchain_is_rejected(self):
        self.info["toolchainLockSha256"] = "0" * 64
        self.save()
        with self.assertRaisesRegex(ValueError, "different toolchain"):
            BUILDER.verify_export(self.output)

    def test_failed_or_malformed_build_provenance_is_rejected(self):
        original = dict(self.info)
        for field, value in (("schemaVersion", True), ("runtimeSmoke", "failed"),
                             ("runtimeSmoke", None), ("sourceFiles", -1),
                             ("sourceFiles", True), ("sourceFiles", None)):
            with self.subTest(field=field, value=value):
                self.info = dict(original)
                self.info[field] = value
                self.save()
                with self.assertRaises(ValueError):
                    BUILDER.verify_export(self.output)

    def test_gzip_without_delivery_metadata_is_rejected(self):
        self.package()
        del self.info["packaging"]
        self.save()
        with self.assertRaisesRegex(ValueError, "undeclared"):
            BUILDER.verify_export(self.output)

    def test_compressed_bytes_cannot_claim_a_different_original(self):
        self.package()
        self.info["packaging"]["wasm"]["uncompressedSha256"] = "0" * 64
        self.save()
        with self.assertRaisesRegex(ValueError, "original export"):
            BUILDER.verify_export(self.output)

    def test_metadata_and_source_symlinks_are_rejected(self):
        metadata = self.output / "build-info.json"
        moved = self.root / "elsewhere.json"
        metadata.rename(moved)
        metadata.symlink_to(moved)
        with self.assertRaisesRegex(ValueError, "regular Godot export metadata"):
            BUILDER.verify_export(self.output)
        metadata.unlink()
        metadata.write_bytes(moved.read_bytes())
        (self.project / "linked.gd").symlink_to(self.project / "main.gd")
        with self.assertRaisesRegex(ValueError, "sources must not be symlinks"):
            BUILDER.verify_export(self.output)


if __name__ == "__main__":
    unittest.main()
