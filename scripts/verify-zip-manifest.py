#!/usr/bin/env python3
"""Bind a ZIP's exact uncompressed files to a pre-existing deterministic manifest."""
import argparse
import hashlib
import json
import re
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath

SHA=re.compile(r"^[a-f0-9]{64}$")
MAX_FILES=20000
MAX_ASSET_BYTES=25*1024*1024
MAX_TOTAL_BYTES=1024*1024*1024
def verify(archive, manifest):
    if not isinstance(manifest,dict) or manifest.get("schema_version")!=1:
        raise ValueError("invalid manifest schema")
    expected=manifest.get("files")
    if not isinstance(expected,list) or not expected:
        raise ValueError("manifest has no files")
    if len(expected)>MAX_FILES:
        raise ValueError("manifest exceeds file limit")
    index={}
    folded=set()
    total=0
    for row in expected:
        if not isinstance(row,dict) or set(row)!={"path","size","sha256"}:
            raise ValueError("invalid manifest entry")
        name=row["path"]
        if not isinstance(name,str) or name in index or not isinstance(row["size"],int) or isinstance(row["size"],bool) or row["size"]<0 or not isinstance(row["sha256"],str) or not SHA.fullmatch(row["sha256"]):
            raise ValueError("invalid or duplicate manifest entry")
        p=PurePosixPath(name)
        if p.is_absolute() or ".." in p.parts or str(p)!=name or "\\" in name or not name:
            raise ValueError("unsafe manifest path")
        if name.casefold() in folded:
            raise ValueError("case-colliding manifest path")
        folded.add(name.casefold())
        if row["size"]>MAX_ASSET_BYTES:
            raise ValueError("manifest asset exceeds size limit")
        total+=row["size"]
        if total>MAX_TOTAL_BYTES:
            raise ValueError("manifest exceeds total uncompressed limit")
        index[name]=row
    if manifest.get("file_count")!=len(index) or "index.html" not in index:
        raise ValueError("manifest file count/entrypoint mismatch")
    archive=Path(archive)
    if archive.is_symlink() or not archive.is_file():
        raise ValueError("ZIP must be a regular file")
    seen=set()
    folded_zip=set()
    with zipfile.ZipFile(archive) as z:
        if len(z.infolist())>MAX_FILES+1000:
            raise ValueError("ZIP exceeds entry count limit")
        for info in z.infolist():
            name=info.filename
            if not name or "\\" in name or name.startswith("/") or ".." in PurePosixPath(name).parts:
                raise ValueError("unsafe ZIP path")
            if info.is_dir():
                continue
            if name in seen:
                raise ValueError("duplicate ZIP member")
            if name.casefold() in folded_zip:
                raise ValueError("case-colliding ZIP member")
            folded_zip.add(name.casefold())
            seen.add(name)
            mode=(info.external_attr>>16)&0xF000
            if mode not in (0,stat.S_IFREG):
                raise ValueError("symlink or special ZIP member")
            if info.flag_bits&1:
                raise ValueError("encrypted ZIP member")
            item=index.get(name)
            if item is None:
                raise ValueError("ZIP has an unexpected file: "+name)
            if info.file_size!=item["size"]:
                raise ValueError("ZIP file size differs from manifest: "+name)
            h=hashlib.sha256()
            n=0
            with z.open(info) as f:
                for chunk in iter(lambda:f.read(1024*1024),b""):
                    n+=len(chunk)
                    if n>item["size"]:
                        raise ValueError("ZIP member exceeds declared size")
                    h.update(chunk)
            if n!=item["size"] or h.hexdigest()!=item["sha256"]:
                raise ValueError("ZIP member hash mismatch: "+name)
    if seen!=set(index):
        raise ValueError("ZIP missing manifest files: "+", ".join(sorted(set(index)-seen)[:5]))
    return {"status":"verified","files":len(seen),"zip_sha256":file_sha(archive),
            "manifest_sha256":hashlib.sha256((json.dumps(manifest,ensure_ascii=False,sort_keys=True,separators=(",",":"))+"\n").encode()).hexdigest(),
            "publication_performed":False}

def file_sha(path):
    h=hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("zip",type=Path)
    p.add_argument("--manifest",required=True,type=Path)
    a=p.parse_args()
    try:
        result=verify(a.zip,json.loads(a.manifest.read_text(encoding="utf-8")))
    except (ValueError,OSError,TypeError,zipfile.BadZipFile,RuntimeError,EOFError,json.JSONDecodeError) as e:
        print("BLOCK RELEASE: "+str(e),file=sys.stderr)
        return 2
    print(json.dumps(result,indent=2))
    return 0
if __name__=="__main__":
    raise SystemExit(main())
