#!/usr/bin/env python3
"""R128 read-only R87 baseline/rollback preflight, NEVER deploy.

A matching *repository manifest* proves only an unchanged claimed release,
not a live publication or a rehearsed rollback. Optional --files-dir performs
independent 7/7 local byte verification (files must have been fetched
separately from the genuine live URL). It does not sign off art/hardware.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

PINNED_SOURCE_COMMIT = "43ae041e8df52418ca74c02405de9c196b59bd37"
PINNED_FILES = {
    "index.audio.position.worklet.js": "347b512529c5dca302093f7b9de6d184dd09d10e9a6fba62cbab098a891b2368",
    "index.audio.worklet.js": "5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3",
    "index.html": "d6582b09928afd70d67f666cc5b2653c9a6d5a1ec774b92ff44cf4f2d8bbe1b8",
    "index.js": "19eb180d568bb8e17bcf4c72ca034ed3af44deeb90304deefee4e665562dfe31",
    "index.pck": "c34d9b717b024bcec43239032d259229181568284186482ecfcd0f28e580fd4e",
    "index.png": "3cb4495c0b98dfbe4b663cbf2b6836473572339beb66d902367893162a70be0e",
    "index.wasm": "e4a43dbae28662b2a68f6136857a94db6695430901515800b9883f6327cb7116",
}


def inspect_manifest(data: dict) -> list[str]:
    problems = []
    if not isinstance(data, dict):
        return ["release manifest is not a JSON object"]
    if data.get("source_commit") != PINNED_SOURCE_COMMIT:
        problems.append("R87 public source_commit changed; stop and independently investigate")
    values = data.get("files")
    if not isinstance(values, dict):
        return problems + ["seven original file hashes are missing"]
    if set(values) != set(PINNED_FILES):
        problems.append("release manifest must contain exactly the seven original R87 filenames")
    for name, expected in PINNED_FILES.items():
        if values.get(name) != expected:
            problems.append("R87 manifest SHA changed/missing: " + name)
    return problems


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as reader:
        for block in iter(lambda: reader.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_downloaded_bytes(directory: Path) -> list[str]:
    """Read-only verification: input must be a separately acquired real 7-file copy.

    This routine deliberately cannot infer that those bytes came from production;
    a human must record the exact HTTPS download URL and timestamp separately.
    """
    errors = []
    if directory.is_symlink() or not directory.is_dir():
        return ["real seven-file download directory is absent or a symlink"]
    for name, expected in PINNED_FILES.items():
        path = directory / name
        if not path.is_file() or path.is_symlink() or path.resolve().parent != directory.resolve():
            errors.append("downloaded original file missing or unsafe: " + name)
            continue
        if path.stat().st_size == 0 or _sha256(path) != expected:
            errors.append("original downloaded byte SHA-256 mismatch: " + name)
            continue
        if name == "index.wasm" and path.read_bytes()[:4] != bytes((0, 97, 115, 109)):
            errors.append("Godot/WebAssembly binary magic invalid")
        if name == "index.pck" and path.read_bytes()[:4] != b"GDPC":
            errors.append("original Godot PCK magic invalid")
    return errors


def run_checks(manifest: dict, files_dir: Path | None) -> dict:
    problems = inspect_manifest(manifest)
    binary_errors = verify_downloaded_bytes(files_dir) if files_dir is not None else []
    return {
        "schema": "empire-omega-r128-r87-rollback-integrity-v1",
        "immutable_r87_source_commit": PINNED_SOURCE_COMMIT,
        "expected_r87_file_count": 7,
        "manifest_claims_match_pinned_r87": not problems,
        "actual_7_downloaded_bytes_verified": files_dir is not None and not binary_errors,
        "observations": problems + binary_errors,
        "not_a_liveness_probe": True,
        "not_independent_human_rollback_rehearsal": True,
        "not_aaa_art_review": True,
        "not_physical_phone_performance": True,
        "production_authorized": False,
    }


def self_test() -> None:
    good = {"source_commit": PINNED_SOURCE_COMMIT, "files": dict(PINNED_FILES)}
    assert inspect_manifest(good) == []
    changed = {"source_commit": PINNED_SOURCE_COMMIT, "files": dict(PINNED_FILES)}
    changed["files"]["index.pck"] = "0" * 64
    assert any("index.pck" in e for e in inspect_manifest(changed))
    changed["source_commit"] = "0" * 40
    assert any("source_commit" in e for e in inspect_manifest(changed))
    changed["files"]["extra.js"] = "0" * 64
    assert any("exactly" in e for e in inspect_manifest(changed))
    record = run_checks(good, None)
    assert record["manifest_claims_match_pinned_r87"]
    assert not record["actual_7_downloaded_bytes_verified"]
    assert record["production_authorized"] is False
    assert verify_downloaded_bytes(Path("/path/that/does/not/exist"))
    print("R128 R87 manifest tamper/7-byte-source HOLD self-test PASS (no production contacted)")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, help="R87 master release.json from checked Git source")
    parser.add_argument("--files-dir", type=Path, help="optional independently downloaded 7 live files")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if args.manifest is None or not args.manifest.is_file():
        parser.error("--manifest must be the actual master/R87 release.json")
    try:
        data = json.loads(args.manifest.read_text(encoding="utf-8"))
        result = run_checks(data, args.files_dir)
        printed = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        if args.output:
            args.output.write_text(printed, encoding="utf-8")
        print(printed)
        return 0 if result["manifest_claims_match_pinned_r87"] and (
            args.files_dir is None or result["actual_7_downloaded_bytes_verified"]
        ) else 1
    except (OSError, ValueError, json.JSONDecodeError) as err:
        print("R128 R87 HOLD: " + str(err), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
