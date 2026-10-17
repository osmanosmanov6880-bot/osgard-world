#!/usr/bin/env python3
"""Build or verify a deterministic release-artifact manifest, without deploying."""
import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

SHA = re.compile(r"^(?:[a-f0-9]{40}|[a-f0-9]{64})$")
def digest(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda:f.read(1024*1024),b""):
            h.update(block)
    return h.hexdigest()

def inspect(root, commit):
    root=Path(root)
    if root.is_symlink() or not root.is_dir():
        raise ValueError("artifact root must be a directory, not a symlink")
    if not isinstance(commit,str) or not SHA.fullmatch(commit.lower()):
        raise ValueError("invalid Git commit digest")
    rows=[]
    for directory,dirs,files in os.walk(root,followlinks=False):
        for name in dirs+files:
            p=Path(directory)/name
            if p.is_symlink():
                raise ValueError("artifact contains a symlink: "+str(p.relative_to(root)))
        for name in files:
            p=Path(directory)/name
            if not p.is_file():
                raise ValueError("artifact contains non-regular file")
            rel=p.relative_to(root).as_posix()
            if any(part in (".git",".env",".ssh") or part.startswith(".env.") for part in p.relative_to(root).parts):
                raise ValueError("secret-related path: "+rel)
            rows.append({"path":rel,"size":p.stat().st_size,"sha256":digest(p)})
    rows.sort(key=lambda x:x["path"])
    if not rows or not any(row["path"]=="index.html" for row in rows):
        raise ValueError("missing root index.html")
    return {"schema_version":1,"commit_sha":commit.lower(),"file_count":len(rows),"files":rows}

def verify(root, manifest):
    if not isinstance(manifest,dict) or manifest.get("schema_version")!=1:
        raise ValueError("invalid manifest version")
    actual=inspect(root,manifest.get("commit_sha"))
    if actual!=manifest:
        raise ValueError("manifest mismatch: files changed, removed, added, or metadata invalid")
    return {"status":"verified","commit_sha":actual["commit_sha"],"file_count":actual["file_count"],
            "manifest_sha256":hashlib.sha256(canonical(manifest)).hexdigest(),"publication_performed":False}

def canonical(obj):
    return (json.dumps(obj,ensure_ascii=False,sort_keys=True,separators=(",",":"))+"\n").encode("utf-8")

def main():
    p=argparse.ArgumentParser(description=__doc__)
    sub=p.add_subparsers(dest="operation",required=True)
    build=sub.add_parser("build")
    build.add_argument("root",type=Path)
    build.add_argument("--commit",required=True)
    build.add_argument("--output",required=True,type=Path)
    check=sub.add_parser("verify")
    check.add_argument("root",type=Path)
    check.add_argument("--manifest",required=True,type=Path)
    args=p.parse_args()
    try:
        if args.operation=="build":
            report=inspect(args.root,args.commit)
            destination=args.output.absolute()
            if destination.is_symlink() or destination.exists():
                raise ValueError("manifest output must be a new path")
            destination.write_bytes(canonical(report))
            print(json.dumps({"status":"created","files":report["file_count"],"manifest_sha256":digest(destination),"publication_performed":False}))
        else:
            print(json.dumps(verify(args.root,json.loads(args.manifest.read_text(encoding="utf-8")))))
        return 0
    except (OSError,ValueError,TypeError,json.JSONDecodeError) as e:
        print("BLOCK RELEASE: "+str(e),file=sys.stderr)
        return 2
if __name__=="__main__":
    raise SystemExit(main())
