#!/usr/bin/env python3
"""Conservative static output configuration auditor; read-only and fail-closed."""
import argparse
import json
import sys
from pathlib import Path

FORBIDDEN={".env","id_ed25519","id_rsa","credentials.json","secrets.json",".ssh",".git"}
def audit(root):
    root=Path(root)
    failures=[]
    if root.is_symlink() or not root.is_dir():
        return {"status":"blocked","failures":["release root is absent or symlinked"],"read_only":True}
    for filename in ("_headers","_redirects","robots.txt"):
        path=root/filename
        if path.is_symlink() or not path.is_file():
            failures.append("missing or unsafe "+filename)
    path=root/"_headers"
    try:
        headers=path.read_text(encoding="utf-8") if path.is_file() and not path.is_symlink() else ""
    except (UnicodeError,OSError):
        headers=""
        failures.append("unreadable headers")
    declarations={}
    for line in headers.splitlines():
        stripped=line.strip()
        if not stripped or stripped.startswith("#") or ":" not in stripped:
            continue
        name,value=stripped.split(":",1)
        declarations.setdefault(name.strip().lower(),[]).append(value.strip().lower())
    if "nosniff" not in declarations.get("x-content-type-options",[]):
        failures.append("missing security header X-Content-Type-Options: nosniff")
    if not any(value for value in declarations.get("referrer-policy",[])):
        failures.append("missing security header Referrer-Policy:")
    for path in root.rglob("*"):
        relative=path.relative_to(root)
        if path.is_symlink():
            failures.append("symlink "+relative.as_posix())
            continue
        if not path.is_file() and not path.is_dir():
            failures.append("non-regular entry "+relative.as_posix())
        if any(part.lower() in FORBIDDEN or part.lower().startswith(".env.") for part in relative.parts):
            failures.append("secret-like filename "+relative.as_posix())
    return {"status":"passed" if not failures else "blocked","failures":failures,"read_only":True}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("root");a=p.parse_args()
    try:
        result=audit(a.root)
    except (OSError,UnicodeError) as exc:
        print("BLOCK:",exc,file=sys.stderr);return 2
    print(json.dumps(result,indent=2))
    return 0 if result["status"]=="passed" else 2
if __name__=="__main__":raise SystemExit(main())
