import importlib.util
import hashlib
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("release_gate", ROOT / "scripts/unified-release-gate.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

def valid():
    return {"schema_version":1,"release_id":"release-2026-10-17",
            "commit_sha":"a"*40 + "b"*24,"artifact_sha256":"c"*64,
            "payment_mode":"disabled","publication_authorized":False,
            "checks":{key:{"status":"passed","evidence_url":"https://github.com/example/check"}
                      for key in gate.REQUIRED}}

class UnifiedReleaseGateTest(unittest.TestCase):
    def test_fully_evidenced_release_is_only_ready_for_review(self):
        result = gate.check(valid())
        self.assertEqual(result["status"], "ready_for_human_review")
        self.assertFalse(result["publication_performed"])
    def test_every_missing_gate_blocks(self):
        for key in gate.REQUIRED:
            data=valid()
            del data["checks"][key]
            with self.subTest(key=key):
                self.assertEqual(gate.check(data)["status"],"blocked")
    def test_failed_ci_blocks(self):
        data=valid()
        data["checks"]["frontend_ci"]["status"]="failed"
        self.assertEqual(gate.check(data)["status"],"blocked")
    def test_untrusted_evidence_url_blocks(self):
        data=valid()
        data["checks"]["archive"]["evidence_url"]="http://unsafe.test"
        self.assertEqual(gate.check(data)["status"],"blocked")
    def test_bad_hash_blocks(self):
        data=valid()
        data["artifact_sha256"]="unverified"
        self.assertEqual(gate.check(data)["status"],"blocked")
    def test_payments_must_remain_disabled(self):
        data=valid()
        data["payment_mode"]="live"
        self.assertEqual(gate.check(data)["status"],"blocked")
    def test_no_implicit_publication(self):
        data=valid()
        data["publication_authorized"]=True
        self.assertEqual(gate.check(data)["status"],"blocked")
    def test_valid_artifact_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/"release.zip"
            path.write_bytes(b"safe fixture")
            data=valid()
            data["artifact_sha256"]=hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertEqual(gate.check(data,path)["status"],"ready_for_human_review")
            path.write_bytes(b"tampered")
            self.assertEqual(gate.check(data,path)["status"],"blocked")
    def test_symlink_artifact_blocks(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/"release.zip"
            path.write_bytes(b"safe fixture")
            link=Path(directory)/"alias.zip"
            link.symlink_to(path)
            self.assertEqual(gate.check(valid(),link)["status"],"blocked")
    def test_invalid_evidence_format(self):
        with self.assertRaisesRegex(ValueError,"schema_version"):
            gate.check({"schema_version":2})

if __name__=="__main__":
    unittest.main()
