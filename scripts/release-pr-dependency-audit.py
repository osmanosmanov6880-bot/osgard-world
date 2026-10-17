#!/usr/bin/env python3
"""Auditable dry-run plan for stacking OSGARD pull requests. Never merges or deploys."""
import argparse,json,sys
from pathlib import Path
CHAIN=tuple(range(107,123))
CANONICAL="osmanosmanov6880-bot/osgard-world"
BASE_BRANCHES={107:"master",108:"integration/osgard-quality-suite-2026-10-17",109:"security/attested-release-evidence-2026-10-17",110:"release/artifact-provenance-manifest-2026-10-17",111:"release/zip-manifest-binding-2026-10-17",112:"release/end-to-end-bundle-verification-2026-10-17",113:"qa/staged-game-route-contract-2026-10-17",114:"ci/full-source-release-acceptance-2026-10-17",115:"qa/staging-operations-suite-2026-10-17",116:"hardening/release-quality-fixes-2026-10-17",117:"hardening/release-safety-batch-2026-10-17",118:"hardening/integrated-release-2026-10-17",119:"integration/three-step-acceptance-2026-10-17",120:"engineering/three-block-fifteen-tasks-2026-10-17",121:"hardening/release-evidence-integrity-2026-10-17",122:"hardening/release-proof-validation-2026-10-17"}
def inspect(rows):
    errors=[]
    byid={}
    if not isinstance(rows,list): raise ValueError("PR metadata must be array")
    for row in rows:
        if not isinstance(row,dict) or type(row.get("number")) is not int: raise ValueError("invalid PR record")
        n=row["number"]
        if n in byid:errors.append(f"duplicate PR {n}")
        byid[n]=row
    for n in CHAIN:
        p=byid.get(n)
        if not p:errors.append(f"missing PR {n}");continue
        if p.get("state")!="open":errors.append(f"PR {n} not open")
        if p.get("base")!=BASE_BRANCHES[n]:errors.append(f"PR {n} changed base")
        if p.get("draft") is not True:errors.append(f"PR {n} unexpectedly not draft")
        if p.get("mergeable") is not True:errors.append(f"PR {n} not confirmed mergeable")
        if not isinstance(p.get("head_sha"),str) or len(p["head_sha"])!=40 or any(c not in "0123456789abcdef" for c in p["head_sha"]):errors.append(f"PR {n} invalid head sha")
    return {"status":"ready_for_independent_review" if not errors else "blocked","problems":errors,
            "suggested_order":list(CHAIN),"merge_performed":False,"deploy_performed":False,
            "notice":"PR 103-106 overlap with integrated PR 107; do not merge both sets blindly. Review push-to-master workflow triggers."}
def main():
    p=argparse.ArgumentParser();p.add_argument("pr_snapshot",type=Path);a=p.parse_args()
    try:r=inspect(json.loads(a.pr_snapshot.read_text(encoding="utf-8")))
    except (OSError,ValueError) as e:print("BLOCK",e,file=sys.stderr);return 2
    print(json.dumps(r,ensure_ascii=False,indent=2));return 0 if r["status"]=="ready_for_independent_review" else 2
if __name__=="__main__":raise SystemExit(main())
