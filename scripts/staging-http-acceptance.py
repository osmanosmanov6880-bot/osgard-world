#!/usr/bin/env python3
"""Read-only staging HTTP acceptance; allowlisted origin, bounded responses, no credentials."""
import argparse,json,sys
from urllib.parse import urlsplit
from urllib.request import Request,urlopen
from urllib.error import HTTPError,URLError

ROUTES=("/", "/play", "/games", "/intelligence", "/privacy", "/learning/program")
def origin(url):
    p=urlsplit(url)
    if p.scheme!="https" or not p.hostname or p.username or p.password or p.query or p.fragment or p.path not in ("","/"):
        raise ValueError("staging origin must be an HTTPS scheme+host, with no path, credentials or query")
    if p.hostname in ("localhost","127.0.0.1","0.0.0.0") or p.hostname.endswith(".local"):
        raise ValueError("local/non-public staging host refused")
    return url.rstrip("/")
def probe(base,routes=ROUTES,opener=urlopen):
    base=origin(base)
    results=[]
    for route in routes:
        if not route.startswith("/") or route.startswith("//") or ".." in route:
            raise ValueError("unsafe route")
        req=Request(base+route,headers={"User-Agent":"OSGARD-staging-acceptance/1","Accept":"text/html"})
        try:
            with opener(req,timeout=8) as response:
                final=response.geturl()
                if urlsplit(final).netloc.lower()!=urlsplit(base).netloc.lower() or urlsplit(final).scheme!="https":
                    raise ValueError("redirect outside staging origin")
                status=response.status
                ctype=response.headers.get("Content-Type","")
                body=response.read(256*1024+1)
                if len(body)>256*1024:raise ValueError("response exceeds 256 KiB")
                good=status==200 and "text/html" in ctype.lower() and b"<html" in body.lower()
                results.append({"route":route,"passed":good,"status":status,"bytes":len(body)})
        except (HTTPError,URLError,TimeoutError,ValueError) as e:
            results.append({"route":route,"passed":False,"error":type(e).__name__})
    return {"status":"passed" if all(x["passed"] for x in results) else "blocked","routes":results,"read_only":True}
def main():
    p=argparse.ArgumentParser();p.add_argument("--origin",required=True);a=p.parse_args()
    try: result=probe(a.origin)
    except ValueError as e:print("BLOCK:",e,file=sys.stderr);return 2
    print(json.dumps(result,indent=2))
    return 0 if result["status"]=="passed" else 2
if __name__=="__main__":raise SystemExit(main())
