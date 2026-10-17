import importlib.util
import io
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("attestation", ROOT/"scripts/verify-github-release-evidence.py")
att = importlib.util.module_from_spec(spec)
spec.loader.exec_module(att)

REPO="osmanosmanov6880-bot/osgard-world"
SHA="a"*40
NAMES={key:"OSGARD "+key for key in att.REQUIRED}
def evidence():
    return {"commit_sha":SHA,"checks":{key:{"status":"passed","evidence_url":f"https://github.com/{REPO}/actions/runs/{i+1}"} for i,key in enumerate(att.REQUIRED)}}
class Response:
    def __init__(self, obj): self.stream=io.BytesIO(json.dumps(obj).encode())
    def __enter__(self): return self
    def __exit__(self,*args): self.stream.close()
    def read(self,size): return self.stream.read(size)
def opener(replace=None):
    def fetch(req,timeout=10):
        rid=int(req.full_url.rsplit("/",1)[-1])
        obj={"id":rid,"head_sha":SHA,"name":NAMES[att.REQUIRED[rid-1]],"status":"completed","conclusion":"success","repository":{"full_name":REPO}}
        if replace: obj.update(replace)
        return Response(obj)
    return fetch
class EvidenceTests(unittest.TestCase):
    def test_all_five_valid(self):
        self.assertEqual(att.verify(evidence(),REPO,NAMES,opener())["status"],"verified")
    def test_other_commit_blocked(self):
        self.assertEqual(att.verify(evidence(),REPO,NAMES,opener({"head_sha":"b"*40}))["status"],"blocked")
    def test_failure_blocked(self):
        self.assertEqual(att.verify(evidence(),REPO,NAMES,opener({"conclusion":"failure"}))["status"],"blocked")
    def test_pending_blocked(self):
        self.assertEqual(att.verify(evidence(),REPO,NAMES,opener({"status":"in_progress"}))["status"],"blocked")
    def test_other_repository_blocked(self):
        self.assertEqual(att.verify(evidence(),REPO,NAMES,opener({"repository":{"full_name":"attacker/fork"}}))["status"],"blocked")
    def test_wrong_workflow_blocked(self):
        self.assertEqual(att.verify(evidence(),REPO,NAMES,opener({"name":"Other workflow"}))["status"],"blocked")
    def test_missing_check_blocked(self):
        data=evidence();data["checks"].pop("smoke")
        self.assertEqual(att.verify(data,REPO,NAMES,opener())["status"],"blocked")
    def test_fake_url_blocked(self):
        data=evidence();data["checks"]["archive"]["evidence_url"]="https://github.com.attacker.invalid/foo"
        self.assertEqual(att.verify(data,REPO,NAMES,opener())["status"],"blocked")
    def test_other_repo_url_blocked(self):
        data=evidence();data["checks"]["smoke"]["evidence_url"]="https://github.com/attacker/other/actions/runs/5"
        self.assertEqual(att.verify(data,REPO,NAMES,opener())["status"],"blocked")
    def test_fake_status_blocked(self):
        data=evidence();data["checks"]["code_ci"]["status"]="pending"
        self.assertEqual(att.verify(data,REPO,NAMES,opener())["status"],"blocked")
    def test_redirect_to_userinfo_rejected(self):
        with self.assertRaises(ValueError): att.parse_run_url("https://evil@github.com/"+REPO+"/actions/runs/1",REPO)
    def test_other_run_id_blocked(self):
        self.assertEqual(att.verify(evidence(),REPO,NAMES,opener({"id":999}))["status"],"blocked")
if __name__=="__main__":unittest.main()
