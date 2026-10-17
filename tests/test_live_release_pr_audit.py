import importlib.util
import io
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/"scripts"
spec=importlib.util.spec_from_file_location("live_pr_audit",ROOT/"live-release-pr-audit.py")
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Response:
 def __init__(self,url,payload):self.url=url;self.payload=payload
 def __enter__(self):return self
 def __exit__(self,*args):pass
 def geturl(self):return self.url
 def read(self,n):return self.payload
class TestLivePRAudit(unittest.TestCase):
 def record(self,n):
  return {"number":n,"state":"open","draft":True,"mergeable":True,
          "base":{"ref":m.POLICY.BASE_BRANCHES[n],"repo":{"full_name":m.POLICY.CANONICAL}},
          "head":{"sha":"a"*40,"ref":m.POLICY.BASE_BRANCHES[n+1] if n!=m.POLICY.CHAIN[-1] else "integration/live-pr-chain-audit-2026-10-17","repo":{"full_name":m.POLICY.CANONICAL}}}
 def test_live_success(self):
  def fake(n):
   x=self.record(n)
   return {"number":n,"state":x["state"],"draft":x["draft"],"mergeable":x["mergeable"],
           "base":x["base"]["ref"],"head_sha":x["head"]["sha"],"head_ref":x["head"]["ref"]}
  self.assertEqual(m.audit_live(fake)["status"],"ready_for_independent_review")
 def test_wrong_repo_refused(self):
  n=107;data=self.record(n);data["base"]["repo"]["full_name"]="evil/other"
  def opener(req,timeout):return Response(req.full_url,json.dumps(data).encode())
  with self.assertRaisesRegex(ValueError,"repository mismatch"):m.fetch_pr(n,opener)
 def test_redirect_refused(self):
  n=107;data=self.record(n)
  def opener(req,timeout):return Response("https://evil.invalid/",json.dumps(data).encode())
  with self.assertRaisesRegex(ValueError,"unexpected GitHub API response URL"):m.fetch_pr(n,opener)
 def test_wrong_number_refused(self):
  n=107;data=self.record(n);data["number"]=999
  def opener(req,timeout):return Response(req.full_url,json.dumps(data).encode())
  with self.assertRaisesRegex(ValueError,"unexpected PR API response"):m.fetch_pr(n,opener)
 def test_oversized_response_refused(self):
  n=107
  def opener(req,timeout):return Response(req.full_url,b"x"*131073)
  with self.assertRaisesRegex(ValueError,"too large"):m.fetch_pr(n,opener)
 def test_unexpected_pr_number_refused(self):
  with self.assertRaisesRegex(ValueError,"unexpected PR number"):m.fetch_pr(999)
 def test_incomplete_chain_blocked(self):
  def fake(n):
   return {"number":n,"state":"open","draft":True,"mergeable":None,"base":m.POLICY.BASE_BRANCHES[n],"head_sha":"a"*40,"head_ref":m.POLICY.BASE_BRANCHES[n+1] if n!=m.POLICY.CHAIN[-1] else "integration/live-pr-chain-audit-2026-10-17"}
  self.assertEqual(m.audit_live(fake)["status"],"blocked")
if __name__=="__main__":unittest.main()
