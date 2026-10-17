import importlib.util
import unittest
from pathlib import Path
p=Path(__file__).resolve().parents[1]/"scripts/release-pr-dependency-audit.py"
s=importlib.util.spec_from_file_location("pr_audit",p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class PRAuditTest(unittest.TestCase):
 def fixture(self):
  return [{"number":n,"state":"open","base":m.BASE_BRANCHES[n],"draft":True,"mergeable":True,"head_sha":"a"*40,"head_ref":m.BASE_BRANCHES[n+1] if n!=m.CHAIN[-1] else "integration/live-pr-chain-audit-2026-10-17"} for n in m.CHAIN]
 def test_complete_review_only(self):
  r=m.inspect(self.fixture())
  self.assertEqual(r["status"],"ready_for_independent_review")
  self.assertFalse(r["merge_performed"])
  self.assertFalse(r["deploy_performed"])
 def test_missing(self):
  self.assertEqual(m.inspect(self.fixture()[:-1])["status"],"blocked")
 def test_retarget(self):
  d=self.fixture();d[1]["base"]="master"
  self.assertEqual(m.inspect(d)["status"],"blocked")
 def test_not_draft(self):
  d=self.fixture();d[0]["draft"]=False
  self.assertEqual(m.inspect(d)["status"],"blocked")
 def test_unmergeable(self):
  d=self.fixture();d[0]["mergeable"]=None
  self.assertEqual(m.inspect(d)["status"],"blocked")
 def test_duplicate(self):
  d=self.fixture();d.append(dict(d[0]))
  self.assertEqual(m.inspect(d)["status"],"blocked")
 def test_non_hex_sha(self):
  d=self.fixture();d[0]["head_sha"]="x"*40
  self.assertEqual(m.inspect(d)["status"],"blocked")
if __name__=="__main__":unittest.main()
