#!/usr/bin/env python3
"""Independent release gate policy over machine-readable status observations."""
import argparse,json,sys
GATES=("source_build","zip_integrity","game_routes","staging_http","rollback_readiness","backup_recovery","security_config")
def assess(d):
    fail=[k for k in GATES if not isinstance(d.get(k),dict) or d[k].get("status") not in ("passed","ready_for_human_review","verified","verified_for_staging")]
    if d.get("human_approval") is not False:fail.append("human_approval must be pending")
    return {"status":"ready_for_review" if not fail else "blocked","blocked_gates":fail,"deployed":False}
def main():
    p=argparse.ArgumentParser();p.add_argument("evidence");a=p.parse_args()
    try:r=assess(json.load(open(a.evidence,encoding="utf-8")))
    except (ValueError,OSError) as e:print(e,file=sys.stderr);return 2
    print(json.dumps(r,indent=2));return 0 if r["status"]=="ready_for_review" else 2
if __name__=="__main__":raise SystemExit(main())
