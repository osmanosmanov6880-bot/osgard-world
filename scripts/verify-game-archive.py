#!/usr/bin/env python3
"""Offline game-release contract against ZIP: 11 ZION worlds plus catalog/legacy routes."""
import argparse
import json
import re
import sys
import zipfile
from pathlib import PurePosixPath

ZION_PREFIX="games/zion-9/queue/"
ZION_IDS=tuple(f"ZION-{i:03d}" for i in range(20,31))
LEGACY=("afterimage-run","empire-orbit","inherit","null-shift","remix","swarm","time-empire","vector-zero")
LOCAL_TAG=re.compile(r'<(?:script|link)\b[^>]*?(?:src|href)\s*=\s*["\']([^"\']+)["\']',re.I)
def verify(archive):
    with zipfile.ZipFile(archive) as z:
        names={x.filename for x in z.infolist() if not x.is_dir()}
        required={"index.html","games/index.html","play/index.html",
                  "games/zion-9/worlds.json"}
        required.update(f"{ZION_PREFIX}{id}/index.html" for id in ZION_IDS)
        required.update(f"games/{name}/index.html" for name in LEGACY)
        missing=sorted(required-names)
        if missing: raise ValueError("missing game routes: "+", ".join(missing[:15]))
        manifest=json.loads(z.read("games/zion-9/worlds.json"))
        games=manifest.get("games")
        if not isinstance(games,list) or len(games)!=11:
            raise ValueError("ZION manifest must have 11 worlds")
        ids=set()
        checked_dependencies=0
        for game in games:
            gid=game.get("id")
            if gid in ids: raise ValueError("duplicate ZION game ID")
            ids.add(gid)
            route=game.get("route")
            expected=f"/{ZION_PREFIX}{gid.upper()}/index.html" if isinstance(gid,str) else None
            if route!=expected:
                raise ValueError("ZION route/id mismatch")
            rel=route.lstrip("/")
            html=z.read(rel).decode("utf-8")
            if "<html" not in html.lower() or "</html>" not in html.lower():
                raise ValueError("invalid HTML shell: "+gid)
            for raw in LOCAL_TAG.findall(html):
                raw=raw.split("?",1)[0].split("#",1)[0]
                if not raw or raw.startswith(("http:","https:","data:","mailto:","//","#")):
                    continue
                if raw.startswith("/"):
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
