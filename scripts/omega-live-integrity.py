#!/usr/bin/env python3
"""Verify the exact public OSGARD Godot Web binary, not just HTTP 200.

The expected release.json comes from a native-tested GitHub commit. The live
manifest must match it exactly and every publicly served byte is independently
SHA-256 checked. Does not require SSH, accounts, keys, or payment access.
"""
import argparse
import hashlib
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

REQUIRED = {"index.html", "index.js", "index.wasm", "index.pck"}
MAX_MANIFEST = 32768
MAX_ASSET = 110 * 1024 * 1024
SHA = re.compile(r"[0-9a-f]{64}")
FILENAME = re.compile(r"[a-zA-Z0-9_.-]{1,128}")


def verify_manifest(expected, observed):
    if not isinstance(expected, dict) or not isinstance(observed, dict):
        raise ValueError("Expected and published manifests must be JSON objects")
    fields = ("engine", "native_tests", "artifact_kind", "source_path", "source_commit")
    if expected.get("engine") != "Godot 4.4.1":
        raise ValueError("Expected artifact must be Godot 4.4.1")
    if expected.get("native_tests") != "passed" or expected.get("artifact_kind") != "native-Godot-HTML5-export":
        raise ValueError("Expected artifact is not a tested original Godot Web export")
    if expected.get("source_path") != "godot/empire-omega":
        raise ValueError("Wrong game source directory")
    if not re.fullmatch(r"[0-9a-f]{40}", str(expected.get("source_commit", ""))):
        raise ValueError("Missing source commit SHA")
    for key in fields:
        if observed.get(key) != expected[key]:
            raise ValueError("Published release mismatch: " + key)
    files = expected.get("files")
    if not isinstance(files, dict) or not REQUIRED.issubset(files) or len(files) > 24:
        raise ValueError("Incomplete or oversized Godot release manifest")
    for name, digest in files.items():
        if not FILENAME.fullmatch(name) or name in (".", "..") or not SHA.fullmatch(str(digest)):
            raise ValueError("Unsafe filename or checksum: " + str(name))
    if observed.get("files") != files:
        raise ValueError("Published file SHA-256 manifest does not match GitHub build")
    return files


def verify_bytes(expected_sha, blocks):
    digest = hashlib.sha256()
    count = 0
    for block in blocks:
        count += len(block)
        if count > MAX_ASSET:
            raise ValueError("Oversized game asset")
        digest.update(block)
    if count == 0:
        raise ValueError("Empty game asset")
    if digest.hexdigest() != expected_sha:
        raise ValueError("Live SHA-256 mismatch")
    return count


def stream_remote(url):
    request = urllib.request.Request(url, headers={
        "User-Agent": "OSGARD-Omega-Original-Binary-Audit/1.0",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "Accept-Encoding": "identity",
    })
    with urllib.request.urlopen(request, timeout=45) as response:
        if response.status != 200:
            raise ValueError("Live server returned HTTP " + str(response.status))
        while True:
            part = response.read(256 * 1024)
            if not part:
                break
            yield part


def verify_live(base, expected, nonce):
    manifest_url = base.rstrip("/") + "/release.json?" + urllib.parse.urlencode({"omega_verify": nonce})
    manifest_data = b""
    for block in stream_remote(manifest_url):
        manifest_data += block
        if len(manifest_data) > MAX_MANIFEST:
            raise ValueError("Oversized live release.json")
    live = json.loads(manifest_data)
    files = verify_manifest(expected, live)
    findings = []
    for name, digest in sorted(files.items()):
        url = base.rstrip("/") + "/" + urllib.parse.quote(name) + "?" + urllib.parse.urlencode({"omega_verify": nonce})
        length = verify_bytes(digest, stream_remote(url))
        findings.append({"file": name, "bytes": length, "sha256": "matched"})
    return {
        "status": "PASS",
        "base": base,
        "source_commit": expected["source_commit"],
        "verified_files": len(findings),
        "bytes": sum(x["bytes"] for x in findings),
        "results": findings,
    }


def self_test():
    files = {"index.html": b"<canvas id='canvas'></canvas>", "index.js": b"Engine", "index.wasm": b"WASM 4.4.1", "index.pck": b"GAME"}
    manifest = {
        "engine": "Godot 4.4.1", "native_tests": "passed",
        "artifact_kind": "native-Godot-HTML5-export", "source_path": "godot/empire-omega",
        "source_commit": "a" * 40,
        "files": {name: hashlib.sha256(body).hexdigest() for name, body in files.items()},
    }
    assert verify_manifest(manifest, dict(manifest)) == manifest["files"]
    for name, data in files.items():
        assert verify_bytes(manifest["files"][name], [data[:2], data[2:]]) == len(data)
    def must_reject(fn):
        try:
            fn()
        except ValueError:
            return
        raise AssertionError("Unsafe release was not rejected")
    tampered = json.loads(json.dumps(manifest))
    tampered["source_commit"] = "b" * 40
    must_reject(lambda: verify_manifest(manifest, tampered))
    tampered = json.loads(json.dumps(manifest))
    tampered["files"]["index.wasm"] = "f" * 64
    must_reject(lambda: verify_manifest(manifest, tampered))
    tampered = json.loads(json.dumps(manifest))
    tampered["files"].pop("index.pck")
    must_reject(lambda: verify_manifest(manifest, tampered))
    tampered = json.loads(json.dumps(manifest))
    tampered["files"]["../private"] = "f" * 64
    must_reject(lambda: verify_manifest(tampered, tampered))
    must_reject(lambda: verify_bytes(manifest["files"]["index.js"], [b"FAKE"]))
    must_reject(lambda: verify_bytes(manifest["files"]["index.js"], []))
    must_reject(lambda: verify_bytes(manifest["files"]["index.js"], [b"Z" * (MAX_ASSET + 1)]))
    print("PASS OMEGA integrity contracts: manifest exactness, source SHA, file SHA, missing/unsafe/oversized rejection")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--expected", default="public/games/omega-3d-preview/release.json")
    parser.add_argument("--base", default="https://osgard.world/games/omega-3d-preview")
    parser.add_argument("--nonce", default="native-release")
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
        else:
            expected = json.loads(Path(args.expected).read_text(encoding="utf-8"))
            result = verify_live(args.base, expected, args.nonce)
            print(json.dumps(result, indent=2))
    except Exception as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}, indent=2), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
