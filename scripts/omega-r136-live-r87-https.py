#!/usr/bin/env python3
"""R136: READ-ONLY real public HTTPS R87 byte audit (NOT a deployment).

Only fetch the fixed known osgard.world release URL. Reject redirects, HTTP,
foreign hosts, compressed/transformed bytes, missing data, mismatched digests,
and invalid Godot WASM/PCK magic. This does not certify the origin VPS, a
human playthrough, art, physical GPU or an actual production rollback.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import io
import json
from pathlib import Path
import runpy
import ssl
import sys
from urllib.error import URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, HTTPSHandler, Request, build_opener

HERE = Path(__file__).resolve().parent
BASELINE = runpy.run_path(str(HERE / "omega-r128-r87-immutability.py"))
SOURCE_SHA = BASELINE["PINNED_SOURCE_COMMIT"]
PINNED_FILES = BASELINE["PINNED_FILES"]
MANIFEST_VALIDATOR = BASELINE["inspect_manifest"]
ALLOWED = "https://osgard.world/games/omega-3d-preview/"
CAPS = {
    "index.wasm": 128 * 1024 * 1024,
    "index.pck": 128 * 1024 * 1024,
    "index.js": 24 * 1024 * 1024,
    "index.html": 2 * 1024 * 1024,
    "index.png": 8 * 1024 * 1024,
    "index.audio.worklet.js": 2 * 1024 * 1024,
    "index.audio.position.worklet.js": 2 * 1024 * 1024,
}


class ReadbackError(RuntimeError):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        raise ReadbackError("redirect forbidden for original HTTPS byte proof")


def validate_url(url: str) -> str:
    parsed = urlsplit(url)
    if (parsed.scheme != "https" or parsed.hostname != "osgard.world"
        or parsed.path != "/games/omega-3d-preview/"
        or parsed.port not in (None, 443) or parsed.username is not None
        or parsed.password is not None or parsed.query or parsed.fragment):
        raise ReadbackError("only the exact pinned public HTTPS game path is allowed")
    return ALLOWED


def real_fetch(url: str):
    # HTTPS certificate checking is mandatory; redirects are never followed.
    opener = build_opener(
        NoRedirect(),
        HTTPSHandler(context=ssl.create_default_context()),
    )
    req = Request(url, headers={
        "Accept-Encoding": "identity", "Cache-Control": "no-cache",
        "User-Agent": "EMPIRE-OMEGA-R136-R87-readonly-verifier/1.0",
    }, method="GET")
    return opener.open(req, timeout=55)


def stream_response(fetch, url: str, cap: int, collect: bool = False) -> dict:
    with fetch(url) as response:
        status = getattr(response, "status", None)
        if status != 200:
            raise ReadbackError("HTTP %s for %s" % (status, url.rsplit("/", 1)[-1]))
        if response.geturl() != url:
            raise ReadbackError("unexpected final URL: redirect/proxy changed path")
        enc = str(response.headers.get("Content-Encoding", "identity")).lower()
        if enc not in ("identity", ""):
            raise ReadbackError("transformed/compressed response cannot prove original bytes")
        digest = hashlib.sha256()
        size = 0
        first = b""
        stored = bytearray() if collect else None
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            if size > cap:
                raise ReadbackError("download exceeds pinned resource size cap")
            if len(first) < 4:
                first = (first + chunk)[:4]
            digest.update(chunk)
            if stored is not None:
                stored.extend(chunk)
        if not size:
            raise ReadbackError("empty HTTPS response")
        return {
            "status": status,
            "bytes": size,
            "sha256": digest.hexdigest(),
            "magic4": first,
            "payload": bytes(stored) if stored is not None else None,
        }


def audit(fetch, expected: dict[str, str] | None = None,
          *, real_network: bool = False, base: str = ALLOWED) -> dict:
    record = {
        "schema": "empire-omega-r136-real-public-r87-https-v1",
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "tested_unmodified_public_url": base,
        "pinned_original_source": SOURCE_SHA,
        "expected_files": 7,
        "files": [],
        "errors": [],
        "manifest_verified": False,
        "all_seven_original_byte_digests_match": False,
        "live_public_r87_7_of_7_verified": False,
        "not_a_public_origin_or_vps_proof": True,
        "not_a_real_staging_rollback": True,
        "no_production_mutation": True,
        "aaa_art_approved": False,
        "physical_gpu_approved": False,
        "human_gameplay_approved": False,
        "production_authorized": False,
    }
    try:
        base = validate_url(base)
        expected = dict(PINNED_FILES if expected is None else expected)
        if set(expected) != set(PINNED_FILES):
            raise ReadbackError("all seven exact original R87 filenames required")
        raw = stream_response(fetch, base + "release.json", 128 * 1024, True)
        try:
            manifest = json.loads(raw["payload"].decode("utf-8"))
        except (UnicodeError, ValueError) as exc:
            raise ReadbackError("real HTTPS release.json invalid: %s" % exc) from exc
        problems = MANIFEST_VALIDATOR(manifest) if expected == PINNED_FILES else (
            [] if isinstance(manifest, dict) and
            manifest.get("source_commit") == SOURCE_SHA and
            manifest.get("files") == expected else ["test fixture manifest mismatch"]
        )
        if problems:
            raise ReadbackError("; ".join(problems))
        record["manifest_verified"] = True
        for name in sorted(PINNED_FILES):
            downloaded = stream_response(fetch, base + name, CAPS[name])
            actual = downloaded["sha256"]
            if name == "index.wasm" and downloaded["magic4"] != b"\x00asm":
                raise ReadbackError("real WebAssembly binary has invalid magic")
            if name == "index.pck" and downloaded["magic4"] != b"GDPC":
                raise ReadbackError("real Godot PCK binary has invalid magic")
            if actual != expected[name]:
                raise ReadbackError("public original R87 byte SHA-256 mismatch: " + name)
            record["files"].append({
                "name": name, "url": base + name,
                "http_status": 200, "bytes": downloaded["bytes"],
                "sha256": actual, "original_bytes_verified": True,
            })
        record["all_seven_original_byte_digests_match"] = len(record["files"]) == 7
        # Test-only fixtures can never be promoted to live public verification.
        record["live_public_r87_7_of_7_verified"] = (
            bool(real_network) and record["all_seven_original_byte_digests_match"])
    except (OSError, URLError, ReadbackError, ValueError, TypeError) as exc:
        record["errors"].append(str(exc))
    return record


def self_test() -> None:
    # Deterministic in-memory fixtures test our parser and fail-closed
    # guards. They are NEVER represented as live or as R87 production proof.
    samples = {name: (b"\x00asm" + b"fake-wasm" if name == "index.wasm"
                     else (b"GDPC" + b"fake-pck" if name == "index.pck"
                           else ("test-" + name).encode())) for name in PINNED_FILES}
    expected = {name: hashlib.sha256(value).hexdigest()
                for name, value in samples.items()}
    release = json.dumps({"source_commit": SOURCE_SHA, "files": expected}).encode()
    data = {"release.json": release, **samples}

    class Fake:
        def __init__(self, url: str, item: bytes, *, final_url: str | None = None,
                     status: int = 200, encoding: str = "identity"):
            self.status = status
            self.headers = {"Content-Encoding": encoding}
            self._url = final_url or url
            self._file = io.BytesIO(item)
        def __enter__(self): return self
        def __exit__(self, *_): self._file.close()
        def geturl(self): return self._url
        def read(self, size: int): return self._file.read(size)

    def fake(url):
        return Fake(url, data[url.rsplit("/", 1)[-1]])

    good = audit(fake, expected=expected, real_network=False)
    assert good["manifest_verified"] and good["all_seven_original_byte_digests_match"]
    assert not good["live_public_r87_7_of_7_verified"]
    assert good["production_authorized"] is False
    assert len(good["files"]) == 7
    try:
        validate_url("http://osgard.world/games/omega-3d-preview/")
        raise AssertionError("accepted insecure HTTP")
    except ReadbackError:
        pass
    try:
        validate_url("https://attacker.invalid/games/omega-3d-preview/")
        raise AssertionError("accepted external host")
    except ReadbackError:
        pass
    altered = dict(data)
    altered["index.pck"] = data["index.pck"] + b"extra"
    def wrong_pck(url): return Fake(url, altered[url.rsplit("/", 1)[-1]])
    assert not audit(wrong_pck, expected=expected)["all_seven_original_byte_digests_match"]
    def redirect(url): return Fake(url, data[url.rsplit("/", 1)[-1]], final_url=url+"?new")
    assert audit(redirect, expected=expected)["errors"]
    def gzip(url): return Fake(url, data[url.rsplit("/", 1)[-1]], encoding="gzip")
    assert audit(gzip, expected=expected)["errors"]
    def missing(url): return Fake(url, b"", status=404)
    assert audit(missing, expected=expected)["errors"]
    bad_manifest = dict(data)
    bad_manifest["release.json"] = b'{"source_commit":"0000000000000000000000000000000000000000","files":{}}'
    def changed(url): return Fake(url, bad_manifest[url.rsplit("/", 1)[-1]])
    assert not audit(changed, expected=expected)["manifest_verified"]
    print("R136 PASS: 7/7 synthetic unit fixtures; tamper/redirect/HTTP/gzip/missing/source all HOLD; 0 live claims")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--output", type=Path, help="write machine-readable evidence; never write binaries")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    evidence = audit(real_fetch, real_network=True)
    rendered = json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    print(rendered)
    if args.output:
        if args.output.is_symlink():
            print("R136 HOLD: output symlink forbidden", file=sys.stderr)
            return 2
        args.output.write_text(rendered, encoding="utf-8")
    return 0 if evidence["live_public_r87_7_of_7_verified"] else 1


if __name__ == "__main__":
    sys.exit(main())
