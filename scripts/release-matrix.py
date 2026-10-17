#!/usr/bin/env python3
"""Release-readiness policy; fail closed on forged, partial or mismatched evidence."""
import argparse
import json
import re
import sys
from pathlib import Path
GATES=("source_build","zip_integrity","game_routes","staging_http","rollback_readiness","backup_recovery","security_config")
SHA=re.compile(r"^[a-f0-9]{64}$")
COMMIT=re.compile(r"^(?:[a-f0-9]{40}|[a-f0-9]{64})$")
def assess(data):
    errors=[]
    if not isinstance(data,dict):raise ValueError("evidence must be an object")
    if isinstance(data.get("checks"),dict) and set(data["checks"]) - set(GATES):
        errors.append("unexpected evidence gates")
    if data.get("schema_version")!=2:errors.append("schema_version")
    repository=data.get("repository")
    if repository!="osmanosmanov6880-bot/osgard-world":
        errors.append("repository must identify canonical OSGARD source")
    commit=data.get("commit_sha")
    artifact=data.get("artifact_sha256")
    if not isinstance(commit,str) or not COMMIT.fullmatch(commit):errors.append("commit_sha")
    if not isinstance(artifact,str) or not SHA.fullmatch(artifact):errors.append("artifact_sha256")
    checks=data.get("checks")
    if not isinstance(checks,dict):checks={}
    seen_runs=set()
    for gate in GATES:
        item=checks.get(gate)
        if not isinstance(item,dict) or item.get("status")!="passed":
            errors.append(gate+": missing verified PASS")
            continue
        if item.get("commit_sha")!=commit or item.get("artifact_sha256")!=artifact:
            errors.append(gate+": evidence does not match candidate")
        evidence=item.get("evidence_url")
        if not isinstance(evidence,str) or not re.fullmatch(
            r"https://github\.com/osmanosmanov6880-bot/osgard-world/actions/runs/[1-9][0-9]*", evidence
        ):
            errors.append(gate+": missing auditable CI URL")
        elif evidence in seen_runs:
            errors.append(gate+": reused CI run across independent gates")
        else:
            seen_runs.add(evidence)
    if data.get("human_approval") is not False:errors.append("human approval must remain pending")
    if data.get("payments_enabled") is not False:errors.append("payments must remain disabled")
    return {"status":"ready_for_human_review" if not errors else "blocked",
            "problems":errors,"publication_performed":False}
def main():
    p=argparse.ArgumentParser();p.add_argument("evidence",type=Path);a=p.parse_args()
    try:
        result=assess(json.loads(a.evidence.read_text(encoding="utf-8")))
    except (ValueError,OSError,TypeError) as e:
        print("BLOCK:",e,file=sys.stderr);return 2
    print(json.dumps(result,indent=2));return 0 if result["status"]=="ready_for_human_review" else 2
if __name__=="__main__":raise SystemExit(main())
