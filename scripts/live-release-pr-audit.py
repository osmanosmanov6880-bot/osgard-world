#!/usr/bin/env python3
"""Read-only live GitHub PR dependency audit: no merge, no deployment, no secrets."""
import argparse
import importlib.util
import json
import re
import sys
from urllib.error import HTTPError,URLError
from urllib.request import Request,build_opener,HTTPRedirectHandler
from pathlib import Path

ROOT=Path(__file__).resolve().parent
SPEC=importlib.util.spec_from_file_location("osgard_pr_policy",ROOT/"release-pr-dependency-audit.py")
POLICY=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(POLICY)
API="https://api.github.com/repos/"+POLICY.CANONICAL
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
    return {"number":n,"state":data.get("state"),"base":data.get("base",{}).get("ref"),
            "draft":data.get("draft"),"mergeable":data.get("mergeable"),
            "head_sha":data.get("head",{}).get("sha")}
def audit_live(fetcher=fetch_pr):
    records=[fetcher(n) for n in POLICY.CHAIN]
    return POLICY.inspect(records)
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out",type=Path,help="write report as new file; never overwrite")
    a=p.parse_args()
    try:
        result=audit_live()
        serialized=json.dumps(result,indent=2,ensure_ascii=False)+"\n"
        if a.out:
            with a.out.open("x",encoding="utf-8") as f:f.write(serialized)
        print(serialized,end="")
        return 0 if result["status"]=="ready_for_independent_review" else 2
    except (OSError,ValueError,TypeError,HTTPError,URLError,TimeoutError) as e:
        print("BLOCK PR AUDIT:",e,file=sys.stderr);return 2
if __name__=="__main__":raise SystemExit(main())
