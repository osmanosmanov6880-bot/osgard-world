#!/usr/bin/env python3
"""Conservative static release configuration linter."""
import argparse,json,re,sys
from pathlib import Path
def audit(root):
    root=Path(root)
    failures=[]
    for filename in ("_headers","_redirects","robots.txt"):
        if not (root/filename).is_file():failures.append("missing "+filename)
    headers=(root/"_headers").read_text(encoding="utf-8") if (root/"_headers").is_file() else ""
    for setting in ("X-Content-Type-Options: nosniff","Referrer-Policy:"):
        if setting.lower() not in headers.lower():failures.append("missing security header "+setting)
    for path in root.rglob("*"):
        if path.is_symlink():failures.append("symlink "+str(path.relative_to(root)))
        elif path.is_file():
            name=path.name.lower()
            if name in (".env","id_ed25519","id_rsa","credentials.json") or name.startswith(".env."):
                failures.append("secret-like filename "+str(path.relative_to(root)))
    return {"status":"passed" if not failures else "blocked","failures":failures,"read_only":True}
def main():
    p=argparse.ArgumentParser();p.add_argument("root");a=p.parse_args();r=audit(a.root);print(json.dumps(r,indent=2));return 0 if r["status"]=="passed" else 2
if __name__=="__main__":raise SystemExit(main())
