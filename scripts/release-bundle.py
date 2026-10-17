#!/usr/bin/env python3
"""Offline deterministic ZIP release builder + acceptance verifier.

No internet, deployment, production credentials or production database access.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import re
import stat
import sys
import zipfile
from pathlib import Path

HERE=Path(__file__).resolve().parent
FIXED_DATE=(2020,1,1,0,0,0)
REQUIRED_ROUTES=("index.html","play/index.html","games/index.html",
                 "intelligence/index.html","privacy/index.html")
MAX_FILES=20000
MAX_FILE_BYTES=25*1024*1024
MAX_TOTAL_BYTES=1024*1024*1024

def load_module(filename,name):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def snapshot(root,sha):
    m=load_module("release-artifact-manifest.py","osgard_manifest")
    return m.inspect(root,sha)

def digest(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for data in iter(lambda:f.read(1024*1024),b""):
            h.update(data)
    return h.hexdigest()

def build(root,commit,output,manifest_output,required_routes=REQUIRED_ROUTES):
    root=Path(root).absolute()
    output=Path(output).absolute()
    manifest_output=Path(manifest_output).absolute()
    if output==manifest_output or output.is_relative_to(root) or manifest_output.is_relative_to(root):
        raise ValueError("outputs must be distinct and outside build root")
    if output.exists() or manifest_output.exists() or output.is_symlink() or manifest_output.is_symlink():
        raise ValueError("outputs must not already exist")
    data=snapshot(root,commit)
    rows=data["files"]
    if len(rows)>MAX_FILES or sum(r["size"] for r in rows)>MAX_TOTAL_BYTES:
        raise ValueError("build exceeds size/file limit")
    if any(r["size"]==0 or r["size"]>MAX_FILE_BYTES for r in rows):
        raise ValueError("empty or oversized build file")
    missing=sorted(set(required_routes)-{r["path"] for r in rows})
    if missing:
        raise ValueError("required routes missing: "+", ".join(missing))
    # Verify files unchanged while they are streamed into archive. Writing to new output.
    try:
        with zipfile.ZipFile(output,"x",compression=zipfile.ZIP_DEFLATED,compresslevel=9,allowZip64=True) as z:
            for row in rows:
                path=root/row["path"]
                info=zipfile.ZipInfo(row["path"],date_time=FIXED_DATE)
                info.compress_type=zipfile.ZIP_DEFLATED
                info.external_attr=(stat.S_IFREG | 0o644)<<16
                h=hashlib.sha256()
                count=0
                with path.open("rb") as source, z.open(info,"w",force_zip64=True) as dest:
                    for chunk in iter(lambda:source.read(1024*1024),b""):
                        h.update(chunk)
                        count+=len(chunk)
                        dest.write(chunk)
                if count!=row["size"] or h.hexdigest()!=row["sha256"]:
                    raise ValueError("build files changed during ZIP creation: "+row["path"])
        bind=load_module("verify-zip-manifest.py","osgard_zip_binding")
        result=bind.verify(output,data)
        if result["status"]!="verified":
            raise ValueError("ZIP verification not successful")
        serialized=(json.dumps(data,ensure_ascii=False,sort_keys=True,separators=(",",":"))+"\n").encode("utf-8")
        with manifest_output.open("xb") as f:
            f.write(serialized)
        return {"status":"built_and_verified","files":len(rows),
                "zip_sha256":result["zip_sha256"],
                "manifest_sha256":result["manifest_sha256"],
                "commit_sha":commit,"publication_performed":False}
    except BaseException:
        output.unlink(missing_ok=True)
        manifest_output.unlink(missing_ok=True)
        raise

def verify(archive,manifest_path,required_routes=REQUIRED_ROUTES):
    manifest_path=Path(manifest_path)
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise ValueError("manifest must be a regular file")
    data=json.loads(manifest_path.read_text(encoding="utf-8"))
    bind=load_module("verify-zip-manifest.py","osgard_zip_binding")
    result=bind.verify(archive,data)
    gate=load_module("verify-release-zip.py","osgard_zip_safety")
    result2=gate.validate(archive)
    expected={r["path"] for r in data["files"]}
    missing=sorted(set(required_routes)-expected)
    if missing:
        raise ValueError("required routes missing: "+", ".join(missing))
    if result["zip_sha256"]!=result2["archive_sha256"]:
        raise ValueError("ZIP hash discrepancy between independent validators")
    return {"status":"verified_for_staging","file_count":result["files"],
            "zip_sha256":result["zip_sha256"],
            "manifest_sha256":result["manifest_sha256"],
            "required_routes":len(required_routes),"publication_performed":False}

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    sub=p.add_subparsers(dest="action",required=True)
    b=sub.add_parser("build")
    b.add_argument("dist",type=Path)
    b.add_argument("--commit",required=True)
    b.add_argument("--zip",required=True,type=Path)
    b.add_argument("--manifest",required=True,type=Path)
    v=sub.add_parser("verify")
    v.add_argument("zip",type=Path)
    v.add_argument("--manifest",required=True,type=Path)
    args=p.parse_args(argv)
    try:
        result=build(args.dist,args.commit,args.zip,args.manifest) if args.action=="build" else verify(args.zip,args.manifest)
        print(json.dumps(result,indent=2,ensure_ascii=False))
        return 0
    except (OSError,ValueError,TypeError,zipfile.BadZipFile,RuntimeError,EOFError,json.JSONDecodeError) as e:
        print("BLOCK RELEASE: "+str(e),file=sys.stderr)
        return 2

if __name__=="__main__":
    raise SystemExit(main())
