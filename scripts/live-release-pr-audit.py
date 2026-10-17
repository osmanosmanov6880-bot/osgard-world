#!/usr/bin/env python3
"""Read-only live GitHub PR dependency audit: no merge, no deployment, no credential output."""
import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
from datetime import datetime,timezone
from urllib.error import HTTPError,URLError
from urllib.request import Request,build_opener,HTTPRedirectHandler
from pathlib import Path

ROOT=Path(__file__).resolve().parent
SPEC=importlib.util.spec_from_file_location("osgard_pr_policy",ROOT/"release-pr-dependency-audit.py")
POLICY=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(POLICY)
API="https://api.github.com/repos/"+POLICY.CANONICAL
CONSOLIDATED_PR=128
CONSOLIDATED_HEAD="integration/consolidated-release-candidate-2026-10-17"
CONSOLIDATED_DEPENDENCIES=tuple(range(107,128))
CONSOLIDATED_BASES={**POLICY.BASE_BRANCHES,
    125:"integration/live-pr-chain-audit-2026-10-17",
    126:"integration/live-chain-verification-2026-10-17",
    127:"integration/chain-integrity-2026-10-17"}
CONSOLIDATED_HEADS={n:CONSOLIDATED_BASES[n+1] for n in CONSOLIDATED_DEPENDENCIES[:-1]}
CONSOLIDATED_HEADS[127]="integration/chain-security-gates-2026-10-17"
class BlockRedirects(HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):
        raise ValueError("GitHub API redirect refused")
def fetch_pr(n,opener=None):
    if type(n) is not int or n not in POLICY.CHAIN:raise ValueError("unexpected PR number")
    opener=opener or build_opener(BlockRedirects()).open
    req=Request(f"{API}/pulls/{n}",headers={"Accept":"application/vnd.github+json","User-Agent":"osgard-pr-chain-audit"})
    with opener(req,timeout=12) as response:
        if response.geturl()!=req.full_url:raise ValueError("unexpected GitHub API response URL")
        raw=response.read(131073)
    if len(raw)>131072:raise ValueError("GitHub API PR response too large")
    data=json.loads(raw)
    if not isinstance(data,dict) or data.get("number")!=n:raise ValueError("unexpected PR API response")
    if data.get("base",{}).get("repo",{}).get("full_name")!=POLICY.CANONICAL:
        raise ValueError("PR repository mismatch")
    if data.get("head",{}).get("repo",{}).get("full_name")!=POLICY.CANONICAL:
        raise ValueError("PR head repository mismatch")
    return {"number":n,"head_ref":data.get("head",{}).get("ref"),"state":data.get("state"),"base":data.get("base",{}).get("ref"),
            "draft":data.get("draft"),"mergeable":data.get("mergeable"),
            "head_sha":data.get("head",{}).get("sha")}
def audit_live(fetcher=fetch_pr):
    records=[fetcher(n) for n in POLICY.CHAIN]
    return POLICY.inspect(records)

def valid_sha(value):
    return isinstance(value,str) and re.fullmatch(r"[0-9a-f]{40}",value) is not None

def fetch_consolidated_json(path,opener=None):
    """Only callers below choose API paths; redirects and oversized replies fail closed."""
    allowed={f"/pulls/{n}" for n in (*CONSOLIDATED_DEPENDENCIES,CONSOLIDATED_PR)}
    allowed.add("/git/ref/heads/master")
    if path not in allowed:raise ValueError("unexpected consolidated API path")
    opener=opener or build_opener(BlockRedirects()).open
    headers={"Accept":"application/vnd.github+json","User-Agent":"osgard-consolidated-pr-audit"}
    token=os.environ.get("OSGARD_PR_AUDIT_TOKEN")
    if token:
        if len(token)>1024 or any(ord(char)<33 or ord(char)>126 for char in token):
            raise ValueError("invalid audit token format")
        headers["Authorization"]="Bearer "+token
    req=Request(API+path,headers=headers)
    try:
        with opener(req,timeout=12) as response:
            if response.geturl()!=req.full_url:raise ValueError("unexpected GitHub API response URL")
            raw=response.read(131073)
    except HTTPError as error:
        raise ValueError(f"GitHub API request failed (HTTP {error.code})") from None
    except (OSError,URLError,TimeoutError) as error:
        raise ValueError("GitHub API request failed") from None
    if len(raw)>131072:raise ValueError("GitHub API response too large")
    data=json.loads(raw)
    if not isinstance(data,dict):raise ValueError("unexpected GitHub API response")
    return data

def fetch_consolidated_pr(n,opener=None):
    if type(n) is not int or n not in (*CONSOLIDATED_DEPENDENCIES,CONSOLIDATED_PR):
        raise ValueError("unexpected consolidated PR number")
    data=fetch_consolidated_json(f"/pulls/{n}",opener)
    if type(data.get("number")) is not int or data["number"]!=n:
        raise ValueError("unexpected PR API response")
    base,head=data.get("base"),data.get("head")
    if not isinstance(base,dict) or not isinstance(head,dict):
        raise ValueError("invalid PR repository metadata")
    for label,side in (("base",base),("head",head)):
        repo=side.get("repo")
        if not isinstance(repo,dict) or repo.get("full_name")!=POLICY.CANONICAL:
            raise ValueError(f"PR {label} repository mismatch")
    return {"number":n,"head_ref":head.get("ref"),"state":data.get("state"),"base":base.get("ref"),
            "draft":data.get("draft"),"merged":data.get("merged"),"mergeable":data.get("mergeable"),
            "head_sha":head.get("sha"),"base_repo":base["repo"]["full_name"],"head_repo":head["repo"]["full_name"]}

def fetch_master_head(opener=None):
    data=fetch_consolidated_json("/git/ref/heads/master",opener)
    obj=data.get("object")
    if data.get("ref")!="refs/heads/master" or not isinstance(obj,dict) or obj.get("type")!="commit" or not valid_sha(obj.get("sha")):
        raise ValueError("invalid live master commit reference")
    return obj["sha"]

def consolidated_record_problems(record,n,base,head):
    if not isinstance(record,dict):return [f"PR {n} missing metadata"]
    errors=[]
    if type(record.get("number")) is not int or record["number"]!=n:errors.append(f"PR {n} identity mismatch")
    if record.get("base_repo")!=POLICY.CANONICAL or record.get("head_repo")!=POLICY.CANONICAL:
        errors.append(f"PR {n} repository mismatch")
    if record.get("state")!="open":errors.append(f"PR {n} not open")
    if record.get("draft") is not True:errors.append(f"PR {n} not a draft review candidate")
    if record.get("merged") is not False:errors.append(f"PR {n} not confirmed unmerged")
    if record.get("base")!=base:errors.append(f"PR {n} changed base")
    if record.get("head_ref")!=head:errors.append(f"PR {n} changed head branch")
    if not valid_sha(record.get("head_sha")):errors.append(f"PR {n} invalid head sha")
    return errors

def candidate_problems(record,expected_head):
    errors=consolidated_record_problems(record,CONSOLIDATED_PR,"master",CONSOLIDATED_HEAD)
    if isinstance(record,dict):
        if record.get("head_sha")!=expected_head:errors.append("candidate head does not match expected head")
        if record.get("mergeable") is not True:errors.append("candidate not confirmed mergeable")
    return errors

def git_read(repository,*args,allow_exit_one=False):
    """No fetch, checkout, hooks or writes; inherited Git overrides cannot change the proof."""
    env={key:value for key,value in os.environ.items() if not key.startswith("GIT_")}
    env.update({"GIT_NO_REPLACE_OBJECTS":"1","GIT_OPTIONAL_LOCKS":"0","GIT_NO_LAZY_FETCH":"1",
                "GIT_TERMINAL_PROMPT":"0","GIT_CONFIG_NOSYSTEM":"1","GIT_CONFIG_GLOBAL":os.devnull})
    completed=subprocess.run(["git","--no-replace-objects","--no-optional-locks","-C",str(repository),*args],
        capture_output=True,text=True,env=env,timeout=15,check=False)
    if len(completed.stdout)>131072 or len(completed.stderr)>131072:raise ValueError("Git proof output too large")
    if completed.returncode==1 and allow_exit_one:return None
    if completed.returncode!=0:
        raise ValueError(f"Git proof failed ({args[0]}): {completed.stderr.strip()[:1000]}")
    return completed.stdout.strip()

def verify_checkout(repository,expected_head,master_sha,dependencies):
    """Prove immutable objects and ancestry in a complete, unmodified local Git graph."""
    repository=Path(repository).resolve()
    if not valid_sha(expected_head) or not valid_sha(master_sha):raise ValueError("invalid Git proof commit sha")
    if git_read(repository,"rev-parse","--is-shallow-repository")!="false":raise ValueError("shallow Git history cannot prove ancestry")
    if git_read(repository,"for-each-ref","--format=%(refname)","refs/replace"):
        raise ValueError("Git replacement refs are forbidden in ancestry proof")
    grafts=Path(git_read(repository,"rev-parse","--git-path","info/grafts"))
    if not grafts.is_absolute():grafts=repository/grafts
    if grafts.exists():raise ValueError("Git grafts are forbidden in ancestry proof")
    # Avoid lazy object downloads even on Git versions without GIT_NO_LAZY_FETCH.
    partial=git_read(repository,"config","--local","--get-regexp",r"^(extensions\.partialclone|remote\..*\.promisor)$",allow_exit_one=True)
    if partial:raise ValueError("partial Git object stores cannot prove local full history")
    def require_commit(sha,label):
        if not valid_sha(sha):raise ValueError(f"{label} invalid commit sha")
        if git_read(repository,"cat-file","-t",sha)!="commit":raise ValueError(f"{label} is not a Git commit")
    def require_ancestor(ancestor,descendant,label):
        if git_read(repository,"merge-base","--is-ancestor",ancestor,descendant,allow_exit_one=True) is None:
            raise ValueError(f"{label} is not an ancestor of the required commit")
    def require_clean_tracked_files():
        flags=("--quiet","--exit-code","--no-ext-diff","--no-textconv","--ignore-submodules=untracked")
        if git_read(repository,"diff","--cached",*flags,"HEAD","--",allow_exit_one=True) is None:
            raise ValueError("tracked staged changes are forbidden in checkout proof")
        if git_read(repository,"diff",*flags,"--",allow_exit_one=True) is None:
            raise ValueError("tracked unstaged changes are forbidden in checkout proof")
    checkout_head=git_read(repository,"rev-parse","--verify","HEAD")
    for sha,label in ((expected_head,"candidate"),(checkout_head,"checkout HEAD"),(master_sha,"master")):
        require_commit(sha,label)
    require_ancestor(expected_head,checkout_head,"candidate in checkout HEAD")
    candidate_tree=git_read(repository,"rev-parse",expected_head+"^{tree}")
    checkout_tree=git_read(repository,"rev-parse",checkout_head+"^{tree}")
    if not valid_sha(candidate_tree) or candidate_tree!=checkout_tree:raise ValueError("checkout tree does not match candidate tree")
    require_clean_tracked_files()
    require_ancestor(master_sha,expected_head,"live master")
    proven=[]
    for record in dependencies:
        sha=record["head_sha"];label=f"PR {record['number']} head"
        require_commit(sha,label)
        require_ancestor(sha,expected_head,label)
        proven.append({"number":record["number"],"head_sha":sha,"is_ancestor":True})
    if git_read(repository,"rev-parse","--verify","HEAD")!=checkout_head:raise ValueError("checkout HEAD moved during Git proof")
    require_clean_tracked_files()
    return {"repository":str(repository),"shallow":False,"replacement_refs":[],"grafts":False,
            "head_sha":checkout_head,"head_tree":checkout_tree,"candidate_sha":expected_head,"candidate_tree":candidate_tree,
            "candidate_is_ancestor_of_checkout":True,"same_tree":True,"tracked_index_clean":True,"tracked_worktree_clean":True,
            "master_sha":master_sha,"master_is_ancestor":True,
            "dependencies":proven}

def audit_consolidated(pr_number,expected_head,repository,fetcher=fetch_consolidated_pr,
                       master_fetcher=fetch_master_head,git_verifier=verify_checkout):
    result={"mode":"consolidated","status":"blocked","pr_number":pr_number,"expected_head":expected_head,
            "canonical_repository":POLICY.CANONICAL,"started_at":datetime.now(timezone.utc).isoformat(),
            "candidate":None,"master_sha":None,"dependencies":[],"checkout_proof":None,"live_recheck":None,
            "problems":[],"merge_performed":False,"deploy_performed":False,
            "notice":"Read-only consolidated review evidence from two matching observations, not an atomic GitHub snapshot. This does not authorize merging or deployment; the independent PR-chain policy is unchanged."}
    try:
        if type(pr_number) is not int or pr_number!=CONSOLIDATED_PR:raise ValueError("only consolidated PR 128 is allowed")
        if not valid_sha(expected_head):raise ValueError("expected head must be a full lowercase commit SHA")
        if repository is None:raise ValueError("local full-history repository is required")
        candidate=fetcher(pr_number)
        result["candidate"]=candidate
        errors=candidate_problems(candidate,expected_head)
        if errors:raise ValueError("; ".join(errors))
        master_sha=master_fetcher()
        if not valid_sha(master_sha):raise ValueError("invalid live master commit sha")
        result["master_sha"]=master_sha
        seen=set();errors=[]
        for n in CONSOLIDATED_DEPENDENCIES:
            record=fetcher(n)
            result["dependencies"].append(record)
            errors.extend(consolidated_record_problems(record,n,CONSOLIDATED_BASES[n],CONSOLIDATED_HEADS[n]))
            if isinstance(record,dict) and valid_sha(record.get("head_sha")):
                if record["head_sha"] in seen:errors.append(f"PR {n} reuses another dependency head commit")
                seen.add(record["head_sha"])
        if errors:raise ValueError("; ".join(errors))
        result["checkout_proof"]=git_verifier(repository,expected_head,master_sha,result["dependencies"])
        # Two observed samples, not an atomic GitHub snapshot. Historical mergeability is
        # irrelevant to inclusion; all dependency identity/state/head fields remain fixed.
        changed=[];errors=[]
        for before in result["dependencies"]:
            n=before["number"];after=fetcher(n)
            errors.extend(consolidated_record_problems(after,n,CONSOLIDATED_BASES[n],CONSOLIDATED_HEADS[n]))
            relevant=lambda row:{key:value for key,value in row.items() if key!="mergeable"} if isinstance(row,dict) else row
            if relevant(before)!=relevant(after):
                changed.append(n);errors.append(f"live dependency PR {n} changed during audit")
        # Re-read the candidate and master last; neither an unknown state nor a moved target passes.
        candidate_after=fetcher(pr_number)
        master_after=master_fetcher()
        errors.extend(candidate_problems(candidate_after,expected_head))
        if candidate_after!=candidate:errors.append("live candidate changed during audit")
        if master_after!=master_sha:errors.append("live master changed during audit")
        result["live_recheck"]={"candidate_unchanged":candidate_after==candidate,"master_unchanged":master_after==master_sha,
                                "dependencies_unchanged":not changed,"changed_dependencies":changed,"master_sha":master_after}
        if errors:raise ValueError("; ".join(errors))
        result["status"]="ready_for_consolidated_review"
    except (OSError,ValueError,TypeError,HTTPError,URLError,TimeoutError,subprocess.SubprocessError) as e:
        message=str(e);token=os.environ.get("OSGARD_PR_AUDIT_TOKEN")
        if token:message=message.replace(token,"[redacted]")
        result["problems"].append(message)
    result["completed_at"]=datetime.now(timezone.utc).isoformat()
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,help="write report as new file; never overwrite")
    p.add_argument("--consolidated-pr",type=int,choices=[CONSOLIDATED_PR],help="explicitly inspect the known consolidated review PR")
    p.add_argument("--expected-head",help="full head SHA from the current PR event, not its synthetic merge SHA")
    p.add_argument("--repository",type=Path,help="local checkout with full history for immutable Git ancestry proof")
    a=p.parse_args()
    if a.consolidated_pr is None and (a.expected_head is not None or a.repository is not None):
        p.error("--expected-head and --repository require --consolidated-pr")
    if a.consolidated_pr is not None and (a.expected_head is None or a.repository is None):
        p.error("--consolidated-pr requires --expected-head and --repository")
    try:
        result=audit_live() if a.consolidated_pr is None else audit_consolidated(a.consolidated_pr,a.expected_head,a.repository)
        serialized=json.dumps(result,indent=2,ensure_ascii=False)+"\n"
        if a.out:
            with a.out.open("x",encoding="utf-8") as f:f.write(serialized)
        print(serialized,end="")
        return 0 if result["status"] in ("ready_for_independent_review","ready_for_consolidated_review") else 2
    except (OSError,ValueError,TypeError,HTTPError,URLError,TimeoutError) as e:
        print("BLOCK PR AUDIT:",e,file=sys.stderr);return 2
if __name__=="__main__":raise SystemExit(main())
