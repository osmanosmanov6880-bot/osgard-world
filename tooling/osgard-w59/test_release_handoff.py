#!/usr/bin/env python3
"""Synthetic-only malicious archive and W58 provenance regressions."""
import copy
import hashlib
import io
import json
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_handoff as g


def sha(data):
    return hashlib.sha256(data).hexdigest()


def zip_bytes(members):
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in members.items():
            z.writestr(name, data)
    return out.getvalue()


def fake_assets(directory):
    members = {
        "web/index.wasm": b"\x00asm" + b"a" * 16,
        "web/index.pck": b"GDPC" + b"b" * 16,
        "web/index.js": b"console.log('test')",
        "windows/OSGARD_FIELD_LAB_W33.exe": b"MZ" + b"c" * 16,
        "windows/OSGARD_FIELD_LAB_W33.pck": b"GDPC" + b"d" * 16,
    }
    members.update({f"qa/test_{i}.txt": bytes([i]) for i in range(26)})
    report = {"source_commit": g.SOURCE_SHA, "godot": "4.4.1",
              "candidate_only": True, "production_modified": False,
              "physical_device_certified": False, "AAA_graphics_certified": False,
              "browser_6_cases_verified": True, "windows_os_boot_verified": True,
              "files": [{"name": n, "bytes": len(data), "sha256": sha(data)}
                        for n, data in sorted(members.items())]}
    members["CANDIDATE_MANIFEST.json"] = json.dumps(report).encode()
    payloads = {
        g.CANDIDATE_NAME: zip_bytes(members),
        g.WEB_NAME: zip_bytes({"index.wasm": b"\x00asm", "index.pck": b"GDPC", "index.js": b"ok"}),
        g.WINDOWS_NAME: zip_bytes({"game.exe": b"MZ", "game.pck": b"GDPC"}),
        g.EVIDENCE_NAME: zip_bytes({"proof.json": b"{}"}),
    }
    for n, data in payloads.items():
        (directory / n).write_bytes(data)
    (directory / "SHA256SUMS.txt").write_text("".join(f"{sha(data)}  {n}\n" for n, data in payloads.items()))
    return payloads


class OfflineHandoffTest(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.addCleanup(self.t.cleanup)
        self.folder = Path(self.t.name)
        self.payloads = fake_assets(self.folder)
        self.pinned = sha(self.payloads[g.CANDIDATE_NAME])

    def verify(self):
        with patch.object(g, "CANDIDATE_SHA256", self.pinned):
            return g.verify(self.folder)

    def test_valid_synthetic_bytes_never_authorize_release(self):
        report = self.verify()
        self.assertEqual(report["offline_integrity"], "PASS")
        self.assertEqual(report["production_decision"], "HOLD")
        self.assertFalse(report["physical_hardware_certified"])
        self.assertFalse(report["master_merge_authorized"])
        self.assertFalse(report["production_published"])
        self.assertEqual(report["assets"][g.CANDIDATE_NAME]["manifest_files_sha256_verified"], 31)

    def test_reject_modified_asset(self):
        (self.folder / g.WEB_NAME).write_bytes(b"modified")
        with self.assertRaisesRegex(ValueError, "SHA256 mismatch"):
            self.verify()

    def test_reject_forged_checklist_and_candidate_checksum(self):
        with self.assertRaisesRegex(ValueError, "independent W52"):
            g.verify(self.folder)

    def test_reject_missing_asset(self):
        (self.folder / g.EVIDENCE_NAME).unlink()
        with self.assertRaisesRegex(ValueError, "exactly four"):
            self.verify()

    def test_reject_duplicate_hash_entries(self):
        f = self.folder / "SHA256SUMS.txt"
        f.write_text(f.read_text() + f"{self.pinned}  {g.CANDIDATE_NAME}\n")
        with self.assertRaisesRegex(ValueError, "duplicated"):
            self.verify()

    def test_reject_source_mismatch(self):
        with self.assertRaisesRegex(ValueError, "pinned"):
            self.verify_source("a" * 40)

    def verify_source(self, value):
        with patch.object(g, "CANDIDATE_SHA256", self.pinned):
            return g.verify(self.folder, value)

    def test_reject_zip_slip_even_if_rehashed(self):
        self.replace_candidate_extra("../escape.txt", b"evil")
        with self.assertRaisesRegex(ValueError, "Unsafe ZIP path"):
            self.verify()

    def test_reject_unmanifested_member(self):
        self.replace_candidate_extra("qa/unmanifested.txt", b"evil")
        with self.assertRaisesRegex(ValueError, "Unmanifested"):
            self.verify()

    def test_reject_manifest_forged_production_or_hardware_flag(self):
        for key, value in (("production_modified", True), ("physical_device_certified", True)):
            with self.subTest(key=key):
                self.change_manifest(key, value)
                with self.assertRaisesRegex(ValueError, "falsely claims"):
                    self.verify()
                self.payloads = fake_assets(self.folder)
                self.pinned = sha(self.payloads[g.CANDIDATE_NAME])

    def test_reject_stale_inner_manifest_sha(self):
        self.change_manifest("source_commit", "a" * 40)
        with self.assertRaisesRegex(ValueError, "Stale"):
            self.verify()

    def test_reject_nested_binary_mismatch(self):
        self.mutate_candidate_member("web/index.wasm", b"notwasm")
        with self.assertRaisesRegex(ValueError, "Invalid game header"):
            self.verify()

    def test_reject_duplicate_zip_member(self):
        p = self.folder / g.EVIDENCE_NAME
        out = io.BytesIO()
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(out, "w") as z:
                z.writestr("proof.json", "{}")
                z.writestr("proof.json", "{}")
        p.write_bytes(out.getvalue())
        self.replace_sums()
        with self.assertRaisesRegex(ValueError, "Duplicate ZIP member"):
            self.verify()

    def test_reject_symlink_member(self):
        p = self.folder / g.EVIDENCE_NAME
        out = io.BytesIO()
        info = zipfile.ZipInfo("shadow")
        info.create_system = 3
        info.external_attr = (0o120777 << 16)
        with zipfile.ZipFile(out, "w") as z:
            z.writestr(info, "path")
        p.write_bytes(out.getvalue())
        self.replace_sums()
        with self.assertRaisesRegex(ValueError, "symbolic link"):
            self.verify()

    def change_manifest(self, key, value):
        p = self.folder / g.CANDIDATE_NAME
        with zipfile.ZipFile(p) as z:
            data = {n: z.read(n) for n in z.namelist()}
        manifest = json.loads(data["CANDIDATE_MANIFEST.json"])
        manifest[key] = value
        data["CANDIDATE_MANIFEST.json"] = json.dumps(manifest).encode()
        p.write_bytes(zip_bytes(data))
        self.pinned = sha(p.read_bytes())
        self.replace_sums()

    def mutate_candidate_member(self, name, payload):
        p = self.folder / g.CANDIDATE_NAME
        with zipfile.ZipFile(p) as z:
            data = {n: z.read(n) for n in z.namelist()}
        data[name] = payload
        manifest = json.loads(data["CANDIDATE_MANIFEST.json"])
        for record in manifest["files"]:
            if record["name"] == name:
                record["bytes"], record["sha256"] = len(payload), sha(payload)
        data["CANDIDATE_MANIFEST.json"] = json.dumps(manifest).encode()
        p.write_bytes(zip_bytes(data))
        self.pinned = sha(p.read_bytes())
        self.replace_sums()

    def replace_candidate_extra(self, name, payload):
        p = self.folder / g.CANDIDATE_NAME
        with zipfile.ZipFile(p) as z:
            data = {n: z.read(n) for n in z.namelist()}
        data[name] = payload
        p.write_bytes(zip_bytes(data))
        self.pinned = sha(p.read_bytes())
        self.replace_sums()

    def replace_sums(self):
        (self.folder / "SHA256SUMS.txt").write_text("".join(
            f"{g.file_sha256(self.folder / n)}  {n}\n" for n in sorted(g.ZIP_NAMES)))


if __name__ == "__main__":
    unittest.main()
