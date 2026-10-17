import importlib.util
import copy
import io
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError,URLError
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
          "head":{"sha":f"{n:040x}","ref":m.POLICY.BASE_BRANCHES[n+1] if n!=m.POLICY.CHAIN[-1] else "integration/live-pr-chain-audit-2026-10-17","repo":{"full_name":m.POLICY.CANONICAL}}}
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
   return {"number":n,"state":"open","draft":True,"mergeable":None,"base":m.POLICY.BASE_BRANCHES[n],"head_sha":f"{n:040x}","head_ref":m.POLICY.BASE_BRANCHES[n+1] if n!=m.POLICY.CHAIN[-1] else "integration/live-pr-chain-audit-2026-10-17"}
  self.assertEqual(m.audit_live(fake)["status"],"blocked")

def consolidated_record(n):
 return {"number":n,"state":"open","draft":True,"merged":False,"mergeable":True,
         "base":"master" if n==128 else m.CONSOLIDATED_BASES[n],
         "head_ref":m.CONSOLIDATED_HEAD if n==128 else m.CONSOLIDATED_HEADS[n],
         "head_sha":f"{n:040x}","base_repo":m.POLICY.CANONICAL,"head_repo":m.POLICY.CANONICAL}

def api_record(n):
 r=consolidated_record(n)
 return {"number":n,"state":r["state"],"draft":r["draft"],"merged":r["merged"],"mergeable":r["mergeable"],
         "base":{"ref":r["base"],"sha":"a"*40,"repo":{"full_name":r["base_repo"]}},
         "head":{"ref":r["head_ref"],"sha":r["head_sha"],"repo":{"full_name":r["head_repo"]}}}

class TestConsolidatedTransport(unittest.TestCase):
 def setUp(self):
  self.clean=patch.dict(os.environ,{},clear=False)
  self.clean.start();self.addCleanup(self.clean.stop)
  os.environ.pop("OSGARD_PR_AUDIT_TOKEN",None)
 def opener(self,data,seen=None,url=None):
  def receive(req,timeout):
   if seen is not None:seen.append(req)
   self.assertEqual(timeout,12)
   return Response(url or req.full_url,json.dumps(data).encode())
  return receive
 def test_canonical_pr_and_live_master_endpoint(self):
  seen=[]
  self.assertEqual(m.fetch_consolidated_pr(128,self.opener(api_record(128),seen)),consolidated_record(128))
  master={"ref":"refs/heads/master","object":{"type":"commit","sha":"b"*40}}
  self.assertEqual(m.fetch_master_head(self.opener(master,seen)),"b"*40)
  self.assertEqual([req.full_url for req in seen],[m.API+"/pulls/128",m.API+"/git/ref/heads/master"])
  self.assertTrue(all(req.get_header("Authorization") is None for req in seen))
 def test_token_only_in_fixed_request_header(self):
  seen=[];token="ghs_test_only_secret"
  with patch.dict(os.environ,{"OSGARD_PR_AUDIT_TOKEN":token}):
   value=m.fetch_consolidated_pr(128,self.opener(api_record(128),seen))
  self.assertEqual(seen[0].full_url,m.API+"/pulls/128")
  self.assertEqual(seen[0].get_header("Authorization"),"Bearer "+token)
  self.assertNotIn(token,json.dumps(value))
 def test_invalid_token_never_reaches_transport_or_exception(self):
  for token in ("secret\r\nInjected: x","secret\n","токен","a b","a"*1025):
   with self.subTest(token_length=len(token)),patch.dict(os.environ,{"OSGARD_PR_AUDIT_TOKEN":token}):
    seen=[]
    with self.assertRaisesRegex(ValueError,"invalid audit token format") as caught:
     m.fetch_consolidated_pr(128,self.opener(api_record(128),seen))
    self.assertNotIn(token,str(caught.exception));self.assertEqual(seen,[])
 def test_redirects_and_wrong_repositories_are_refused(self):
  with self.assertRaisesRegex(ValueError,"unexpected GitHub API response URL"):
   m.fetch_consolidated_pr(128,self.opener(api_record(128),url="https://evil.invalid/"))
  with self.assertRaisesRegex(ValueError,"redirect refused"):
   m.BlockRedirects().redirect_request(None,None,302,"Found",{},"https://evil.invalid/")
  for side in ("base","head"):
   for repo in ({"full_name":"evil/fork"},None):
    data=api_record(128);data[side]["repo"]=repo
    with self.subTest(side=side,repo=repo),self.assertRaisesRegex(ValueError,"repository mismatch"):
     m.fetch_consolidated_pr(128,self.opener(data))
 def test_identity_paths_and_response_bounds(self):
  for n in (106,129,True,"128"):
   with self.subTest(n=n),self.assertRaisesRegex(ValueError,"unexpected consolidated PR number"):
    m.fetch_consolidated_pr(n,self.opener(api_record(128)))
  for number in (127,True,None):
   data=api_record(128);data["number"]=number
   with self.subTest(number=number),self.assertRaisesRegex(ValueError,"unexpected PR API response"):
    m.fetch_consolidated_pr(128,self.opener(data))
  with self.assertRaisesRegex(ValueError,"unexpected consolidated API path"):
   m.fetch_consolidated_json("https://evil.invalid/")
  with self.assertRaisesRegex(ValueError,"too large"):
   m.fetch_consolidated_pr(128,lambda req,timeout:Response(req.full_url,b"x"*131073))
  for raw in (b"{",b"null",b"[]"):
   with self.subTest(raw=raw),self.assertRaises(ValueError):
    m.fetch_consolidated_pr(128,lambda req,timeout:Response(req.full_url,raw))
 def test_master_must_be_exact_commit_reference(self):
  valid={"ref":"refs/heads/master","object":{"type":"commit","sha":"b"*40}}
  for change in ({"ref":"refs/heads/other"},{"object":{"type":"tag","sha":"b"*40}},{"object":{"type":"commit","sha":"short"}},{"object":None}):
   with self.subTest(change=change),self.assertRaisesRegex(ValueError,"invalid live master"):
    m.fetch_master_head(self.opener({**valid,**change}))
 def test_transport_errors_do_not_disclose_token(self):
  token="ghs_test_only_secret"
  for error in (URLError("failure "+token),TimeoutError(token),HTTPError(m.API,429,token,None,None)):
   def fail(req,timeout):raise error
   with self.subTest(kind=type(error).__name__),patch.dict(os.environ,{"OSGARD_PR_AUDIT_TOKEN":token}):
    with self.assertRaisesRegex(ValueError,"GitHub API request failed") as caught:
     m.fetch_consolidated_pr(128,fail)
    self.assertNotIn(token,str(caught.exception))

class TestConsolidatedPRAudit(unittest.TestCase):
 def setUp(self):
  self.records={n:consolidated_record(n) for n in (*m.CONSOLIDATED_DEPENDENCIES,128)}
  self.expected=self.records[128]["head_sha"]
  self.master="b"*40;self.reads=[];self.master_reads=0;self.git_calls=[]
 def fetch(self,n):
  self.reads.append(n)
  return copy.deepcopy(self.records[n])
 def fetch_master(self):
  self.master_reads+=1
  return self.master
 def git(self,repository,expected,master,dependencies):
  self.git_calls.append((repository,expected,master,dependencies))
  return {"head_sha":expected,"same_tree":True,"master_sha":master,"dependencies":[r["head_sha"] for r in dependencies]}
 def run_audit(self,**kwargs):
  return m.audit_consolidated(128,self.expected,".",fetcher=kwargs.get("fetcher",self.fetch),
    master_fetcher=kwargs.get("master_fetcher",self.fetch_master),git_verifier=kwargs.get("git_verifier",self.git))
 def assert_blocked(self,result,problem):
  self.assertEqual(result["status"],"blocked")
  self.assertIn(problem,"; ".join(result["problems"]))
  self.assertFalse(result["merge_performed"]);self.assertFalse(result["deploy_performed"])
 def test_included_unmergeable_dependency_passes_only_consolidated_policy(self):
  self.records[107]["mergeable"]=False
  result=self.run_audit()
  self.assertEqual(result["status"],"ready_for_consolidated_review")
  self.assertEqual(result["problems"],[])
  self.assertEqual(len(result["dependencies"]),21)
  self.assertEqual(len(self.reads),44);self.assertEqual(self.master_reads,2)
  for n in (*m.CONSOLIDATED_DEPENDENCIES,128):self.assertEqual(self.reads.count(n),2)
  self.assertTrue(result["live_recheck"]["dependencies_unchanged"])
  self.assertFalse(result["merge_performed"]);self.assertFalse(result["deploy_performed"])
  self.assertIn("does not authorize",result["notice"])
  legacy=m.audit_live(lambda n:copy.deepcopy(self.records[n]))
  self.assertEqual(legacy["status"],"blocked")
  self.assertIn("PR 107 not confirmed mergeable",legacy["problems"])
  self.assertEqual(tuple(m.POLICY.CHAIN),tuple(range(107,125)))
 def test_candidate_state_identity_and_event_head_are_strict(self):
  changes=[("mergeable",None),("mergeable",False),("mergeable",1),("draft",False),("draft",1),
   ("merged",True),("merged",None),("state","closed"),("base","other"),("head_ref","other"),
   ("base_repo","evil/fork"),("head_repo","evil/fork"),("head_sha","c"*40),("head_sha","SHORT"),("number",True)]
  for field,value in changes:
   with self.subTest(field=field,value=value):
    self.records[128]=consolidated_record(128);self.records[128][field]=value
    self.assert_blocked(self.run_audit(),"")
  self.assertEqual(self.git_calls,[])
 def test_explicit_mode_inputs_are_required(self):
  for pr,head,repo in ((127,self.expected,"."),(True,self.expected,"."),(128,"short","."),(128,"A"*40,"."),(128,self.expected,None)):
   with self.subTest(pr=pr,head=head,repo=repo):
    result=m.audit_consolidated(pr,head,repo,fetcher=self.fetch,master_fetcher=self.fetch_master,git_verifier=self.git)
    self.assert_blocked(result,"")
  self.assertEqual(self.reads,[])
 def test_dependency_state_retarget_missing_or_duplicate_blocks(self):
  changes=[(107,"state","closed"),(107,"draft",False),(107,"merged",None),(107,"base","other"),
   (107,"head_ref","other"),(124,"head_ref","other"),(125,"base","other"),(126,"head_ref","other"),(127,"head_ref","other"),
   (125,"base_repo","evil/fork"),(127,"head_repo","evil/fork"),(120,"head_sha","bad"),(127,"head_sha",f"{107:040x}"),(110,"number",111)]
  for n,field,value in changes:
   with self.subTest(n=n,field=field):
    before=self.records[n];self.records[n]={**before,field:value}
    self.assert_blocked(self.run_audit(),"")
    self.records[n]=before
  self.assert_blocked(self.run_audit(fetcher=lambda n:None if n==125 else self.fetch(n)),"PR 125 missing metadata")
  self.assertEqual(self.git_calls,[])
 def test_dependency_mergeability_changes_do_not_replace_inclusion_proof(self):
  def fetch(n):
   value=self.fetch(n)
   if n!=128:value["mergeable"]=False if self.reads.count(n)==1 else None
   return value
  self.assertEqual(self.run_audit(fetcher=fetch)["status"],"ready_for_consolidated_review")
  self.assertEqual(len(self.git_calls),1)
 def test_candidate_changes_after_graph_proof_block(self):
  for field,value in (("head_sha","c"*40),("draft",False),("mergeable",None),("base","other")):
   with self.subTest(field=field):
    self.reads=[]
    def fetch(n):
     record=self.fetch(n)
     if n==128 and self.reads.count(n)>1:record[field]=value
     return record
    self.assert_blocked(self.run_audit(fetcher=fetch),"live candidate changed during audit")
 def test_dependency_head_base_or_state_movement_blocks(self):
  for field,value in (("head_sha","c"*40),("base","other"),("draft",False)):
   with self.subTest(field=field):
    self.reads=[]
    def fetch(n):
     record=self.fetch(n)
     if n==107 and self.reads.count(n)>1:record[field]=value
     return record
    result=self.run_audit(fetcher=fetch)
    self.assert_blocked(result,"live dependency PR 107 changed during audit")
    self.assertEqual(result["live_recheck"]["changed_dependencies"],[107])
 def test_live_master_movement_or_invalid_value_blocks(self):
  values=iter([self.master,"c"*40])
  self.assert_blocked(self.run_audit(master_fetcher=lambda:next(values)),"live master changed during audit")
  self.assert_blocked(self.run_audit(master_fetcher=lambda:"bad"),"invalid live master")
 def test_transport_and_git_proof_errors_block_without_stale_fallback(self):
  def fail(*args):raise URLError("offline")
  self.assert_blocked(self.run_audit(fetcher=fail),"offline")
  self.assert_blocked(self.run_audit(master_fetcher=fail),"offline")
  self.assert_blocked(self.run_audit(git_verifier=fail),"offline")
  self.reads=[]
  def late_fail(n):
   if n==128 and self.reads.count(n)==1:raise TimeoutError("late timeout")
   return self.fetch(n)
  self.assert_blocked(self.run_audit(fetcher=late_fail),"late timeout")
 def test_failure_report_and_cli_never_print_token(self):
  token="ghs_test_only_secret"
  def fail(n):raise ValueError("header failure: Bearer "+token)
  with patch.dict(os.environ,{"OSGARD_PR_AUDIT_TOKEN":token}):
   result=self.run_audit(fetcher=fail)
  self.assertNotIn(token,json.dumps(result))
  malformed="secret\r\nprivate"
  stdout=io.StringIO();stderr=io.StringIO()
  with patch.dict(os.environ,{"OSGARD_PR_AUDIT_TOKEN":malformed}),patch("sys.argv",["audit","--consolidated-pr","128","--expected-head",self.expected,"--repository","."]),patch("sys.stdout",stdout),patch("sys.stderr",stderr):
   code=m.main()
  self.assertEqual(code,2)
  self.assertNotIn(malformed,stdout.getvalue()+stderr.getvalue())
  self.assertIn("invalid audit token format",stdout.getvalue())
 def test_default_cli_still_uses_only_independent_chain(self):
  output=m.POLICY.inspect([consolidated_record(n) for n in m.POLICY.CHAIN])
  stdout=io.StringIO()
  with patch.object(m,"audit_live",return_value=output) as legacy,patch.object(m,"audit_consolidated") as separate,patch("sys.argv",["audit"]),patch("sys.stdout",stdout):
   self.assertEqual(m.main(),0)
  legacy.assert_called_once_with();separate.assert_not_called()
  self.assertEqual(json.loads(stdout.getvalue()),output)

class TestConsolidatedRealGitProof(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.repo=Path(self.tmp.name)
  self.env={key:value for key,value in os.environ.items() if not key.startswith("GIT_")}
  self.env.update({"GIT_CONFIG_NOSYSTEM":"1","GIT_CONFIG_GLOBAL":os.devnull,"GIT_AUTHOR_NAME":"Proof Test","GIT_AUTHOR_EMAIL":"proof@example.invalid",
   "GIT_COMMITTER_NAME":"Proof Test","GIT_COMMITTER_EMAIL":"proof@example.invalid","GIT_TERMINAL_PROMPT":"0"})
  self.command("init","--quiet")
  blob=self.command("hash-object","-w","--stdin",input="original\n")
  self.tree=self.command("mktree",input=f"100644 blob {blob}\ttracked.txt\n")
  root=self.commit("root")
  parent=root;self.dependencies=[]
  for n in m.CONSOLIDATED_DEPENDENCIES:
   parent=self.commit(f"PR {n}",parent)
   self.dependencies.append({"number":n,"head_sha":parent})
  self.master=self.commit("master",root)
  self.candidate=self.commit("candidate",parent,self.master)
  self.checkout=self.commit("synthetic merge",self.master,self.candidate)
  self.command("update-ref","refs/heads/review",self.checkout)
  self.command("symbolic-ref","HEAD","refs/heads/review")
  self.command("read-tree","--reset","-u",self.checkout)
 def command(self,*args,input=None):
  return subprocess.run(["git","-C",str(self.repo),*args],input=input,text=True,capture_output=True,check=True,env=self.env).stdout.strip()
 def commit(self,message,*parents,tree=None):
  args=["commit-tree",tree or self.tree]
  for parent in parents:args.extend(["-p",parent])
  return self.command(*args,input=message+"\n")
 def proof(self,**changes):
  return m.verify_checkout(self.repo,changes.get("candidate",self.candidate),changes.get("master",self.master),changes.get("dependencies",self.dependencies))
 def test_real_full_dag_accepts_only_clean_synthetic_tree(self):
  proof=self.proof()
  self.assertEqual(proof["head_sha"],self.checkout)
  self.assertEqual(proof["candidate_sha"],self.candidate)
  self.assertEqual(proof["head_tree"],proof["candidate_tree"])
  self.assertTrue(proof["same_tree"]);self.assertTrue(proof["master_is_ancestor"])
  self.assertTrue(proof["tracked_index_clean"]);self.assertTrue(proof["tracked_worktree_clean"])
  self.assertEqual(len(proof["dependencies"]),21)
  self.assertTrue(all(row["is_ancestor"] for row in proof["dependencies"]))
 def test_same_tree_without_candidate_ancestry_is_rejected(self):
  self.command("update-ref","refs/heads/review",self.master)
  with self.assertRaisesRegex(ValueError,"candidate in checkout HEAD is not an ancestor"):self.proof()
 def test_descendant_checkout_with_changed_tree_is_rejected(self):
  blob=self.command("hash-object","-w","--stdin",input="changed\n")
  tree=self.command("mktree",input=f"100644 blob {blob}\tproof.txt\n")
  changed=self.commit("different tree",self.candidate,tree=tree)
  self.command("update-ref","refs/heads/review",changed)
  with self.assertRaisesRegex(ValueError,"checkout tree does not match"):self.proof()
 def test_unknown_and_noncommit_objects_are_rejected(self):
  for label,sha in (("missing","f"*40),("tree",self.tree)):
   with self.subTest(label=label):
    for field in ("candidate","master","dependencies"):
     changes={field:sha} if field!="dependencies" else {field:[{"number":107,"head_sha":sha}]}
     with self.subTest(field=field),self.assertRaises(ValueError):self.proof(**changes)
 def test_unrelated_dependency_and_live_master_are_rejected(self):
  unrelated=self.commit("unrelated")
  with self.assertRaisesRegex(ValueError,"PR 107 head is not an ancestor"):
   self.proof(dependencies=[{"number":107,"head_sha":unrelated}])
  with self.assertRaisesRegex(ValueError,"live master is not an ancestor"):
   self.proof(master=unrelated)
 def test_shallow_history_is_rejected(self):
  (self.repo/".git/shallow").write_text(self.candidate+"\n")
  with self.assertRaisesRegex(ValueError,"shallow Git history"):self.proof()
 def test_replacements_cannot_forge_ancestry(self):
  unrelated=self.commit("unrelated")
  self.command("replace",unrelated,self.candidate)
  with self.assertRaisesRegex(ValueError,"replacement refs are forbidden"):
   self.proof(master=unrelated)
 def test_grafts_cannot_forge_ancestry(self):
  unrelated=self.commit("unrelated")
  (self.repo/".git/info/grafts").write_text(self.candidate+" "+unrelated+"\n")
  with self.assertRaisesRegex(ValueError,"grafts are forbidden"):
   self.proof(master=unrelated)
 def test_partial_store_and_git_errors_are_rejected(self):
  self.command("config","remote.origin.promisor","true")
  with self.assertRaisesRegex(ValueError,"partial Git object stores"):self.proof()
  with self.assertRaisesRegex(ValueError,"Git proof failed"):
   m.verify_checkout(self.repo/"missing",self.candidate,self.master,self.dependencies)
 def test_inherited_git_environment_cannot_redirect_the_proof(self):
  with patch.dict(os.environ,{"GIT_DIR":str(self.repo/"missing"),"GIT_SHALLOW_FILE":str(self.repo/"fake-shallow"),"GIT_REPLACE_REF_BASE":"refs/evil/"}):
   self.assertEqual(self.proof()["head_sha"],self.checkout)
 def test_tracked_unstaged_diff_is_rejected(self):
  (self.repo/"tracked.txt").write_text("unstaged edit\n")
  with self.assertRaisesRegex(ValueError,"tracked unstaged changes"):self.proof()
 def test_tracked_staged_diff_is_rejected(self):
  (self.repo/"tracked.txt").write_text("staged edit\n")
  self.command("add","tracked.txt")
  with self.assertRaisesRegex(ValueError,"tracked staged changes"):self.proof()
 def test_untracked_and_ignored_outputs_are_allowed(self):
  (self.repo/"untracked-output.json").write_text("{}\n")
  (self.repo/".git/info/exclude").write_text("ignored-output.json\n")
  (self.repo/"ignored-output.json").write_text("{}\n")
  self.assertTrue(self.proof()["tracked_worktree_clean"])

if __name__=="__main__":unittest.main()
