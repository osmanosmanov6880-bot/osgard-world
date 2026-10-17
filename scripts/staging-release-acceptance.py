#!/usr/bin/env python3
"""Static, fail-closed staging release acceptance; no outgoing network or deployment."""
import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def evaluate(dist,archive,manifest):
    dist=Path(dist)
    config=module("config","release-config-audit.py").audit(dist)
    bundle=module("bundle","release-bundle.py").verify(archive,manifest)
    games=module("games","verify-game-archive.py").verify(archive)
    checks={"security_config":config["status"],"bundle":bundle["status"],"game_routes":games["status"]}
    expected={"security_config":"passed","bundle":"verified_for_staging","game_routes":"verified"}
    failed=[key for key in expected if checks[key]!=expected[key]]
    zion=games.get("zion_worlds")
    legacy=games.get("legacy_entrypoints")
    if type(zion) is not int or zion!=11 or type(legacy) is not int or legacy!=8:
        failed.append("game_entrypoint_count")
    if not isinstance(bundle.get("zip_sha256"),str) or not re.fullmatch(r"[a-f0-9]{64}",bundle["zip_sha256"]):
        failed.append("zip_sha256")
    return {"status":"ready_for_staging_review" if not failed else "blocked",
            "failed":failed,"checks":checks,"zip_sha256":bundle["zip_sha256"],
            "game_entrypoints_checked":zion+legacy if type(zion) is int and type(legacy) is int else 0,
            "staging_deployed":False,"production_modified":False}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--dist",type=Path,required=True)
    p.add_argument("--zip",type=Path,required=True)
    p.add_argument("--manifest",type=Path,required=True)
    args=p.parse_args()
    try:
        result=evaluate(args.dist,args.zip,args.manifest)
    except (OSError,ValueError,TypeError,KeyError,RuntimeError) as exc:
        print("BLOCK STAGING: "+str(exc),file=sys.stderr)
        return 2
    print(json.dumps(result,indent=2))
    return 0 if result["status"]=="ready_for_staging_review" else 2
if __name__=="__main__":raise SystemExit(main())
