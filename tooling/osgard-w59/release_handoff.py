#!/usr/bin/env python3
"""OSGARD W59: offline W58 asset byte integrity; NEVER hardware or production GO.

The published release SHA256SUMS is checked against an independently recorded
W52 full candidate digest. The hash list alone is not a trust anchor.
No network, extraction, device access, deployment, or GitHub credentials.
"""
import argparse
import hashlib
import json
import re
import stat
import zipfile
from pathlib import Path, PurePosixPath

SOURCE_SHA = "ef570cf6c406cc14ec180585ee2c5d64c667c658"
CANDIDATE_SHA256 = "d38390b6bc483431193ada34382330f101bb2aee3923f1eb619029f212fe7684"
CANDIDATE_NAME = f"OSGARD_OBSIDIAN_{SOURCE_SHA}.zip"
WEB_NAME = "OSGARD_W58_WEBGL_SOFTWARE_PREVIEW.zip"
WINDOWS_NAME = "OSGARD_W58_WINDOWS_SOFTWARE_PREVIEW.zip"
EVIDENCE_NAME = "OSGARD_W58_9OF9_SOFTWARE_EVIDENCE.zip"
ZIP_NAMES = frozenset((CANDIDATE_NAME, WEB_NAME, WINDOWS_NAME, EVIDENCE_NAME))
HEX64 = re.compile(r"^[0-9a-f]{64}$")
SUM_LINE = re.compile(r"^([0-9a-f]{64})\s+\*?([^\r\n]+)$")
MAX_ENTRY_BYTES = 512 * 1024 * 1024
MAX_ARCHIVE_BYTES = 1024 * 1024 * 1024


def insist(condition, message):
    if not condition:
        raise ValueError(message)


def file_sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(data)
    return digest.hexdigest()


def checksum_entries(raw):
    lines = raw.splitlines()
    insist(lines, "SHA256SUMS is empty")
    records = {}
    for line in lines:
        match = SUM_LINE.fullmatch(line)
        insist(match is not None, "Invalid SHA256SUMS line")
        sha, name = match.groups()
        insist(name in ZIP_NAMES and name not in records, "Unexpected or duplicated asset in SHA256SUMS")
        records[name] = sha
    insist(set(records) == ZIP_NAMES, "SHA256SUMS misses required preview asset")
    insist(records[CANDIDATE_NAME] == CANDIDATE_SHA256,
           "SHA256SUMS candidate digest differs from independent W52 proof")
    return records


def zip_entries(archive):
    entries = {}
    total = 0
    for info in archive.infolist():
        name = info.filename
        parts = PurePosixPath(name).parts
        insist(name and not name.startswith("/") and not name.startswith("\\")
               and "\\" not in name and ":" not in name and ".." not in parts
               and not any(p in ("", ".") for p in name.rstrip("/").split("/")),
               "Unsafe ZIP path")
        insist(not (info.flag_bits & 1), "Encrypted ZIP content not accepted")
        insist(not stat.S_ISLNK(info.external_attr >> 16), "ZIP symbolic link not accepted")
        if info.is_dir():
            continue
        insist(name not in entries, "Duplicate ZIP member")
        insist(info.file_size <= MAX_ENTRY_BYTES, "Oversized ZIP member")
        total += info.file_size
        insist(total <= MAX_ARCHIVE_BYTES, "Oversized ZIP payload")
        entries[name] = info
    insist(entries, "ZIP archive is empty")
    insist(archive.testzip() is None, "ZIP CRC verification failed")
    return entries


def signature(archive, entries, name, expected):
    insist(name in entries, "Required original game member missing: " + name)
    with archive.open(name) as stream:
        insist(stream.read(len(expected)) == expected, "Invalid game header: " + name)


def check_candidate(archive, entries, source_sha):
    insist("CANDIDATE_MANIFEST.json" in entries, "Original candidate manifest missing")
    manifest = json.loads(archive.read("CANDIDATE_MANIFEST.json"))
    insist(isinstance(manifest, dict), "Invalid candidate manifest")
    insist(manifest.get("source_commit") == source_sha, "Stale candidate source SHA")
    insist(manifest.get("godot") == "4.4.1", "Unexpected Godot version")
    insist(manifest.get("candidate_only") is True and manifest.get("production_modified") is False,
           "Candidate falsely claims production release")
    insist(manifest.get("physical_device_certified") is False
           and manifest.get("AAA_graphics_certified") is False,
           "Candidate falsely claims hardware or AAA certification")
    insist(manifest.get("browser_6_cases_verified") is True and
           manifest.get("windows_os_boot_verified") is True,
           "Missing exact-source software CI proof in candidate")
    files = manifest.get("files")
    insist(isinstance(files, list) and len(files) >= 30, "Incomplete original candidate manifest")
    seen = set()
    for item in files:
        insist(isinstance(item, dict), "Invalid original file record")
        name, size, digest = item.get("name"), item.get("bytes"), item.get("sha256")
        insist(isinstance(name, str) and name in entries and name not in seen,
               "Missing or duplicate manifest member")
        insist(type(size) is int and size >= 0 and entries[name].file_size == size,
               "Candidate size mismatch")
        insist(isinstance(digest, str) and HEX64.fullmatch(digest), "Invalid manifest digest")
        checksum = hashlib.sha256()
        with archive.open(name) as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                checksum.update(block)
        insist(checksum.hexdigest() == digest, "Candidate member digest mismatch: " + name)
        seen.add(name)
    insist(seen | {"CANDIDATE_MANIFEST.json"} == set(entries),
           "Unmanifested original candidate members")
    signature(archive, entries, "web/index.wasm", b"\x00asm")
    signature(archive, entries, "web/index.pck", b"GDPC")
    signature(archive, entries, "windows/OSGARD_FIELD_LAB_W33.exe", b"MZ")
    signature(archive, entries, "windows/OSGARD_FIELD_LAB_W33.pck", b"GDPC")
    return len(files)


def inspect_zip(path, name, source_sha):
    with zipfile.ZipFile(path) as archive:
        entries = zip_entries(archive)
        if name == CANDIDATE_NAME:
            count = check_candidate(archive, entries, source_sha)
            return {"members_verified": len(entries), "manifest_files_sha256_verified": count}
        if name == WEB_NAME:
            insist(any(x.endswith(".wasm") for x in entries)
                   and any(x.endswith(".pck") for x in entries)
                   and any(x.endswith(".js") for x in entries),
                   "WebGL preview lacks executable/PCK/WASM")
        elif name == WINDOWS_NAME:
            insist(any(x.endswith(".exe") for x in entries)
                   and any(x.endswith(".pck") for x in entries),
                   "Windows preview lacks EXE/PCK")
        return {"members_verified": len(entries)}


def verify(asset_dir, source_sha=SOURCE_SHA):
    insist(source_sha == SOURCE_SHA, "This handoff is pinned to W58 ef570cf exact SHA")
    insist(asset_dir.is_dir(), "Release assets directory not found")
    expected = ZIP_NAMES | {"SHA256SUMS.txt"}
    present = {p.name for p in asset_dir.iterdir() if p.is_file()}
    insist(present == expected, "Asset folder must contain exactly four preview ZIPs and SHA256SUMS.txt")
    checksum_path = asset_dir / "SHA256SUMS.txt"
    records = checksum_entries(checksum_path.read_text(encoding="utf-8-sig"))
    assets = {}
    for name in sorted(ZIP_NAMES):
        path = asset_dir / name
        insist(path.is_file(), "Missing original release asset " + name)
        digest = file_sha256(path)
        insist(digest == records[name], "Asset SHA256 mismatch: " + name)
        record = inspect_zip(path, name, source_sha)
        assets[name] = {"sha256": digest, "bytes": path.stat().st_size, **record}
    return {"schema": "OSGARD_W59_W58_OFFLINE_HANDOFF_V1",
            "release_source_sha": source_sha, "offline_integrity": "PASS",
            "assets": assets, "candidate_sha256_independent_w52": CANDIDATE_SHA256,
            "production_decision": "HOLD", "physical_hardware_certified": False,
            "visual_signoff": False, "master_merge_authorized": False,
            "production_published": False,
            "limitations": "Byte integrity and CI evidence only. No real GPU/phone test, no release GO."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source-sha", default=SOURCE_SHA)
    args = parser.parse_args()
    try:
        result = verify(args.asset_dir, args.source_sha)
        code = 0
    except (ValueError, OSError, zipfile.BadZipFile, json.JSONDecodeError, UnicodeError) as exc:
        result = {"schema": "OSGARD_W59_W58_OFFLINE_HANDOFF_V1",
                  "release_source_sha": args.source_sha, "offline_integrity": "FAIL",
                  "error": str(exc), "production_decision": "HOLD",
                  "physical_hardware_certified": False, "visual_signoff": False,
                  "master_merge_authorized": False, "production_published": False}
        code = 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"offline_integrity={result['offline_integrity']} production={result['production_decision']}")
    raise SystemExit(code)


if __name__ == "__main__":
    main()
