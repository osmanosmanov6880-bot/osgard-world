#!/usr/bin/env python3
"""Synthetic-only packaging tests. No real Windows engine or GPU is tested."""
import json
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path
import release_package as r

SHA = "a" * 40


def fixture(root):
    web, win = root / "web", root / "windows"
    web.mkdir()
    win.mkdir()
    data = {
        "index.html": (b"<html><canvas></canvas><script src='index.js'></script></html>" + b" " * 260),
        "index.js": b"// Godot synthetic fixture\n" + b"j" * 1500,
        "index.wasm": b"\0asm" + b"w" * 110000,
        "index.pck": b"GDPC" + b"p" * 6000,
    }
    for name, content in data.items():
        (web / name).write_bytes(content)
    evidence = {
        "source_commit": SHA, "godot_release": "4.4.1",
        "software_only": True, "physical_phone_verified": False,
        "files": [{"name": n, "bytes": len(b), "sha256": r.digest(b)}
                  for n,b in data.items()],
    }
    (web / "evidence.json").write_text(json.dumps(evidence))
    pe = bytearray(3_100_000)
    pe[0:2] = b"MZ"
    struct.pack_into("<I", pe, 60, 128)
    pe[128:132] = b"PE\0\0"
    struct.pack_into("<H", pe, 132, 0x8664)
    (win / "LAST_FRONTIER.exe").write_bytes(pe)
    (win / "LAST_FRONTIER.pck").write_bytes(b"GDPC"+b"P"*25000)
    items = {n: {"sha256": r.digest((win/n).read_bytes()),
                 "bytes": (win/n).stat().st_size}
             for n in ("LAST_FRONTIER.exe", "LAST_FRONTIER.pck")}
    (win / "windows-build.json").write_text(json.dumps({
        "schema":"LAST_FRONTIER_W62_WINDOWS_SOURCE_V1", "source_commit": SHA,
        "godot":"4.4.1", "physical_gpu_certified":False,
        "real_windows_boot_verified":False, "files":items,
    }))
    return web,win


class FailClosed(unittest.TestCase):
    def setUp(self):
        tmp=tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root=Path(tmp.name)
        self.web,self.win=fixture(self.root)

    def test_valid_synthetic_structure_not_device_certification(self):
        got=r.package(self.web,self.win,SHA,self.root/"out")
        self.assertEqual(got["status"],"PASS")
        self.assertFalse(got["production_approved"])
        self.assertFalse(got["real_hardware_certified"])
        self.assertGreater(got["verified_members"],8)
        self.assertTrue((self.root/"out"/"SHA256SUMS.txt").is_file())

    def test_same_inputs_reproducible_zip(self):
        a=r.package(self.web,self.win,SHA,self.root/"one")
        b=r.package(self.web,self.win,SHA,self.root/"two")
        self.assertEqual(a["sha256"],b["sha256"])

    def test_rejects_stale_exact_source(self):
        with self.assertRaisesRegex(r.Reject,"stale source"):
            r.package(self.web,self.win,"b"*40,self.root/"out")

    def test_rejects_partial_source_sha(self):
        with self.assertRaisesRegex(r.Reject,"40-character"):
            r.package(self.web,self.win,"abc",self.root/"out")

    def test_rejects_forged_physical_certification(self):
        p=self.win/"windows-build.json"
        meta=json.loads(p.read_text())
        meta["physical_gpu_certified"]=True
        p.write_text(json.dumps(meta))
        with self.assertRaisesRegex(r.Reject,"self-certify"):
            r.package(self.web,self.win,SHA,self.root/"out")

    def test_rejects_missing_wasm(self):
        (self.web/"index.wasm").unlink()
        with self.assertRaisesRegex(r.Reject,"Incomplete"):
            r.package(self.web,self.win,SHA,self.root/"out")

    def test_rejects_corrupt_windows_exe(self):
        p=self.win/"LAST_FRONTIER.exe"
        p.write_bytes(b"NO"+p.read_bytes()[2:])
        with self.assertRaisesRegex(r.Reject,"real Windows EXE"):
            r.package(self.web,self.win,SHA,self.root/"out")

    def test_rejects_stale_browser_byte_attestation(self):
        p=self.web/"index.js"
        p.write_bytes(p.read_bytes()+b"tampered")
        with self.assertRaisesRegex(r.Reject,"Web byte manifest"):
            r.package(self.web,self.win,SHA,self.root/"out")

    def test_rejects_wrong_windows_pck(self):
        p=self.win/"LAST_FRONTIER.pck"
        p.write_bytes(b"NOTA"+p.read_bytes()[4:])
        with self.assertRaisesRegex(r.Reject,"Windows PCK"):
            r.package(self.web,self.win,SHA,self.root/"out")

    def test_rejects_parent_path(self):
        with self.assertRaisesRegex(r.Reject,"Unsafe"):
            r.safe_rel("../payload.exe")

    def test_rejects_absolute_path(self):
        with self.assertRaisesRegex(r.Reject,"Unsafe"):
            r.safe_rel("/tmp/file")

    def test_rejects_symlinked_release_file(self):
        p=self.web/"index.wasm"
        p.unlink()
        p.symlink_to(self.win/"LAST_FRONTIER.exe")
        with self.assertRaisesRegex(r.Reject,"Symlinks"):
            r.package(self.web,self.win,SHA,self.root/"out")

    def test_verifier_refuses_forged_release_go(self):
        report=r.package(self.web,self.win,SHA,self.root/"out")
        original=self.root/"out"/report["file"]
        with zipfile.ZipFile(original) as zf:
            members={name:zf.read(name) for name in zf.namelist()}
        meta=json.loads(members["CANDIDATE_MANIFEST.json"])
        meta["production_approved"]=True
        members["CANDIDATE_MANIFEST.json"]=json.dumps(meta).encode()
        with zipfile.ZipFile(original,"w") as zf:
            for name,data in members.items():
                zf.writestr(name,data)
        with self.assertRaisesRegex(r.Reject,"Forged production"):
            r.verify_archive(original,SHA)


if __name__ == "__main__":
    unittest.main()
