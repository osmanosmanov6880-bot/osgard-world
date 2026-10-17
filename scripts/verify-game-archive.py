#!/usr/bin/env python3
"""Offline game-release contract against ZIP: 11 ZION worlds plus catalog/legacy routes."""
import argparse
import json
import re
import sys
import zipfile
from pathlib import PurePosixPath

MAX_GAME_HTML_BYTES=8*1024*1024
MAX_WORLD_MANIFEST_BYTES=256*1024
ZION_PREFIX="games/zion-9/queue/"
ZION_IDS=tuple(f"ZION-{i:03d}" for i in range(20,31))
LEGACY=("afterimage-run","empire-orbit","inherit","null-shift","remix","swarm","time-empire","vector-zero")
LOCAL_TAG=re.compile(r'<(?:script|link)\b[^>]*?(?:src|href)\s*=\s*["\']([^"\']+)["\']',re.I)
def bounded_read(z, name, limit):
    info=z.getinfo(name)
    if info.file_size>limit:
        raise ValueError("oversized game archive entry: "+name)
    with z.open(info) as stream:
        data=stream.read(limit+1)
    if len(data)>limit:
        raise ValueError("oversized game archive entry: "+name)
    return data

def verify(archive):
    with zipfile.ZipFile(archive) as z:
        for member in z.infolist():
            path=member.filename
            if (not path or path.startswith("/") or "\\" in path or
                any(part in ("", ".", "..") for part in path.rstrip("/").split("/"))):
                raise ValueError("unsafe ZIP game archive path: "+path)
            if member.flag_bits & 1:
                raise ValueError("encrypted ZIP game archive entry: "+path)
            mode=(member.external_attr >> 16) & 0o170000
            if mode==0o120000:
                raise ValueError("ZIP game archive symlink: "+path)
        entries=[x.filename for x in z.infolist() if not x.is_dir()]
        if len(entries)!=len(set(entries)):
            raise ValueError("duplicate ZIP game archive member")
        folded=[name.casefold() for name in entries]
        if len(folded)!=len(set(folded)):
            raise ValueError("case-colliding ZIP game archive member")
        names=set(entries)
        required={"index.html","games/index.html","play/index.html",
                  "games/zion-9/worlds.json"}
        required.update(f"{ZION_PREFIX}{id}/index.html" for id in ZION_IDS)
        required.update(f"games/{name}/index.html" for name in LEGACY)
        missing=sorted(required-names)
        if missing: raise ValueError("missing game routes: "+", ".join(missing[:15]))
        manifest=json.loads(bounded_read(z,"games/zion-9/worlds.json",MAX_WORLD_MANIFEST_BYTES))
        if not isinstance(manifest,dict):
            raise ValueError("ZION manifest must be an object")
        games=manifest.get("games")
        if not isinstance(games,list) or len(games)!=11:
            raise ValueError("ZION manifest must have 11 worlds")
        ids=set()
        checked_dependencies=0
        for game in games:
            if not isinstance(game,dict):
                raise ValueError("ZION manifest game must be object")
            gid=game.get("id")
            if not isinstance(gid,str) or gid not in {f"zion-{i:03d}" for i in range(20,31)}:
                raise ValueError("invalid ZION game ID")
            if gid in ids: raise ValueError("duplicate ZION game ID")
            ids.add(gid)
            route=game.get("route")
            expected=f"/{ZION_PREFIX}{gid.upper()}/index.html"
            if route!=expected:
                raise ValueError("ZION route/id mismatch")
            rel=route.lstrip("/")
            html=bounded_read(z,rel,MAX_GAME_HTML_BYTES).decode("utf-8")
            if "<html" not in html.lower() or "</html>" not in html.lower():
                raise ValueError("invalid HTML shell: "+gid)
            for raw in LOCAL_TAG.findall(html):
                raw=raw.split("?",1)[0].split("#",1)[0]
                if not raw or raw.startswith(("http:","https:","data:","mailto:","//","#")):
                    continue
                if raw.startswith("/"):
                    if any(part in (".", "..") for part in raw.split("/")):
                        raise ValueError("unsafe absolute game dependency path")
                    target=raw.lstrip("/")
                else:
                    p=PurePosixPath(rel).parent/raw
                    chunks=[]
                    for part in p.parts:
                        if part=="..":
                            if not chunks: raise ValueError("dependency escapes root")
                            chunks.pop()
                        elif part!=".":chunks.append(part)
                    target="/".join(chunks)
                if target not in names:
                    raise ValueError(f"{gid}: missing dependency {target}")
                checked_dependencies+=1
        # Legacy entries need executable shells too; their mere presence is insufficient.
        for name in LEGACY:
            rel=f"games/{name}/index.html"
            html=bounded_read(z,rel,MAX_GAME_HTML_BYTES).decode("utf-8")
            if "<html" not in html.lower() or "</html>" not in html.lower():
                raise ValueError("invalid legacy HTML shell: "+name)
            for raw in LOCAL_TAG.findall(html):
                raw=raw.split("?",1)[0].split("#",1)[0]
                if not raw or raw.startswith(("http:","https:","data:","mailto:","//","#")):
                    continue
                if raw.startswith("/"):
                    if any(part in (".", "..") for part in raw.split("/")):
                        raise ValueError("unsafe absolute game dependency path")
                    target=raw.lstrip("/")
                else:
                    p=PurePosixPath(rel).parent/raw
                    chunks=[]
                    for part in p.parts:
                        if part=="..":
                            if not chunks: raise ValueError("dependency escapes root")
                            chunks.pop()
                        elif part!=".":chunks.append(part)
                    target="/".join(chunks)
                if target not in names:
                    raise ValueError(f"legacy {name}: missing dependency {target}")
                checked_dependencies+=1
        if ids!={f"zion-{i:03d}" for i in range(20,31)}:
            raise ValueError("unexpected ZION IDs")
        return {"status":"verified","zion_worlds":11,"legacy_entrypoints":len(LEGACY),
                "local_dependencies_checked":checked_dependencies,"publication_performed":False}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("zip")
    args=p.parse_args()
    try:
        result=verify(args.zip)
    except (OSError,ValueError,TypeError,KeyError,zipfile.BadZipFile,UnicodeError,json.JSONDecodeError) as e:
        print("GAME RELEASE BLOCKED: "+str(e),file=sys.stderr)
        return 2
    print(json.dumps(result,indent=2))
    return 0
if __name__=="__main__":raise SystemExit(main())
