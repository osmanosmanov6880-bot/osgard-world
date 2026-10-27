#!/usr/bin/env python3
"""R137: original LIVE HTTPS R87 -> temporary candidate -> byte-identical R87 recovery.

This tool NEVER deploys, writes master, contacts SSH, changes osgard.world,
claims the original VPS, or grants production/art/hardware approval.
Unlike R134's checked-out source, the seven R87 original bytes originate
from the actual publicly served HTTPS endpoint with pinned digests.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import runpy
import ssl
import sys
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, HTTPSHandler, Request, build_opener

HERE = Path(__file__).resolve().parent
R134 = runpy.run_path(str(HERE / "omega-r134-isolated-rollback.py"))
GUARD = runpy.run_path(str(HERE / "omega-r128-r87-immutability.py"))
FILES = GUARD["PINNED_FILES"]
R87 = GUARD["PINNED_SOURCE_COMMIT"]
ORIGIN = "https://osgard.world/games/omega-3d-preview/"
CAPS = {"index.wasm": 128 << 20, "index.pck": 128 << 20,
        "index.js": 24 << 20, "index.html": 2 << 20, "index.png": 8 << 20,
        "index.audio.worklet.js": 2 << 20,
        "index.audio.position.worklet.js": 2 << 20,
        "release.json": 128 << 10}
SHA40 = re.compile(r"^[a-f0-9]{40}$")


class Hold(RuntimeError):
    pass


class RejectRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise Hold("public R87 HTTPS redirects forbidden")


def _url(name: str) -> str:
    if name not in CAPS:
        raise Hold("only original seven R87 names and release manifest allowed")
    address = ORIGIN + name
    parsed = urlsplit(address)
    if (parsed.scheme != "https" or parsed.hostname != "osgard.world" or
        parsed.port not in (None, 443) or parsed.username is not None or
        parsed.password is not None or parsed.query or parsed.fragment):
        raise Hold("unapproved public R87 HTTP address")
    return address


def private_new(root: Path) -> Path:
    runner = os.environ.get("RUNNER_TEMP")
    if not runner:
        raise Hold("RUNNER_TEMP mandatory; production paths forbidden")
    base = Path(runner).resolve()
    absolute = root.absolute()
    if root.is_symlink() or absolute == base or not absolute.is_relative_to(base):
        raise Hold("writes permitted ONLY inside a dedicated CI RUNNER_TEMP child")
    if root.exists() or absolute.parent.resolve() != base:
        raise Hold("public source download destination must be a fresh direct RUNNER_TEMP child")
    absolute.mkdir(mode=0o700,parents=False,exist_ok=False)
    return absolute


def fetch_original(root: Path) -> dict:
    if len(FILES) != 7 or set(FILES) != set(CAPS) - {"release.json"}:
        raise Hold("original seven SHA-pinned master filenames changed")
    root = private_new(root)
    opener = build_opener(RejectRedirect(),
                          HTTPSHandler(context=ssl.create_default_context()))
    evidence = []
    for filename in ["release.json"] + sorted(FILES):
        address = _url(filename)
        request = Request(address,method="GET",headers={
            "Accept-Encoding":"identity","Cache-Control":"no-cache",
            "User-Agent":"EMPIRE-OMEGA-R137-read-only-real-R87-rollback/1.0"})
        digest = sha256()
        total = 0
        first = b""
        path = root / filename
        fd = os.open(path, os.O_CREAT|os.O_EXCL|os.O_WRONLY, 0o600)
        try:
            with os.fdopen(fd,"wb") as dest,opener.open(request,timeout=60) as res:
                if getattr(res,"status",None)!=200 or res.geturl()!=address:
                    raise Hold("real public R87 HTTPS did not return HTTP 200 at ORIGINAL URL")
                if res.headers.get("Content-Encoding","identity").lower() not in ("identity",""):
                    raise Hold("compressed or transformed bytes cannot prove public original")
                while True:
                    block=res.read(1 << 20)
                    if not block: break
                    total+=len(block)
                    if total>CAPS[filename]:
                        raise Hold("original public file exceeds its hard size cap")
                    if len(first)<4:
                        first=(first+block)[:4]
                    digest.update(block)
                    dest.write(block)
            if not total:
                raise Hold("real public R87 file is empty")
            if filename=="index.wasm" and first!=b"\x00asm":
                raise Hold("real HTTPS WebAssembly magic wrong")
            if filename=="index.pck" and first!=b"GDPC":
                raise Hold("real HTTPS Godot PCK magic wrong")
            if filename in FILES and digest.hexdigest()!=FILES[filename]:
                raise Hold("real public R87 HTTPS original SHA-256 mismatch: "+filename)
            evidence.append({"file":filename,"url":address,"http_status":200,
                             "size":total,"sha256":digest.hexdigest(),
                             "original_live_https_bytes_verified":True})
        except BaseException:
            path.unlink(missing_ok=True)
            raise

    manifest = json.loads((root/"release.json").read_text("utf-8"))
    problems = GUARD["inspect_manifest"](manifest)
    if problems:
        raise Hold("HTTPS original manifest wrong: "+"; ".join(problems))
    original = R134["validate_r87"](root,root/"release.json")
    if original != FILES:
        raise Hold("live public HTTPS R87 bytes not byte-identical to pinned original")
    return {"real_public_https":ORIGIN, "original_source_sha":R87,
            "real_https_original_7_of_7_verified":True,
            "downloaded":evidence,"manifest_sha256":sha256(
                (root/"release.json").read_bytes()).hexdigest()}


def prepare(args: argparse.Namespace) -> dict:
    if not SHA40.fullmatch(args.candidate_sha) or not SHA40.fullmatch(args.master_sha):
        raise Hold("both candidate and checkout master must have real 40-digit Git SHAs")
    evidence = fetch_original(args.baseline)
    info = R134["run"](args.baseline,args.baseline/"release.json",
                       args.candidate,args.stage,args.output,
                       args.candidate_sha,args.master_sha)
    if not info["all_seven_restored_bytes_identical_to_checked_out_master"]:
        raise Hold("recovery stage missing actual seven byte-for-byte restored originals")
    if info["r87_backup_sha256"] != FILES or info["restored_r87_sha256"] != FILES:
        raise Hold("R137 restored bytes differ from real HTTPS original R87")
    record={
        "schema":"empire-omega-r137-real-https-origin-isolated-recovery-v1",
        "status":"ISOLATED_REAL_HTTPS_BACKUP_AND_ROLLBACK_PASS_BROWSER_PENDING",
        "time_utc":datetime.now(timezone.utc).isoformat(),
        "candidate_exact_head_sha":args.candidate_sha,
        "read_only_master_git_sha_for_comparison":args.master_sha,
        "actual_public_https_source_not_git_checkout":True,
        "actual_live_r87_https_7_files_sha_pass":True,
        "public_download":evidence,
        "actual_candidate_replaced_original_in_ephemeral_runner":True,
        "all_seven_original_https_bytes_restored":True,
        "restored_original_SHA256":info["restored_r87_sha256"],
        "restored_real_WebGL2_browser_pass":False,
        "historic_R134_json_origin_field_is_not_R137_provenance":True,
        "read_only_public_HTTP_request_no_VPS_auth":True,
        "real_VPS_or_public_production_rollback_executed":False,
        "physical_hardware_approved":False,
        "human_gameplay_approved":False,
        "aaa_art_approved":False,
        "production_authorized":False
    }
    path=args.output/"R137_REAL_PUBLIC_HTTPS_ISOLATED_RECOVERY.json"
    path.write_text(json.dumps(record,indent=2,sort_keys=True)+"\n",encoding="utf8")
    return record


def finalize(output: Path) -> dict:
    original=output/"R137_REAL_PUBLIC_HTTPS_ISOLATED_RECOVERY.json"
    if original.is_symlink() or not original.is_file():
        raise Hold("missing original source-verified public HTTPS and rollback record")
    obj=json.loads(original.read_text("utf8"))
    if not obj.get("actual_live_r87_https_7_files_sha_pass") or not obj.get(
            "all_seven_original_https_bytes_restored"):
        raise Hold("original real HTTPS recovery is not verified")
    if obj.get("production_authorized"):
        raise Hold("staging evidence must never approve live production")
    viewports=[]
    for name in ("r87-portrait-390x844.json","r87-desktop-1366x768.json"):
        path=output/name
        if path.is_symlink() or not path.is_file():
            raise Hold("original Chromium real R87 browser result missing: "+name)
        v=json.loads(path.read_text("utf8"))
        if not v["real_original_godot_webgl2"] or not v["world"]["realWorldEdges"]:
            raise Hold("restored Godot failed to draw actual city for "+name)
        if not v.get("isolated_nginx_https_restored_r87_verified") or not v.get(
                "original_files_from_public_https_verified_by_r137_source"):
            raise Hold("restored real Godot was not played from isolated HTTPS Nginx")
        if v["page_errors"] or v["git_manifest_source_commit"]!=R87:
            raise Hold("restored original R87 page error or wrong original source")
        if v["rollback_wasm_sha256"] != FILES["index.wasm"]:
            raise Hold("restored Chromium came from wrong source")
        if v["rollback_pck_sha256"] != FILES["index.pck"]:
            raise Hold("restored Chromium PCK wrong")
        viewports.append(v["project"])
    obj["restored_real_WebGL2_browser_pass"]=True
    obj["isolation_acceptance"]="REAL_LIVE_HTTPS_ORIGIN_TO_EPHEMERAL_ROLLBACK_2_BROWSER_PASS"
    obj["real_browser_projects"]=viewports
    obj["real_VPS_or_public_production_rollback_executed"]=False
    obj["production_authorized"]=False
    path=output/"R137_FINAL_TRUE_HTTPS_RECOVERY_AND_CHROMIUM.json"
    path.write_text(json.dumps(obj,indent=2,sort_keys=True)+"\n",encoding="utf8")
    return obj



def self_test() -> None:
    """Fail with actionable diagnostic instead of an empty AssertionError.

    Every positive proof is paired with a negative tamper/escape attempt.
    No real production URL, public download or production path is accessed.
    """
    def require(condition: bool, label: str) -> None:
        if not condition:
            raise Hold("R137 self-test failed: " + label)

    require(len(FILES) == 7, "expected exactly seven original hash locks")
    require(set(FILES) == set(CAPS) - {"release.json"},
            "caps filenames must match all seven original R87 assets")
    require(_url("release.json") == ORIGIN + "release.json",
            "origin HTTPS manifest URL must be exact")
    require(not _url("index.wasm").startswith("http://"),
            "real source must be HTTPS and TLS validated")
    for invalid in ("../secrets", "", "https://evil.example/", "release.json?token=1"):
        rejected = False
        try:
            _url(invalid)
        except Hold:
            rejected = True
        require(rejected, "foreign pathname not rejected: " + repr(invalid))

    require(not bool(SHA40.fullmatch("fake")), "fake source SHA accepted")
    require(bool(SHA40.fullmatch(R87)), "pinned original source SHA malformed")

    good = {"source_commit": R87, "files": dict(FILES)}
    guard = GUARD["inspect_manifest"]
    actual_valid_errors = guard(good)
    require(actual_valid_errors == [],
            "pinned original R87 manifest rejected: " + repr(actual_valid_errors))

    bad_files = dict(FILES)
    bad_files["index.pck"] = "0" * 64
    require(bool(guard({"source_commit": R87, "files": bad_files})),
            "modified original PCK SHA not rejected")
    require(bool(guard({"source_commit": "0" * 40, "files": dict(FILES)})),
            "modified original R87 commit not rejected")
    extra = dict(FILES)
    extra["unexpected.js"] = "0" * 64
    require(bool(guard({"source_commit": R87, "files": extra})),
            "unapproved eighth published file not rejected")
    require(bool(guard({"source_commit": R87, "files": {"index.pck": "0" * 64}})),
            "missing six public files not rejected")

    # Keep exercise entirely offline and read-only. The real R87 HTTPS fetch
    # and true candidate/rollback/browser run in separate mandatory CI steps.
    require(not os.environ.get("EMPIRE_R137_ALLOW_PRODUCTION"),
            "production authorization environment flag must be absent")
    print("R137 self-test PASS: source and 7 SHA locks, strict TLS allowlist, "
          "tamper/extra names rejected, REAL PRODUCTION HOLD")

def main() -> int:
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest="mode",required=True)
    sub.add_parser("self-test")
    x=sub.add_parser("prepare")
    x.add_argument("--baseline",required=True,type=Path)
    x.add_argument("--candidate",required=True,type=Path)
    x.add_argument("--stage",required=True,type=Path)
    x.add_argument("--output",required=True,type=Path)
    x.add_argument("--candidate-sha",required=True)
    x.add_argument("--master-sha",required=True)
    y=sub.add_parser("finalize")
    y.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    try:
        if args.mode=="self-test": self_test()
        elif args.mode=="prepare":
            result=prepare(args)
            print("R137 TRUE HTTPS ORIGINAL 7/7 + EPHEMERAL CANDIDATE TO R87 ROLLBACK PASS, browser pending")
            print("EXACT_SHA="+result["candidate_exact_head_sha"])
        else:
            result=finalize(args.output)
            print("R137 TRUE HTTPS 7/7+ ISOLATED BYTE RESTORE + TWO GENUINE WebGL Chrome PASS, NO PRODUCTION")
        return 0
    except (Hold,OSError,ValueError,AssertionError,KeyError,TypeError) as error:
        print("R137 REAL HTTPS -> ORIGINAL R87 ROLLBACK HARD HOLD:",error,file=sys.stderr)
        return 1

if __name__=="__main__":
    raise SystemExit(main())
