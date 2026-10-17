#!/usr/bin/env python3
"""Offline rollback readiness gate: review-only, no filesystem or production mutation."""
import argparse
import json
import re
import sys
from pathlib import Path

COMMIT=re.compile(r"^[a-f0-9]{40}$")
DIGEST=re.compile(r"^[a-f0-9]{64}$")
def verify(d):
    if not isinstance(d,dict):
        raise ValueError("rollback evidence must be JSON object")
    issues=[]
    if d.get("schema_version")!=2:issues.append("schema_version")
    current=d.get("current_commit")
    previous=d.get("previous_commit")
    if not isinstance(current,str) or not COMMIT.fullmatch(current):issues.append("current_commit")
    if not isinstance(previous,str) or not COMMIT.fullmatch(previous):issues.append("previous_commit")
    if current==previous:issues.append("rollback must target a different commit")
    for key in ("previous_zip_sha256","backup_sha256"):
        value=d.get(key)
        if not isinstance(value,str) or not DIGEST.fullmatch(value):issues.append(key)
    if d.get("backup_restore_tested") is not True:issues.append("backup_restore_tested")
    if d.get("previous_release_available") is not True:issues.append("previous_release_available")
    if d.get("rollback_runbook_reviewed") is not True:issues.append("rollback_runbook_reviewed")
    if d.get("operator_assigned") is not True:issues.append("operator_assigned")
    if d.get("maintenance_window_approved") is not True:issues.append("maintenance_window_approved")
    if d.get("payments_enabled") is not False:issues.append("payments_enabled")
    if d.get("rollback_executed") is not False:issues.append("rollback_executed must be false")
    return {"status":"ready_for_human_review" if not issues else "blocked",
            "missing":issues,"rollback_performed":False}
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("evidence",type=Path);a=p.parse_args()
    try:
        result=verify(json.loads(a.evidence.read_text(encoding="utf-8")))
    except (OSError,ValueError) as error:
        print("BLOCK:",error,file=sys.stderr);return 2
    print(json.dumps(result,indent=2))
    return 0 if result["status"]=="ready_for_human_review" else 2
if __name__=="__main__":raise SystemExit(main())
