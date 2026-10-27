import importlib.util
from pathlib import Path
import json
import tempfile
import unittest
import zipfile
import hashlib

SCRIPT = Path(__file__).with_name("gate.py")
spec = importlib.util.spec_from_file_location("osgard_m182_gate", SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

class M182GateTests(unittest.TestCase):
    def setUp(self):
        self.baseline = json.loads(Path(__file__).with_name("M182_EVIDENCE_TEMPLATE.json").read_text())

    def test_empty_real_world_evidence_is_no_go(self):
        result = gate.evaluate(self.baseline, {"ok": False})
        self.assertEqual(result["production_release"], "NO_GO")
        self.assertEqual(result["local_readiness"], "BLOCKED")

    def test_author_is_not_reviewer(self):
        self.assertFalse(gate.independently_accepted({"status":"accepted","author":"same",
            "reviewer":"same","review_url":"https://example.test/1","evidence_sha256":"a"*64}))

    def test_missing_review_url_rejected(self):
        self.assertFalse(gate.independently_accepted({"status":"accepted","author":"alice",
            "reviewer":"bob","evidence_sha256":"a"*64}))

    def test_bad_evidence_hash_rejected(self):
        self.assertFalse(gate.independently_accepted({"status":"accepted","author":"alice",
            "reviewer":"bob","review_url":"https://example.test/1","evidence_sha256":"BAD"}))

    def test_distinct_review_shape_only(self):
        self.assertTrue(gate.independently_accepted({"status":"accepted","author":"alice",
            "reviewer":"bob","review_url":"https://example.test/1","evidence_sha256":"a"*64}))

    def test_dependency_cycle(self):
        self.assertTrue(gate.has_cycle({"a","b"}, [{"from":"a","to":"b"},{"from":"b","to":"a"}]))

    def test_dependency_dag(self):
        self.assertFalse(gate.has_cycle({"a","b"}, [{"from":"a","to":"b"}]))

    def test_sha_mismatch_blocks_archive_before_zip_read(self):
        with tempfile.TemporaryDirectory() as root:
            p = Path(root) / "m181.zip"
            p.write_bytes(b"not an archive")
            self.assertEqual(gate.check_archive(p)["reason"], "archive_sha256_mismatch")

    def test_missing_archive(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(gate.check_archive(Path(root)/"none.zip")["reason"],"archive_missing")

    def test_zip_slip_rejected(self):
        self.assert_unsafe_zip("../escape.txt", "unsafe_member_path")

    def test_windows_backslash_traversal_rejected(self):
        self.assert_unsafe_zip("a\\..\\secret", "unsafe_member_path")

    def test_absolute_zip_rejected(self):
        self.assert_unsafe_zip("/root/file", "unsafe_member_path")

    def test_windows_drive_zip_rejected(self):
        self.assert_unsafe_zip("C:/boot", "unsafe_member_path")

    def test_duplicate_zip_rejected(self):
        self.assert_unsafe_zip(["A.txt", "a.txt"], "duplicate_member")

    def test_nonzip_correct_hash_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            p = Path(root) / "file.zip"
            p.write_bytes(b"broken zip")
            result = gate.check_archive(p, hashlib.sha256(p.read_bytes()).hexdigest())
            self.assertEqual(result["reason"], "invalid_zip")

    def test_safe_zip_accepts_correct_hash(self):
        with tempfile.TemporaryDirectory() as root:
            p = Path(root) / "file.zip"
            with zipfile.ZipFile(p,"w") as z:
                z.writestr("source/readme.txt", "safe")
            result=gate.check_archive(p,hashlib.sha256(p.read_bytes()).hexdigest())
            self.assertTrue(result["ok"])

    def test_no_claim_from_only_176_author_tests(self):
        copy=dict(self.baseline)
        copy["author_test_passes"]=176
        result=gate.evaluate(copy, {"ok":False})
        self.assertEqual(result["production_release"],"NO_GO")

    def assert_unsafe_zip(self,names, reason):
        if isinstance(names,str):
            names=[names]
        with tempfile.TemporaryDirectory() as root:
            p=Path(root)/"source.zip"
            with zipfile.ZipFile(p,"w") as z:
                for name in names:
                    z.writestr(name, "x")
            result=gate.check_archive(p,hashlib.sha256(p.read_bytes()).hexdigest())
            self.assertEqual(result["reason"],reason)

if __name__=="__main__":
    unittest.main()
