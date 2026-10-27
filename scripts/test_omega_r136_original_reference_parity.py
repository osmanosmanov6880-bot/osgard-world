#!/usr/bin/env python3
"""R136: stdlib-only synthetic CONTRACT tests, NEVER user-art evidence.

No output is a real approved reference or hardware FPS measurement.
"""
from __future__ import annotations

import hashlib
import json
import os
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
import zlib
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "omega-r136-original-reference-parity.py"
SHA = "a" * 40
NAMES = ["omega-r90-report/data/" + c * 40 + ".png" for c in ("b","c","d")]
ORIG_SHA = "omega-r109-evidence/exact-tested-checkout.txt"


def chunk(kind: bytes, payload: bytes) -> bytes:
    crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I",len(payload)) + kind + payload + struct.pack(">I",crc)


def original_png(rgb: tuple[int,int,int]) -> bytes:
    # Isolated source-parser fixture, NOT a pixel reference for the game.
    width, height = 360, 250
    raw = b"".join(b"\x00" + bytes(rgb) * width for _ in range(height))
    return (b"\x89PNG\r\n\x1a\n" +
            chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,2,0,0,0)) +
            chunk(b"IDAT",zlib.compress(raw,8)) + chunk(b"IEND",b""))


def exec_gate(*args: str):
    return subprocess.run([sys.executable,str(SCRIPT),*args],
                          encoding="utf-8",capture_output=True,check=False)


class OriginalSourceArtContract(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory(prefix="omega-r136-private-")
        self.dir = Path(self.t.name)
        self.frames = [original_png((27,51,71)),original_png((53,36,24)),original_png((67,43,78))]
        self.refs = [original_png((140,113,88)),original_png((18,26,32))]
        self.zip = self.dir / "original_chromium.zip"
        with zipfile.ZipFile(self.zip,"w",compression=zipfile.ZIP_DEFLATED) as bundle:
            bundle.writestr(ORIG_SHA,SHA+"\n")
            for name,image in zip(NAMES,self.frames):
                bundle.writestr(name,image)
        self.reference1 = self.dir / "user-APPROVED-world.png"
        self.reference2 = self.dir / "user-APPROVED-cabinet.png"
        self.reference1.write_bytes(self.refs[0])
        self.reference2.write_bytes(self.refs[1])
        self.root = self.dir / "PRIVATE-ART-PAIR"

    def tearDown(self):
        self.t.cleanup()

    def args(self, **kwargs):
        options = {
            "root": str(self.root),
            "sha": SHA,
            "browser-zip": str(self.zip),
            "world-frame": NAMES[0],
            "cabinet-frame": NAMES[1],
            "world-reference":str(self.reference1),
            "cabinet-reference":str(self.reference2),
            "world-approved-sha256":hashlib.sha256(self.refs[0]).hexdigest(),
            "cabinet-approved-sha256":hashlib.sha256(self.refs[1]).hexdigest(),
            "run-id":"40534942845",
            "artifact-id":"12749957022",
        }
        options.update(kwargs)
        args = ["prepare"]
        for key,value in options.items():
            args.extend(["--"+key,str(value)])
        return args

    def test_inspect_original_bounded_members_without_aaa_claim(self):
        proc = exec_gate("inspect","--browser-zip",str(self.zip))
        self.assertEqual(proc.returncode,0,proc.stderr)
        data = json.loads(proc.stdout)
        self.assertEqual(data["source_sha"],SHA)
        self.assertEqual(set(data["source_locked_png_members"]),set(NAMES))
        self.assertNotIn("production_authorized",data)

    def test_missing_original_reference_fails_closed(self):
        self.reference1.unlink()
        proc=exec_gate(*self.args())
        self.assertEqual(proc.returncode,1,proc.stdout)
        self.assertIn("HOLD",proc.stderr)
        self.assertFalse(self.root.exists())

    def test_source_mismatch_fails_closed(self):
        proc=exec_gate(*self.args(sha="e"*40))
        self.assertEqual(proc.returncode,1)
        self.assertIn("must equal actual tested",proc.stderr)
        self.assertFalse(self.root.exists())

    def test_duplicate_original_reference_refused(self):
        self.reference2.write_bytes(self.refs[0])
        proc=exec_gate(*self.args(**{
            "cabinet-approved-sha256":hashlib.sha256(self.refs[0]).hexdigest()
        }))
        self.assertEqual(proc.returncode,1)
        self.assertIn("different ORIGINAL",proc.stderr)
        self.assertFalse(self.root.exists())

    def test_duplicate_godot_screen_refused(self):
        proc=exec_gate(*self.args(**{"cabinet-frame": NAMES[0]}))
        self.assertEqual(proc.returncode,1)
        self.assertIn("DISTINCT original",proc.stderr)
        self.assertFalse(self.root.exists())

    def test_reuse_godot_frame_as_user_original_refused(self):
        self.reference1.write_bytes(self.frames[0])
        proc=exec_gate(*self.args(**{
            "world-approved-sha256":hashlib.sha256(self.frames[0]).hexdigest()
        }))
        self.assertEqual(proc.returncode,1)
        self.assertIn("reference cannot be actual",proc.stderr)

    def test_wrong_approved_original_sha_blocks_art_source_spoof(self):
        proc=exec_gate(*self.args(**{"world-approved-sha256":"f"*64}))
        self.assertEqual(proc.returncode,1)
        self.assertIn("DOES NOT MATCH approved reference SHA",proc.stderr)
        self.assertFalse(self.root.exists())

    def test_source_missing_zip_refused(self):
        with zipfile.ZipFile(self.zip,"w") as z:
            z.writestr(NAMES[0],self.frames[0]);z.writestr(NAMES[1],self.frames[1])
        proc=exec_gate("inspect","--browser-zip",str(self.zip))
        self.assertEqual(proc.returncode,1)
        self.assertIn("missing exact tested checkout",proc.stderr)

    def test_unsafe_zip_member_rejected(self):
        with zipfile.ZipFile(self.zip,"a") as z:
            z.writestr("../not-an-art-source.txt",b"unsafe")
        proc=exec_gate("inspect","--browser-zip",str(self.zip))
        self.assertEqual(proc.returncode,1)
        self.assertIn("unsafe zip",proc.stderr)

    def test_initial_intake_is_private_integrity_not_production_approval(self):
        proc=exec_gate(*self.args())
        self.assertEqual(proc.returncode,0,proc.stderr)
        data=json.loads(proc.stdout)
        self.assertEqual(data["status"],"ART_EVIDENCE_CREATED_REVIEW_REQUIRED")
        self.assertFalse(data["production_authorized"])
        for file in ["reference-world.png","reference-cabinet.png",
                     "actual-world.png","actual-cabinet.png",
                     "manifest.json","comparison.html","review.template.json"]:
            self.assertTrue((self.root/file).is_file(),file)
        self.assertEqual((self.root/"actual-world.png").read_bytes(),self.frames[0])
        self.assertEqual((self.root/"actual-cabinet.png").read_bytes(),self.frames[1])
        self.assertEqual((self.root/"reference-world.png").read_bytes(),self.refs[0])
        html=(self.root/"comparison.html").read_text("utf-8")
        self.assertIn("ART HOLD",html)
        self.assertIn("REAL GODOT",html.upper())
        self.assertNotIn("https://",html)
        if os.name=="posix":
            self.assertEqual(stat.S_IMODE(self.root.stat().st_mode),0o700)
            self.assertEqual(stat.S_IMODE((self.root/"manifest.json").stat().st_mode),0o600)
        audited=exec_gate("audit","--root",str(self.root))
        self.assertEqual(audited.returncode,0,audited.stderr)
        proof=json.loads(audited.stdout)
        self.assertEqual(proof["original_pairs"],2)
        self.assertEqual(proof["status"],"REFERENCE_INTEGRITY_PASS_HUMAN_REVIEW_HOLD")
        self.assertFalse(proof["independent_original_art_review_verified"])
        self.assertFalse(proof["production_authorized"])

    def test_audit_refuses_modified_reference_and_frame(self):
        self.assertEqual(exec_gate(*self.args()).returncode,0)
        (self.root/"reference-world.png").write_bytes(self.refs[1])
        altered=exec_gate("audit","--root",str(self.root))
        self.assertEqual(altered.returncode,1)
        self.assertIn("HOLD",altered.stderr)
        (self.root/"reference-world.png").write_bytes(self.refs[0])
        (self.root/"actual-cabinet.png").write_bytes(self.frames[2])
        altered=exec_gate("audit","--root",str(self.root))
        self.assertEqual(altered.returncode,1)
        self.assertIn("source image modified",altered.stderr)

    def test_private_workspace_cannot_be_reused_or_overwritten(self):
        self.assertEqual(exec_gate(*self.args()).returncode,0)
        another=exec_gate(*self.args())
        self.assertEqual(another.returncode,1)
        self.assertIn("refuse replacement",another.stderr)

    def test_reference_cannot_be_link(self):
        fake=self.dir/"linked-user-ref.png"
        fake.symlink_to(self.reference1)
        proc=exec_gate(*self.args(**{"world-reference":str(fake)}))
        self.assertEqual(proc.returncode,1)
        self.assertIn("must be a real",proc.stderr)


if __name__=="__main__":
    unittest.main(verbosity=2)
