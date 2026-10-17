#!/usr/bin/env python3
"""Offline rollback readiness gate, no changes to infrastructure."""
import argparse,json,re,sys
def verify(d):
    issues=[]
    if d.get("schema_version")!=1: issues.append("schema_version")
    if not re.fullmatch("[a-f0-9]{40}",str(d.get("previous_commit",""))):issues.append("previous_commit")
    if not re.fullmatch("[a-f0-9]{64}",str(d.get("previous_zip_sha256",""))):issues.append("previous_zip_sha256")
    if not re.fullmatch("[a-f0-9]{64}",str(d.get("backup_sha256",""))):issues.append("backup_sha256")
    for k in ("backup_restore_tested","previous_release_available","rollback_runbook_reviewed","operator_assigned","maintenance_window_approved"):
        if d.get(k) is not True:issues.append(k)
    if d.get("payments_enabled") is not False:issues.append("payments_enabled")
    return {"status":"ready_for_human_review" if not issues else "blocked","missing":issues,"rollback_performed":False}
def main():
    p=argparse.ArgumentParser();p.add_argument("evidence");a=p.parse_args()
    try:r=verify(json.load(open(a.evidence,encoding="utf-8")))
    except (OSError,ValueError) as e:print("BLOCK:",e,file=sys.stderr);return 2
    print(json.dumps(r,indent=2));return 0 if r["status"]=="ready_for_human_review" else 2
if __name__=="__main__":raise SystemExit(main())
